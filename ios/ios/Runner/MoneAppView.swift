import SwiftUI
import Charts
import LocalAuthentication

// MARK: - Deep Link & Route Dispatcher
public final class MoneRouteManager: ObservableObject {
    public static let shared = MoneRouteManager()
    
    @Published public var showAddTransaction: Bool = false
    @Published public var prefillAmount: Double? = nil
    @Published public var prefillCategory: String? = nil
    @Published public var prefillMerchant: String? = nil
    @Published public var prefillType: String? = nil
    @Published public var prefillAccountId: Int64? = nil
    
    @Published public var showAccountChoiceSheet: Bool = false
    @Published public var accountChoiceAmount: Double = 0.0
    @Published public var accountChoiceType: String = "EXPENSE"
    @Published public var accountChoiceCategory: String = "Food & Dining"
    @Published public var accountChoiceMerchant: String = "Expense"
    
    public func handle(url: URL) {
        guard url.scheme == "mone" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = url.host ?? ""
        let path = url.path
        let queryItems = components?.queryItems ?? []
        
        func param(_ keys: [String]) -> String? {
            for k in keys {
                if let item = queryItems.first(where: { $0.name.lowercased() == k.lowercased() }), let val = item.value, !val.isEmpty {
                    return val
                }
            }
            return nil
        }
        
        if host == "accounts" || host == "get-accounts" || path.contains("accounts") {
            let names = MoneDatabase.shared.accounts.map { $0.name }.joined(separator: "\n")
            UIPasteboard.general.string = names
            MoneHaptics.notification(.success)
            return
        }
        
        if host == "log" || host == "quick-log" || host == "add" || path.contains("log") || path.contains("add") {
            let rawAmount = param(["amount", "amt", "value", "val", "price", "cost", "sum"])
            let rawType = (param(["type", "kind", "mode"]) ?? "EXPENSE").uppercased()
            let rawCat = param(["category", "cat", "tag"]) ?? (rawType == "INCOME" ? "Salary" : "Food & Dining")
            let rawMerchant = param(["merchant", "note", "title", "name", "desc", "vendor", "payee"]) ?? rawCat
            let rawAccount = param(["account", "bank", "acc", "wallet"])
            
            var parsedAmount: Double? = nil
            if let str = rawAmount {
                let clean = str.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                parsedAmount = Double(clean)
            }
            
            let isChoiceRequested = rawAccount == nil || 
                                    rawAccount!.isEmpty || 
                                    rawAccount!.hasPrefix("[") || 
                                    rawAccount!.lowercased() == "choose" || 
                                    rawAccount!.lowercased() == "ask" || 
                                    rawAccount!.lowercased() == "select"
            
            if let amt = parsedAmount, amt > 0 {
                // If account is specified, try to match it
                if !isChoiceRequested {
                    let q = rawAccount!.lowercased()
                    if let matched = MoneDatabase.shared.accounts.first(where: {
                        $0.name.lowercased().contains(q) || $0.bankName.lowercased().contains(q) || $0.bankCode.lowercased() == q
                    }) {
                        // Log directly!
                        MoneDatabase.shared.addTransaction(MoneTransaction(
                            merchant: rawMerchant,
                            category: rawCat,
                            amount: amt,
                            type: rawType,
                            date: Date(),
                            accountId: matched.id
                        ))
                        MoneHaptics.notification(.success)
                        return
                    }
                }
                
                // Show choice sheet
                DispatchQueue.main.async {
                    self.accountChoiceAmount = amt
                    self.accountChoiceType = rawType
                    self.accountChoiceCategory = rawCat
                    self.accountChoiceMerchant = rawMerchant
                    self.showAccountChoiceSheet = true
                    MoneHaptics.impact(.medium)
                }
            } else {
                // Open add transaction modal
                DispatchQueue.main.async {
                    self.prefillAmount = nil
                    self.prefillType = rawType
                    self.prefillCategory = rawCat
                    self.prefillMerchant = rawMerchant
                    self.showAddTransaction = true
                    MoneHaptics.impact(.medium)
                }
            }
        }
    }
}

