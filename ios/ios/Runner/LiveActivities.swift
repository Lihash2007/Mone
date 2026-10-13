import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes (iOS 16.1+)
@available(iOS 16.1, *)
public struct MoneTransactionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var amount: String
        public var merchant: String
        public var bankName: String
        public var isDebit: Bool
        public var balance: String
        public var timestamp: Date

        public init(amount: String, merchant: String, bankName: String, isDebit: Bool, balance: String, timestamp: Date = Date()) {
            self.amount = amount
            self.merchant = merchant
            self.bankName = bankName
            self.isDebit = isDebit
            self.balance = balance
            self.timestamp = timestamp
        }
    }

    public var transactionId: String

    public init(transactionId: String = UUID().uuidString) {
        self.transactionId = transactionId
    }
}

// MARK: - Live Activity Manager
@available(iOS 16.1, *)
public class MoneLiveActivityManager {
    public static func showTransactionActivity(
        amount: Double,
        merchant: String,
        bankName: String,
        isDebit: Bool,
        balance: Double?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let amountStr = String(format: "₹%.0f", amount)
        let balStr = balance != nil ? String(format: "₹%.0f", balance!) : "Updated"

        let state = MoneTransactionAttributes.ContentState(
            amount: amountStr,
            merchant: merchant,
            bankName: bankName,
            isDebit: isDebit,
            balance: balStr,
            timestamp: Date()
        )

        let attributes = MoneTransactionAttributes()

        do {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15))
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                // Auto-dismiss Dynamic Island heads-up after 6 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
                }
            } else {
                let activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
                Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    await activity.end(using: state, dismissalPolicy: .immediate)
                }
            }
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
}
