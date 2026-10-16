import SwiftUI
import Charts
import LocalAuthentication
import PhotosUI

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
                if !isChoiceRequested {
                    let q = rawAccount!.lowercased()
                    if let matched = MoneDatabase.shared.accounts.first(where: {
                        $0.name.lowercased().contains(q) || $0.bankName.lowercased().contains(q) || $0.bankCode.lowercased() == q
                    }) {
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
                
                DispatchQueue.main.async {
                    self.accountChoiceAmount = amt
                    self.accountChoiceType = rawType
                    self.accountChoiceCategory = rawCat
                    self.accountChoiceMerchant = rawMerchant
                    self.showAccountChoiceSheet = true
                    MoneHaptics.impact(.medium)
                }
            } else {
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

// MARK: - Dynamic Island / Top HUD Toast Notification View
public struct DynamicIslandToastView: View {
    @ObservedObject private var hud = MoneHUDManager.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public var body: some View {
        if hud.isVisible {
            HStack(spacing: 12) {
                // Bank Logo or Status Icon
                if let bId = hud.bankId, let bank = IndianBankDirectory.allBanks.first(where: { $0.id == bId }) {
                    bank.badgeView(size: 32)
                } else {
                    ZStack {
                        Circle()
                            .fill(hud.isSuccess ? MoneTheme.badgeGreenBg : MoneTheme.badgeRedBg)
                            .frame(width: 32, height: 32)
                        Image(systemName: hud.isSuccess ? "checkmark" : "exclamationmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(hud.isSuccess ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(hud.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        .lineLimit(1)
                    
                    Text(hud.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    hud.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        .frame(width: 24, height: 24)
                        .background(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isDarkMode ? Color(hex: "151926") : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.4 : 0.12), radius: 18, x: 0, y: 6)
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        if value.translation.height < 0 {
                            hud.dismiss()
                        }
                    }
            )
            .zIndex(9999)
        }
    }
}

// MARK: - Root Mone SwiftUI Application View
public struct MoneAppView: View {
    @StateObject private var database = MoneDatabase.shared
    @StateObject private var routeManager = MoneRouteManager.shared
    
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("userName") private var userName: String = "Lihash"
    @AppStorage("userProfilePhotoData") private var userProfilePhotoData: Data = Data()
    
    @State private var selectedTab: Int = 0
    @State private var showMenuDrawer: Bool = false
    @State private var showAllTransactions: Bool = false
    @State private var showProfileModal: Bool = false
    @State private var showAddAccountSheet: Bool = false
    @State private var editingTransaction: MoneTransaction? = nil
    @State private var editingAccount: MoneAccount? = nil
    @State private var showShareSheet: Bool = false
    @State private var csvToShare: String = ""
    
    @Namespace private var dockAnimation
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottom) {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                // Tab Content
                Group {
                    switch selectedTab {
                    case 0:
                        OverviewDashboardView(
                            selectedTab: $selectedTab,
                            showMenuDrawer: $showMenuDrawer,
                            showAllTransactions: $showAllTransactions,
                            showProfileModal: $showProfileModal,
                            editingTransaction: $editingTransaction
                        )
                    case 1:
                        AnalyticsTrendsView(
                            showMenuDrawer: $showMenuDrawer,
                            showAllTransactions: $showAllTransactions,
                            showProfileModal: $showProfileModal,
                            editingTransaction: $editingTransaction
                        )
                    case 2:
                        AccountsDirectoryView(
                            showAddAccountSheet: $showAddAccountSheet,
                            editingAccount: $editingAccount
                        )
                    case 3:
                        SettingsView(
                            showProfileModal: $showProfileModal,
                            showShareSheet: $showShareSheet,
                            csvToShare: $csvToShare
                        )
                    default:
                        OverviewDashboardView(
                            selectedTab: $selectedTab,
                            showMenuDrawer: $showMenuDrawer,
                            showAllTransactions: $showAllTransactions,
                            showProfileModal: $showProfileModal,
                            editingTransaction: $editingTransaction
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Floating Bespoke Capsule Dock (Formal Symbols)
                floatingDock
            }
            
            // Dynamic Island / Top HUD Toast Pill
            DynamicIslandToastView()
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $routeManager.showAddTransaction) {
            AddTransactionSheet(
                prefillMerchant: routeManager.prefillMerchant,
                prefillAmount: routeManager.prefillAmount,
                prefillCategory: routeManager.prefillCategory,
                prefillType: routeManager.prefillType,
                prefillAccountId: routeManager.prefillAccountId
            )
        }
        .sheet(item: $editingTransaction) { tx in
            EditTransactionSheet(tx: tx)
        }
        .sheet(item: $editingAccount) { acc in
            EditAccountSheet(acc: acc)
        }
        .sheet(isPresented: $showMenuDrawer) {
            QuickControlMenuSheet(
                selectedTab: $selectedTab,
                showAllTransactions: $showAllTransactions,
                showAddAccountSheet: $showAddAccountSheet,
                showShareSheet: $showShareSheet,
                csvToShare: $csvToShare
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAllTransactions) {
            AllTransactionsView(editingTransaction: $editingTransaction)
        }
        .sheet(isPresented: $showProfileModal) {
            ProfileCustomizationSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [csvToShare])
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
            dockTabButton(index: 0, icon: "house.fill", title: "Insights")
            dockTabButton(index: 1, icon: "chart.bar.xaxis", title: "Trends")
            
            // Center Action Button (+)
            centerAddButton
            
            dockTabButton(index: 2, icon: "creditcard.fill", title: "Accounts")
            dockTabButton(index: 3, icon: "gearshape.fill", title: "Settings")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isDarkMode ? Color(hex: "131722") : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .shadow(color: isDarkMode ? Color.black.opacity(0.40) : Color(hex: "0D2040").opacity(0.10), radius: 22, x: 0, y: 8)
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
                        .fill(isDarkMode ? Color.white : MoneTheme.deepBlack)
                        .frame(width: 44, height: 44)
                        .matchedGeometryEffect(id: "DOCK_ACTIVE_CIRCLE", in: dockAnimation)
                        .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.28), radius: 6, y: 3)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : (isDarkMode ? Color(hex: "8E9DAE") : Color(hex: "788496")))
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
                    .fill(isDarkMode ? Color.white : MoneTheme.deepBlack)
                    .frame(width: 50, height: 50)
                    .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.3), radius: 10, y: 4)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }
}

