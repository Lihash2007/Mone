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

// MARK: - Biometric Security Lock Screen (Apple Face ID)
public struct FaceIDLockScreenView: View {
    public let isDark: Bool
    public let userName: String
    public let userProfilePhotoData: Data
    public let onBeginUnlock: () -> Void
    public let onFinishUnlock: () -> Void
    
    @ObservedObject private var database = MoneDatabase.shared
    @State private var isAuthenticating: Bool = false
    @State private var isVerified: Bool = false
    @State private var isGoingInside: Bool = false
    @State private var errorMessage: String? = nil
    
    public init(
        isDark: Bool,
        userName: String,
        userProfilePhotoData: Data = Data(),
        onBeginUnlock: @escaping () -> Void,
        onFinishUnlock: @escaping () -> Void
    ) {
        self.isDark = isDark
        self.userName = userName
        self.userProfilePhotoData = userProfilePhotoData
        self.onBeginUnlock = onBeginUnlock
        self.onFinishUnlock = onFinishUnlock
    }
    
    private var activePhotoData: Data {
        if !database.profilePhotoData.isEmpty {
            return database.profilePhotoData
        }
        return userProfilePhotoData
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Frosted Lock Screen Backdrop Canvas
                MoneTheme.bgCanvasGradient(isDark: isDark)
                    .overlay(
                        Color(isDark ? .black : .white)
                            .opacity(isDark ? 0.35 : 0.45)
                    )
                    .ignoresSafeArea()
                    .opacity(isGoingInside ? 0.0 : 1.0)
                
                // Portal Light Ring (Aura expanding when going inside)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "0284C7").opacity(isDark ? 0.45 : 0.3),
                                Color(hex: "0284C7").opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 180
                        )
                    )
                    .frame(width: 320, height: 320)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.36)
                    .scaleEffect(isGoingInside ? 3.0 : (isVerified ? 1.25 : 0.95))
                    .opacity(isGoingInside ? 0.0 : (isVerified ? 0.8 : 0.3))
                
                // Front Logo (Avatar with verification badge & going-inside zoom)
                ZStack(alignment: .bottomTrailing) {
                    // Profile Photo / Emblem
                    ZStack {
                        if let uiImg = UIImage(data: activePhotoData) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "0284C7"), Color(hex: "0369A1")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 96, height: 96)
                                Text(String(userName.prefix(1)).uppercased())
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(
                                isVerified ? Color(hex: "10B981") : (isAuthenticating ? Color(hex: "0284C7") : Color.white.opacity(0.35)),
                                lineWidth: isVerified ? 3.5 : 2.5
                            )
                    )
                    .shadow(
                        color: (isVerified ? Color(hex: "10B981") : Color(hex: "0284C7")).opacity(isVerified ? 0.6 : 0.25),
                        radius: isVerified ? 16 : 8,
                        y: 4
                    )
                    
                    // Verification Checkmark Badge
                    if isVerified {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "10B981"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 2, y: 2)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.36)
                .scaleEffect(isGoingInside ? 2.6 : (isVerified ? 1.08 : 1.0))
                .opacity(isGoingInside ? 0.0 : 1.0)
                
                // Lock Screen Texts & Actions
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: geo.size.height * 0.44)
                    
                    VStack(spacing: 8) {
                        Text(isVerified ? "Access Granted" : "Welcome back, \(userName)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(isVerified ? Color(hex: "10B981") : MoneTheme.textPrimary(isDark: isDark))
                        
                        Text(isVerified ? "Opening your money dashboard..." : "mone is locked to protect your finances")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDark))
                    }
                    
                    if let err = errorMessage, !isVerified {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(MoneTheme.badgeRedText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(MoneTheme.badgeRedBg)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Unlock with Face ID Button
                    Button {
                        triggerAuthentication()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isVerified ? "checkmark.circle.fill" : "faceid")
                                .font(.system(size: 22, weight: .bold))
                            Text(isVerified ? "Verified" : (isAuthenticating ? "Verifying Face ID..." : "Unlock with Face ID"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(isDark ? Color(hex: "10141D") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isVerified ? Color(hex: "10B981") : (isDark ? Color.white : MoneTheme.deepBlack))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(isDark ? 0.35 : 0.12), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 36)
                    .disabled(isVerified)
                }
                .scaleEffect(isGoingInside ? 1.06 : 1.0)
                .opacity(isGoingInside ? 0.0 : 1.0)
            }
        }
        .onAppear {
            triggerAuthentication()
        }
    }
    
    private func triggerAuthentication() {
        guard !isAuthenticating, !isVerified else { return }
        isAuthenticating = true
        errorMessage = nil
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        
        let reason = "Unlock mone to view financial records"
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        
        if context.canEvaluatePolicy(policy, error: &error) {
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    if success {
                        self.handleVerificationSuccess()
                    } else {
                        MoneHaptics.notification(.error)
                        self.errorMessage = "Authentication failed. Tap to try again."
                    }
                }
            }
        } else {
            isAuthenticating = false
            errorMessage = error?.localizedDescription ?? "Face ID unavailable."
        }
    }
    
    private func handleVerificationSuccess() {
        guard !isVerified else { return }
        
        // 1. Verification Ping (Face ID checkmark + green glow + haptic)
        MoneHaptics.notification(.success)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            isVerified = true
        }
        
        // 2. Short pause to register "Verified", then trigger the "Going Inside" transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            // Trigger coordinated zoom on root dashboard
            onBeginUnlock()
            
            // Trigger internal portal expansion
            withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                isGoingInside = true
            }
            
            // 3. Complete unlock and remove lock screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                onFinishUnlock()
            }
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
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled: Bool = false
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAppUnlocked: Bool = false
    @State private var isUnlockingTransition: Bool = false
    
    @State private var selectedTab: Int = 0
    @State private var showMenuDrawer: Bool = false
    @State private var showAllTransactions: Bool = false
    @State private var showProfileModal: Bool = false
    @State private var showAddAccountSheet: Bool = false
    @State private var editingTransaction: MoneTransaction? = nil
    @State private var editingAccount: MoneAccount? = nil
    @State private var showShareSheet: Bool = false
    @State private var csvFileURLToShare: URL? = nil
    @State private var showManageFamilySheet: Bool = false
    
    @Namespace private var dockAnimation
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Main App Content (Layers underneath and surges forward upon Face ID verification)
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
                            editingTransaction: $editingTransaction,
                            showAddAccountSheet: $showAddAccountSheet,
                            editingAccount: $editingAccount,
                            showManageFamilySheet: $showManageFamilySheet
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
                            csvFileURLToShare: $csvFileURLToShare,
                            showManageFamilySheet: $showManageFamilySheet
                        )
                    default:
                        OverviewDashboardView(
                            selectedTab: $selectedTab,
                            showMenuDrawer: $showMenuDrawer,
                            showAllTransactions: $showAllTransactions,
                            showProfileModal: $showProfileModal,
                            editingTransaction: $editingTransaction,
                            showAddAccountSheet: $showAddAccountSheet,
                            editingAccount: $editingAccount,
                            showManageFamilySheet: $showManageFamilySheet
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Floating Bespoke Capsule Dock (Formal Symbols)
                floatingDock
                    .offset(y: (isFaceIDEnabled && !isAppUnlocked && !isUnlockingTransition) ? 100 : 0)
            }
            .scaleEffect((isFaceIDEnabled && !isAppUnlocked) ? (isUnlockingTransition ? 1.0 : 0.88) : 1.0)
            .blur(radius: (isFaceIDEnabled && !isAppUnlocked) ? (isUnlockingTransition ? 0 : 20) : 0)
            .opacity((isFaceIDEnabled && !isAppUnlocked) ? (isUnlockingTransition ? 1.0 : 0.0) : 1.0)
            .allowsHitTesting(!isFaceIDEnabled || isAppUnlocked)
            
            // Dynamic Island / Top HUD Toast Pill
            DynamicIslandToastView()
            
            // Biometric Security Lock Screen Overlay
            if isFaceIDEnabled && !isAppUnlocked {
                FaceIDLockScreenView(
                    isDark: isDarkMode,
                    userName: userName,
                    userProfilePhotoData: database.profilePhotoData,
                    onBeginUnlock: {
                        withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                            isUnlockingTransition = true
                        }
                    },
                    onFinishUnlock: {
                        isAppUnlocked = true
                        isUnlockingTransition = false
                    }
                )
                .zIndex(999)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                if isFaceIDEnabled {
                    isAppUnlocked = false
                    isUnlockingTransition = false
                }
            }
        }
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
        .sheet(isPresented: $showManageFamilySheet) {
            ManageFamilySheet()
        }
        .sheet(isPresented: $showMenuDrawer) {
            QuickControlMenuSheet(
                selectedTab: $selectedTab,
                showAllTransactions: $showAllTransactions,
                showAddAccountSheet: $showAddAccountSheet,
                showShareSheet: $showShareSheet,
                csvFileURLToShare: $csvFileURLToShare,
                showManageFamilySheet: $showManageFamilySheet
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
            if let fileURL = csvFileURLToShare {
                ActivityViewController(activityItems: [fileURL])
            }
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

// MARK: - Bespoke Apple Wallet Bank Card
public struct AppleWalletCardView: View {
    public let account: MoneAccount
    public let isFocused: Bool
    public let isDarkMode: Bool
    
    @ObservedObject private var database = MoneDatabase.shared
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Card Background Gradient
            LinearGradient(
                colors: account.bankInfo.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle Luxury Glass / Metallic Sheen
            LinearGradient(
                colors: [
                    Color.white.opacity(0.26),
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.black.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Card Inner Rim
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1.0)
            
            // Card Contents
            VStack(alignment: .leading, spacing: 0) {
                // Top Header Row
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        account.bankInfo.badgeView(size: 24)
                        Text(account.bankName.isEmpty ? account.name : account.bankName)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Option A: Member Owner Pill
                    if let mId = account.memberId,
                       let member = database.familyMembers.first(where: { $0.id == mId }) {
                        HStack(spacing: 3) {
                            Text(member.avatarEmoji)
                                .font(.system(size: 9))
                            Text(member.name)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.22))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                    }
                    
                    // Contactless Wave Symbol
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                Spacer(minLength: 4)
                
                // Middle Row: EMV Chip & Balance
                HStack(alignment: .center, spacing: 12) {
                    // Realistic Gold EMV Chip
                    emvChipView
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.type.uppercased() + " BALANCE")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .tracking(1.0)
                            .foregroundColor(Color.white.opacity(0.75))
                        
                        Text(String(format: "₹ %.2f", account.balance))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .shadow(color: Color.black.opacity(0.35), radius: 2.5, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                Spacer(minLength: 4)
                
                // Bottom Row: Account Name, Masked Number & Card Network
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        Text(account.accountNumber.isEmpty ? "•••• •••• •••• 0000" : account.maskedNumber)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Network / Type Pill
                    Text(account.type.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(height: 195)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(isDarkMode ? 0.45 : 0.20), radius: isFocused ? 14 : 6, y: isFocused ? 6 : 3)
    }
    
    // Realistic Gold EMV Chip Graphic
    private var emvChipView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F7D788"), Color(hex: "C9993B"), Color(hex: "F3CE7B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(hex: "8C6218"), lineWidth: 0.5)
                )
            
            // Microchip circuit grid lines
            VStack(spacing: 2.5) {
                Rectangle().fill(Color(hex: "8C6218").opacity(0.6)).frame(width: 20, height: 0.5)
                HStack(spacing: 3) {
                    Rectangle().fill(Color(hex: "8C6218").opacity(0.6)).frame(width: 0.5, height: 8)
                    Rectangle().fill(Color(hex: "8C6218").opacity(0.6)).frame(width: 0.5, height: 8)
                }
                Rectangle().fill(Color(hex: "8C6218").opacity(0.6)).frame(width: 20, height: 0.5)
            }
        }
        .shadow(color: Color.black.opacity(0.18), radius: 1.5, y: 1)
    }
}

