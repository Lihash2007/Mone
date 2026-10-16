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
    @Namespace private var dockAnimation
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            MoneTheme.bgCanvasGradient.ignoresSafeArea()
            
            // Tab Content
            Group {
                switch selectedTab {
                case 0:
                    OverviewDashboardView(
                        isPrivacyActive: $isPrivacyActive,
                        selectedTab: $selectedTab
                    )
                case 1:
                    AnalyticsTrendsView()
                case 2:
                    AccountsDirectoryView()
                case 3:
                    SettingsAndShortcutsView()
                default:
                    OverviewDashboardView(
                        isPrivacyActive: $isPrivacyActive,
                        selectedTab: $selectedTab
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Bespoke Capsule Dock (Exact Image 2 Replication)
            floatingDock
        }
        .preferredColorScheme(.light)
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
    
    // MARK: - Floating Capsule Dock
    private var floatingDock: some View {
        HStack(spacing: 0) {
            dockTabButton(index: 0, icon: "sparkles", title: "Insights")
            dockTabButton(index: 1, icon: "chart.line.uptrend.xyaxis", title: "Trends")
            
            // Center Action Button (+)
            centerAddButton
            
            dockTabButton(index: 2, icon: "creditcard.fill", title: "Accounts")
            dockTabButton(index: 3, icon: "bolt.fill", title: "Shortcuts")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .shadow(color: Color(hex: "0D2040").opacity(0.10), radius: 22, x: 0, y: 8)
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }
    
    private func dockTabButton(index: Int, icon: String, title: String) -> some View {
        let isSelected = selectedTab == index
        return Button {
            MoneHaptics.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                selectedTab = index
            }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(MoneTheme.deepBlack)
                        .frame(width: 44, height: 44)
                        .matchedGeometryEffect(id: "DOCK_ACTIVE_CIRCLE", in: dockAnimation)
                        .shadow(color: MoneTheme.deepBlack.opacity(0.28), radius: 6, y: 3)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color(hex: "788496"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
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
                    .fill(MoneTheme.deepBlack)
                    .frame(width: 50, height: 50)
                    .shadow(color: MoneTheme.deepBlack.opacity(0.3), radius: 10, y: 4)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }
}

// MARK: - 1. Overview Dashboard (Screen 2: "Your financial insights" Cockpit)
public struct OverviewDashboardView: View {
    @Binding public var isPrivacyActive: Bool
    @Binding public var selectedTab: Int
    @ObservedObject private var database = MoneDatabase.shared
    @ObservedObject private var routeManager = MoneRouteManager.shared
    @State private var selectedFilter: String = "ALL"
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header (Avatar + Circular Menu & Privacy buttons)
                headerRow
                    .padding(.top, 12)
                
                // Display Headline: "Your financial insights"
                headlineSection
                
                // Dual KPI Cards: Balance & Save
                dualKpiCards
                
                // ✦ AI Assistant Banner with Black Mic Button
                aiAssistantBanner
                
                // Action Row: Solid Black "+ Add money" + 3 White Action Buttons
                quickActionBar
                
                // 2x2 Feature Grid: Optimize Budget, Smart Saving, Active Banks, Expense Flow
                featureGrid
                
                // Recent Transactions List
                recentActivitySection
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var headerRow: some View {
        HStack {
            // Profile Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "D9E6EF"))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 42))
                    .foregroundColor(Color(hex: "7C9CB3"))
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                // Privacy Toggle
                Button {
                    MoneHaptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        isPrivacyActive.toggle()
                    }
                } label: {
                    Image(systemName: isPrivacyActive ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MoneTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color(hex: "0D2040").opacity(0.06), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                
                // Menu Button
                Button {
                    MoneHaptics.impact(.light)
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MoneTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color(hex: "0D2040").opacity(0.06), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var headlineSection: some View {
        Text("Your financial\ninsights")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(MoneTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(-2)
    }
    
    private var dualKpiCards: some View {
        let budget = max(database.totalMonthlyBudget, 1000.0)
        let spent = database.monthlySpent
        let unspent = max(budget - spent, 0.0)
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let day = calendar.component(.day, from: Date())
        let daysLeft = max(range - day + 1, 1)
        let dailySafeSpend = unspent / Double(daysLeft)
        
        return HStack(spacing: 12) {
            // Balance Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .black))
                        Text("+0.8%")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .foregroundColor(MoneTheme.badgeGreenText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(MoneTheme.badgeGreenBg)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
                
                Text("Balance")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
                
                Text(isPrivacyActive ? "••••••" : String(format: "₹%.2f", database.totalBalance))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            .whiteCard(cornerRadius: 22, padding: 16)
            
            // Save / Safe Spend Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .black))
                        Text("+0.8%")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .foregroundColor(MoneTheme.badgeGreenText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(MoneTheme.badgeGreenBg)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
                
                Text("Save")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
                
                Text(isPrivacyActive ? "••••••" : String(format: "₹%.2f", dailySafeSpend))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            .whiteCard(cornerRadius: 22, padding: 16)
        }
    }
    
    private var aiAssistantBanner: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MoneTheme.textPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary)
                    Text("Ask Siri or quick voice log")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary)
                }
            }
            
            Spacer()
            
            Button {
                MoneHaptics.impact(.medium)
                routeManager.showAddTransaction = true
            } label: {
                ZStack {
                    Circle()
                        .fill(MoneTheme.deepBlack)
                        .frame(width: 44, height: 44)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(MoneTheme.bgCardBlue)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: "0D2040").opacity(0.04), radius: 8, y: 3)
    }
    
    private var quickActionBar: some View {
        HStack(spacing: 10) {
            // Solid Black Pill "+ Add money"
            Button {
                MoneHaptics.impact(.medium)
                routeManager.prefillAmount = nil
                routeManager.prefillMerchant = nil
                routeManager.prefillType = "EXPENSE"
                routeManager.showAddTransaction = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add money")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MoneTheme.deepBlack)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: MoneTheme.deepBlack.opacity(0.22), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            
            // 3 White Square Buttons
            actionSquareButton(icon: "creditcard.fill") {
                withAnimation { selectedTab = 2 }
            }
            actionSquareButton(icon: "paperplane.fill") {
                withAnimation { selectedTab = 3 }
            }
            actionSquareButton(icon: "square.grid.2x2.fill") {
                withAnimation { selectedTab = 1 }
            }
        }
    }
    
    private func actionSquareButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            MoneHaptics.impact(.light)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MoneTheme.textPrimary)
                .frame(width: 48, height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "0D2040").opacity(0.06), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // 1. Optimize Budget
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F3F6FA"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 15))
                            .foregroundColor(MoneTheme.textPrimary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optimize\nBudget")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .bold))
                        Text("+0.8% Monthly")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(MoneTheme.badgeGreenText)
                }
            }
            .whiteCard(cornerRadius: 22, padding: 16)
            
            // 2. Smart Saving
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F3F6FA"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(MoneTheme.textPrimary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart\nSaving")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .bold))
                        Text("+1.8% Weekly")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(MoneTheme.badgeGreenText)
                }
            }
            .whiteCard(cornerRadius: 22, padding: 16)
            
            // 3. Indian Banks Active
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F3F6FA"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 15))
                            .foregroundColor(MoneTheme.textPrimary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Linked\nAccounts")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary)
                        .lineLimit(2)
                    
                    Text("\(database.accounts.count) Banks Active")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.badgeBlueText)
                }
            }
            .whiteCard(cornerRadius: 22, padding: 16)
            
            // 4. Expense Velocity
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F3F6FA"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 15))
                            .foregroundColor(MoneTheme.textPrimary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expense\nVelocity")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary)
                        .lineLimit(2)
                    
                    Text("Safe Burn Rate")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.badgeGreenText)
                }
            }
            .whiteCard(cornerRadius: 22, padding: 16)
        }
    }
    
    private var recentActivitySection: some View {
        let filteredTxs: [MoneTransaction] = {
            switch selectedFilter {
            case "EXPENSE":
                return database.transactions.filter { $0.isExpense }
            case "INCOME":
                return database.transactions.filter { !$0.isExpense }
            default:
                return database.transactions
            }
        }()
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                Spacer()
                Text("\(filteredTxs.count) records")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
            }
            
            // Black Pill Segmented Control
            BlackPillSegmentedControl(
                items: [
                    FluidSegmentItem(id: "ALL", title: "All", icon: "square.grid.2x2.fill"),
                    FluidSegmentItem(id: "EXPENSE", title: "Expense", icon: "arrow.down.right"),
                    FluidSegmentItem(id: "INCOME", title: "Income", icon: "arrow.up.left")
                ],
                selection: $selectedFilter
            )
            
            if filteredTxs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 32))
                        .foregroundColor(MoneTheme.textMuted)
                    Text("No transactions logged yet")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .whiteCard(cornerRadius: 22, padding: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredTxs.prefix(15)) { tx in
                        TransactionRowView(tx: tx)
                    }
                }
            }
        }
    }
}