// MARK: - 1. Overview Dashboard (Screen 2: Cockpit)
public struct OverviewDashboardView: View {
    @Binding public var selectedTab: Int
    @Binding public var showMenuDrawer: Bool
    @Binding public var showAllTransactions: Bool
    @Binding public var showProfileModal: Bool
    @Binding public var editingTransaction: MoneTransaction?
    
    @ObservedObject private var database = MoneDatabase.shared
    @ObservedObject private var routeManager = MoneRouteManager.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("userName") private var userName: String = "Lihash"
    @AppStorage("userProfilePhotoData") private var userProfilePhotoData: Data = Data()
    @State private var selectedFilter: String = "ALL"
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header (Avatar + Appearance Toggle & Menu Drawer)
                headerRow
                    .padding(.top, 12)
                
                // Display Headline with dynamic greeting
                headlineSection
                
                // Dual KPI Cards: Balance & Save
                dualKpiCards
                
                // Action Bar: Solid Black "+ Add money" + 3 Action Buttons
                quickActionBar
                
                // 2x2 Feature Grid: Optimize Budget, Smart Saving, Active Banks, Expense Flow
                featureGrid
                
                // Recent Transactions List (with tap-to-edit)
                recentActivitySection
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var headerRow: some View {
        HStack {
            // Profile Avatar (Tap to change photo & name)
            Button {
                MoneHaptics.impact(.light)
                showProfileModal = true
            } label: {
                if !userProfilePhotoData.isEmpty, let uiImg = UIImage(data: userProfilePhotoData) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.08), radius: 6, y: 2)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "D9E6EF"))
                            .frame(width: 44, height: 44)
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "335C7A"))
                    }
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.08), radius: 6, y: 2)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 10) {
                // Dark Mode / Light Mode Switch
                Button {
                    MoneHaptics.impact(.medium)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isDarkMode.toggle()
                    }
                } label: {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isDarkMode ? Color(hex: "F59E0B") : MoneTheme.textPrimary(isDark: isDarkMode))
                        .frame(width: 40, height: 40)
                        .background(isDarkMode ? Color(hex: "1B212D") : Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                
                // Functional Menu Button
                Button {
                    MoneHaptics.impact(.light)
                    showMenuDrawer = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        .frame(width: 40, height: 40)
                        .background(isDarkMode ? Color(hex: "1B212D") : Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var headlineSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Hi, \(userName)!")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            Text("Your financial\ninsights")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .lineSpacing(-2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                
                Text(String(format: "₹%.2f", database.totalBalance))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
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
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                
                Text(String(format: "₹%.2f", dailySafeSpend))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            .whiteCard(cornerRadius: 22, padding: 16)
        }
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
                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.22), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            
            // 3 Action Buttons with formal icons
            actionSquareButton(icon: "creditcard.fill") {
                withAnimation { selectedTab = 2 }
            }
            actionSquareButton(icon: "chart.bar.xaxis") {
                withAnimation { selectedTab = 1 }
            }
            actionSquareButton(icon: "list.bullet.rectangle.portrait.fill") {
                showAllTransactions = true
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
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .frame(width: 48, height: 48)
                .background(isDarkMode ? Color(hex: "131722") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // 1. Optimize Budget
            Button {
                MoneHaptics.selection()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    selectedTab = 1
                }
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color(hex: "1D2433") : Color(hex: "F3F6FA"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 15))
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optimize\nBudget")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
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
            }
            .buttonStyle(.plain)
            
            // 2. Smart Saving
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(isDarkMode ? Color(hex: "1D2433") : Color(hex: "F3F6FA"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart\nSaving")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
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
                            .fill(isDarkMode ? Color(hex: "1D2433") : Color(hex: "F3F6FA"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 15))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Linked\nAccounts")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
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
                            .fill(isDarkMode ? Color(hex: "1D2433") : Color(hex: "F3F6FA"))
                            .frame(width: 36, height: 36)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 15))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expense\nVelocity")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
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
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                Spacer()
                Button {
                    MoneHaptics.selection()
                    showAllTransactions = true
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                }
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
                        .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                    Text("No transactions logged yet")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .whiteCard(cornerRadius: 22, padding: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredTxs.prefix(10)) { tx in
                        TransactionRowView(tx: tx) {
                            editingTransaction = tx
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Transaction Row View (Tap to Edit & Swipe to Delete)
public struct TransactionRowView: View {
    public let tx: MoneTransaction
    public var onEdit: (() -> Void)? = nil
    
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var showDigitalReceiptSlip: Bool = false
    
    public init(tx: MoneTransaction, onEdit: (() -> Void)? = nil) {
        self.tx = tx
        self.onEdit = onEdit
    }
    
    public var body: some View {
        Button {
            MoneHaptics.selection()
            onEdit?()
        } label: {
            HStack(spacing: 12) {
                // Category Icon with Overlapping Bank Emblem Badge
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(tx.categoryColor.opacity(0.14))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: tx.categoryIcon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(tx.categoryColor)
                        .frame(width: 44, height: 44)
                    
                    if let acc = database.accounts.first(where: { $0.id == tx.accountId }) {
                        acc.bankInfo.badgeView(size: 18)
                            .offset(x: 3, y: 3)
                    }
                }
                
                // Title & Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(tx.merchant)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(tx.category)
                        Text("•")
                        Text(tx.formattedDateStamp)
                        Text("•")
                        Text(tx.formattedTime)
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
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
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                }
            }
            .whiteCard(cornerRadius: 18, padding: 12, shadowRadius: 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onEdit?()
            } label: {
                Label("Edit Record", systemImage: "pencil")
            }
            
            Button {
                showDigitalReceiptSlip = true
            } label: {
                Label("View Digital Slip", systemImage: "doc.text.fill")
            }
            
            Button {
                // Duplicate transaction
                var copy = tx
                copy.id = nil
                copy.date = Date()
                database.addTransaction(copy)
                MoneHaptics.notification(.success)
            } label: {
                Label("Duplicate Record", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive) {
                if let id = tx.id {
                    MoneHaptics.notification(.warning)
                    database.deleteTransaction(id: id)
                }
            } label: {
                Label("Delete Record", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showDigitalReceiptSlip) {
            DigitalReceiptSlipSheet(tx: tx)
        }
    }
}

// MARK: - 2. Analytics & Historical Trends View (Screen 1)
public struct AnalyticsTrendsView: View {
    @Binding public var showMenuDrawer: Bool
    @Binding public var showAllTransactions: Bool
    @Binding public var showProfileModal: Bool
    @Binding public var editingTransaction: MoneTransaction?
    
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("userName") private var userName: String = "Lihash"
    @AppStorage("userProfilePhotoData") private var userProfilePhotoData: Data = Data()
    @State private var selectedTimeframe: Int = 1 // Month default
    @State private var showSetCategoryLimitSheet: Bool = false
    @State private var selectedCategoryForLimit: String? = nil
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header (Avatar + Appearance Toggle & Menu)
                HStack {
                    Button {
                        MoneHaptics.impact(.light)
                        showProfileModal = true
                    } label: {
                        if !userProfilePhotoData.isEmpty, let uiImg = UIImage(data: userProfilePhotoData) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "D9E6EF"))
                                    .frame(width: 44, height: 44)
                                Text(String(userName.prefix(1)).uppercased())
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(Color(hex: "335C7A"))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        Button {
                            MoneHaptics.impact(.medium)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isDarkMode.toggle()
                            }
                        } label: {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(isDarkMode ? Color(hex: "F59E0B") : MoneTheme.textPrimary(isDark: isDarkMode))
                                .frame(width: 40, height: 40)
                                .background(isDarkMode ? Color(hex: "1B212D") : Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            MoneHaptics.impact(.light)
                            showMenuDrawer = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                .frame(width: 40, height: 40)
                                .background(isDarkMode ? Color(hex: "1B212D") : Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
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
                
                // Category Limits & Breakdown
                categoryLimitsSection
                
                // Transactions Section with "See all"
                transactionsSection
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showSetCategoryLimitSheet) {
            SetCategoryLimitSheet(initialCategory: selectedCategoryForLimit)
        }
    }
    
    private var dualMetricExpensesIncomeCard: some View {
        let expenses = database.transactions.filter { $0.isExpense }.reduce(0.0) { $0 + $1.amount }
        let income = database.transactions.filter { !$0.isExpense }.reduce(0.0) { $0 + $1.amount }
        
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Expenses")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.7) : MoneTheme.textSecondary(isDark: isDarkMode))
                Text(String(format: "₹%.2f", expenses))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isDarkMode ? Color.white : MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(Color(hex: "BCE0F5").opacity(isDarkMode ? 0.25 : 1.0))
                .frame(width: 1, height: 36)
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Income")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.7) : MoneTheme.textSecondary(isDark: isDarkMode))
                Text(String(format: "₹%.2f", income))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isDarkMode ? Color.white : MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(MoneTheme.bgCardBlue(isDark: isDarkMode))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.04), radius: 8, y: 3)
    }
    
    private var totalBalanceAndTrajectoryCard: some View {
        let trends = computeMonthlyTrends()
        let peakExpense = trends.map { $0.expenseTotal }.max() ?? 2457.50
        
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Balance")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                
                HStack(spacing: 8) {
                    Text(String(format: "₹%.2f", database.totalBalance))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
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
            
            // Apple Swift Charts: Vertical Bars + Line Trajectory Curve
            if #available(iOS 16.0, *), !trends.isEmpty {
                Chart {
                    ForEach(Array(trends.enumerated()), id: \.element.id) { index, item in
                        BarMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(index % 2 == 0 ? (isDarkMode ? Color(hex: "384257") : Color(hex: "2E333D")) : (isDarkMode ? Color(hex: "1F2737") : Color(hex: "C8D7E3")))
                    }
                    
                    ForEach(trends) { item in
                        LineMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(isDarkMode ? Color(hex: "60A5FA") : Color(hex: "10141D"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Month", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(isDarkMode ? Color(hex: "60A5FA") : Color(hex: "10141D"))
                        .symbolSize(item.expenseTotal == peakExpense ? 36 : 16)
                    }
                }
                .frame(height: 170)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.12))
                        AxisValueLabel {
                            if let intVal = value.as(Double.self) {
                                Text("₹\(Int(intVal / 1000))k")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
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
                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 28))
                        .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                    Text("Chart will display as transactions accumulate.")
                        .font(.system(size: 12))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
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
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                Spacer()
                Button {
                    MoneHaptics.selection()
                    showAllTransactions = true
                } label: {
                    Text("See all")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                }
            }
            
            if database.transactions.isEmpty {
                Text("No transactions logged yet.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(database.transactions.prefix(10)) { tx in
                        TransactionRowView(tx: tx) {
                            editingTransaction = tx
                        }
                    }
                }
            }
        }
    }
    
    private var categoryLimitsSection: some View {
        let calendar = Calendar.current
        let now = Date()
        
        let filteredExpenses: [MoneTransaction] = database.transactions.filter { tx in
            guard tx.isExpense else { return false }
            switch selectedTimeframe {
            case 0: // Week
                return calendar.isDate(tx.date, equalTo: now, toGranularity: .weekOfYear)
            case 2: // Year
                return calendar.isDate(tx.date, equalTo: now, toGranularity: .year)
            default: // Month
                return calendar.isDate(tx.date, equalTo: now, toGranularity: .month)
            }
        }
        
        var spentByCat: [String: Double] = [:]
        for tx in filteredExpenses {
            spentByCat[tx.category, default: 0.0] += tx.amount
        }
        
        let allCategories = database.categories.filter { $0.type == "EXPENSE" }.map { $0.name }
        let budgetCategories = Array(database.budgets.keys)
        let activeCategories = Array(Set(allCategories + budgetCategories + Array(spentByCat.keys))).sorted()
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Category Limits")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text("Budget vs actual spending")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                Button {
                    MoneHaptics.impact(.light)
                    selectedCategoryForLimit = nil
                    showSetCategoryLimitSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Set Limit")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            if activeCategories.isEmpty {
                Text("No category data yet.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(activeCategories, id: \.self) { cat in
                        let spent = spentByCat[cat] ?? 0.0
                        let limit = database.budgets[cat]
                        let pct: Double = {
                            if let lim = limit, lim > 0 {
                                return spent / lim
                            }
                            let totalExp = filteredExpenses.reduce(0.0) { $0 + $1.amount }
                            return totalExp > 0 ? (spent / totalExp) : 0.0
                        }()
                        let isOver = limit != nil && spent > limit!
                        let catColor = MoneCategory.color(for: cat)
                        
                        Button {
                            MoneHaptics.selection()
                            selectedCategoryForLimit = cat
                            showSetCategoryLimitSheet = true
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(catColor.opacity(0.15))
                                                .frame(width: 30, height: 30)
                                            Image(systemName: MoneCategory.icon(for: cat))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(catColor)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(cat)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                            
                                            if let lim = limit, lim > 0 {
                                                Text(String(format: "Spent: ₹%.0f / Limit: ₹%.0f", spent, lim))
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                            } else {
                                                Text(String(format: "Unbudgeted • Spent: ₹%.0f", spent))
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                                    .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if let lim = limit, lim > 0 {
                                        let pctInt = Int(pct * 100)
                                        Text(isOver ? "\(pctInt)% OVER" : "\(pctInt)%")
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundColor(isOver ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(isOver ? MoneTheme.badgeRedBg : MoneTheme.badgeGreenBg)
                                            .clipShape(Capsule())
                                    } else {
                                        Text("Set Cap")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(hex: "0284C7"))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(MoneTheme.badgeBlueBg)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                            .frame(height: 7)
                                        
                                        Capsule()
                                            .fill(isOver ? Color.red : catColor)
                                            .frame(width: max(4, min(geo.size.width, geo.size.width * CGFloat(min(1.0, pct)))), height: 7)
                                    }
                                }
                                .frame(height: 7)
                            }
                            .whiteCard(cornerRadius: 18, padding: 14)
                        }
                        .buttonStyle(.plain)
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

// MARK: - Full Screen "See All" Transactions Manager
public struct AllTransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @Binding public var editingTransaction: MoneTransaction?
    
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "ALL"
    @State private var selectedBankFilter: String = "ALL"
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                VStack(spacing: 14) {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        TextField("Search payee, category, amount...", text: $searchText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            }
                        }
                    }
                    .padding(12)
                    .background(isDarkMode ? Color(hex: "131722") : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Filter Pill Segment
                    BlackPillSegmentedControl(
                        items: [
                            FluidSegmentItem(id: "ALL", title: "All"),
                            FluidSegmentItem(id: "EXPENSE", title: "Expense"),
                            FluidSegmentItem(id: "INCOME", title: "Income")
                        ],
                        selection: $selectedFilter
                    )
                    .padding(.horizontal, 20)
                    
                    // Bank Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            bankChip(title: "All Banks", id: "ALL")
                            ForEach(database.accounts) { acc in
                                bankChip(title: acc.name, id: String(acc.id ?? 0), bankInfo: acc.bankInfo)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Transactions List Grouped by Timeline
                    let filtered = filteredTransactions
                    if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 40))
                                .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                            Text("No transactions match criteria")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filtered) { tx in
                                TransactionRowView(tx: tx) {
                                    editingTransaction = tx
                                }
                                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let id = tx.id {
                                             MoneHaptics.notification(.warning)
                                            database.deleteTransaction(id: id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        editingTransaction = tx
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(Color(hex: "0284C7"))
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("All Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "0284C7"))
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
    
    private func bankChip(title: String, id: String, bankInfo: BankInfo? = nil) -> some View {
        let isSelected = selectedBankFilter == id
        return Button {
            MoneHaptics.selection()
            selectedBankFilter = id
        } label: {
            HStack(spacing: 6) {
                if let b = bankInfo {
                    b.badgeView(size: 16)
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var filteredTransactions: [MoneTransaction] {
        database.transactions.filter { tx in
            // Search filter
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let matchesMerchant = tx.merchant.lowercased().contains(q)
                let matchesCategory = tx.category.lowercased().contains(q)
                let matchesAmount = String(format: "%.0f", tx.amount).contains(q)
                if !matchesMerchant && !matchesCategory && !matchesAmount { return false }
            }
            // Type filter
            if selectedFilter == "EXPENSE" && !tx.isExpense { return false }
            if selectedFilter == "INCOME" && tx.isExpense { return false }
            // Bank filter
            if selectedBankFilter != "ALL" {
                if String(tx.accountId ?? -1) != selectedBankFilter { return false }
            }
            return true
        }
    }
}

// MARK: - 3. Accounts Directory View (Screen 2 & Image 2)
public struct AccountsDirectoryView: View {
    @Binding public var showAddAccountSheet: Bool
    @Binding public var editingAccount: MoneAccount?
    
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
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
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("Indian banking directories & account balances")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
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
                        .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                        .clipShape(Capsule())
                        .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.2), radius: 6, y: 2)
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
                            .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                        Text("No accounts in this category")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
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
        Button {
            MoneHaptics.selection()
            editingAccount = acc
        } label: {
            HStack(spacing: 14) {
                acc.bankInfo.badgeView(size: 42)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(acc.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    
                    HStack(spacing: 6) {
                        Text(acc.bankName.isEmpty ? "Account" : acc.bankName)
                        if !acc.accountNumber.isEmpty {
                            Text("•")
                            Text(acc.maskedNumber)
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text(acc.formattedBalance)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
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
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingAccount = acc
            } label: {
                Label("Edit Account", systemImage: "pencil")
            }
            
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

// MARK: - Edit Account Sheet (Full Account Edit & Delete)
public struct EditAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public let acc: MoneAccount
    
    @State private var name: String = ""
    @State private var accountNumber: String = ""
    @State private var balanceString: String = ""
    @State private var selectedBank: BankInfo = IndianBankDirectory.hdfc
    @State private var type: String = "SAVINGS"
    @State private var showDeleteConfirmation: Bool = false
    
    public init(acc: MoneAccount) {
        self.acc = acc
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        // Bank Selection
                        bankSelector
                        
                        // Account Nickname
                        inputField(title: "Account Nickname", text: $name, placeholder: "e.g. Salary Account")
                        
                        // Masked / Last 4 Digits
                        inputField(title: "Account Number / Last 4 Digits", text: $accountNumber, placeholder: "e.g. 4821")
                        
                        // Current Balance
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Balance")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                TextField("0.0", text: $balanceString)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                            }
                            .padding(14)
                            .background(isDarkMode ? Color(hex: "131722") : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
                        }
                        
                        // Save Button
                        Button {
                            let bal = Double(balanceString) ?? 0.0
                            let accName = name.isEmpty ? "\(selectedBank.shortName) Account" : name
                            var updated = acc
                            updated.name = accName
                            updated.bankName = selectedBank.name
                            updated.bankCode = selectedBank.id
                            updated.accountNumber = accountNumber
                            updated.balance = bal
                            updated.type = type
                            
                            database.updateAccount(updated)
                            MoneHaptics.notification(.success)
                            dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.25), radius: 8, y: 3)
                        }
                        .padding(.top, 6)
                        
                        // Delete Button
                        Button {
                            MoneHaptics.notification(.warning)
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Delete Bank Account")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(MoneTheme.badgeRedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(MoneTheme.badgeRedBg)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Bank Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
            .alert("Delete Bank Account?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let id = acc.id {
                        MoneHaptics.notification(.warning)
                        database.deleteAccount(id: id)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure? Removing this bank account will not delete previously recorded transactions.")
            }
            .onAppear {
                name = acc.name
                accountNumber = acc.accountNumber
                balanceString = String(format: "%.0f", acc.balance)
                type = acc.type
                if let b = IndianBankDirectory.allBanks.first(where: { $0.id == acc.bankCode }) {
                    selectedBank = b
                }
            }
        }
    }
    
    private var bankSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Bank")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IndianBankDirectory.allBanks) { b in
                        let isSelected = selectedBank.id == b.id
                        Button {
                            MoneHaptics.selection()
                            selectedBank = b
                        } label: {
                            HStack(spacing: 6) {
                                b.badgeView(size: 20)
                                Text(b.shortName)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
                            .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.05), radius: 5, y: 2)
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
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .padding(14)
                .background(isDarkMode ? Color(hex: "131722") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
        }
    }
}

// MARK: - 4. Full Settings Screen (Replacing Tab 3)
public struct SettingsView: View {
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("userName") private var userName: String = "Lihash"
    @AppStorage("userProfilePhotoData") private var userProfilePhotoData: Data = Data()
    
    @Binding public var showProfileModal: Bool
    @Binding public var showShareSheet: Bool
    @Binding public var csvToShare: String
    
    @State private var budgetString: String = "50000"
    @State private var showResetAlert: Bool = false
    @State private var showClearAlert: Bool = false
    @State private var showCategoryLimitSheet: Bool = false
    @State private var showManageCategoriesSheet: Bool = false
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("Profile, Appearance, Shortcuts & Engine")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                    Spacer()
                }
                .padding(.top, 16)
                
                // 1. Profile & Avatar Card
                profileCard
                
                // 2. Appearance Card (Dark / Light)
                appearanceCard
                
                // 3. Monthly Budget Control
                monthlyBudgetCard
                
                // 4. Category Limits & Category Directory
                categoryManagementCard
                
                // 5. Apple Shortcuts Recipes
                shortcutsHubCard
                
                // 6. Data Management (Export, Reset, Clear)
                dataManagementCard
                
                // 7. About Card
                aboutCard
                
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            budgetString = String(format: "%.0f", database.totalMonthlyBudget)
        }
        .sheet(isPresented: $showCategoryLimitSheet) {
            SetCategoryLimitSheet()
        }
        .sheet(isPresented: $showManageCategoriesSheet) {
            ManageCategoriesSheet()
        }
        .alert("Reset to Demo Data?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                MoneHaptics.notification(.success)
                database.resetToDemoData()
            }
        } message: {
            Text("This will replace current transactions and accounts with realistic sample demo records.")
        }
        .alert("Clear All Transactions?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                MoneHaptics.notification(.warning)
                database.clearAllTransactions()
            }
        } message: {
            Text("This will permanently delete all transaction history.")
        }
    }
    
    private var profileCard: some View {
        Button {
            MoneHaptics.impact(.light)
            showProfileModal = true
        } label: {
            HStack(spacing: 14) {
                if !userProfilePhotoData.isEmpty, let uiImg = UIImage(data: userProfilePhotoData) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "D9E6EF"))
                            .frame(width: 50, height: 50)
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "335C7A"))
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(userName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text("Tap to change name or profile photo")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
            }
            .whiteCard(cornerRadius: 22, padding: 16)
        }
        .buttonStyle(.plain)
    }
    
    private var appearanceCard: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color(hex: "1F293D") : Color(hex: "F3F4F6"))
                        .frame(width: 38, height: 38)
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(isDarkMode ? Color(hex: "F59E0B") : Color(hex: "0284C7"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dark Mode")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text(isDarkMode ? "Enabled" : "Disabled (Light Frost)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isDarkMode)
                .labelsHidden()
        }
        .whiteCard(cornerRadius: 20, padding: 16)
    }
    
    private var monthlyBudgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Budget Target")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            
            HStack {
                Text("₹")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                
                TextField("50000", text: $budgetString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
                
                Button("Save") {
                    if let val = Double(budgetString), val > 0 {
                        database.setTotalBudget(val)
                        MoneHaptics.notification(.success)
                    }
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                .clipShape(Capsule())
            }
            .padding(12)
            .background(MoneTheme.bgCanvas(isDark: isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .whiteCard(cornerRadius: 20, padding: 16)
    }
    
    private var categoryManagementCard: some View {
        VStack(spacing: 12) {
            Button {
                MoneHaptics.selection()
                showCategoryLimitSheet = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "E0F2FE"))
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "0284C7"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set Category Limits")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("\(database.budgets.count) category limits configured")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                }
            }
            .buttonStyle(.plain)
            
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
            
            Button {
                MoneHaptics.selection()
                showManageCategoriesSheet = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FEF3C7"))
                            .frame(width: 40, height: 40)
                        Image(systemName: "tag.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "D97706"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Categories")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("\(database.categories.count) active categories")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                }
            }
            .buttonStyle(.plain)
        }
        .whiteCard(cornerRadius: 20, padding: 16)
    }
    
    private var shortcutsHubCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(Color(hex: "0284C7"))
                Text("Apple Shortcuts Engine")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            }
            
            Text("1-tap automations for Action Button, Back Tap, or Home Screen:")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            // Direct Button to Launch Apple Shortcuts App
            Button {
                MoneHaptics.impact(.medium)
                if let url = URL(string: "shortcuts://create-shortcut"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let generalUrl = URL(string: "shortcuts://") {
                    UIApplication.shared.open(generalUrl)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                    Text("Open Apple Shortcuts App")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 13))
                }
                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            // 1-Tap Ready URL Copier with Direct Open
            Button {
                MoneHaptics.notification(.success)
                UIPasteboard.general.string = "mone://log"
                if let url = URL(string: "shortcuts://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "0284C7"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Copy 'mone://log' & Launch Shortcuts")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("Pastes URL into an 'Open URL' action")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                .padding(12)
                .background(MoneTheme.bgCanvas(isDark: isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .whiteCard(cornerRadius: 24, padding: 18)
    }
    
    private var dataManagementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Management")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            
            // Export CSV
            Button {
                MoneHaptics.impact(.medium)
                csvToShare = database.exportCSV()
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundColor(Color(hex: "0284C7"))
                    Text("Export All Transactions (CSV)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Spacer()
                }
                .padding(12)
                .background(MoneTheme.bgCanvas(isDark: isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // Reset to Demo Data
            Button {
                showResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(MoneTheme.badgeBlueText)
                    Text("Reset to Sample Demo Data")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Spacer()
                }
                .padding(12)
                .background(MoneTheme.bgCanvas(isDark: isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // Clear All Data
            Button {
                showClearAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(MoneTheme.badgeRedText)
                    Text("Clear All Transactions")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.badgeRedText)
                    Spacer()
                }
                .padding(12)
                .background(MoneTheme.badgeRedBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .whiteCard(cornerRadius: 22, padding: 18)
    }
    
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("mone • iOS 26 FinTech")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            Text("Pure native SwiftUI • Local SQLite v8 • Zero Telemetry")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .whiteCard(cornerRadius: 18, padding: 14)
    }
}


// MARK: - Quick Control Menu Sheet (Hamburger Menu Action Drawer)
public struct QuickControlMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @ObservedObject private var database = MoneDatabase.shared
    
    @Binding public var selectedTab: Int
    @Binding public var showAllTransactions: Bool
    @Binding public var showAddAccountSheet: Bool
    @Binding public var showShareSheet: Bool
    @Binding public var csvToShare: String
    
    public var body: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                Text("Quick Control")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                
                VStack(spacing: 10) {
                    menuRow(icon: "list.bullet.rectangle.portrait.fill", title: "All Transactions", subtitle: "Search, filter & manage history") {
                        dismiss()
                        showAllTransactions = true
                    }
                    
                    menuRow(icon: "building.columns.fill", title: "Add Bank Account", subtitle: "Link new Indian bank directory") {
                        dismiss()
                        showAddAccountSheet = true
                    }
                    
                    menuRow(icon: isDarkMode ? "sun.max.fill" : "moon.fill", title: isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode", subtitle: "Toggle appearance") {
                        withAnimation { isDarkMode.toggle() }
                    }
                    
                    menuRow(icon: "square.and.arrow.up.fill", title: "Export Statement (CSV)", subtitle: "Share transaction history") {
                        dismiss()
                        csvToShare = database.exportCSV()
                        showShareSheet = true
                    }
                    
                    menuRow(icon: "chart.pie.fill", title: "Category Limits", subtitle: "Budgets & category caps") {
                        dismiss()
                        selectedTab = 1
                    }
                    
                    menuRow(icon: "gearshape.fill", title: "App Settings", subtitle: "Budget, Shortcuts, Profile") {
                        dismiss()
                        selectedTab = 3
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
    private func menuRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            MoneHaptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color(hex: "1F2737") : MoneTheme.bgCardBlue)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: "0284C7"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
            }
            .whiteCard(cornerRadius: 16, padding: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Customization Sheet (Photo Picker & Name)
public struct ProfileCustomizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("userName") private var userName: String = "Lihash"
    @AppStorage("userProfilePhotoData") private var userProfilePhotoData: Data = Data()
    
    @State private var nameInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Avatar with Photo Picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if !userProfilePhotoData.isEmpty, let uiImg = UIImage(data: userProfilePhotoData) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "D9E6EF"))
                                        .frame(width: 90, height: 90)
                                    Text(String(userName.prefix(1)).uppercased())
                                        .font(.system(size: 36, weight: .black, design: .rounded))
                                        .foregroundColor(Color(hex: "335C7A"))
                                }
                            }
                            
                            // Edit Badge
                            ZStack {
                                Circle()
                                    .fill(isDarkMode ? Color.white : MoneTheme.deepBlack)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhotoItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                userProfilePhotoData = data
                                MoneHaptics.notification(.success)
                            }
                        }
                    }
                    
                    Text("Tap photo to change avatar")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                    
                    // Name Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Name")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        
                        TextField("Name", text: $nameInput)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                            .padding(14)
                            .background(isDarkMode ? Color(hex: "131722") : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    
                    // Save Button
                    Button {
                        if !nameInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            userName = nameInput.trimmingCharacters(in: .whitespaces)
                        }
                        MoneHaptics.notification(.success)
                        dismiss()
                    } label: {
                        Text("Save Profile")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Profile & Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
            .onAppear {
                nameInput = userName
            }
        }
    }
}

