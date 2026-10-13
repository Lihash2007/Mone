import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 1. Interactive Privacy Intent (iOS 17+)
@available(iOS 17.0, *)
public struct TogglePrivacyIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Privacy"
    public static var description = IntentDescription("Hides or reveals the balance on the mone widget.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        let storage = UserDefaults(suiteName: "group.com.personalmoneyos.frontend") ?? UserDefaults.standard
        let current = storage.bool(forKey: "is_privacy_active")
        storage.set(!current, forKey: "is_privacy_active")
        storage.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - 2. Timeline Provider
public struct MoneWidgetEntry: TimelineEntry {
    public let date: Date
    public let balance: String
    public let todaySpent: String
    public let recentMerchant: String
    public let recentAmount: String
    public let recentBank: String
    public let recentTime: String
    public let isPrivate: Bool
}

public struct MoneTimelineProvider: TimelineProvider {
    public func placeholder(in context: Context) -> MoneWidgetEntry {
        MoneWidgetEntry(
            date: Date(),
            balance: "₹ 34,500",
            todaySpent: "₹ 450",
            recentMerchant: "Swiggy",
            recentAmount: "-₹350",
            recentBank: "HDFC Bank",
            recentTime: "10:30 PM",
            isPrivate: false
        )
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (MoneWidgetEntry) -> ()) {
        completion(fetchCurrentEntry())
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<MoneWidgetEntry>) -> ()) {
        let entry = fetchCurrentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchCurrentEntry() -> MoneWidgetEntry {
        let storage = UserDefaults(suiteName: "group.com.personalmoneyos.frontend") ?? UserDefaults.standard
        let bal = storage.string(forKey: "balance") ?? "₹ 0"
        let spent = storage.string(forKey: "today_spent") ?? "₹ 0"
        let merchant = storage.string(forKey: "recent_merchant") ?? "mone OS"
        let amount = storage.string(forKey: "recent_amount") ?? "Active"
        let bank = storage.string(forKey: "recent_bank") ?? "Bank"
        let time = storage.string(forKey: "recent_time") ?? "Today"
        let isPrivate = storage.bool(forKey: "is_privacy_active")
        
        return MoneWidgetEntry(
            date: Date(),
            balance: bal,
            todaySpent: spent,
            recentMerchant: merchant,
            recentAmount: amount,
            recentBank: bank,
            recentTime: time,
            isPrivate: isPrivate
        )
    }
}

// MARK: - 3. Widget Views (Small & Medium)
public struct MoneWidgetEntryView: View {
    public var entry: MoneWidgetEntry
    @Environment(\.widgetFamily) var family

    public var body: some View {
        ZStack {
            Color(red: 9/255, green: 9/255, blue: 11/255)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 6) {
                // Header: Logo & Today's Spent
                HStack {
                    Text("mone")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(red: 129/255, green: 140/255, blue: 248/255), Color(red: 192/255, green: 132/255, blue: 252/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Spacer()
                    if #available(iOS 17.0, *) {
                        Button(intent: TogglePrivacyIntent()) {
                            Image(systemName: entry.isPrivate ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Balance
                VStack(alignment: .leading, spacing: 1) {
                    Text("TOTAL NET WORTH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                        .tracking(1.0)
                    
                    Text(entry.isPrivate ? "••••••" : entry.balance)
                        .font(.system(size: family == .systemSmall ? 20 : 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Bottom Row / Recent Tx
                if family == .systemMedium {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RECENT ACTIVITY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.4))
                            HStack(spacing: 4) {
                                Text(entry.recentBank)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(red: 129/255, green: 140/255, blue: 248/255))
                                Text("•")
                                    .foregroundColor(Color.white.opacity(0.3))
                                Text(entry.recentMerchant)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("TODAY SPENT")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.4))
                            Text(entry.isPrivate ? "•••" : entry.todaySpent)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                } else {
                    HStack {
                        Text("Today:")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.5))
                        Text(entry.isPrivate ? "•••" : entry.todaySpent)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 255/255, green: 69/255, blue: 58/255))
                    }
                }
            }
            .padding(14)
        }
    }
}

// MARK: - 4. Home Screen Widget Definition
public struct MoneBalanceWidget: Widget {
    public let kind: String = "MoneBalanceWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoneTimelineProvider()) { entry in
            MoneWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("mone Balance")
        .description("Track your live net worth and daily expenses at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 5. Live Activity & Dynamic Island Widget (iOS 16.1+)
@available(iOS 16.1, *)
public struct MoneLiveActivityWidget: Widget {
    public let kind: String = "MoneLiveActivityWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: MoneTransactionAttributes.self) { context in
            // Lock Screen / Notification Banner View
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(context.state.isDebit ? Color(red: 255/255, green: 59/255, blue: 48/255).opacity(0.2) : Color(red: 52/255, green: 199/255, blue: 89/255).opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: context.state.isDebit ? "arrow.down.right" : "arrow.up.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(context.state.isDebit ? Color(red: 255/255, green: 59/255, blue: 48/255) : Color(red: 52/255, green: 199/255, blue: 89/255))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.merchant)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(context.state.bankName) • Bal: \(context.state.balance)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                
                Spacer()
                
                Text(context.state.amount)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(context.state.isDebit ? Color(red: 255/255, green: 59/255, blue: 48/255) : Color(red: 52/255, green: 199/255, blue: 89/255))
            }
            .padding()
            .background(Color(red: 18/255, green: 18/255, blue: 20/255))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isDebit ? "creditcard.fill" : "banknote.fill")
                            .foregroundColor(Color(red: 129/255, green: 140/255, blue: 248/255))
                        VStack(alignment: .leading) {
                            Text(context.state.bankName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.6))
                            Text(context.state.merchant)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.state.amount)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(context.state.isDebit ? Color(red: 255/255, green: 59/255, blue: 48/255) : Color(red: 52/255, green: 199/255, blue: 89/255))
                        Text("Bal: \(context.state.balance)")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("mone Autonomous Ledger")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))
                        Spacer()
                        Text("Updated in background")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(red: 52/255, green: 199/255, blue: 89/255))
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: context.state.isDebit ? "arrow.down.forward" : "arrow.up.forward")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(context.state.isDebit ? Color(red: 255/255, green: 59/255, blue: 48/255) : Color(red: 52/255, green: 199/255, blue: 89/255))
                    Text(context.state.amount)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(context.state.isDebit ? Color(red: 255/255, green: 59/255, blue: 48/255) : Color(red: 52/255, green: 199/255, blue: 89/255))
                }
            } compactTrailing: {
                Text(context.state.merchant)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            } minimal: {
                Text(context.state.amount)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(context.state.isDebit ? Color(red: 255/255, green: 59/255, blue: 48/255) : Color(red: 52/255, green: 199/255, blue: 89/255))
            }
        }
    }
}