// MARK: - Transaction Row View (Exact Screen 1 & Image 2 White Card Style)
public struct TransactionRowView: View {
    public let tx: MoneTransaction
    @ObservedObject private var database = MoneDatabase.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            // Category Icon or Bank Badge
            ZStack {
                Circle()
                    .fill(tx.categoryColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                
                Image(systemName: tx.categoryIcon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(tx.categoryColor)
            }
            
            // Title & Info
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(tx.category)
                    Text("•")
                    Text(tx.formattedTime)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary)
            }
            
            Spacer()
            
            // Amount Pill Badge
            VStack(alignment: .trailing, spacing: 3) {
                Text(tx.formattedAmount)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(tx.isExpense ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tx.isExpense ? MoneTheme.badgeRedBg : MoneTheme.badgeGreenBg)
                    .clipShape(Capsule())
                
                if let acc = database.accounts.first(where: { $0.id == tx.accountId }) {
                    Text(acc.name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary)
                }
            }
        }
        .whiteCard(cornerRadius: 18, padding: 12, shadowRadius: 8)
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

// MARK: - 2. Analytics & Historical Trends View (Exact Screen 1 Replication)
public struct AnalyticsTrendsView: View {
    @ObservedObject private var database = MoneDatabase.shared
    @State private var selectedTimeframe: Int = 1 // Month default
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header (Avatar + Menu)
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "D9E6EF"))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 42))
                            .foregroundColor(Color(hex: "7C9CB3"))
                    }
                    
                    Spacer()
                    
                    Button {
                        MoneHaptics.impact(.light)
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(MoneTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color(hex: "0D2040").opacity(0.06), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
                
                // Timeframe Black Pill Segment: Week | Month | Year
                BlackPillSegmentedControl(
                    items: [
                        FluidSegmentItem(id: 0, title: "Week"),
                        FluidSegmentItem(id: 1, title: "Month"),
                        FluidSegmentItem(id: 2, title: "Year")
                    ],
                    selection: $selectedTimeframe
                )
                
                // Dual Metric Card: Expenses & Income in soft sky-blue
                dualMetricExpensesIncomeCard
                
                // Total Balance & Trajectory Chart Card with Callout Tooltip
                totalBalanceAndTrajectoryCard
                
                // Transactions Section with "See all"
                transactionsSection
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var dualMetricExpensesIncomeCard: some View {
        let expenses = database.transactions.filter { $0.isExpense }.reduce(0.0) { $0 + $1.amount }
        let income = database.transactions.filter { !$0.isExpense }.reduce(0.0) { $0 + $1.amount }
        
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Expenses")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
                Text(String(format: "₹%.2f", expenses))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(Color(hex: "BCE0F5"))
                .frame(width: 1, height: 36)
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Income")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
                Text(String(format: "₹%.2f", income))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(MoneTheme.bgCardBlue)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color(hex: "0D2040").opacity(0.04), radius: 8, y: 3)
    }
    
    private var totalBalanceAndTrajectoryCard: some View {
        let trends = computeMonthlyTrends()
        let peakExpense = trends.map { $0.expenseTotal }.max() ?? 2457.50
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header: Total Balance & +1.8% Badge
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Balance")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
                
                HStack(spacing: 8) {
                    Text(String(format: "₹%.2f", database.totalBalance))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary)
                        .monospacedDigit()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .black))
                        Text("+1.8%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundColor(MoneTheme.badgeGreenText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MoneTheme.badgeGreenBg)
                    .clipShape(Capsule())
                }
            }
            
            // Peak Tooltip Badge
            HStack {
                Spacer()
                HStack(spacing: 3) {
                    Text(String(format: "₹%.2f", peakExpense))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MoneTheme.badgeBlueBg)
                .clipShape(Capsule())
                .offset(y: 4)
                Spacer()
            }
            
            // Apple Swift Charts: Vertical Bars + Black Line Trajectory Curve
            if #available(iOS 16.0, *), !trends.isEmpty {
                Chart {
                    ForEach(Array(trends.enumerated()), id: \.element.id) { index, item in
                        BarMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(index % 2 == 0 ? Color(hex: "2E333D") : Color(hex: "C8D7E3"))
                    }
                    
                    ForEach(trends) { item in
                        LineMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(Color(hex: "10141D"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(Color(hex: "10141D"))
                        .symbolSize(item.expenseTotal == peakExpense ? 36 : 16)
                    }
                }
                .frame(height: 170)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.black.opacity(0.04))
                        AxisValueLabel {
                            if let intVal = value.as(Double.self) {
                                Text("₹\(Int(intVal / 1000))k")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(MoneTheme.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let str = value.as(String.self) {
                                Text(str)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(MoneTheme.textSecondary)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 28))
                        .foregroundColor(MoneTheme.textMuted)
                    Text("Chart will display as transactions accumulate.")
                        .font(.system(size: 12))
                        .foregroundColor(MoneTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
            }
        }
        .whiteCard(cornerRadius: 26, padding: 20)
    }
    
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                Spacer()
                Button {
                    // See all
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary)
                }
            }
            
            if database.transactions.isEmpty {
                Text("No transactions logged yet.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(database.transactions.prefix(10)) { tx in
                        TransactionRowView(tx: tx)
                    }
                }
            }
        }
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
        
        // Ensure standard months if empty or few
        if grouped.isEmpty {
            let cal = Calendar.current
            let now = Date()
            for i in (0..<6).reversed() {
                if let d = cal.date(byAdding: .month, value: -i, to: now) {
                    let k = f.string(from: d)
                    grouped[k] = Double([1200, 1800, 2457, 1900, 2100, 2300][i])
                }
            }
        }
        
        let sortedKeys = grouped.keys.sorted()
        var result: [MonthlyTrend] = []
        for k in sortedKeys.suffix(6) {
            if let date = f.date(from: k) {
                let label = displayF.string(from: date)
                result.append(MonthlyTrend(monthKey: k, monthLabel: label, expenseTotal: grouped[k] ?? 0.0))
            }
        }
        return result
    }
}