// MARK: - Native iOS Share Activity Sheet
public struct ActivityViewController: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil

    public func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

// MARK: - In-App Account Choice Sheet
public struct AccountChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public let amount: Double
    public let type: String
    public let category: String
    public let merchant: String
    
    public var body: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose Account")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("Select which account to log this shortcut to")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                    Spacer()
                }
                
                // Transaction Preview Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(merchant)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text(category)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
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
                                MoneHUDManager.shared.show(
                                    title: "\(type == "INCOME" ? "+" : "-")₹\(String(format: "%.0f", amount)) Logged",
                                    subtitle: "\(merchant) • \(acc.name)",
                                    bankId: acc.bankInfo.id
                                )
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    acc.bankInfo.badgeView(size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acc.name)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                        Text(acc.bankName)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(acc.formattedBalance)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
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
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var name: String = ""
    @State private var accountNumber: String = ""
    @State private var balanceString: String = ""
    @State private var selectedBank: BankInfo = IndianBankDirectory.hdfc
    @State private var type: String = "SAVINGS"
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        bankSelector
                        
                        inputField(title: "Account Nickname", text: $name, placeholder: "\(selectedBank.shortName) Primary")
                        
                        inputField(title: "Account Number / Last 4 Digits", text: $accountNumber, placeholder: "e.g. 4821")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Balance")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                TextField("0.0", text: $balanceString)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                            }
                            .padding(14)
                            .background(isDarkMode ? Color(hex: "131722") : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
                        }
                        
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
                                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.25), radius: 8, y: 3)
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
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
        }
    }
    
    private var bankSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Bank")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
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
                            .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
                            .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.05), radius: 5, y: 2)
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
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .padding(14)
                .background(isDarkMode ? Color(hex: "131722") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
        }
    }
}