// MARK: - Apple Wallet Stacked Cards Section (Home Cockpit)
public struct AppleWalletCardsSection: View {
    @ObservedObject private var database = MoneDatabase.shared
    @ObservedObject private var routeManager = MoneRouteManager.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @Binding public var showAddAccountSheet: Bool
    @Binding public var editingAccount: MoneAccount?
    public var selectedFamilyMemberId: Int64? = nil
    
    @State private var focusedCardId: Int64? = nil
    @State private var isStackExpanded: Bool = false
    
    private var displayedAccounts: [MoneAccount] {
        if let mId = selectedFamilyMemberId {
            return database.accounts.filter { $0.memberId == mId }
        }
        return database.accounts
    }
    
    private var activeMember: MoneFamilyMember? {
        if let mId = selectedFamilyMemberId {
            return database.familyMembers.first(where: { $0.id == mId })
        }
        return nil
    }
    
    private var dynamicPeekHeight: CGFloat {
        let count = displayedAccounts.count
        if count <= 1 { return 0 }
        if count == 2 { return 55 }
        if count == 3 { return 50 }
        return 44
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeMember != nil ? "\(activeMember!.name)'s Cards" : "Accounts & Cards")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text(activeMember != nil ? "\(displayedAccounts.count) Cards • \(activeMember!.role)" : "\(database.accounts.count) Linked • Apple Wallet Stack")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Expand / Stack Toggle Button
                    if displayedAccounts.count > 1 {
                        Button {
                            MoneHaptics.impact(.light)
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                                isStackExpanded.toggle()
                                if isStackExpanded { focusedCardId = nil }
                            }
                        } label: {
                            Image(systemName: isStackExpanded ? "rectangle.stack.fill" : "square.stack.3d.up.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "0284C7"))
                                .frame(width: 32, height: 32)
                                .background(MoneTheme.badgeBlueBg)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Add Bank Button
                    Button {
                        MoneHaptics.impact(.medium)
                        showAddAccountSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add")
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
            }
            
            if displayedAccounts.isEmpty {
                // Empty state card
                if let member = activeMember {
                    emptyMemberCard(member: member)
                } else {
                    emptyWalletCard
                }
            } else if isStackExpanded {
                // Expanded list of cards with smart spacing
                VStack(spacing: 14) {
                    ForEach(displayedAccounts) { acc in
                        VStack(spacing: 8) {
                            AppleWalletCardView(account: acc, isFocused: true, isDarkMode: isDarkMode)
                                .onTapGesture {
                                    MoneHaptics.selection()
                                    editingAccount = acc
                                }
                            
                            cardQuickActions(for: acc)
                        }
                    }
                }
            } else {
                // Apple Wallet Smart Adaptive Overlapping Stack (Full Real Card Size)
                walletStackContainer
            }
        }
        .padding(.bottom, 16)
    }
    
    private var walletStackContainer: some View {
        let accounts = displayedAccounts
        let cardHeight: CGFloat = 195
        let peekHeight = dynamicPeekHeight
        
        let totalHeight: CGFloat = {
            guard let fId = focusedCardId, let fIdx = accounts.firstIndex(where: { $0.id == fId }) else {
                return cardHeight + CGFloat(max(0, accounts.count - 1)) * peekHeight + 8
            }
            if fIdx < accounts.count - 1 {
                let lastCardTop = CGFloat(fIdx) * 24 + cardHeight + 58 + CGFloat(accounts.count - 2 - fIdx) * 32
                return lastCardTop + cardHeight + 14
            } else {
                let focusedTotal = CGFloat(fIdx) * 24 + cardHeight + 64
                return focusedTotal + 14
            }
        }()
        
        return ZStack(alignment: .top) {
            ForEach(Array(accounts.enumerated()), id: \.element.id) { index, acc in
                let isFocused = focusedCardId == acc.id
                let yOffset: CGFloat = {
                    if let fId = focusedCardId, let fIdx = accounts.firstIndex(where: { $0.id == fId }) {
                        if index <= fIdx {
                            return CGFloat(index) * 24
                        } else {
                            return CGFloat(fIdx) * 24 + cardHeight + 58 + CGFloat(index - fIdx - 1) * 32
                        }
                    } else {
                        return CGFloat(index) * peekHeight
                    }
                }()
                
                VStack(spacing: 6) {
                    AppleWalletCardView(account: acc, isFocused: isFocused, isDarkMode: isDarkMode)
                        .onTapGesture {
                            MoneHaptics.impact(.medium)
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                                if focusedCardId == acc.id {
                                    focusedCardId = nil
                                } else {
                                    focusedCardId = acc.id
                                }
                            }
                        }
                    
                    if isFocused {
                        cardQuickActions(for: acc)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .offset(y: yOffset)
                .zIndex(isFocused ? 100 : Double(index))
                .scaleEffect(isFocused ? 1.015 : 1.0)
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: focusedCardId)
            }
        }
        .frame(height: totalHeight)
        .frame(maxWidth: .infinity)
    }
    
