import Foundation
import SwiftUI

// MARK: - Transaction Model
public struct MoneTransaction: Identifiable, Hashable {
    public var id: Int64?
    public var merchant: String
    public var category: String
    public var amount: Double
    public var type: String
    public var date: Date
    public var goalId: Int64?
    public var accountId: Int64?
    public var needsReview: Bool
    
    public init(
        id: Int64? = nil,
        merchant: String,
        category: String,
        amount: Double,
        type: String = "EXPENSE",
        date: Date = Date(),
        goalId: Int64? = nil,
        accountId: Int64? = nil,
        needsReview: Bool = false
    ) {
        self.id = id
        self.merchant = merchant
        self.category = category
        self.amount = amount
        self.type = type
        self.date = date
        self.goalId = goalId
        self.accountId = accountId
        self.needsReview = needsReview
    }
    
    public var isExpense: Bool {
        return type == "EXPENSE" || type == "TRANSFER_OUT"
    }
    
    public var formattedAmount: String {
        let prefix = isExpense ? "-₹" : "+₹"
        return String(format: "%@%.0f", prefix, amount)
    }
    
    public var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
    
    public var formattedDateHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let f = DateFormatter()
            f.dateFormat = "d MMMM, yyyy"
            return f.string(from: date)
        }
    }
    
    public var categoryIcon: String {
        return MoneCategory.icon(for: category)
    }
    
    public var categoryColor: Color {
        return MoneCategory.color(for: category)
    }
}

// MARK: - Account Model
public struct MoneAccount: Identifiable, Hashable {
    public var id: Int64?
    public var name: String
    public var bankName: String
    public var bankCode: String
    public var accountNumber: String
    public var balance: Double
    public var type: String
    public var includeInTotal: Bool
    
    public init(
        id: Int64? = nil,
        name: String,
        bankName: String,
        bankCode: String = "",
        accountNumber: String = "",
        balance: Double = 0.0,
        type: String = "SAVINGS",
        includeInTotal: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bankName = bankName
        self.bankCode = bankCode
        self.accountNumber = accountNumber
        self.balance = balance
        self.type = type
        self.includeInTotal = includeInTotal
    }
    
    public var bankInfo: BankInfo {
        if type.uppercased() == "CASH" {
            return IndianBankDirectory.cash
        }
        return IndianBankDirectory.findBank(codeOrName: bankCode.isEmpty ? bankName : bankCode)
    }
    
    public var formattedBalance: String {
        return String(format: "₹ %.0f", balance)
    }
    
    public var maskedNumber: String {
        if accountNumber.isEmpty { return "" }
        if accountNumber.count <= 4 { return "••\(accountNumber)" }
        return "••\(accountNumber.suffix(4))"
    }
}

// MARK: - Category Model
public struct MoneCategory: Identifiable, Hashable {
    public var id: Int64?
    public var name: String
    public var type: String
    
    public init(id: Int64? = nil, name: String, type: String = "EXPENSE") {
        self.id = id
        self.name = name
        self.type = type
    }
    
    public var icon: String {
        return MoneCategory.icon(for: name)
    }
    
    public var color: Color {
        return MoneCategory.color(for: name)
    }
    
    public static func icon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("food") || lower.contains("dine") || lower.contains("dining") || lower.contains("restaurant") {
            return "fork.knife"
        } else if lower.contains("shop") || lower.contains("cloth") {
            return "bag.fill"
        } else if lower.contains("transp") || lower.contains("travel") || lower.contains("fuel") || lower.contains("petrol") {
            return "car.fill"
        } else if lower.contains("bill") || lower.contains("util") || lower.contains("electric") {
            return "bolt.fill"
        } else if lower.contains("groc") || lower.contains("supermarket") {
            return "cart.fill"
        } else if lower.contains("entertain") || lower.contains("movie") || lower.contains("spotify") {
            return "tv.fill"
        } else if lower.contains("health") || lower.contains("fit") || lower.contains("med") {
            return "heart.fill"
        } else if lower.contains("sal") || lower.contains("income") || lower.contains("earn") {
            return "banknote.fill"
        } else if lower.contains("invest") || lower.contains("stock") {
            return "chart.line.uptrend.xyaxis"
        }
        return "tag.fill"
    }
    
    public static func color(for name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("food") { return Color(hex: "F59E0B") }
        if lower.contains("shop") { return Color(hex: "EC4899") }
        if lower.contains("transp") { return Color(hex: "3B82F6") }
        if lower.contains("bill") { return Color(hex: "8B5CF6") }
        if lower.contains("groc") { return Color(hex: "10B981") }
        if lower.contains("sal") { return Color(hex: "059669") }
        if lower.contains("invest") { return Color(hex: "6366F1") }
        return Color(hex: "6B7280")
    }
}

// MARK: - Monthly Trend Model (For Apple Charts)
public struct MonthlyTrend: Identifiable, Hashable {
    public var id: String { monthKey }
    public var monthKey: String
    public var monthLabel: String
    public var expenseTotal: Double
    public var incomeTotal: Double
    public var deltaPercent: Double?
    
    public init(
        monthKey: String,
        monthLabel: String,
        expenseTotal: Double,
        incomeTotal: Double = 0.0,
        deltaPercent: Double? = nil
    ) {
        self.monthKey = monthKey
        self.monthLabel = monthLabel
        self.expenseTotal = expenseTotal
        self.incomeTotal = incomeTotal
        self.deltaPercent = deltaPercent
    }
}