// MARK: - Set Category Limit Sheet (Category Limits Management)
public struct SetCategoryLimitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public var initialCategory: String?
    
    @State private var selectedCategory: String = "Food & Dining"
    @State private var limitAmountString: String = ""
    
    public init(initialCategory: String? = nil) {
        self.initialCategory = initialCategory
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Category Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select Category")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            let expenseCats = database.categories.filter { $0.type == "EXPENSE" }
                            let list: [MoneCategory] = expenseCats.isEmpty ? [
                                MoneCategory(name: "Food & Dining"),
                                MoneCategory(name: "Shopping"),
                                MoneCategory(name: "Transport"),
                                MoneCategory(name: "Bills & Utilities"),
                                MoneCategory(name: "Groceries"),
                                MoneCategory(name: "Entertainment")
                            ] : expenseCats
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(list) { cat in
                                        let isSelected = selectedCategory.lowercased() == cat.name.lowercased()
                                        Button {
                                            MoneHaptics.selection()
                                            selectedCategory = cat.name
                                            if let existing = database.budgets[cat.name] {
                                                limitAmountString = String(format: "%.0f", existing)
                                            } else {
                                                limitAmountString = ""
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: MoneCategory.icon(for: cat.name))
                                                    .font(.system(size: 11, weight: .bold))
                                                Text(cat.name)
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
                                            .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                                            .clipShape(Capsule())
                                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.05), radius: 5, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // Limit Input Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monthly Spending Limit")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                TextField("5000", text: $limitAmountString)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                    .monospacedDigit()
                            }
                            .padding(14)
                            .background(isDarkMode ? Color(hex: "131722") : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
                        }
                        
                        // Current status info card
                        if let currentLimit = database.budgets[selectedCategory] {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color(hex: "0284C7"))
                                Text(String(format: "Current active limit: ₹%.0f / month", currentLimit))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Save Button
                        Button {
                            if let limit = Double(limitAmountString), limit > 0 {
                                database.setCategoryBudget(category: selectedCategory, limit: limit)
                                MoneHaptics.notification(.success)
                                dismiss()
                            }
                        } label: {
                            Text("Save Category Limit")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: (isDarkMode ? Color.white : MoneTheme.deepBlack).opacity(0.25), radius: 8, y: 3)
                        }
                        .padding(.top, 10)
                        
                        // Remove limit if exists
                        if database.budgets[selectedCategory] != nil {
                            Button {
                                database.deleteCategoryBudget(category: selectedCategory)
                                MoneHaptics.notification(.warning)
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Remove Limit for \(selectedCategory)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(MoneTheme.badgeRedText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MoneTheme.badgeRedBg)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Set Category Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
            .onAppear {
                if let initial = initialCategory, !initial.isEmpty {
                    selectedCategory = initial
                } else if let first = database.categories.first(where: { $0.type == "EXPENSE" }) {
                    selectedCategory = first.name
                }
                if let existing = database.budgets[selectedCategory] {
                    limitAmountString = String(format: "%.0f", existing)
                }
            }
        }
    }
}