// MARK: - Root Mone SwiftUI Application View
public struct MoneAppView: View {
    @StateObject private var database = MoneDatabase.shared
    @StateObject private var routeManager = MoneRouteManager.shared
    
    @State private var selectedTab: Int = 0
    @State private var isPrivacyActive: Bool = false
    @State private var isUnlocked: Bool = false
    @State private var isBiometricEnabled: Bool = false
    @State private var isLoaded: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            MoneTheme.bgDeepVoid.ignoresSafeArea()
            
            // Tab Content
            Group {
                switch selectedTab {
                case 0:
                    OverviewDashboardView(isPrivacyActive: $isPrivacyActive)
                case 1:
                    AnalyticsTrendsView()
                case 2:
                    AccountsDirectoryView()
                case 3:
                    SettingsAndShortcutsView()
                default:
                    OverviewDashboardView(isPrivacyActive: $isPrivacyActive)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Bespoke Dock
            floatingDock
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $routeManager.showAddTransaction) {
            AddTransactionSheet(
                prefillMerchant: routeManager.prefillMerchant,
                prefillAmount: routeManager.prefillAmount,
                prefillCategory: routeManager.prefillCategory,
                prefillType: routeManager.prefillType,
                prefillAccountId: routeManager.prefillAccountId
            )
        }
        .sheet(isPresented: $routeManager.showAccountChoiceSheet) {
            AccountChoiceSheet(
                amount: routeManager.accountChoiceAmount,
                type: routeManager.accountChoiceType,
                category: routeManager.accountChoiceCategory,
                merchant: routeManager.accountChoiceMerchant
            )
            .presentationDetents([.medium, .large])
        }
        .onOpenURL { url in
            routeManager.handle(url: url)
        }
    }
    
