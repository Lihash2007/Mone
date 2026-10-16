import Foundation
import SQLite3
import WidgetKit
import Combine

// MARK: - Mone SQLite Database Manager
public final class MoneDatabase: ObservableObject {
    public static let shared = MoneDatabase()
    
    @Published public var transactions: [MoneTransaction] = []
    @Published public var accounts: [MoneAccount] = []
    @Published public var categories: [MoneCategory] = []
    @Published public var budgets: [String: Double] = [:]
    @Published public var totalBalance: Double = 0.0
    @Published public var todaySpent: Double = 0.0
    @Published public var monthlySpent: Double = 0.0
    @Published public var totalMonthlyBudget: Double = 50000.0
    
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.personalmoneyos.mone.database", qos: .userInitiated)
    
    private init() {
        openDatabase()
        createTables()
        seedDefaultsIfNeeded()
        reloadAllData()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Path Resolution
    private static func resolveDatabaseURL() -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("money_os_v8.db")
        if let groupURL = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.personalmoneyos.frontend")?.appendingPathComponent("money_os_v8.db") {
            if !fm.fileExists(atPath: groupURL.path) && fm.fileExists(atPath: docs.path) {
                try? fm.copyItem(at: docs, to: groupURL)
            }
            return groupURL
        }
        return docs
    }
    
    // MARK: - Open Connection
    private func openDatabase() {
        let dbURL = Self.resolveDatabaseURL()
        if sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            print("Failed to open SQLite database at \(dbURL.path)")
        } else {
            print("Successfully connected to SQLite database at \(dbURL.path)")
        }
    }
    
    // MARK: - Schema Creation
    private func createTables() {
        let queries = [
            """
            CREATE TABLE IF NOT EXISTS transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                merchant TEXT,
                category TEXT,
                amount REAL,
                type TEXT,
                date TEXT,
                goal_id INTEGER,
                account_id INTEGER,
                needs_review INTEGER DEFAULT 0
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS accounts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT,
                bank_name TEXT,
                bank_code TEXT,
                account_number TEXT,
                balance REAL,
                initial_balance REAL,
                type TEXT,
                include_in_total INTEGER DEFAULT 1
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT,
                type TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS budgets (
                category TEXT PRIMARY KEY,
                limit_amount REAL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value REAL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS processed_sms (
                date_id INTEGER PRIMARY KEY
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS user_profile (
                key TEXT PRIMARY KEY,
                value TEXT
            );
            """
        ]
        
        for sql in queries {
            execute(sql: sql)
        }
    }
    
    private func execute(sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let err = err {
                print("SQLite exec error: \(String(cString: err))")
                sqlite3_free(err)
            }
        }
    }
    
    // MARK: - Default Data Seeding
    private func seedDefaultsIfNeeded() {
        let existingAccounts = fetchAccountsInternal()
        if existingAccounts.isEmpty {
            let _ = insertAccountInternal(MoneAccount(
                name: "Primary HDFC",
                bankName: "HDFC Bank",
                bankCode: "hdfc",
                accountNumber: "4821",
                balance: 34500.0,
                type: "SAVINGS"
            ))
            let _ = insertAccountInternal(MoneAccount(
                name: "Cash Wallet",
                bankName: "Cash",
                bankCode: "cash",
                accountNumber: "",
                balance: 2450.0,
                type: "CASH"
            ))
        }
        
        let existingCategories = fetchCategoriesInternal()
        if existingCategories.isEmpty {
            let defaults: [(String, String)] = [
                ("Food & Dining", "EXPENSE"),
                ("Shopping", "EXPENSE"),
                ("Transport", "EXPENSE"),
                ("Bills & Utilities", "EXPENSE"),
                ("Groceries", "EXPENSE"),
                ("Entertainment", "EXPENSE"),
                ("Health & Fitness", "EXPENSE"),
                ("Investment", "EXPENSE"),
                ("Other", "EXPENSE"),
                ("Salary", "INCOME"),
                ("Freelance", "INCOME"),
                ("Investment Returns", "INCOME"),
                ("Gift", "INCOME")
            ]
            for (name, type) in defaults {
                let sql = "INSERT INTO categories (name, type) VALUES ('\(name)', '\(type)');"
                execute(sql: sql)
            }
        }
    }
    
    // MARK: - Public Reload
    public func reloadAllData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let txs = self.fetchTransactionsInternal()
            let accs = self.fetchAccountsInternal()
            let cats = self.fetchCategoriesInternal()
            let bdgs = self.fetchBudgetsInternal()
            let budgetSetting = self.fetchSettingInternal(key: "total_budget") ?? 50000.0
            
            // Calculate stats
            let now = Date()
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: now)
            
            var todaySpentCalc: Double = 0.0
            var monthlySpentCalc: Double = 0.0
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            
            for t in txs {
                let isExpense = t.type == "EXPENSE" || t.type == "TRANSFER_OUT"
                if isExpense {
                    if t.date >= todayStart {
                        todaySpentCalc += t.amount
                    }
                    let tMonth = calendar.component(.month, from: t.date)
                    let tYear = calendar.component(.year, from: t.date)
                    if tMonth == currentMonth && tYear == currentYear {
                        monthlySpentCalc += t.amount
                    }
                }
            }
            
            let totalBalCalc = accs.reduce(0.0) { $0 + ($1.includeInTotal ? $1.balance : 0.0) }
            
            DispatchQueue.main.async {
                self.transactions = txs
                self.accounts = accs
                self.categories = cats
                self.budgets = bdgs
                self.totalBalance = totalBalCalc
                self.todaySpent = todaySpentCalc
                self.monthlySpent = monthlySpentCalc
                self.totalMonthlyBudget = budgetSetting
                self.syncToWidgets(accs: accs, totalBal: totalBalCalc, todaySpent: todaySpentCalc, txs: txs)
            }
        }
    }
    
    // MARK: - Transactions Operations
    public func addTransaction(_ tx: MoneTransaction) {
        queue.async { [weak self] in
            guard let self = self else { return }
            _ = self.insertTransactionInternal(tx)
            
            // Update account balance
            if let accId = tx.accountId {
                let delta = (tx.type == "INCOME" || tx.type == "TRANSFER_IN") ? tx.amount : -tx.amount
                self.updateAccountBalanceInternal(id: accId, delta: delta)
            }
            self.reloadAllData()
            
            // Post dynamic island & notification if available
            if #available(iOS 16.1, *) {
                let isDebit = tx.type != "INCOME"
                let bankName = self.accounts.first(where: { $0.id == tx.accountId })?.name ?? "Account"
                MoneLiveActivityManager.showTransactionActivity(
                    amount: tx.amount,
                    merchant: tx.merchant,
                    bankName: bankName,
                    isDebit: isDebit,
                    balance: self.totalBalance - (isDebit ? tx.amount : -tx.amount)
                )
            }
        }
    }
    
    public func deleteTransaction(id: Int64) {
        queue.async { [weak self] in
            guard let self = self else { return }
            // Revert account balance
            if let target = self.transactions.first(where: { $0.id == id }), let accId = target.accountId {
                let revertDelta = (target.type == "INCOME" || target.type == "TRANSFER_IN") ? -target.amount : target.amount
                self.updateAccountBalanceInternal(id: accId, delta: revertDelta)
            }
            self.execute(sql: "DELETE FROM transactions WHERE id = \(id);")
            self.reloadAllData()
        }
    }
    
    public func updateTransaction(_ tx: MoneTransaction) {
        guard let id = tx.id else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            // Revert previous transaction balance effect
            if let existing = self.transactions.first(where: { $0.id == id }), let oldAccId = existing.accountId {
                let revertDelta = (existing.type == "INCOME" || existing.type == "TRANSFER_IN") ? -existing.amount : existing.amount
                self.updateAccountBalanceInternal(id: oldAccId, delta: revertDelta)
            }
            
            // Apply new transaction balance effect
            if let newAccId = tx.accountId {
                let applyDelta = (tx.type == "INCOME" || tx.type == "TRANSFER_IN") ? tx.amount : -tx.amount
                self.updateAccountBalanceInternal(id: newAccId, delta: applyDelta)
            }
            
            let iso = ISO8601DateFormatter().string(from: tx.date)
            let sql = """
            UPDATE transactions SET 
                merchant = '\(tx.merchant.replacingOccurrences(of: "'", with: "''"))',
                category = '\(tx.category.replacingOccurrences(of: "'", with: "''"))',
                amount = \(tx.amount),
                type = '\(tx.type)',
                date = '\(iso)',
                account_id = \(tx.accountId != nil ? "\(tx.accountId!)" : "NULL")
            WHERE id = \(id);
            """
            self.execute(sql: sql)
            self.reloadAllData()
        }
    }
    
    // MARK: - Accounts Operations
    public func addAccount(_ acc: MoneAccount) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let _ = self.insertAccountInternal(acc)
            self.reloadAllData()
        }
    }
    
    public func updateAccount(_ acc: MoneAccount) {
        guard let id = acc.id else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = """
            UPDATE accounts SET 
                name = '\(acc.name.replacingOccurrences(of: "'", with: "''"))',
                bank_name = '\(acc.bankName.replacingOccurrences(of: "'", with: "''"))',
                bank_code = '\(acc.bankCode)',
                account_number = '\(acc.accountNumber)',
                balance = \(acc.balance),
                type = '\(acc.type)',
                include_in_total = \(acc.includeInTotal ? 1 : 0)
            WHERE id = \(id);
            """
            self.execute(sql: sql)
            self.reloadAllData()
        }
    }
    
    public func deleteAccount(id: Int64) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.execute(sql: "DELETE FROM accounts WHERE id = \(id);")
            self.reloadAllData()
        }
    }
    
    // MARK: - Budgets & Settings
    public func setTotalBudget(_ budget: Double) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = "INSERT OR REPLACE INTO settings (key, value) VALUES ('total_budget', \(budget));"
            self.execute(sql: sql)
            self.reloadAllData()
        }
    }
    
    public func setCategoryBudget(category: String, limit: Double) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let safeCat = category.replacingOccurrences(of: "'", with: "''")
            let sql = "INSERT OR REPLACE INTO budgets (category, limit_amount) VALUES ('\(safeCat)', \(limit));"
            self.execute(sql: sql)
            self.reloadAllData()
        }
    }
    
    public func deleteCategoryBudget(category: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let safeCat = category.replacingOccurrences(of: "'", with: "''")
            let sql = "DELETE FROM budgets WHERE category = '\(safeCat)';"
            self.execute(sql: sql)
            self.reloadAllData()
        }
    }
    
    public func addCategory(name: String, type: String = "EXPENSE") {
        queue.async { [weak self] in
            guard let self = self else { return }
            let safeName = name.replacingOccurrences(of: "'", with: "''")
            let safeType = type.uppercased()
            let sql = "INSERT INTO categories (name, type) VALUES ('\(safeName)', '\(safeType)');"
            self.execute(sql: sql)
            self.reloadAllData()
        }
    }
    
    public func deleteCategory(id: Int64) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.execute(sql: "DELETE FROM categories WHERE id = \(id);")
            self.reloadAllData()
        }
    }
    
    // MARK: - Data Management & Reset
    public func clearAllTransactions() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.execute(sql: "DELETE FROM transactions;")
            self.reloadAllData()
        }
    }
    
    public func exportCSV() -> String {
        var csv = "\u{FEFF}ID,Date,Time,Type,Merchant,Category,Amount,Account\r\n"
        let dateF = DateFormatter()
        dateF.dateFormat = "yyyy-MM-dd"
        let timeF = DateFormatter()
        timeF.dateFormat = "HH:mm:ss"
        
        for t in transactions {
            let accName = accounts.first(where: { $0.id == t.accountId })?.name ?? "None"
            let cleanMerchant = t.merchant
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let cleanCat = t.category
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let cleanAcc = accName
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let dStr = dateF.string(from: t.date)
            let tStr = timeF.string(from: t.date)
            let amtStr = String(format: "%.2f", t.amount)
            csv += "\(t.id ?? 0),\(dStr),\(tStr),\(t.type),\"\(cleanMerchant)\",\"\(cleanCat)\",\(amtStr),\"\(cleanAcc)\"\r\n"
        }
        return csv
    }
    
    public func exportCSVFileURL() -> URL? {
        let csvContent = exportCSV()
        let fileDateF = DateFormatter()
        fileDateF.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "Mone_Statement_\(fileDateF.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to write CSV file: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func columnText(_ stmt: OpaquePointer?, _ index: Int32, default defaultVal: String = "") -> String {
        guard let ptr = sqlite3_column_text(stmt, index) else { return defaultVal }
        return String(cString: ptr)
    }
    
    // MARK: - Internal SQLite Helpers
    private func fetchTransactionsInternal() -> [MoneTransaction] {
        var list: [MoneTransaction] = []
        let sql = "SELECT id, merchant, category, amount, type, date, goal_id, account_id, needs_review FROM transactions ORDER BY date DESC;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let isoFormatter = ISO8601DateFormatter()
            let standardFormatter = DateFormatter()
            standardFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let merchant = columnText(stmt, 1)
                let category = columnText(stmt, 2)
                let amount = sqlite3_column_double(stmt, 3)
                let type = columnText(stmt, 4, default: "EXPENSE")
                let dateStr = columnText(stmt, 5)
                
                let date = isoFormatter.date(from: dateStr) ?? 
                           standardFormatter.date(from: dateStr) ?? 
                           ISO8601DateFormatter().date(from: dateStr) ?? 
                           Date()
                
                let goalId = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? sqlite3_column_int64(stmt, 6) : nil
                let accountId = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? sqlite3_column_int64(stmt, 7) : nil
                let needsReview = sqlite3_column_int(stmt, 8) == 1
                
                list.append(MoneTransaction(
                    id: id,
                    merchant: merchant,
                    category: category,
                    amount: amount,
                    type: type,
                    date: date,
                    goalId: goalId,
                    accountId: accountId,
                    needsReview: needsReview
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    private func insertTransactionInternal(_ tx: MoneTransaction) -> Int64 {
        let iso = ISO8601DateFormatter().string(from: tx.date)
        let safeMerchant = tx.merchant.replacingOccurrences(of: "'", with: "''")
        let safeCategory = tx.category.replacingOccurrences(of: "'", with: "''")
        let sql = """
        INSERT INTO transactions (merchant, category, amount, type, date, goal_id, account_id, needs_review)
        VALUES ('\(safeMerchant)', '\(safeCategory)', \(tx.amount), '\(tx.type)', '\(iso)', \(tx.goalId != nil ? "\(tx.goalId!)" : "NULL"), \(tx.accountId != nil ? "\(tx.accountId!)" : "NULL"), \(tx.needsReview ? 1 : 0));
        """
        execute(sql: sql)
        return sqlite3_last_insert_rowid(db)
    }
    
    private func fetchAccountsInternal() -> [MoneAccount] {
        var list: [MoneAccount] = []
        let sql = "SELECT id, name, bank_name, bank_code, account_number, balance, type, include_in_total FROM accounts;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let name = columnText(stmt, 1, default: "Account")
                let bankName = columnText(stmt, 2)
                let bankCode = columnText(stmt, 3)
                let accNum = columnText(stmt, 4)
                let balance = sqlite3_column_double(stmt, 5)
                let type = columnText(stmt, 6, default: "SAVINGS")
                let inc = sqlite3_column_int(stmt, 7) == 1
                
                list.append(MoneAccount(
                    id: id,
                    name: name,
                    bankName: bankName,
                    bankCode: bankCode,
                    accountNumber: accNum,
                    balance: balance,
                    type: type,
                    includeInTotal: inc
                ))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    private func insertAccountInternal(_ acc: MoneAccount) -> Int64 {
        let safeName = acc.name.replacingOccurrences(of: "'", with: "''")
        let safeBank = acc.bankName.replacingOccurrences(of: "'", with: "''")
        let sql = """
        INSERT INTO accounts (name, bank_name, bank_code, account_number, balance, initial_balance, type, include_in_total)
        VALUES ('\(safeName)', '\(safeBank)', '\(acc.bankCode)', '\(acc.accountNumber)', \(acc.balance), \(acc.balance), '\(acc.type)', \(acc.includeInTotal ? 1 : 0));
        """
        execute(sql: sql)
        return sqlite3_last_insert_rowid(db)
    }
    
    private func updateAccountBalanceInternal(id: Int64, delta: Double) {
        let sql = "UPDATE accounts SET balance = balance + (\(delta)) WHERE id = \(id);"
        execute(sql: sql)
    }
    
    private func fetchCategoriesInternal() -> [MoneCategory] {
        var list: [MoneCategory] = []
        let sql = "SELECT id, name, type FROM categories;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let name = columnText(stmt, 1)
                let type = columnText(stmt, 2, default: "EXPENSE")
                list.append(MoneCategory(id: id, name: name, type: type))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }
    
    private func fetchBudgetsInternal() -> [String: Double] {
        var dict: [String: Double] = [:]
        let sql = "SELECT category, limit_amount FROM budgets;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let cat = columnText(stmt, 0)
                let limit = sqlite3_column_double(stmt, 1)
                dict[cat] = limit
            }
        }
        sqlite3_finalize(stmt)
        return dict
    }
    
    private func fetchSettingInternal(key: String) -> Double? {
        let sql = "SELECT value FROM settings WHERE key = '\(key)';"
        var stmt: OpaquePointer?
        var val: Double? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                val = sqlite3_column_double(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        return val
    }
    
    // MARK: - Widget & App Group Sync
    private func syncToWidgets(accs: [MoneAccount], totalBal: Double, todaySpent: Double, txs: [MoneTransaction]) {
        let storage = UserDefaults(suiteName: "group.com.personalmoneyos.frontend") ?? UserDefaults.standard
        storage.set(totalBal, forKey: "raw_balance")
        storage.set(String(format: "₹ %.0f", totalBal), forKey: "balance")
        storage.set(todaySpent, forKey: "raw_today_spent")
        storage.set(String(format: "₹ %.0f", todaySpent), forKey: "today_spent")
        
        let names = accs.map { $0.name }
        storage.set(names, forKey: "user_account_names")
        
        let simplified = accs.map { ["id": $0.id ?? 0, "name": $0.name, "bank_name": $0.bankName, "balance": $0.balance] as [String : Any] }
        if let data = try? JSONSerialization.data(withJSONObject: simplified),
           let jsonStr = String(data: data, encoding: .utf8) {
            storage.set(jsonStr, forKey: "user_accounts_json")
        }
        
        if let first = txs.first {
            storage.set(first.merchant, forKey: "recent_merchant")
            let isIncome = first.type == "INCOME"
            storage.set(String(format: "%@₹%.0f", isIncome ? "+" : "-", first.amount), forKey: "recent_amount")
            let acc = accs.first(where: { $0.id == first.accountId })
            storage.set(acc?.name ?? "Account", forKey: "recent_bank")
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            storage.set(formatter.string(from: first.date), forKey: "recent_time")
        }
        storage.synchronize()
        
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