// MARK: - Manage Categories Sheet
public struct ManageCategoriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var selectedType: String = "EXPENSE"
    @State private var newCategoryName: String = ""
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Type Segment (Expense vs Income)
                    BlackPillSegmentedControl(
                        items: [
                            FluidSegmentItem(id: "EXPENSE", title: "Expense Categories"),
                            FluidSegmentItem(id: "INCOME", title: "Income Categories")
                        ],
                        selection: $selectedType
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Add Category Inline Card
                    HStack(spacing: 10) {
                        TextField("New category name (e.g. Subscriptions)", text: $newCategoryName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        
                        Button {
                            let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                database.addCategory(name: trimmed, type: selectedType)
                                MoneHaptics.notification(.success)
                                newCategoryName = ""
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Add")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(isDarkMode ? Color(hex: "131722") : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
                    .padding(.horizontal, 20)
                    
                    // Categories List
                    let currentList = database.categories.filter { $0.type.uppercased() == selectedType }
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            if currentList.isEmpty {
                                Text("No categories found.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                    .padding(.vertical, 30)
                            } else {
                                ForEach(currentList) { cat in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(cat.color.opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(cat.color)
                                        }
                                        
                                        Text(cat.name)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                        
                                        Spacer()
                                        
                                        if let lim = database.budgets[cat.name], lim > 0 {
                                            Text(String(format: "Limit: ₹%.0f", lim))
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(Color(hex: "0284C7"))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(MoneTheme.badgeBlueBg)
                                                .clipShape(Capsule())
                                        }
                                        
                                        Button {
                                            if let id = cat.id {
                                                MoneHaptics.notification(.warning)
                                                database.deleteCategory(id: id)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13))
                                                .foregroundColor(MoneTheme.badgeRedText)
                                                .frame(width: 30, height: 30)
                                                .background(MoneTheme.badgeRedBg)
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .whiteCard(cornerRadius: 16, padding: 12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "0284C7"))
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
}