    // MARK: - Floating Liquid Dock
    private var floatingDock: some View {
        HStack(spacing: 0) {
            dockTabButton(index: 0, icon: "sparkles", title: "Overview")
            dockTabButton(index: 1, icon: "chart.line.uptrend.xyaxis", title: "Trends")
            
            // Center Action Button (+)
            centerAddButton
            
            dockTabButton(index: 2, icon: "creditcard.fill", title: "Accounts")
            dockTabButton(index: 3, icon: "slider.horizontal.3", title: "Shortcuts")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(hex: "10121A").opacity(0.85))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    private func dockTabButton(index: Int, icon: String, title: String) -> some View {
        let isSelected = selectedTab == index
        return Button {
            MoneHaptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? MoneTheme.indigo : .white.opacity(0.5))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
    
    private var centerAddButton: some View {
        Button {
            MoneHaptics.impact(.medium)
            routeManager.prefillAmount = nil
            routeManager.prefillMerchant = nil
            routeManager.prefillType = "EXPENSE"
            routeManager.showAddTransaction = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    )
                    .shadow(color: MoneTheme.indigo.opacity(0.5), radius: 10, x: 0, y: 4)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .offset(y: -4)
        .padding(.horizontal, 6)
    }
}

// MARK: - 1. Overview Dashboard
public struct OverviewDashboardView: View {
    @Binding public var isPrivacyActive: Bool
    @ObservedObject private var database = MoneDatabase.shared
    @ObservedObject private var routeManager = MoneRouteManager.shared
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                headerRow
                
                // Balance Hero Card
                heroBalanceCard
                
                // Safe Daily Spend & Budget Capsule
                budgetBurnRateCard
                
                // Quick Action Bar
                quickActionBar
                
                // Recent Activity
                recentActivitySection
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("mone")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                
                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            
            Button {
                MoneHaptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isPrivacyActive.toggle()
                }
            } label: {
                Image(systemName: isPrivacyActive ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
    }
    
    private var heroBalanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("NET WORTH")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.2)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(MoneTheme.emerald)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.emerald)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(MoneTheme.emerald.opacity(0.15))
                .clipShape(Capsule())
            }
            
            // Amount
            if isPrivacyActive {
                Text("••••••••")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text(String(format: "₹ %.0f", database.totalBalance))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .foregroundColor(MoneTheme.rose)
                    Text("Today:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(format: "₹ %.0f", database.todaySpent))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(MoneTheme.indigo)
                    Text("This Month:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(format: "₹ %.0f", database.monthlySpent))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .glassCard(cornerRadius: 28, padding: 22)
    }
    
    private var budgetBurnRateCard: some View {
        let budget = max(database.totalMonthlyBudget, 1000.0)
        let spent = database.monthlySpent
        let pct = min(spent / budget, 1.0)
        let unspent = max(budget - spent, 0.0)
        
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let day = calendar.component(.day, from: Date())
        let daysLeft = max(range - day + 1, 1)
        let dailySafeSpend = unspent / Double(daysLeft)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(MoneTheme.amber)
                    Text("Safe Daily Spend")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(daysLeft) days left")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "₹ %.0f", dailySafeSpend))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(dailySafeSpend > 0 ? MoneTheme.emerald : MoneTheme.rose)
                Text("/ day")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Text(String(format: "₹%.0f / ₹%.0f", spent, budget))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Progress Capsule
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: pct > 0.9 ? [Color(hex: "F43F5E"), Color(hex: "EF4444")] : [Color(hex: "06B6D4"), Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * CGFloat(pct), 8), height: 8)
                }
            }
            .frame(height: 8)
        }
        .glassCard(cornerRadius: 22, padding: 18)
    }
    
    private var quickActionBar: some View {
        HStack(spacing: 10) {
            quickActionButton(title: "Expense", icon: "arrow.up.right", color: MoneTheme.rose) {
                routeManager.prefillType = "EXPENSE"
                routeManager.showAddTransaction = true
            }
            quickActionButton(title: "Income", icon: "arrow.down.left", color: MoneTheme.emerald) {
                routeManager.prefillType = "INCOME"
                routeManager.showAddTransaction = true
            }
            quickActionButton(title: "Transfer", icon: "arrow.left.arrow.right", color: MoneTheme.cyan) {
                routeManager.prefillType = "TRANSFER"
                routeManager.showAddTransaction = true
            }
        }
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            MoneHaptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(database.transactions.count) records")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            if database.transactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No transactions logged yet")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .glassCard(cornerRadius: 22, padding: 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(database.transactions.prefix(15)) { tx in
                        TransactionRowView(tx: tx)
                    }
                }
            }
        }
    }
}

// MARK: - Transaction Row View
public struct TransactionRowView: View {
    public let tx: MoneTransaction
    @ObservedObject private var database = MoneDatabase.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tx.categoryColor.opacity(0.18))
                    .frame(width: 42, height: 42)
                
                Image(systemName: tx.categoryIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tx.categoryColor)
            }
            
            // Title & Info
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(tx.category)
                    Text("•")
                    Text(tx.formattedTime)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Amount & Type
            VStack(alignment: .trailing, spacing: 2) {
                Text(tx.formattedAmount)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(tx.isExpense ? .white : MoneTheme.emerald)
                    .monospacedDigit()
                
                if let acc = database.accounts.first(where: { $0.id == tx.accountId }) {
                    Text(acc.name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                if let id = tx.id {
                    MoneHaptics.notification(.warning)
                    database.deleteTransaction(id: id)
                }
            } label: {
                Label("Delete Record", systemImage: "trash")
            }
        }
    }
}