// MARK: - 3. Accounts Directory View (Exact Image 2 Clean Card Style)
public struct AccountsDirectoryView: View {
    @ObservedObject private var database = MoneDatabase.shared
    @State private var showAddAccountSheet: Bool = false
    @State private var selectedAccountType: String = "ALL"
    
    public var body: some View {
        let filteredAccounts: [MoneAccount] = {
            if selectedAccountType == "ALL" {
                return database.accounts
            }
            return database.accounts.filter { $0.type.uppercased() == selectedAccountType }
        }()
        
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accounts & Banks")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary)
                        Text("Indian banking directories & account balances")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary)
                    }
                    Spacer()
                    
                    Button {
                        MoneHaptics.impact(.medium)
                        showAddAccountSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add Bank")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MoneTheme.deepBlack)
                        .clipShape(Capsule())
                        .shadow(color: MoneTheme.deepBlack.opacity(0.2), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                
                // Black Pill Filter
                BlackPillSegmentedControl(
                    items: [
                        FluidSegmentItem(id: "ALL", title: "All", icon: "square.grid.2x2.fill"),
                        FluidSegmentItem(id: "SAVINGS", title: "Savings", icon: "building.columns.fill"),
                        FluidSegmentItem(id: "CREDIT", title: "Credit", icon: "creditcard.fill"),
                        FluidSegmentItem(id: "WALLET", title: "Wallets", icon: "wallet.pass.fill")
                    ],
                    selection: $selectedAccountType
                )
                
                // Account Cards
                if filteredAccounts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 32))
                            .foregroundColor(MoneTheme.textMuted)
                        Text("No accounts in this category")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .whiteCard(cornerRadius: 22, padding: 16)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredAccounts) { acc in
                            accountCard(acc)
                        }
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
                    .foregroundColor(MoneTheme.textPrimary)
                
                HStack(spacing: 6) {
                    Text(acc.bankName.isEmpty ? "Account" : acc.bankName)
                    if !acc.accountNumber.isEmpty {
                        Text("•")
                        Text(acc.maskedNumber)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(acc.formattedBalance)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                    .monospacedDigit()
                
                Text(acc.type)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.badgeBlueText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(MoneTheme.badgeBlueBg)
                    .clipShape(Capsule())
            }
        }
        .whiteCard(cornerRadius: 20, padding: 16)
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
                        Text("Shortcuts & Engine")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary)
                        Text("Apple Shortcuts recipe, URL schemes, and engine")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary)
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
                    .foregroundColor(MoneTheme.textPrimary)
            }
            
            Text("Set up a 1-tap shortcut on your Home Screen or Action Button that prompts for Amount & Category, then logs directly into mone.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary)
                .lineSpacing(2)
            
            VStack(spacing: 10) {
                shortcutCopyButton(
                    title: "Copy URL with In-App Account Choice",
                    subtitle: "mone://log?...&account=choose (Prompts account picker in app)",
                    urlText: "mone://log?type=[Type]&amount=[Amount]&category=[Category]&merchant=[Merchant]&account=choose",
                    accent: MoneTheme.indigo
                )
                
                shortcutCopyButton(
                    title: "Copy Direct Shortcut URL Template",
                    subtitle: "mone://log?...&account=[Account] (Logs directly without screens)",
                    urlText: "mone://log?type=[Type]&amount=[Amount]&category=[Category]&account=[Account]&merchant=[Merchant]",
                    accent: MoneTheme.deepBlack
                )
                
                shortcutCopyButton(
                    title: "Copy 1-Tap Interactive Prompt URL",
                    subtitle: "mone://log (Opens app with empty on-screen keypad)",
                    urlText: "mone://log",
                    accent: MoneTheme.badgeBlueText
                )
            }
        }
        .whiteCard(cornerRadius: 24, padding: 18)
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
                        .foregroundColor(MoneTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 13))
                    .foregroundColor(accent)
            }
            .padding(12)
            .background(MoneTheme.bgCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var accountsCopyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Registered Accounts:")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary)
            
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
                            .background(MoneTheme.bgCanvas)
                            .foregroundColor(MoneTheme.textPrimary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
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
                .foregroundColor(MoneTheme.deepBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(MoneTheme.bgSegmentContainer)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .whiteCard(cornerRadius: 20, padding: 16)
    }
    
    private var monthlyBudgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Budget Target")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary)
            
            HStack {
                Text("₹")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                
                TextField("50000", text: $budgetString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
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
                .padding(.vertical, 8)
                .background(MoneTheme.deepBlack)
                .clipShape(Capsule())
            }
            .padding(12)
            .background(MoneTheme.bgCanvas)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .whiteCard(cornerRadius: 20, padding: 16)
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
            MoneTheme.bgCanvasGradient.ignoresSafeArea()
            
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose Account")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary)
                        Text("Select which account to log this shortcut to")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary)
                    }
                    Spacer()
                }
                
                // Transaction Preview Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(merchant)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary)
                        Text(category)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary)
                    }
                    Spacer()
                    Text(String(format: "%@₹%.0f", type == "INCOME" ? "+" : "-", amount))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(type == "INCOME" ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText)
                }
                .whiteCard(cornerRadius: 18, padding: 14)
                
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
                                            .foregroundColor(MoneTheme.textPrimary)
                                        Text(acc.bankName)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(MoneTheme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(acc.formattedBalance)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(MoneTheme.textPrimary)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(MoneTheme.textMuted)
                                }
                                .whiteCard(cornerRadius: 16, padding: 12)
                            }
                            .buttonStyle(.plain)
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
                MoneTheme.bgCanvasGradient.ignoresSafeArea()
                
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
                                .foregroundColor(MoneTheme.textSecondary)
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary)
                                TextField("0.0", text: $balanceString)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary)
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color(hex: "0D2040").opacity(0.04), radius: 6, y: 2)
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
                                .background(MoneTheme.deepBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: MoneTheme.deepBlack.opacity(0.25), radius: 8, y: 3)
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
                        .foregroundColor(MoneTheme.textSecondary)
                }
            }
        }
    }
    
    private var bankSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Bank")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary)
            
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
                            .background(isSelected ? MoneTheme.deepBlack : Color.white)
                            .foregroundColor(isSelected ? .white : MoneTheme.textPrimary)
                            .clipShape(Capsule())
                            .shadow(color: Color(hex: "0D2040").opacity(0.05), radius: 5, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary)
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary)
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "0D2040").opacity(0.04), radius: 6, y: 2)
        }
    }
}
