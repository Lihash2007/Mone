import Foundation
import AppIntents
import ActivityKit
import UserNotifications

// MARK: - 0. Notification Categories Registration
public func registerMoneNotificationCategories() {
    let confirmAction = UNNotificationAction(
        identifier: "confirm_ok",
        title: "Confirm",
        options: []
    )
    let transferAction = UNNotificationAction(
        identifier: "change_transfer",
        title: "Transfer",
        options: []
    )
    let incomeAction = UNNotificationAction(
        identifier: "change_income",
        title: "Income",
        options: []
    )
    let category = UNNotificationCategory(
        identifier: "transaction_actions",
        actions: [confirmAction, transferAction, incomeAction],
        intentIdentifiers: [],
        options: [.customDismissAction]
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
}

// MARK: - 1. Shared Storage (App Group + Standard Fallback)
public struct MoneSharedStorage {
    private static let appGroupId = "group.com.personalmoneyos.frontend"
    
    private static var storage: UserDefaults {
        return UserDefaults(suiteName: appGroupId) ?? UserDefaults.standard
    }
    
    public static func enqueuePendingTransaction(_ txData: [String: Any]) {
        var list: [[String: Any]] = []
        if let currentJson = storage.string(forKey: "pending_transactions_json"),
           let data = currentJson.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            list = decoded
        }
        list.append(txData)
        if let newData = try? JSONSerialization.data(withJSONObject: list),
           let jsonStr = String(data: newData, encoding: .utf8) {
            storage.set(jsonStr, forKey: "pending_transactions_json")
            storage.synchronize()
        }
    }

    public static func updatePendingTransaction(id: String, actionId: String) {
        var list: [[String: Any]] = []
        if let currentJson = storage.string(forKey: "pending_transactions_json"),
           let data = currentJson.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            list = decoded
        }
        for i in 0..<list.count {
            if let txId = list[i]["id"] as? String, txId == id {
                if actionId == "confirm_ok" {
                    list[i]["confirmed"] = true
                } else if actionId == "change_transfer" {
                    list[i]["type"] = "TRANSFER"
                    list[i]["confirmed"] = true
                } else if actionId == "change_income" {
                    list[i]["type"] = "INCOME"
                    list[i]["confirmed"] = true
                }
            }
        }
        if let newData = try? JSONSerialization.data(withJSONObject: list),
           let jsonStr = String(data: newData, encoding: .utf8) {
            storage.set(jsonStr, forKey: "pending_transactions_json")
            storage.synchronize()
        }
    }
    
    public static func recordTransaction(amount: Double, isDebit: Bool, merchant: String, bankName: String, balance: Double?) {
        let currentToday = storage.double(forKey: "raw_today_spent")
        let currentTxCount = storage.integer(forKey: "raw_tx_count_today")
        let currentBalance = storage.double(forKey: "raw_balance")
        
        let newToday = isDebit ? currentToday + amount : currentToday
        let newCount = currentTxCount + 1
        let newBalance = balance ?? (isDebit ? currentBalance - amount : currentBalance + amount)
        
        storage.set(newToday, forKey: "raw_today_spent")
        storage.set(newCount, forKey: "raw_tx_count_today")
        storage.set(newBalance, forKey: "raw_balance")
        
        storage.set(String(format: "₹ %.0f", newBalance), forKey: "balance")
        storage.set(String(format: "₹ %.0f", newToday), forKey: "today_spent")
        storage.set(merchant, forKey: "recent_merchant")
        storage.set(String(format: "%@₹%.0f", isDebit ? "-" : "+", amount), forKey: "recent_amount")
        storage.set(bankName, forKey: "recent_bank")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        storage.set(formatter.string(from: Date()), forKey: "recent_time")
        storage.synchronize()
    }
    
    public static func getDailyStats() -> (todaySpent: Double, count: Int, balance: Double) {
        let spent = storage.double(forKey: "raw_today_spent")
        let count = storage.integer(forKey: "raw_tx_count_today")
        let bal = storage.double(forKey: "raw_balance")
        return (spent, count, bal)
    }
}

// MARK: - 2. Native Swift SMS Parser for Indian Banking
public struct MoneSmsParser {
    public struct ParsedResult {
        public var isValid: Bool
        public var amount: Double
        public var isDebit: Bool
        public var merchant: String
        public var bankName: String
        public var accountMask: String
        public var availableBalance: Double?
    }
    