// MARK: - 2. Analytics & Historical Trends View
public struct AnalyticsTrendsView: View {
    @ObservedObject private var database = MoneDatabase.shared
    @State private var selectedTimeframe: Int = 0
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Analytics & Trends")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Spending insights & month-over-month deltas")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.top, 16)
                
                // Lifetime KPI Card
                lifetimeKPICard
                
                // Native Apple Swift Charts Trend Graph
                monthlyTrendChartCard
                
                // Top Categories Breakdown
                categoryBreakdownCard
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var lifetimeKPICard: some View {
        let allExpenses = database.transactions.filter { $0.isExpense }
        let totalLifetime = allExpenses.reduce(0.0) { $0 + $1.amount }
        let monthsCount = max(uniqueMonthsCount(txs: allExpenses), 1)
        let monthlyAverage = totalLifetime / Double(monthsCount)
        
        return HStack(spacing: 12) {
            kpiPill(title: "LIFETIME EXPENSE", value: String(format: "₹ %.0f", totalLifetime), icon: "chart.bar.fill", color: MoneTheme.rose)
            kpiPill(title: "MONTHLY AVG", value: String(format: "₹ %.0f", monthlyAverage), icon: "waveform.path.ecg", color: MoneTheme.indigo)
            kpiPill(title: "TRACKED", value: "\(monthsCount) mos", icon: "calendar.badge.clock", color: MoneTheme.cyan)
        }
    }
    
    private func kpiPill(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18, padding: 14)
    }
    
    private var monthlyTrendChartCard: some View {
        let trends = computeMonthlyTrends()
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Spending Trajectory")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("Last 6 Months")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            if #available(iOS 16.0, *), !trends.isEmpty {
                Chart(trends) { item in
                    BarMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Expense", item.expenseTotal)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "06B6D4"), Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.1))
                        AxisValueLabel {
                            if let intVal = value.as(Double.self) {
                                Text("₹\(Int(intVal / 1000))k")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let str = value.as(String.self) {
                                Text(str)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            } else {
                Text("Chart will display as transactions accumulate.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(height: 100)
            }
        }
        .glassCard(cornerRadius: 24, padding: 18)
    }
    
    private var categoryBreakdownCard: some View {
        let categoryMap = computeCategorySpend()
        let total = categoryMap.reduce(0.0) { $0 + $1.value }
        
        return VStack(alignment: .leading, spacing: 14) {
            Text("Category Breakdown")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if categoryMap.isEmpty {
                Text("No categorized expenses recorded yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryMap.sorted(by: { $0.value > $1.value }), id: \.key) { cat, amount in
                        let pct = total > 0 ? (amount / total) : 0.0
                        VStack(spacing: 6) {
                            HStack {
                                Text(cat)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "₹ %.0f (%.0f%%)", amount, pct * 100))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .monospacedDigit()
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "6366F1"), Color(hex: "06B6D4")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(geo.size.width * CGFloat(pct), 6), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
        .glassCard(cornerRadius: 24, padding: 18)
    }
    
    private func computeMonthlyTrends() -> [MonthlyTrend] {
        let expenses = database.transactions.filter { $0.isExpense }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let displayF = DateFormatter()
        displayF.dateFormat = "MMM"
        
        var grouped: [String: Double] = [:]
        for t in expenses {
            let key = f.string(from: t.date)
            grouped[key, default: 0.0] += t.amount
        }
        
        let sortedKeys = grouped.keys.sorted().suffix(6)
        var result: [MonthlyTrend] = []
        for k in sortedKeys {
            if let date = f.date(from: k) {
                let label = displayF.string(from: date)
                result.append(MonthlyTrend(monthKey: k, monthLabel: label, expenseTotal: grouped[k] ?? 0.0))
            }
        }
        return result
    }
    
    private func computeCategorySpend() -> [String: Double] {
        let expenses = database.transactions.filter { $0.isExpense }
        var map: [String: Double] = [:]
        for t in expenses {
            map[t.category, default: 0.0] += t.amount
        }
        return map
    }
    
    private func uniqueMonthsCount(txs: [MoneTransaction]) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        let set = Set(txs.map { f.string(from: $0.date) })
        return set.count
    }
}

// MARK: - 3. Accounts Directory View
public struct AccountsDirectoryView: View {
    @ObservedObject private var database = MoneDatabase.shared
    @State private var showAddAccountSheet: Bool = false
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accounts & Banks")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Manage bank balances & Indian banking directories")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Button {
                        MoneHaptics.impact(.medium)
                        showAddAccountSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add Bank")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MoneTheme.indigo)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 16)
                
                // Account Cards
                VStack(spacing: 12) {
                    ForEach(database.accounts) { acc in
                        accountCard(acc)
                    }
                }
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showAddAccountSheet) {
            AddAccountSheet()
        }
    }
    
    private func accountCard(_ acc: MoneAccount) -> some View {
        HStack(spacing: 14) {
            acc.bankInfo.badgeView(size: 42)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(acc.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Text(acc.bankName.isEmpty ? "Account" : acc.bankName)
                    if !acc.accountNumber.isEmpty {
                        Text("•")
                        Text(acc.maskedNumber)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(acc.formattedBalance)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                Text(acc.type)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.indigo)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(MoneTheme.indigo.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .glassCard(cornerRadius: 22, padding: 16)
        .contextMenu {
            Button(role: .destructive) {
                if let id = acc.id {
                    MoneHaptics.notification(.warning)
                    database.deleteAccount(id: id)
                }
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
        }
    }
}

// MARK: - 4. Settings & Apple Shortcuts Hub
public struct SettingsAndShortcutsView: View {
    @ObservedObject private var database = MoneDatabase.shared
    @State private var budgetString: String = "50000"
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shortcuts & Control")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Apple Shortcuts recipe, URL schemes, and engine")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.top, 16)
                
                // Shortcuts Recipe Hub
                shortcutsHubCard
                
                // Registered Accounts Fast Copy
                accountsCopyCard
                
                // Monthly Budget Control
                monthlyBudgetCard
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            budgetString = String(format: "%.0f", database.totalMonthlyBudget)
        }
    }
    
    private var shortcutsHubCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(MoneTheme.indigo)
                Text("Apple Shortcuts Quick Logger")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text("Set up a 1-tap shortcut on your Home Screen or Action Button that prompts for Amount & Category, then logs directly into mone.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(2)
            
            VStack(spacing: 10) {
                // Copy with Account Choice URL
                shortcutCopyButton(
                    title: "Copy URL with In-App Account Choice",
                    subtitle: "mone://log?...&account=choose (Prompts account picker in app)",
                    urlText: "mone://log?type=[Type]&amount=[Amount]&category=[Category]&merchant=[Merchant]&account=choose",
                    accent: MoneTheme.indigo
                )
                
                // Copy Direct Template URL
                shortcutCopyButton(
                    title: "Copy Direct Shortcut URL Template",
                    subtitle: "mone://log?...&account=[Account] (Logs directly without screens)",
                    urlText: "mone://log?type=[Type]&amount=[Amount]&category=[Category]&account=[Account]&merchant=[Merchant]",
                    accent: MoneTheme.emerald
                )
                
                // Copy 1-Tap Interactive Prompt URL
                shortcutCopyButton(
                    title: "Copy 1-Tap Interactive Prompt URL",
                    subtitle: "mone://log (Opens app with empty logger)",
                    urlText: "mone://log",
                    accent: MoneTheme.cyan
                )
            }
        }
        .glassCard(cornerRadius: 24, padding: 18)
    }
    
    private func shortcutCopyButton(title: String, subtitle: String, urlText: String, accent: Color) -> some View {
        Button {
            UIPasteboard.general.string = urlText
            MoneHaptics.notification(.success)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 13))
                    .foregroundColor(accent)
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    private var accountsCopyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Registered Accounts:")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(database.accounts) { acc in
                        Button {
                            UIPasteboard.general.string = acc.name
                            MoneHaptics.selection()
                        } label: {
                            HStack(spacing: 6) {
                                acc.bankInfo.badgeView(size: 18)
                                Text(acc.name)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Button {
                let names = database.accounts.map { $0.name }.joined(separator: "\n")
                UIPasteboard.general.string = names
                MoneHaptics.notification(.success)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.clipboard.fill")
                    Text("Copy All Account Names for Shortcuts 'Choose from List'")
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(MoneTheme.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .glassCard(cornerRadius: 20, padding: 16)
    }
    
    private var monthlyBudgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Budget Target")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack {
                Text("₹")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.indigo)
                
                TextField("50000", text: $budgetString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                Button("Save") {
                    if let val = Double(budgetString), val > 0 {
                        database.setTotalBudget(val)
                        MoneHaptics.notification(.success)
                    }
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(MoneTheme.indigo)
                .clipShape(Capsule())
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .glassCard(cornerRadius: 20, padding: 16)
    }
}

// MARK: - In-App Account Choice Sheet
public struct AccountChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    
    public let amount: Double
    public let type: String
    public let category: String
    public let merchant: String
    
    public var body: some View {
        ZStack {
            MoneTheme.bgDeepVoid.ignoresSafeArea()
            
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose Account")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Select which account to log this shortcut to")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                
                // Transaction Preview Capsule
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(merchant)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(category)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Text(String(format: "%@₹%.0f", type == "INCOME" ? "+" : "-", amount))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(type == "INCOME" ? MoneTheme.emerald : MoneTheme.rose)
                }
                .glassCard(cornerRadius: 18, padding: 14)
                
                // Account Choices
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(database.accounts) { acc in
                            Button {
                                MoneHaptics.notification(.success)
                                database.addTransaction(MoneTransaction(
                                    merchant: merchant,
                                    category: category,
                                    amount: amount,
                                    type: type,
                                    date: Date(),
                                    accountId: acc.id
                                ))
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    acc.bankInfo.badgeView(size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acc.name)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text(acc.bankName)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(acc.formattedBalance)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .glassCard(cornerRadius: 16, padding: 12)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Add Account Sheet
public struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    
    @State private var name: String = ""
    @State private var accountNumber: String = ""
    @State private var balanceString: String = ""
    @State private var selectedBank: BankInfo = IndianBankDirectory.hdfc
    @State private var type: String = "SAVINGS"
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgDeepVoid.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        // Bank Selection
                        bankSelector
                        
                        // Account Nickname
                        inputField(title: "Account Nickname", text: $name, placeholder: "\(selectedBank.shortName) Primary")
                        
                        // Masked / Last 4 Digits
                        inputField(title: "Account Number / Last 4 Digits", text: $accountNumber, placeholder: "e.g. 4821")
                        
                        // Initial Balance
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Balance")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.indigo)
                                TextField("0.0", text: $balanceString)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        
                        // Save Button
                        Button {
                            let bal = Double(balanceString) ?? 0.0
                            let accName = name.isEmpty ? "\(selectedBank.shortName) Account" : name
                            database.addAccount(MoneAccount(
                                name: accName,
                                bankName: selectedBank.name,
                                bankCode: selectedBank.id,
                                accountNumber: accountNumber,
                                balance: bal,
                                type: type
                            ))
                            MoneHaptics.notification(.success)
                            dismiss()
                        } label: {
                            Text("Save Account")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(MoneTheme.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Bank Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    private var bankSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Bank")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IndianBankDirectory.allBanks) { b in
                        let isSelected = selectedBank.id == b.id
                        Button {
                            MoneHaptics.selection()
                            selectedBank = b
                            if name.isEmpty || name.hasSuffix("Account") {
                                name = "\(b.shortName) Account"
                            }
                        } label: {
                            HStack(spacing: 6) {
                                b.badgeView(size: 20)
                                Text(b.shortName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? MoneTheme.indigo : Color.white.opacity(0.06))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }
    
    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(14)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}