    private func cardQuickActions(for acc: MoneAccount) -> some View {
        HStack(spacing: 8) {
            Button {
                MoneHaptics.impact(.medium)
                routeManager.prefillAccountId = acc.id
                routeManager.prefillMerchant = nil
                routeManager.prefillAmount = nil
                routeManager.prefillType = "EXPENSE"
                routeManager.showAddTransaction = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add Expense")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: "0284C7"))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(MoneTheme.badgeBlueBg)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button {
                MoneHaptics.selection()
                editingAccount = acc
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .bold))
                    Text("Edit Card")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(MoneTheme.bgCanvas(isDark: isDarkMode))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button {
                MoneHaptics.selection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    focusedCardId = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
    
    private func emptyMemberCard(member: MoneFamilyMember) -> some View {
        Button {
            MoneHaptics.impact(.medium)
            showAddAccountSheet = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(member.accentColor.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Text(member.avatarEmoji)
                        .font(.system(size: 22))
                }
                
                VStack(spacing: 2) {
                    Text("No Bank Cards Linked for \(member.name)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text("Tap here to assign an account to \(member.name)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(MoneTheme.bgCanvas(isDark: isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
                    .foregroundColor(member.accentColor.opacity(0.40))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var emptyWalletCard: some View {
        Button {
            MoneHaptics.impact(.medium)
            showAddAccountSheet = true
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0284C7").opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "0284C7"))
                }
                
                VStack(spacing: 3) {
                    Text("No Bank Cards Linked Yet")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text("Tap here to link HDFC, SBI, ICICI, Axis or Cash Wallet")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Link First Account")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                .clipShape(Capsule())
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(MoneTheme.bgCanvas(isDark: isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
                    .foregroundColor(Color(hex: "0284C7").opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 1. Overview Dashboard (Screen 2: Cockpit)
public struct OverviewDashboardView: View {
    @Binding public var selectedTab: Int
    @Binding public var showMenuDrawer: Bool
    @Binding public var showAllTransactions: Bool
    @Binding public var showProfileModal: Bool
    @Binding public var editingTransaction: MoneTransaction?
    @Binding public var showAddAccountSheet: Bool
    @Binding public var editingAccount: MoneAccount?
    @Binding public var showManageFamilySheet: Bool
    
    @ObservedObject private var database = MoneDatabase.shared
    @ObservedObject private var routeManager = MoneRouteManager.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("userName") private var userName: String = "Lihash"
    @AppStorage("userProfilePhotoData") private var userProfilePhotoData: Data = Data()
    @State private var selectedFilter: String = "ALL"
    @State private var selectedFamilyMemberId: Int64? = nil
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Header (Avatar + Appearance Toggle & Menu Drawer)
                headerRow
                    .padding(.top, 12)
                
                // Greeting: "Hi, Lihash!"
                greetingSection
                
                // Option A: Family Switcher Capsule Strip
                familySwitcherSection
                
                // Apple Wallet Stacked Bank Cards Section (Immediately after family switcher)
                AppleWalletCardsSection(
                    showAddAccountSheet: $showAddAccountSheet,
                    editingAccount: $editingAccount,
                    selectedFamilyMemberId: selectedFamilyMemberId
                )
                
                // "Your financial insights" Headline
                financialInsightsHeadline
                
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
                let currentPhoto = !database.profilePhotoData.isEmpty ? database.profilePhotoData : userProfilePhotoData
                if !currentPhoto.isEmpty, let uiImg = UIImage(data: currentPhoto) {
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
    
    private var greetingSection: some View {
        HStack {
            Text("Hi, \(userName)!")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            Spacer()
        }
    }
    
    // MARK: - Option A: Family Switcher Capsule Strip
    private var familySwitcherSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All Family" pill
                let isAllSelected = selectedFamilyMemberId == nil
                Button {
                    MoneHaptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedFamilyMemberId = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("👨‍👩‍👧")
                            .font(.system(size: 13))
                        Text("All Family")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        if isAllSelected {
                            Circle()
                                .fill(Color(hex: "0284C7"))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundColor(isAllSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isAllSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "151926") : Color.white))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.04), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.25 : 0.04), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                
                // Individual family members
                ForEach(database.familyMembers) { member in
                    let isSelected = selectedFamilyMemberId == member.id
                    Button {
                        MoneHaptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedFamilyMemberId = member.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(member.avatarEmoji)
                                .font(.system(size: 13))
                            Text(member.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(member.role)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? (isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.8)) : member.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(isSelected ? Color.white.opacity(0.25) : member.accentColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "151926") : Color.white))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.04), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.25 : 0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                
                // Manage Family button
                Button {
                    MoneHaptics.impact(.light)
                    showManageFamilySheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Manage")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "0284C7"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MoneTheme.badgeBlueBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }
    
    private var financialInsightsHeadline: some View {
        Text("Your financial\ninsights")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            .lineSpacing(-2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var dualKpiCards: some View {
        let selectedMember = selectedFamilyMemberId != nil ? database.familyMembers.first(where: { $0.id == selectedFamilyMemberId }) : nil
        let memberAccounts = selectedMember != nil ? database.accounts.filter { $0.memberId == selectedMember!.id } : database.accounts
        let memberAccountIds = Set(memberAccounts.compactMap { $0.id })
        
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let range = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let day = calendar.component(.day, from: now)
        let daysLeft = max(range - day + 1, 1)
        
        let (totalBal, monthlySpent, monthlyIncome): (Double, Double, Double) = {
            if let member = selectedMember {
                let bal = memberAccounts.reduce(0.0) { $0 + ($1.includeInTotal ? $1.balance : 0.0) }
                var spent: Double = 0.0
                var income: Double = 0.0
                for tx in database.transactions {
                    let tMonth = calendar.component(.month, from: tx.date)
                    let tYear = calendar.component(.year, from: tx.date)
                    guard tMonth == currentMonth && tYear == currentYear else { continue }
                    
                    let belongsToMember = (tx.memberId == member.id) || (tx.accountId != nil && memberAccountIds.contains(tx.accountId!))
                    if belongsToMember {
                        if tx.type == "EXPENSE" {
                            spent += tx.amount
                        } else if tx.type == "INCOME" {
                            income += tx.amount
                        }
                    }
                }
                return (bal, spent, income)
            } else {
                return (database.totalBalance, database.monthlySpent, database.monthlyIncome)
            }
        }()
        
        let netFlow = monthlyIncome - monthlySpent
        let hasAllowance = (selectedMember?.monthlyAllowance ?? 0) > 0
        let budgetTarget = hasAllowance ? selectedMember!.monthlyAllowance : database.totalMonthlyBudget
        let hasBudget = budgetTarget > 0
        let isOverBudget = hasBudget && (monthlySpent > budgetTarget)
        let unspent = hasBudget ? max(budgetTarget - monthlySpent, 0.0) : 0.0
        let dailySafeSpend = hasBudget ? (unspent / Double(daysLeft)) : 0.0
        let pctLeft = hasBudget ? Int(round((unspent / budgetTarget) * 100)) : 0
        
        return HStack(spacing: 12) {
            // Balance Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: netFlow >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8, weight: .black))
                        Text(netFlow == 0 ? "₹0 Net" : (netFlow > 0 ? String(format: "+₹%.0f", netFlow) : String(format: "-₹%.0f", abs(netFlow))))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                    }
                    .foregroundColor(netFlow >= 0 ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(netFlow >= 0 ? MoneTheme.badgeGreenBg : MoneTheme.badgeRedBg)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    if let member = selectedMember {
                        Text(member.avatarEmoji)
                            .font(.system(size: 14))
                    }
                }
                
                Text(selectedMember != nil ? "\(selectedMember!.name)'s Balance" : "Total Balance")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    .lineLimit(1)
                
                Text(String(format: "₹%.2f", totalBal))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                
                Text("\(memberAccounts.count) linked accounts")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
            }
            .whiteCard(cornerRadius: 22, padding: 14)
            
            // Remaining Budget / Allowance Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if hasBudget {
                        HStack(spacing: 3) {
                            Image(systemName: isOverBudget ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 8, weight: .black))
                            Text(isOverBudget ? (hasAllowance ? "Allowance Over" : "Over Budget") : "\(pctLeft)% Left")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                        }
                        .foregroundColor(isOverBudget ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isOverBudget ? MoneTheme.badgeRedBg : MoneTheme.badgeGreenBg)
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color(hex: "0284C7"))
                                .frame(width: 5, height: 5)
                            Text("No Budget Set")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "0284C7"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(MoneTheme.badgeBlueBg)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                }
                
                Text(hasAllowance ? (isOverBudget ? "Allowance Exceeded" : "Remaining Allowance") : (hasBudget ? (isOverBudget ? "Budget Exceeded" : "Remaining Budget") : "Monthly Budget"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    .lineLimit(1)
                
                Text(hasBudget ? String(format: "₹%.2f", isOverBudget ? (monthlySpent - budgetTarget) : unspent) : "₹0.00")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(isOverBudget ? MoneTheme.badgeRedText : MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                
                Text(hasBudget ? (isOverBudget ? "₹\(Int(round(monthlySpent))) spent of ₹\(Int(round(budgetTarget)))" : "Safe: ₹\(Int(round(dailySafeSpend)))/day (\(daysLeft)d left)") : "Tap to set in Settings")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                    .lineLimit(1)
            }
            .whiteCard(cornerRadius: 22, padding: 14)
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
        let netFlow = database.monthlyIncome - database.monthlySpent
        
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
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
                        
                        Text(database.totalMonthlyBudget > 0 ? "₹\(Int(database.totalMonthlyBudget)) Limit" : "No Limit Set")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(database.totalMonthlyBudget > 0 ? MoneTheme.badgeGreenText : MoneTheme.textSecondary(isDark: isDarkMode))
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
                    Text("Net\nCashflow")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        .lineLimit(2)
                    
                    HStack(spacing: 2) {
                        Image(systemName: netFlow >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8, weight: .bold))
                        Text(netFlow == 0 ? "₹0 Net" : (netFlow > 0 ? "+₹\(Int(netFlow))" : "-₹\(Int(abs(netFlow)))"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(netFlow >= 0 ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText)
                }
            }
            .whiteCard(cornerRadius: 22, padding: 16)
            
            // 3. Indian Banks Active
            Button {
                MoneHaptics.selection()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    selectedTab = 2
                }
            } label: {
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
            }
            .buttonStyle(.plain)
            
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
                    
                    Text(database.todaySpent > 0 ? "₹\(Int(database.todaySpent)) Today" : "₹0 Spent Today")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(database.todaySpent > 0 ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText)
                }
            }
            .whiteCard(cornerRadius: 22, padding: 16)
        }
    }
    
    private var recentActivitySection: some View {
        let baseList: [MoneTransaction] = {
            if let mId = selectedFamilyMemberId {
                let memberAccIds = Set(database.accounts.filter { $0.memberId == mId }.compactMap { $0.id })
                return database.transactions.filter { tx in
                    if tx.memberId == mId { return true }
                    if let aId = tx.accountId, memberAccIds.contains(aId) { return true }
                    return false
                }
            }
            return database.transactions
        }()
        
        let filteredTxs: [MoneTransaction] = {
            switch selectedFilter {
            case "EXPENSE":
                return baseList.filter { $0.type == "EXPENSE" }
            case "INCOME":
                return baseList.filter { $0.type == "INCOME" }
            case "TRANSFER":
                return baseList.filter { $0.isTransfer }
            default:
                return baseList
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
                        if let memberId = tx.memberId ?? database.accounts.first(where: { $0.id == tx.accountId })?.memberId,
                           let member = database.familyMembers.first(where: { $0.id == memberId }) {
                            Text("•")
                            Text("\(member.avatarEmoji) \(member.name)")
                                .foregroundColor(member.accentColor)
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                // Amount Pill Badge
                VStack(alignment: .trailing, spacing: 3) {
                    Text(tx.formattedAmount)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(tx.isExpense ? MoneTheme.badgeRedText : (tx.isTransfer ? MoneTheme.badgeBlueText : MoneTheme.badgeGreenText))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(tx.isExpense ? MoneTheme.badgeRedBg : (tx.isTransfer ? MoneTheme.badgeBlueBg : MoneTheme.badgeGreenBg))
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

// MARK: - Interactive Month & Year Selector Sheet
public struct MonthPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @Binding public var selectedDate: Date
    @Binding public var selectedTimeframe: Int
    
    @State private var pickerYear: Int
    
    private let months = [
        (1, "Jan", "January"), (2, "Feb", "February"), (3, "Mar", "March"),
        (4, "Apr", "April"), (5, "May", "May"), (6, "Jun", "June"),
        (7, "Jul", "July"), (8, "Aug", "August"), (9, "Sep", "September"),
        (10, "Oct", "October"), (11, "Nov", "November"), (12, "Dec", "December")
    ]
    
    public init(selectedDate: Binding<Date>, selectedTimeframe: Binding<Int>) {
        self._selectedDate = selectedDate
        self._selectedTimeframe = selectedTimeframe
        let cal = Calendar.current
        self._pickerYear = State(initialValue: cal.component(.year, from: selectedDate.wrappedValue))
    }
    
    public var body: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Sheet Grabber Indicator
                Capsule()
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                
                // Pinned Top Header (Clear Title & Prominent Done Button)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select Month")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("Pick a period or view yearly analytics")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                    
                    Spacer()
                    
                    Button {
                        MoneHaptics.selection()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                
                Divider()
                    .background(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    .padding(.bottom, 4)
                
                // Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Year Stepper Header
                        HStack {
                            Button {
                                MoneHaptics.selection()
                                pickerYear -= 1
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                    .frame(width: 40, height: 40)
                                    .background(MoneTheme.bgCardBlue(isDark: isDarkMode))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            VStack(spacing: 2) {
                                Text(String(pickerYear))
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                Text("Year")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "0284C7"))
                            }
                            
                            Spacer()
                            
                            Button {
                                MoneHaptics.selection()
                                pickerYear += 1
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                    .frame(width: 40, height: 40)
                                    .background(MoneTheme.bgCardBlue(isDark: isDarkMode))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        
                        // 12-Month Grid
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(months, id: \.0) { mNum, mShort, mFull in
                                monthCell(monthNumber: mNum, shortName: mShort, fullName: mFull)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Full Year & Jump to Current Month Actions
                        VStack(spacing: 10) {
                            Button {
                                MoneHaptics.impact(.medium)
                                var comps = DateComponents()
                                comps.year = pickerYear
                                comps.month = 1
                                comps.day = 1
                                if let newDate = Calendar.current.date(from: comps) {
                                    selectedDate = newDate
                                    selectedTimeframe = 2 // Year mode
                                }
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "chart.bar.doc.horizontal")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("View Entire Year \(String(pickerYear)) Summary")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MoneTheme.bgCardBlue(isDark: isDarkMode))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                MoneHaptics.impact(.medium)
                                selectedDate = Date()
                                selectedTimeframe = 1 // Month mode
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Jump to Current Month (\(currentMonthTitle))")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color(hex: "0284C7"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MoneTheme.badgeBlueBg)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
    }
    
    private var currentMonthTitle: String {
        Date().formatted(.dateTime.month(.abbreviated).year())
    }
    
    private func monthCell(monthNumber: Int, shortName: String, fullName: String) -> some View {
        let cal = Calendar.current
        let isSelectedMonth = cal.component(.month, from: selectedDate) == monthNumber &&
                             cal.component(.year, from: selectedDate) == pickerYear &&
                             selectedTimeframe == 1
        let isCurrentLiveMonth = cal.component(.month, from: Date()) == monthNumber &&
                                cal.component(.year, from: Date()) == pickerYear
        
        let matchingTxs = database.transactions.filter { tx in
            cal.component(.month, from: tx.date) == monthNumber &&
            cal.component(.year, from: tx.date) == pickerYear
        }
        let totalExpense = matchingTxs.filter { $0.isExpense }.reduce(0.0) { $0 + $1.amount }
        
        return Button {
            MoneHaptics.impact(.medium)
            var comps = DateComponents()
            comps.year = pickerYear
            comps.month = monthNumber
            comps.day = 1
            if let newDate = cal.date(from: comps) {
                selectedDate = newDate
                selectedTimeframe = 1 // Month
            }
            dismiss()
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    Text(shortName)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(isSelectedMonth ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                    
                    if isCurrentLiveMonth {
                        Circle()
                            .fill(isSelectedMonth ? (isDarkMode ? Color(hex: "10141D") : .white) : Color(hex: "0284C7"))
                            .frame(width: 5, height: 5)
                    }
                }
                
                if totalExpense > 0 {
                    Text(String(format: "₹%.0f", totalExpense))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isSelectedMonth ? (isDarkMode ? Color(hex: "10141D").opacity(0.8) : Color.white.opacity(0.9)) : MoneTheme.badgeRedText)
                } else if !matchingTxs.isEmpty {
                    Text("\(matchingTxs.count) txs")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isSelectedMonth ? (isDarkMode ? Color(hex: "10141D").opacity(0.8) : Color.white.opacity(0.8)) : MoneTheme.textSecondary(isDark: isDarkMode))
                } else {
                    Text("—")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isSelectedMonth ? (isDarkMode ? Color(hex: "10141D").opacity(0.5) : Color.white.opacity(0.5)) : MoneTheme.textMuted(isDark: isDarkMode))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelectedMonth ? (isDarkMode ? Color.white : MoneTheme.deepBlack) :
                                  (isDarkMode ? Color(hex: "131722") : Color.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelectedMonth ? Color.clear : (isCurrentLiveMonth ? Color(hex: "0284C7") : Color.clear), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
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
    @State private var selectedFamilyMemberId: Int64? = nil
    @State private var selectedTimeframe: Int = 1 // Month default
    @State private var selectedDate: Date = Date() // Lively defaults to current month!
    @State private var showMonthPickerSheet: Bool = false
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
                        let currentPhoto = !database.profilePhotoData.isEmpty ? database.profilePhotoData : userProfilePhotoData
                        if !currentPhoto.isEmpty, let uiImg = UIImage(data: currentPhoto) {
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
                
                // Option A: Family Switcher Capsule Strip (Filter Analytics by Member)
                familyMemberFilterStrip
                
                // Timeframe Black Pill Segment: Week | Month | Year
                BlackPillSegmentedControl(
                    items: [
                        FluidSegmentItem(id: 0, title: "Week"),
                        FluidSegmentItem(id: 1, title: "Month"),
                        FluidSegmentItem(id: 2, title: "Year")
                    ],
                    selection: Binding(
                        get: { selectedTimeframe },
                        set: { newTimeframe in
                            selectedTimeframe = newTimeframe
                            if newTimeframe == 2 {
                                // "when I click year it should ask me which month in the year"
                                showMonthPickerSheet = true
                            }
                        }
                    )
                )
                
                // Period Navigator (Interactive Month / Week / Year Explorer)
                periodNavigatorBar
                
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
        .sheet(isPresented: $showMonthPickerSheet) {
            MonthPickerSheet(selectedDate: $selectedDate, selectedTimeframe: $selectedTimeframe)
        }
    }
    
    private var periodNavigatorBar: some View {
        HStack(spacing: 10) {
            Button {
                stepPeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .frame(width: 36, height: 36)
                    .background(isDarkMode ? Color(hex: "131722") : Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 4, y: 1)
            }
            .buttonStyle(.plain)
            
            Button {
                MoneHaptics.impact(.light)
                showMonthPickerSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "0284C7"))
                    Text(periodTitleString)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isDarkMode ? Color(hex: "131722") : Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 4, y: 1)
            }
            .buttonStyle(.plain)
            
            Button {
                stepPeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .frame(width: 36, height: 36)
                    .background(isDarkMode ? Color(hex: "131722") : Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 4, y: 1)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if !isCurrentMonth {
                Button {
                    MoneHaptics.impact(.medium)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedDate = Date()
                        selectedTimeframe = 1 // lively current month!
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .bold))
                        Text("Current")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "0284C7"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(MoneTheme.badgeBlueBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        return cal.isDate(selectedDate, equalTo: Date(), toGranularity: .month) &&
               cal.isDate(selectedDate, equalTo: Date(), toGranularity: .year)
    }
    
    private var periodTitleString: String {
        let cal = Calendar.current
        if selectedTimeframe == 0 { // Week
            let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
            let endOfWeek = cal.date(byAdding: .day, value: 6, to: startOfWeek) ?? selectedDate
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            return "\(f.string(from: startOfWeek)) – \(f.string(from: endOfWeek))"
        } else if selectedTimeframe == 2 { // Year
            let f = DateFormatter()
            f.dateFormat = "yyyy"
            return "Year \(f.string(from: selectedDate))"
        } else { // Month
            let f = DateFormatter()
            f.dateFormat = "MMMM yyyy"
            return f.string(from: selectedDate)
        }
    }
    
    private func stepPeriod(by delta: Int) {
        MoneHaptics.selection()
        let cal = Calendar.current
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if selectedTimeframe == 0 {
                selectedDate = cal.date(byAdding: .weekOfYear, value: delta, to: selectedDate) ?? selectedDate
            } else if selectedTimeframe == 2 {
                selectedDate = cal.date(byAdding: .year, value: delta, to: selectedDate) ?? selectedDate
            } else {
                selectedDate = cal.date(byAdding: .month, value: delta, to: selectedDate) ?? selectedDate
            }
        }
    }
    
    private var filteredPeriodTransactions: [MoneTransaction] {
        let cal = Calendar.current
        let memberAccounts = selectedFamilyMemberId != nil ? database.accounts.filter { $0.memberId == selectedFamilyMemberId } : database.accounts
        let memberAccIds = Set(memberAccounts.compactMap { $0.id })
        
        return database.transactions.filter { tx in
            if let mId = selectedFamilyMemberId {
                let matchesMember = tx.memberId == mId || (tx.accountId != nil && memberAccIds.contains(tx.accountId!))
                guard matchesMember else { return false }
            }
            switch selectedTimeframe {
            case 0:
                return cal.isDate(tx.date, equalTo: selectedDate, toGranularity: .weekOfYear) &&
                       cal.isDate(tx.date, equalTo: selectedDate, toGranularity: .yearForWeekOfYear)
            case 2:
                return cal.isDate(tx.date, equalTo: selectedDate, toGranularity: .year)
            default:
                return cal.isDate(tx.date, equalTo: selectedDate, toGranularity: .month) &&
                       cal.isDate(tx.date, equalTo: selectedDate, toGranularity: .year)
            }
        }
    }
    
    private var dualMetricExpensesIncomeCard: some View {
        let periodTxs = filteredPeriodTransactions
        let expenses = periodTxs.filter { $0.type == "EXPENSE" }.reduce(0.0) { $0 + $1.amount }
        let income = periodTxs.filter { $0.type == "INCOME" }.reduce(0.0) { $0 + $1.amount }
        let memberName = activeFamilyMember != nil ? "\(activeFamilyMember!.name) • " : ""
        
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Expenses")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.7) : MoneTheme.textSecondary(isDark: isDarkMode))
                    Text("• " + memberName + periodTitleString)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                        .lineLimit(1)
                }
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
        let trends = chartTrends
        let peakExpense = trends.map { $0.expenseTotal }.max() ?? 0.0
        
        let memberAccounts = selectedFamilyMemberId != nil ? database.accounts.filter { $0.memberId == selectedFamilyMemberId } : database.accounts
        let memberBalance = memberAccounts.reduce(0.0) { $0 + $1.balance }
        let displayedBalance = selectedFamilyMemberId != nil ? memberBalance : database.totalBalance
        
        let periodTxs = filteredPeriodTransactions
        let periodExpenses = periodTxs.filter { $0.type == "EXPENSE" }.reduce(0.0) { $0 + $1.amount }
        let periodIncome = periodTxs.filter { $0.type == "INCOME" }.reduce(0.0) { $0 + $1.amount }
        let net = periodIncome - periodExpenses
        
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(selectedFamilyMemberId != nil ? "\(activeFamilyMember?.name ?? "Member")'s Balance" : "Total Family Balance")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    
                    Spacer()
                    
                    Text(chartPeriodSubtitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                }
                
                HStack(spacing: 8) {
                    Text(String(format: "₹%.2f", displayedBalance))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        .monospacedDigit()
                    
                    HStack(spacing: 2) {
                        Image(systemName: net >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8, weight: .black))
                        Text(net == 0 ? "₹0 Net" : (net > 0 ? String(format: "+₹%.0f", net) : String(format: "-₹%.0f", abs(net))))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .foregroundColor(net >= 0 ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(net >= 0 ? MoneTheme.badgeGreenBg : MoneTheme.badgeRedBg)
                    .clipShape(Capsule())
                }
            }
            
            // Peak Tooltip Badge (only if peak > 0)
            if peakExpense > 0 {
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Text(String(format: "Peak: ₹%.0f", peakExpense))
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
            }
            
            // Apple Swift Charts: Vertical Bars + Line Trajectory Curve
            if #available(iOS 16.0, *), !trends.isEmpty {
                Chart {
                    ForEach(Array(trends.enumerated()), id: \.element.id) { index, item in
                        BarMark(
                            x: .value("Date", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(index % 2 == 0 ? (isDarkMode ? Color(hex: "384257") : Color(hex: "2E333D")) : (isDarkMode ? Color(hex: "1F2737") : Color(hex: "C8D7E3")))
                    }
                    
                    ForEach(trends) { item in
                        LineMark(
                            x: .value("Date", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(isDarkMode ? Color(hex: "60A5FA") : Color(hex: "10141D"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Date", item.monthLabel),
                            y: .value("Expense", item.expenseTotal)
                        )
                        .foregroundStyle(isDarkMode ? Color(hex: "60A5FA") : Color(hex: "10141D"))
                        .symbolSize(item.expenseTotal == peakExpense && peakExpense > 0 ? 36 : 14)
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
                                if selectedTimeframe == 1 {
                                    // For Month view (days 1..31), show every 5 days + day 1 + last day
                                    if let dayNum = Int(str) {
                                        if dayNum == 1 || dayNum % 5 == 0 || dayNum == trends.count {
                                            Text(str)
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                        }
                                    } else {
                                        Text(str)
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                    }
                                } else {
                                    Text(str)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                }
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
    
    private var chartPeriodSubtitle: String {
        let member = activeFamilyMember?.name ?? "Family"
        if selectedTimeframe == 1 {
            return "\(member) • Daily Trajectory"
        } else if selectedTimeframe == 2 {
            return "\(member) • 12-Month Velocity"
        } else {
            return "\(member) • 7-Day Velocity"
        }
    }
    
    private var transactionsSection: some View {
        let periodTxs = filteredPeriodTransactions
        let memberLabel = activeFamilyMember != nil ? "\(activeFamilyMember!.name)'s " : ""
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(memberLabel)Transactions")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text("\(periodTxs.count) recorded in \(periodTitleString)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
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
            
            if periodTxs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28))
                        .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                    Text("No transactions logged in \(periodTitleString)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 32)
                .whiteCard(cornerRadius: 18, padding: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(periodTxs.prefix(15)) { tx in
                        TransactionRowView(tx: tx) {
                            editingTransaction = tx
                        }
                    }
                }
            }
        }
    }
    
    private var categoryLimitsSection: some View {
        let filteredExpenses = filteredPeriodTransactions.filter { $0.isExpense }
        
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
    
    // MARK: - Option A: Family Switcher Capsule Strip (Analytics)
    private var activeFamilyMember: MoneFamilyMember? {
        if let id = selectedFamilyMemberId {
            return database.familyMembers.first(where: { $0.id == id })
        }
        return nil
    }
    
    private var familyMemberFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All Family" pill
                let isAllSelected = selectedFamilyMemberId == nil
                Button {
                    MoneHaptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedFamilyMemberId = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("👨‍👩‍👧")
                            .font(.system(size: 13))
                        Text("All Family")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        if isAllSelected {
                            Circle()
                                .fill(Color(hex: "0284C7"))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .foregroundColor(isAllSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isAllSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "151926") : Color.white))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.04), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.25 : 0.04), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                
                // Individual family members
                ForEach(database.familyMembers) { member in
                    let isSelected = selectedFamilyMemberId == member.id
                    Button {
                        MoneHaptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedFamilyMemberId = member.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(member.avatarEmoji)
                                .font(.system(size: 13))
                            Text(member.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Text(member.role)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? (isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.8)) : member.accentColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(isSelected ? Color.white.opacity(0.25) : member.accentColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "151926") : Color.white))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.04), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.25 : 0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Dynamic Adaptive Trajectory Chart (Month Dates / 12 Months / 7 Days)
    private var chartTrends: [MonthlyTrend] {
        let cal = Calendar.current
        let memberAccounts = selectedFamilyMemberId != nil ? database.accounts.filter { $0.memberId == selectedFamilyMemberId } : database.accounts
        let memberAccIds = Set(memberAccounts.compactMap { $0.id })
        
        let allExpenses = database.transactions.filter { tx in
            guard tx.isExpense else { return false }
            if let mId = selectedFamilyMemberId {
                return tx.memberId == mId || (tx.accountId != nil && memberAccIds.contains(tx.accountId!))
            }
            return true
        }
        
        if selectedTimeframe == 1 {
            // MONTH VIEW: Graph by Days of the selected month (1st through 28/29/30/31)
            let range = cal.range(of: .day, in: .month, for: selectedDate) ?? 1..<32
            let year = cal.component(.year, from: selectedDate)
            let month = cal.component(.month, from: selectedDate)
            
            var dailyTotals: [Int: Double] = [:]
            for tx in allExpenses {
                let tYear = cal.component(.year, from: tx.date)
                let tMonth = cal.component(.month, from: tx.date)
                if tYear == year && tMonth == month {
                    let day = cal.component(.day, from: tx.date)
                    dailyTotals[day, default: 0.0] += tx.amount
                }
            }
            
            var result: [MonthlyTrend] = []
            for day in range {
                let key = String(format: "%04d-%02d-%02d", year, month, day)
                let label = "\(day)"
                let amount = dailyTotals[day] ?? 0.0
                result.append(MonthlyTrend(monthKey: key, monthLabel: label, expenseTotal: amount))
            }
            return result
        } else if selectedTimeframe == 2 {
            // YEAR VIEW: Graph by 12 Months of the selected year (Jan through Dec)
            let year = cal.component(.year, from: selectedDate)
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            
            var monthlyTotals: [Int: Double] = [:]
            for tx in allExpenses {
                let tYear = cal.component(.year, from: tx.date)
                if tYear == year {
                    let m = cal.component(.month, from: tx.date)
                    monthlyTotals[m, default: 0.0] += tx.amount
                }
            }
            
            var result: [MonthlyTrend] = []
            for m in 1...12 {
                var comps = DateComponents()
                comps.year = year
                comps.month = m
                comps.day = 1
                let date = cal.date(from: comps) ?? selectedDate
                let label = monthFormatter.string(from: date)
                let key = String(format: "%04d-%02d", year, m)
                let amount = monthlyTotals[m] ?? 0.0
                result.append(MonthlyTrend(monthKey: key, monthLabel: label, expenseTotal: amount))
            }
            return result
        } else {
            // WEEK VIEW: Graph by 7 days of the selected week (Mon through Sun)
            let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEE"
            
            let keyFormatter = DateFormatter()
            keyFormatter.dateFormat = "yyyy-MM-dd"
            
            var dailyTotals: [String: Double] = [:]
            for tx in allExpenses {
                let k = keyFormatter.string(from: tx.date)
                dailyTotals[k, default: 0.0] += tx.amount
            }
            
            var result: [MonthlyTrend] = []
            for i in 0..<7 {
                if let d = cal.date(byAdding: .day, value: i, to: startOfWeek) {
                    let k = keyFormatter.string(from: d)
                    let label = dayFormatter.string(from: d)
                    let amount = dailyTotals[k] ?? 0.0
                    result.append(MonthlyTrend(monthKey: k, monthLabel: label, expenseTotal: amount))
                }
            }
            return result
        }
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
    @State private var selectedMemberFilter: String = "ALL"
    @State private var showShareSheet: Bool = false
    @State private var csvFileURLToShare: URL? = nil
    
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
                            FluidSegmentItem(id: "INCOME", title: "Income"),
                            FluidSegmentItem(id: "TRANSFER", title: "Transfer")
                        ],
                        selection: $selectedFilter
                    )
                    .padding(.horizontal, 20)
                    
                    // Family Member Filter Chips
                    if database.familyMembers.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                memberFilterChip(title: "👨‍👩‍👧 All Family", id: "ALL")
                                ForEach(database.familyMembers) { member in
                                    memberFilterChip(title: "\(member.avatarEmoji) \(member.name)", id: String(member.id ?? 0))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        MoneHaptics.impact(.medium)
                        if let url = database.exportCSVFileURL() {
                            csvFileURLToShare = url
                            showShareSheet = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(hex: "0284C7"))
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let fileURL = csvFileURLToShare {
                    ActivityViewController(activityItems: [fileURL])
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
    
    private func memberFilterChip(title: String, id: String) -> some View {
        let isSelected = selectedMemberFilter == id
        return Button {
            MoneHaptics.selection()
            selectedMemberFilter = id
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
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
            if selectedFilter == "EXPENSE" && tx.type != "EXPENSE" { return false }
            if selectedFilter == "INCOME" && tx.type != "INCOME" { return false }
            if selectedFilter == "TRANSFER" && !tx.isTransfer { return false }
            // Member filter
            if selectedMemberFilter != "ALL", let mId = Int64(selectedMemberFilter) {
                let memberAccIds = Set(database.accounts.filter { $0.memberId == mId }.compactMap { $0.id })
                let matchesMember = (tx.memberId == mId) || (tx.accountId != nil && memberAccIds.contains(tx.accountId!))
                if !matchesMember { return false }
            }
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
                        if let mId = acc.memberId, let member = database.familyMembers.first(where: { $0.id == mId }) {
                            Text("•")
                            Text("\(member.avatarEmoji) \(member.name)")
                                .foregroundColor(member.accentColor)
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
    @State private var selectedMemberId: Int64? = nil
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
                        
                        // Card Owner (Family Member)
                        memberSelector
                        
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
                            updated.memberId = selectedMemberId
                            
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
                selectedMemberId = acc.memberId ?? database.familyMembers.first?.id
                if let b = IndianBankDirectory.allBanks.first(where: { $0.id == acc.bankCode }) {
                    selectedBank = b
                }
            }
        }
    }
    
    private var memberSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Owner (Family Member)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(database.familyMembers) { member in
                        let isSelected = selectedMemberId == member.id
                        Button {
                            MoneHaptics.selection()
                            selectedMemberId = member.id
                        } label: {
                            HStack(spacing: 6) {
                                Text(member.avatarEmoji)
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(member.name)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                    Text(member.role)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundColor(isSelected ? (isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.8)) : MoneTheme.textSecondary(isDark: isDarkMode))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
                            .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
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
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled: Bool = false
    
    @Binding public var showProfileModal: Bool
    @Binding public var showShareSheet: Bool
    @Binding public var csvFileURLToShare: URL?
    @Binding public var showManageFamilySheet: Bool
    
    @State private var budgetString: String = "0"
    @State private var showClearAlert: Bool = false
    @State private var showResetAllAlert: Bool = false
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
                
                // 2. Family & Household Hub (Option A Multi-Member)
                familyManagementCard
                
                // 3. Appearance Card (Dark / Light)
                appearanceCard
                
                // 4. Security & Privacy Card (Apple Face ID App Lock)
                securityCard
                
                // 5. Monthly Budget Control
                monthlyBudgetCard
                
                // 4. Category Limits & Category Directory
                categoryManagementCard
                
                // 5. Apple Shortcuts Recipes
                shortcutsHubCard
                
                // 6. Data Management (Export, Clear)
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
        .alert("Clear All Transactions?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                MoneHaptics.notification(.warning)
                database.clearAllTransactions()
            }
        } message: {
            Text("This will permanently delete all transaction history.")
        }
        .alert("Reset All Records to Zero?", isPresented: $showResetAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                MoneHaptics.notification(.warning)
                database.resetAllDataToZero()
                budgetString = "0"
            }
        } message: {
            Text("This will purge all bank accounts, delete all transactions, reset monthly budget to zero, and restore a completely fresh zero state.")
        }
    }
    
    private var profileCard: some View {
        Button {
            MoneHaptics.impact(.light)
            showProfileModal = true
        } label: {
            HStack(spacing: 14) {
                let currentPhoto = !database.profilePhotoData.isEmpty ? database.profilePhotoData : userProfilePhotoData
                if !currentPhoto.isEmpty, let uiImg = UIImage(data: currentPhoto) {
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
    
    private var familyManagementCard: some View {
        Button {
            MoneHaptics.impact(.light)
            showManageFamilySheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0284C7").opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Color(hex: "0284C7"))
                        .font(.system(size: 17, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Family & Household")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text("\(database.familyMembers.count) Members • Allowances & Linked Cards")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
            }
            .whiteCard(cornerRadius: 20, padding: 16)
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
    
    private var securityCard: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0284C7").opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "faceid")
                        .foregroundColor(Color(hex: "0284C7"))
                        .font(.system(size: 18, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face ID App Lock")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Text(isFaceIDEnabled ? "Protected upon launch & resume" : "Disabled (Direct Access)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isFaceIDEnabled },
                set: { newValue in
                    if newValue {
                        let context = LAContext()
                        var error: NSError?
                        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ||
                           context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate to enable Face ID App Lock") { success, _ in
                                DispatchQueue.main.async {
                                    if success {
                                        MoneHaptics.notification(.success)
                                        isFaceIDEnabled = true
                                    } else {
                                        MoneHaptics.notification(.error)
                                        isFaceIDEnabled = false
                                    }
                                }
                            }
                        } else {
                            MoneHaptics.notification(.error)
                            isFaceIDEnabled = false
                        }
                    } else {
                        MoneHaptics.selection()
                        isFaceIDEnabled = false
                    }
                }
            ))
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
                
                TextField("0", text: $budgetString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
                
                Button("Save") {
                    if let val = Double(budgetString), val >= 0 {
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
                if let url = database.exportCSVFileURL() {
                    csvFileURLToShare = url
                    showShareSheet = true
                }
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
            
            // Reset All Records to Zero
            Button {
                showResetAllAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(MoneTheme.badgeRedText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset All Records to Zero")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.badgeRedText)
                        Text("Purges accounts & transactions, resets budget to ₹0")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
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
            Text("Pure native SwiftUI • Local SQLite v9 • Zero Telemetry")
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
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled: Bool = false
    @ObservedObject private var database = MoneDatabase.shared
    
    @Binding public var selectedTab: Int
    @Binding public var showAllTransactions: Bool
    @Binding public var showAddAccountSheet: Bool
    @Binding public var showShareSheet: Bool
    @Binding public var csvFileURLToShare: URL?
    @Binding public var showManageFamilySheet: Bool
    
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
                    menuRow(icon: "person.2.fill", title: "Family & Household", subtitle: "Multi-member accounts & allowances") {
                        dismiss()
                        showManageFamilySheet = true
                    }
                    
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
                    
                    menuRow(icon: "faceid", title: "Face ID Protection", subtitle: isFaceIDEnabled ? "Enabled • Protected on exit" : "Disabled • Direct access") {
                        withAnimation {
                            isFaceIDEnabled.toggle()
                            MoneHaptics.selection()
                        }
                    }
                    
                    menuRow(icon: "square.and.arrow.up.fill", title: "Export Statement (CSV)", subtitle: "Share transaction history") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            if let url = database.exportCSVFileURL() {
                                csvFileURLToShare = url
                                showShareSheet = true
                            }
                        }
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
    @ObservedObject private var database = MoneDatabase.shared
    
    @State private var nameInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    private var activePhotoData: Data {
        if !database.profilePhotoData.isEmpty {
            return database.profilePhotoData
        }
        return userProfilePhotoData
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Avatar with Photo Picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if !activePhotoData.isEmpty, let uiImg = UIImage(data: activePhotoData) {
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
                                database.saveProfilePhoto(data: data)
                                userProfilePhotoData = database.profilePhotoData
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
                        if !database.profilePhotoData.isEmpty {
                            userProfilePhotoData = database.profilePhotoData
                        }
                        UserDefaults.standard.synchronize()
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
                if database.profilePhotoData.isEmpty && !userProfilePhotoData.isEmpty {
                    database.saveProfilePhoto(data: userProfilePhotoData)
                }
            }
        }
    }
}

// MARK: - Native iOS Share Activity Sheet
public struct ActivityViewController: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil

    public func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        return controller
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
    @State private var selectedMemberId: Int64? = nil
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        bankSelector
                        
                        // Card Owner (Family Member)
                        memberSelector
                        
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
                                type: type,
                                memberId: selectedMemberId
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
            .onAppear {
                if selectedMemberId == nil {
                    selectedMemberId = database.familyMembers.first?.id
                }
            }
        }
    }
    
    private var memberSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card Owner (Family Member)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(database.familyMembers) { member in
                        let isSelected = selectedMemberId == member.id
                        Button {
                            MoneHaptics.selection()
                            selectedMemberId = member.id
                        } label: {
                            HStack(spacing: 6) {
                                Text(member.avatarEmoji)
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(member.name)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                    Text(member.role)
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundColor(isSelected ? (isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.8)) : MoneTheme.textSecondary(isDark: isDarkMode))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
                            .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
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

// MARK: - Manage Family Sheet (Option A Household Multi-Member Architecture)
public struct ManageFamilySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var editingMember: MoneFamilyMember? = nil
    @State private var showAddMemberModal: Bool = false
    @State private var memberToDelete: MoneFamilyMember? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Household Overview Card
                        householdSummaryCard
                        
                        // Family Members Section Header
                        HStack {
                            Text("Family Members (\(database.familyMembers.count))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                            
                            Spacer()
                            
                            Button {
                                MoneHaptics.impact(.medium)
                                showAddMemberModal = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Add Member")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                        
                        // Family Members List
                        VStack(spacing: 12) {
                            ForEach(database.familyMembers) { member in
                                memberRow(member)
                            }
                        }
                        
                        // Information Banner
                        infoBanner
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Family & Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "0284C7"))
                }
            }
            .sheet(isPresented: $showAddMemberModal) {
                EditFamilyMemberModal(member: nil)
            }
            .sheet(item: $editingMember) { member in
                EditFamilyMemberModal(member: member)
            }
            .alert("Delete Family Member?", isPresented: Binding(
                get: { memberToDelete != nil },
                set: { if !$0 { memberToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { memberToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let m = memberToDelete, let id = m.id {
                        MoneHaptics.notification(.warning)
                        database.deleteFamilyMember(id: id)
                        memberToDelete = nil
                    }
                }
            } message: {
                Text("Their accounts and transactions will be unassigned but preserved in your app.")
            }
        }
    }
    
    private var householdSummaryCard: some View {
        let totalAllowance = database.familyMembers.reduce(0.0) { $0 + $1.monthlyAllowance }
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "0284C7").opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "0284C7"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Household Hub")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        Text("\(database.familyMembers.count) Active Members • Option A Local")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                }
                
                Spacer()
            }
            
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Family Balance")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    Text(String(format: "₹%.2f", database.totalBalance))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        .monospacedDigit()
                }
                
                Spacer()
                
                if totalAllowance > 0 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Monthly Allowances")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        Text(String(format: "₹%.0f/mo", totalAllowance))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "0284C7"))
                            .monospacedDigit()
                    }
                }
            }
        }
        .whiteCard(cornerRadius: 22, padding: 18)
    }
    
    private func memberRow(_ member: MoneFamilyMember) -> some View {
        let memberAccounts = database.accounts.filter { $0.memberId == member.id }
        let memberBalance = memberAccounts.reduce(0.0) { $0 + $1.balance }
        
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        let memberAccIds = Set(memberAccounts.compactMap { $0.id })
        
        var memberMonthSpent: Double = 0.0
        for tx in database.transactions {
            let tMonth = calendar.component(.month, from: tx.date)
            let tYear = calendar.component(.year, from: tx.date)
            guard tMonth == currentMonth && tYear == currentYear else { continue }
            if tx.type == "EXPENSE" {
                if tx.memberId == member.id || (tx.accountId != nil && memberAccIds.contains(tx.accountId!)) {
                    memberMonthSpent += tx.amount
                }
            }
        }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(member.accentColor.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Text(member.avatarEmoji)
                        .font(.system(size: 22))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(member.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        
                        Text(member.role)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(member.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(member.accentColor.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    
                    Text("\(memberAccounts.count) Linked Cards • ₹\(String(format: "%.2f", memberBalance))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button {
                        MoneHaptics.selection()
                        editingMember = member
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                            .frame(width: 32, height: 32)
                            .background(isDarkMode ? Color(hex: "1F2737") : Color(hex: "F3F6FA"))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    if database.familyMembers.count > 1 {
                        Button {
                            MoneHaptics.notification(.warning)
                            memberToDelete = member
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(MoneTheme.badgeRedText)
                                .frame(width: 32, height: 32)
                                .background(MoneTheme.badgeRedBg)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if member.monthlyAllowance > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Monthly Allowance")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        
                        Spacer()
                        
                        let unspent = max(member.monthlyAllowance - memberMonthSpent, 0)
                        Text("₹\(Int(memberMonthSpent)) / ₹\(Int(member.monthlyAllowance)) (₹\(Int(unspent)) left)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(memberMonthSpent > member.monthlyAllowance ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                                .frame(height: 6)
                            
                            let progress = min(CGFloat(memberMonthSpent / member.monthlyAllowance), 1.0)
                            Capsule()
                                .fill(memberMonthSpent > member.monthlyAllowance ? MoneTheme.badgeRedText : member.accentColor)
                                .frame(width: max(geo.size.width * progress, 6), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 4)
            }
        }
        .whiteCard(cornerRadius: 20, padding: 16)
    }
    
    private var infoBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "0284C7"))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Option A: Household Multi-Member Architecture")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                Text("All family accounts, allowances, and transactions are stored 100% locally on device in SQLite with zero cloud dependencies and zero subscription fees.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            }
        }
        .padding(14)
        .background(MoneTheme.badgeBlueBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Edit / Add Family Member Modal
public struct EditFamilyMemberModal: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public let member: MoneFamilyMember?
    
    @State private var name: String = ""
    @State private var role: String = "Spouse"
    @State private var avatarEmoji: String = "👩"
    @State private var colorHex: String = "0284C7"
    @State private var allowanceString: String = ""
    
    private let rolePresets = ["Primary", "Spouse", "Child", "Parent", "Sibling", "Other"]
    private let emojiPresets = ["👤", "👩", "👨", "👧", "👦", "👵", "👴", "🐱", "🐶", "💼", "🎓", "👑", "⭐", "🚀"]
    private let colorPresets = [
        "0284C7", // Sky Blue
        "10B981", // Emerald
        "6366F1", // Indigo
        "EC4899", // Rose Pink
        "F59E0B", // Amber Gold
        "8B5CF6", // Purple
        "14B8A6", // Teal
        "EF4444"  // Coral Red
    ]
    
    public init(member: MoneFamilyMember?) {
        self.member = member
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Live Avatar Preview
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: colorHex).opacity(0.18))
                                    .frame(width: 76, height: 76)
                                Circle()
                                    .stroke(Color(hex: colorHex), lineWidth: 2.5)
                                    .frame(width: 76, height: 76)
                                Text(avatarEmoji)
                                    .font(.system(size: 38))
                            }
                            .shadow(color: Color(hex: colorHex).opacity(0.25), radius: 10, y: 4)
                            
                            Text(name.isEmpty ? "Member Name" : name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                            
                            Text(role)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: colorHex))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: colorHex).opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 10)
                        
                        // Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Member Name")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            TextField("e.g. Sarah, Dad, Emma", text: $name)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                .padding(14)
                                .background(isDarkMode ? Color(hex: "131722") : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
                        }
                        
                        // Role Picker Strip
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Household Role")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(rolePresets, id: \.self) { r in
                                        let isSelected = role == r
                                        Button {
                                            MoneHaptics.selection()
                                            role = r
                                            if member == nil {
                                                if r == "Spouse" { avatarEmoji = "👩" }
                                                else if r == "Child" { avatarEmoji = "👧" }
                                                else if r == "Parent" { avatarEmoji = "👵" }
                                            }
                                        } label: {
                                            Text(r)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
                                                .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                                                .clipShape(Capsule())
                                                .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 4, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // Emoji Avatar Presets
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Avatar Icon")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(emojiPresets, id: \.self) { em in
                                        let isSelected = avatarEmoji == em
                                        Button {
                                            MoneHaptics.selection()
                                            avatarEmoji = em
                                        } label: {
                                            Text(em)
                                                .font(.system(size: 24))
                                                .frame(width: 44, height: 44)
                                                .background(isSelected ? Color(hex: colorHex).opacity(0.2) : (isDarkMode ? Color(hex: "131722") : Color.white))
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(isSelected ? Color(hex: colorHex) : Color.clear, lineWidth: 2))
                                                .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 4, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // Color Swatch Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Theme Color")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            
                            HStack(spacing: 12) {
                                ForEach(colorPresets, id: \.self) { c in
                                    let isSelected = colorHex == c
                                    Button {
                                        MoneHaptics.selection()
                                        colorHex = c
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: c))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                                            )
                                            .shadow(color: Color(hex: c).opacity(0.4), radius: isSelected ? 6 : 2, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Monthly Allowance Input
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Monthly Allowance")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                Spacer()
                                Text("Optional • 0 for none")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                            }
                            
                            HStack {
                                Text("₹")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                TextField("e.g. 10000", text: $allowanceString)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                            }
                            .padding(14)
                            .background(isDarkMode ? Color(hex: "131722") : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 6, y: 2)
                        }
                        
                        // Action Button
                        Button {
                            saveMember()
                        } label: {
                            Text(member == nil ? "Add Family Member" : "Save Changes")
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
            .navigationTitle(member == nil ? "New Member" : "Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
            .onAppear {
                if let m = member {
                    name = m.name
                    role = m.role
                    avatarEmoji = m.avatarEmoji
                    colorHex = m.colorHex
                    if m.monthlyAllowance > 0 {
                        allowanceString = String(format: "%.0f", m.monthlyAllowance)
                    }
                }
            }
        }
    }
    
    private func saveMember() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let allowance = Double(allowanceString) ?? 0.0
        
        if var existing = member {
            existing.name = cleanName
            existing.role = role
            existing.avatarEmoji = avatarEmoji
            existing.colorHex = colorHex
            existing.monthlyAllowance = allowance
            database.updateFamilyMember(existing)
        } else {
            let newMember = MoneFamilyMember(
                name: cleanName,
                role: role,
                avatarEmoji: avatarEmoji,
                colorHex: colorHex,
                monthlyAllowance: allowance
            )
            database.addFamilyMember(newMember)
        }
        MoneHaptics.notification(.success)
        dismiss()
    }
}