    public static func parse(text: String, sender: String? = nil) -> ParsedResult {
        let clean = text.replacingOccurrences(of: "\n", with: " ")
        
        // 1. Direction: Debit vs Credit
        let debitRegex = try? NSRegularExpression(pattern: "(?i)\\b(debited|spent|paid|withdrawn|deducted|dr|purchased)\\b")
        let creditRegex = try? NSRegularExpression(pattern: "(?i)\\b(credited|received|added|deposited|refunded|cr)\\b")
        
        let hasDebit = debitRegex?.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)) != nil
        let hasCredit = creditRegex?.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)) != nil
        
        guard hasDebit || hasCredit else {
            return ParsedResult(isValid: false, amount: 0, isDebit: true, merchant: "", bankName: "", accountMask: "", availableBalance: nil)
        }
        let isDebit = hasDebit
        
        // 2. Amount Extraction (₹, Rs, INR)
        var extractedAmount: Double = 0.0
        let amountPattern = "(?i)(?:rs\\.?|inr|₹|inr\\.)\\s*([\\d,]+(?:\\.\\d{1,2})?)"
        if let regex = try? NSRegularExpression(pattern: amountPattern),
           let match = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
           let range = Range(match.range(at: 1), in: clean) {
            let str = clean[range].replacingOccurrences(of: ",", with: "")
            extractedAmount = Double(str) ?? 0.0
        }
        guard extractedAmount > 0 else {
            return ParsedResult(isValid: false, amount: 0, isDebit: isDebit, merchant: "", bankName: "", accountMask: "", availableBalance: nil)
        }
        
        // 3. Bank Identification
        var bankName = "Bank"
        let upper = clean.uppercased()
        let senderUpper = (sender ?? "").uppercased()
        if upper.contains("HDFC") || senderUpper.contains("HDFC") { bankName = "HDFC Bank" }
        else if upper.contains("SBI") || upper.contains("STATE BANK") || senderUpper.contains("SBI") { bankName = "State Bank of India" }
        else if upper.contains("ICICI") || senderUpper.contains("ICICI") { bankName = "ICICI Bank" }
        else if upper.contains("AXIS") || senderUpper.contains("AXIS") { bankName = "Axis Bank" }
        else if upper.contains("KOTAK") || senderUpper.contains("KOTAK") { bankName = "Kotak Mahindra" }
        else if upper.contains("PUNJAB NATIONAL") || upper.contains("PNB") { bankName = "PNB" }
        else if upper.contains("CANARA") { bankName = "Canara Bank" }
        else if upper.contains("BARODA") || upper.contains("BOB") { bankName = "Bank of Baroda" }
        else if upper.contains("PAYTM") { bankName = "Paytm Payments Bank" }
        else if upper.contains("CRED") { bankName = "CRED" }
        else if upper.contains("INDUSIND") { bankName = "IndusInd Bank" }
        
        // 4. Merchant Extraction
        var merchant = isDebit ? "Expense" : "Deposit"
        let merchantPatterns = [
            "(?i)(?:at|to|info\\/|vpa)\\s+([A-Za-z0-9\\.\\*\\-@_]{3,24})",
            "(?i)towards\\s+([A-Za-z0-9\\.\\*\\-@_]{3,24})"
        ]
        for pattern in merchantPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
               let range = Range(match.range(at: 1), in: clean) {
                let candidate = String(clean[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.lowercased().contains("account") && !candidate.lowercased().contains("a/c") && !candidate.lowercased().contains("card") {
                    merchant = candidate
                    break
                }
            }
        }
        
        // 5. Account Mask
        var mask = ""
        let maskPattern = "(?i)(?:a\\/c|acct|account|card|ending)\\s*(?:no\\.?)?\\s*[xX\\*]*(\\d{3,5})"
        if let regex = try? NSRegularExpression(pattern: maskPattern),
           let match = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
           let range = Range(match.range(at: 1), in: clean) {
            mask = String(clean[range])
        }
        
        // 6. Available Balance Ground Truth
        var balance: Double? = nil
        let balPattern = "(?i)(?:bal|avl\\s*bal|avail|balance)\\s*(?:is|:)?\\s*(?:rs\\.?|inr|₹)?\\s*([\\d,]+(?:\\.\\d{1,2})?)"
        if let regex = try? NSRegularExpression(pattern: balPattern),
           let match = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
           let range = Range(match.range(at: 1), in: clean) {
            let str = clean[range].replacingOccurrences(of: ",", with: "")
            balance = Double(str)
        }
        
        return ParsedResult(
            isValid: true,
            amount: extractedAmount,
            isDebit: isDebit,
            merchant: merchant,
            bankName: bankName,
            accountMask: mask,
            availableBalance: balance
        )
    }
}

// MARK: - 3. Headless Background Intent for Shortcuts (Log Bank SMS)
@available(iOS 16.0, *)
public struct LogBankSmsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Log Bank SMS in mone"
    public static var description = IntentDescription("Silently logs an Indian banking SMS transaction in mone without opening the app.")
    
    // Headless background execution:
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "SMS Body", description: "The message body from the bank SMS")
    public var smsText: String
    
    @Parameter(title: "Sender Address", description: "The sender address header (e.g., AD-HDFCBK)", default: nil)
    public var senderAddress: String?
    
    public init() {}
    
    public static var parameterSummary: some ParameterSummary {
        Summary("Log bank SMS in mone")
    }
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = smsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Message text was empty.")
        }
        
        // Anti-Fraud check
        let lower = trimmed.lowercased()
        let scamKeywords = ["otp", "one time password", "verification code", "pre-approved", "apply now", "loan approved", "win up to", "claim your prize"]
        for kw in scamKeywords {
            if lower.contains(kw) {
                return .result(dialog: "Ignored non-transaction or promotional message.")
            }
        }
        
        let parsed = MoneSmsParser.parse(text: trimmed, sender: senderAddress)
        guard parsed.isValid else {
            return .result(dialog: "Message does not match a verified transaction.")
        }
        
        let notifId = UUID().uuidString
        let isoDate = ISO8601DateFormatter().string(from: Date())
        
        // Save to Shared Queue for Flutter SQLite sync
        MoneSharedStorage.enqueuePendingTransaction([
            "id": notifId,
            "rawBody": trimmed,
            "sender": senderAddress ?? "",
            "amount": parsed.amount,
            "merchant": parsed.merchant,
            "type": parsed.isDebit ? "EXPENSE" : "INCOME",
            "bankName": parsed.bankName,
            "accountMask": parsed.accountMask,
            "availableBalance": parsed.availableBalance ?? 0.0,
            "timestamp": isoDate,
            "confirmed": false
        ])
        
        MoneSharedStorage.recordTransaction(
            amount: parsed.amount,
            isDebit: parsed.isDebit,
            merchant: parsed.merchant,
            bankName: parsed.bankName,
            balance: parsed.availableBalance
        )
        
        // Show Dynamic Island / Live Activity (if enabled)
        if #available(iOS 16.1, *) {
            MoneLiveActivityManager.showTransactionActivity(
                amount: parsed.amount,
                merchant: parsed.merchant,
                bankName: parsed.bankName,
                isDebit: parsed.isDebit,
                balance: parsed.availableBalance
            )
        }
        
        // Ensure action categories are registered before scheduling
        registerMoneNotificationCategories()
        
        // Post Native Interactive Notification Banner (with Confirm, Transfer, Income buttons)
        let center = UNUserNotificationCenter.current()
        let notifContent = UNMutableNotificationContent()
        notifContent.title = parsed.isDebit ? "₹\(String(format: "%.0f", parsed.amount)) Spent" : "₹\(String(format: "%.0f", parsed.amount)) Received"
        var bodyStr = "\(parsed.merchant) • \(parsed.bankName)"
        if let bal = parsed.availableBalance {
            bodyStr += " • Avl: ₹\(String(format: "%.0f", bal))"
        }
        bodyStr += "\nHold banner to Confirm or Transfer."
        notifContent.body = bodyStr
        notifContent.sound = .default
        notifContent.categoryIdentifier = "transaction_actions"
        notifContent.userInfo = [
            "id": notifId,
            "amount": parsed.amount,
            "merchant": parsed.merchant,
            "type": parsed.isDebit ? "EXPENSE" : "INCOME",
            "bankName": parsed.bankName
        ]
        
        let notifTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let notifRequest = UNNotificationRequest(identifier: notifId, content: notifContent, trigger: notifTrigger)
        center.add(notifRequest) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
        
        let typeStr = parsed.isDebit ? "debited at" : "credited from"
        return .result(dialog: "Recorded ₹\(String(format: "%.0f", parsed.amount)) \(typeStr) \(parsed.merchant) in mone.")
    }
}

// MARK: - 4. Interactive Log Transaction Intent (Shortcut & Siri Entry)
@available(iOS 16.0, *)
public struct QuickLogExpenseIntent: AppIntent {
    public static var title: LocalizedStringResource = "Log Transaction in mone"
    public static var description = IntentDescription("Log an expense or income with category and account directly in mone.")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Type (Expense or Income)", default: "Expense")
    public var type: String
    
    @Parameter(title: "Amount (₹)")
    public var amount: Double
    
    @Parameter(title: "Category", default: "Food")
    public var category: String
    
    @Parameter(title: "Account / Bank", default: "Primary Account")
    public var bankName: String

    @Parameter(title: "Merchant / Title", default: "Expense")
    public var merchant: String
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "Please provide a valid amount greater than 0.")
        }
        let cleanType = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isDebit = !cleanType.contains("income") && !cleanType.contains("credit") && !cleanType.contains("deposit")
        let cleanMerchant = merchant.isEmpty ? (isDebit ? "Expense" : "Income") : merchant
        let cleanCategory = category.isEmpty ? (isDebit ? "General" : "Salary") : category
        let notifId = UUID().uuidString
        let isoDate = ISO8601DateFormatter().string(from: Date())
        
        MoneSharedStorage.enqueuePendingTransaction([
            "id": notifId,
            "rawBody": "\(cleanMerchant) - ₹\(amount)",
            "sender": "QuickLog",
            "amount": amount,
            "merchant": cleanMerchant,
            "category": cleanCategory,
            "type": isDebit ? "EXPENSE" : "INCOME",
            "bankName": bankName,
            "accountMask": "",
            "availableBalance": 0.0,
            "timestamp": isoDate,
            "confirmed": true
        ])
        
        MoneSharedStorage.recordTransaction(
            amount: amount,
            isDebit: isDebit,
            merchant: cleanMerchant,
            bankName: bankName,
            balance: nil
        )
        
        registerMoneNotificationCategories()
        let center = UNUserNotificationCenter.current()
        let notifContent = UNMutableNotificationContent()
        notifContent.title = "₹\(String(format: "%.0f", amount)) \(isDebit ? "Spent" : "Received")"
        notifContent.body = "\(cleanMerchant) • \(cleanCategory) • \(bankName)"
        notifContent.sound = .default
        notifContent.categoryIdentifier = "transaction_actions"
        notifContent.userInfo = [
            "id": notifId,
            "amount": amount,
            "merchant": cleanMerchant,
            "type": isDebit ? "EXPENSE" : "INCOME",
            "bankName": bankName
        ]
        
        let notifTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let notifRequest = UNNotificationRequest(identifier: notifId, content: notifContent, trigger: notifTrigger)
        center.add(notifRequest, withCompletionHandler: nil)
        
        return .result(dialog: "Logged ₹\(String(format: "%.0f", amount)) for \(cleanMerchant) in mone.")
    }
}

// MARK: - 5. Siri Daily Spending Intent
@available(iOS 16.0, *)
public struct CheckDailySpendingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Daily Spending"
    public static var description = IntentDescription("Answers how much money was spent today in mone via Siri.")
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let stats = MoneSharedStorage.getDailyStats()
        if stats.count == 0 {
            return .result(dialog: "You haven't recorded any expenses today. Remaining balance is ₹\(String(format: "%.0f", stats.balance)).")
        }
        let dialog = "You have spent ₹\(String(format: "%.0f", stats.todaySpent)) today across \(stats.count) transactions. Current balance is ₹\(String(format: "%.0f", stats.balance))."
        return .result(dialog: "\(dialog)")
    }
}

// MARK: - 6. Siri Balance Check Intent
@available(iOS 16.0, *)
public struct GetBalanceIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Total Balance"
    public static var description = IntentDescription("Answers your total available balance in mone via Siri.")
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let stats = MoneSharedStorage.getDailyStats()
        return .result(dialog: "Your total available balance in mone is ₹\(String(format: "%.0f", stats.balance)).")
    }
}

// MARK: - 7. Siri App Shortcuts Provider
@available(iOS 16.0, *)
public struct MoneShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckDailySpendingIntent(),
            phrases: [
                "Check daily spending in \(.applicationName)",
                "How much did I spend today on \(.applicationName)?",
                "What's my spending today in \(.applicationName)?"
            ],
            shortTitle: "Daily Spending",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: GetBalanceIntent(),
            phrases: [
                "Check my balance in \(.applicationName)",
                "What's my balance in \(.applicationName)?"
            ],
            shortTitle: "Account Balance",
            systemImageName: "indianrupeesign.circle.fill"
        )
        AppShortcut(
            intent: QuickLogExpenseIntent(),
            phrases: [
                "Log expense in \(.applicationName)",
                "Quick log in \(.applicationName)"
            ],
            shortTitle: "Quick Log",
            systemImageName: "plus.circle.fill"
        )
    }
}
