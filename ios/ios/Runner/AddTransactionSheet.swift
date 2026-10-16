import SwiftUI

// MARK: - Add / Edit Transaction Sheet (Exact Screen 3 Replication)
public struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    
    @State private var type: String = "EXPENSE"
    @State private var amountString: String = ""
    @State private var merchant: String = ""
    @State private var selectedCategory: String = "Food & Dining"
    @State private var selectedAccountId: Int64? = nil
    @State private var date: Date = Date()
    @State private var showAccountPickerModal: Bool = false
    
    public var prefillMerchant: String? = nil
    public var prefillAmount: Double? = nil
    public var prefillCategory: String? = nil
    public var prefillType: String? = nil
    public var prefillAccountId: Int64? = nil
    
    public init(
        prefillMerchant: String? = nil,
        prefillAmount: Double? = nil,
        prefillCategory: String? = nil,
        prefillType: String? = nil,
        prefillAccountId: Int64? = nil
    ) {
        self.prefillMerchant = prefillMerchant
        self.prefillAmount = prefillAmount
        self.prefillCategory = prefillCategory
        self.prefillType = prefillType
        self.prefillAccountId = prefillAccountId
    }
    
    public var body: some View {
        ZStack {
            MoneTheme.bgCanvasGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                navHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 1. Balance Pill Badge
                        sourceBalancePill
                        
                        // 2. Account Selector Card
                        accountSelectorCard
                        
                        // 3. Black Pill Segmented Control
                        typeSelector
                        
                        // 4. Large Currency & Amount Display
                        amountHeroCard
                        
                        // 5. Merchant / Note Input
                        merchantInputCard
                        
                        // 6. Category Chips
                        if type != "TRANSFER" {
                            categorySelector
                        }
                        
                        // 7. On-Screen Bespoke Numeric Keypad
                        numericKeypad
                            .padding(.top, 4)
                        
                        // 8. Bottom Action Slider Button
                        bottomActionButton
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showAccountPickerModal) {
            accountSelectionModal
                .presentationDetents([.medium])
        }
        .onAppear {
            initializeDefaults()
        }
    }
    
    private func initializeDefaults() {
        if let amt = prefillAmount, amt > 0 {
            amountString = String(format: "%.0f", amt)
        }
        if let m = prefillMerchant, !m.isEmpty {
            merchant = m
        }
        if let t = prefillType, !t.isEmpty {
            type = t.uppercased()
        }
        if let c = prefillCategory, !c.isEmpty {
            selectedCategory = c
        }
        if let accId = prefillAccountId {
            selectedAccountId = accId
        } else if let firstAcc = database.accounts.first {
            selectedAccountId = firstAcc.id
        }
    }
    
    // MARK: - Components
    
    // Top Header with Close and Title
    private var navHeader: some View {
        HStack {
            Button {
                MoneHaptics.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MoneTheme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
            
            Spacer()
            
            Text(type == "INCOME" ? "Record Income" : (type == "TRANSFER" ? "Transfer Funds" : "Record Expense"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary)
            
            Spacer()
            
            // Trailing balance or spacer for alignment
            Color.clear
                .frame(width: 38, height: 38)
        }
    }
    
    // Source Balance Pill (Exact Screen 3)
    private var sourceBalancePill: some View {
        let currentBal = selectedAccount?.balance ?? database.totalBalance
        return HStack(spacing: 6) {
            Text("Balance is")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary)
            Text(String(format: "₹ %.2f", currentBal))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.deepBlack)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(MoneTheme.bgCardBlue)
        .clipShape(Capsule())
    }
    
    // Account Selector Card (Exact Screen 3)
    private var accountSelectorCard: some View {
        let acc = selectedAccount ?? database.accounts.first
        return Button {
            MoneHaptics.impact(.light)
            showAccountPickerModal = true
        } label: {
            HStack(spacing: 12) {
                if let a = acc {
                    a.bankInfo.badgeView(size: 38)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary)
                        
                        Text(a.accountNumber.isEmpty ? a.bankName : "\(a.bankName) •••• \(a.accountNumber.suffix(4))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary)
                    }
                } else {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(MoneTheme.textSecondary)
                    Text("Select Bank Account")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary)
                }
                
                Spacer()
                
                // Solid Black Chevron Circle (As seen in Screen 3)
                ZStack {
                    Circle()
                        .fill(MoneTheme.deepBlack)
                        .frame(width: 34, height: 34)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .whiteCard(cornerRadius: 20, padding: 14, shadowRadius: 8)
        }
    }
    
    // Type Selector (Black Pill Segmented Control from Image 1)
    private var typeSelector: some View {
        BlackPillSegmentedControl(
            items: [
                FluidSegmentItem(id: "EXPENSE", title: "Expense", icon: "arrow.down.right"),
                FluidSegmentItem(id: "INCOME", title: "Income", icon: "arrow.up.left"),
                FluidSegmentItem(id: "TRANSFER", title: "Transfer", icon: "arrow.left.arrow.right")
            ],
            selection: Binding(
                get: { self.type },
                set: { newType in
                    self.type = newType
                    if newType == "INCOME" {
                        self.selectedCategory = "Salary"
                    } else if newType == "EXPENSE" {
                        self.selectedCategory = "Food & Dining"
                    }
                }
            )
        )
    }
    
    // Currency & Amount Display (Exact Screen 3)
    private var amountHeroCard: some View {
        HStack(alignment: .center) {
            Text("INR")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(MoneTheme.bgCanvas)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            Spacer()
            
            HStack(spacing: 2) {
                Text("₹")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary)
                
                Text(amountString.isEmpty ? "0" : amountString)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                
                // Blinking cursor
                Rectangle()
                    .fill(MoneTheme.deepBlack)
                    .frame(width: 2.5, height: 28)
                    .opacity(0.8)
            }
        }
        .whiteCard(cornerRadius: 22, padding: 18, shadowRadius: 8)
    }
    
    // Merchant / Note Input
    private var merchantInputCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .foregroundColor(MoneTheme.textSecondary)
            TextField("Note / Payee (e.g. Swiggy, Uber, Rent)", text: $merchant)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary)
        }
        .whiteCard(cornerRadius: 18, padding: 14, shadowRadius: 6)
    }
    
    // Category Chips
    private var categorySelector: some View {
        let cats = database.categories.filter { $0.type == type }
        let list = cats.isEmpty ? defaultCategoriesForType(type) : cats
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(list) { cat in
                    let isSelected = selectedCategory.lowercased() == cat.name.lowercased()
                    Button {
                        MoneHaptics.selection()
                        selectedCategory = cat.name
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconForCategory(cat.name))
                                .font(.system(size: 11, weight: .bold))
                            Text(cat.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? MoneTheme.deepBlack : Color.white)
                        .foregroundColor(isSelected ? .white : MoneTheme.textSecondary)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.04), radius: 5, y: 2)
                    }
                }
            }
        }
    }
    
    // On-Screen Bespoke Numeric Keypad (Exact Screen 3)
    private var numericKeypad: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                keypadButton("1")
                keypadButton("2")
                keypadButton("3")
            }
            HStack(spacing: 8) {
                keypadButton("4")
                keypadButton("5")
                keypadButton("6")
            }
            HStack(spacing: 8) {
                keypadButton("7")
                keypadButton("8")
                keypadButton("9")
            }
            HStack(spacing: 8) {
                keypadButton(".")
                keypadButton("0")
                keypadBackButton
            }
        }
    }
    
    private func keypadButton(_ char: String) -> some View {
        Button {
            MoneHaptics.impact(.light)
            handleKeyPress(char)
        } label: {
            Text(char)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color(hex: "0D2040").opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
    
    private var keypadBackButton: some View {
        Button {
            MoneHaptics.impact(.light)
            if !amountString.isEmpty {
                amountString.removeLast()
            }
        } label: {
            Image(systemName: "delete.backward")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MoneTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color(hex: "0D2040").opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
    
    private func handleKeyPress(_ char: String) {
        if char == "." {
            if !amountString.contains(".") {
                if amountString.isEmpty {
                    amountString = "0."
                } else {
                    amountString.append(".")
                }
            }
        } else {
            if amountString == "0" {
                amountString = char
            } else if amountString.count < 9 {
                amountString.append(char)
            }
        }
    }
    
    // Bottom Action Slider (Exact Screen 3 Replication)
    private var bottomActionButton: some View {
        let isEnabled = !amountString.isEmpty && (Double(amountString) ?? 0) > 0
        return Button {
            saveTransaction()
        } label: {
            HStack {
                // Left Black Arrow Circle
                ZStack {
                    Circle()
                        .fill(MoneTheme.deepBlack)
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.leading, 4)
                
                Spacer()
                
                Text(type == "INCOME" ? "Swift to record >>>" : (type == "TRANSFER" ? "Swift to transfer >>>" : "Swift to send >>>"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.deepBlack)
                
                Spacer()
                
                // Right Icon Circle
                ZStack {
                    Circle()
                        .fill(MoneTheme.deepBlack)
                        .frame(width: 44, height: 44)
                    Image(systemName: "indianrupeesign")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(MoneTheme.bgCardBlue)
            .clipShape(Capsule())
            .shadow(color: Color(hex: "0D2040").opacity(isEnabled ? 0.08 : 0.02), radius: 8, y: 4)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
    }
    
    // Account Selection Modal Sheet
    private var accountSelectionModal: some View {
        ZStack {
            MoneTheme.bgCanvasGradient.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                Text("Select Account")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary)
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(database.accounts) { acc in
                            Button {
                                MoneHaptics.selection()
                                selectedAccountId = acc.id
                                showAccountPickerModal = false
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
                                        .monospacedDigit()
                                    
                                    if selectedAccountId == acc.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(MoneTheme.deepBlack)
                                    }
                                }
                                .whiteCard(cornerRadius: 16, padding: 12, shadowRadius: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private var selectedAccount: MoneAccount? {
        if let id = selectedAccountId {
            return database.accounts.first(where: { $0.id == id })
        }
        return database.accounts.first
    }
    
    private func saveTransaction() {
        guard let amt = Double(amountString), amt > 0 else { return }
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory : merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let tx = MoneTransaction(
            merchant: cleanMerchant,
            category: selectedCategory,
            amount: amt,
            type: type,
            date: date,
            accountId: selectedAccountId
        )
        
        MoneHaptics.notification(.success)
        database.addTransaction(tx)
        dismiss()
    }
    
    private func defaultCategoriesForType(_ t: String) -> [MoneCategory] {
        if t == "INCOME" {
            return [
                MoneCategory(name: "Salary", type: "INCOME"),
                MoneCategory(name: "Creator payments", type: "INCOME"),
                MoneCategory(name: "Freelance", type: "INCOME"),
                MoneCategory(name: "Investment", type: "INCOME"),
                MoneCategory(name: "Other", type: "INCOME")
            ]
        }
        return [
            MoneCategory(name: "Food & Dining", type: "EXPENSE"),
            MoneCategory(name: "Shopping", type: "EXPENSE"),
            MoneCategory(name: "Subscription payments", type: "EXPENSE"),
            MoneCategory(name: "Transport", type: "EXPENSE"),
            MoneCategory(name: "Bills & Utilities", type: "EXPENSE"),
            MoneCategory(name: "Groceries", type: "EXPENSE"),
            MoneCategory(name: "Entertainment", type: "EXPENSE"),
            MoneCategory(name: "Other", type: "EXPENSE")
        ]
    }
    
    private func iconForCategory(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("food") { return "fork.knife" }
        if lower.contains("shop") { return "bag.fill" }
        if lower.contains("subscript") { return "creditcard.fill" }
        if lower.contains("transp") { return "car.fill" }
        if lower.contains("bill") { return "bolt.fill" }
        if lower.contains("groc") { return "cart.fill" }
        if lower.contains("entertain") { return "tv.fill" }
        if lower.contains("creator") { return "play.rectangle.fill" }
        if lower.contains("sal") { return "banknote.fill" }
        return "tag.fill"
    }
}

// MARK: - Edit Transaction Sheet (Exact Screen 3 Replication with Delete & Date edit)
public struct EditTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    public let tx: MoneTransaction
    
    @State private var type: String = "EXPENSE"
    @State private var amountString: String = ""
    @State private var merchant: String = ""
    @State private var selectedCategory: String = "Food & Dining"
    @State private var selectedAccountId: Int64? = nil
    @State private var date: Date = Date()
    @State private var showAccountPickerModal: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    public init(tx: MoneTransaction) {
        self.tx = tx
    }
    
    public var body: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                navHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 1. Balance Pill Badge
                        sourceBalancePill
                        
                        // 2. Account Selector Card
                        accountSelectorCard
                        
                        // 3. Black Pill Segmented Control
                        typeSelector
                        
                        // 4. Large Currency & Amount Display
                        amountHeroCard
                        
                        // 5. Merchant / Note Input
                        merchantInputCard
                        
                        // 6. Date Selection Card
                        datePickerCard
                        
                        // 7. Category Chips
                        if type != "TRANSFER" {
                            categorySelector
                        }
                        
                        // 8. On-Screen Bespoke Numeric Keypad
                        numericKeypad
                            .padding(.top, 4)
                        
                        // 9. Bottom Action Buttons: Save & Delete
                        bottomActions
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showAccountPickerModal) {
            accountSelectionModal
                .presentationDetents([.medium])
        }
        .alert("Delete Transaction?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let id = tx.id {
                    MoneHaptics.notification(.warning)
                    database.deleteTransaction(id: id)
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently remove this record and recalculate your linked bank account balance.")
        }
        .onAppear {
            type = tx.type
            amountString = String(format: "%.0f", tx.amount)
            merchant = tx.merchant
            selectedCategory = tx.category
            selectedAccountId = tx.accountId
            date = tx.date
        }
    }
    
    // MARK: - Header
    private var navHeader: some View {
        HStack {
            Button {
                MoneHaptics.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .frame(width: 40, height: 40)
                    .background(isDarkMode ? Color(hex: "1B212D") : Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Edit Transaction")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            
            Spacer()
            
            Button {
                MoneHaptics.notification(.warning)
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MoneTheme.badgeRedText)
                    .frame(width: 40, height: 40)
                    .background(isDarkMode ? Color(hex: "1B212D") : Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Balance Pill
    private var sourceBalancePill: some View {
        let accBalance = selectedAccount?.balance ?? database.totalBalance
        return HStack(spacing: 6) {
            Text("Balance is")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "0284C7"))
            
            Text(String(format: "₹%.2f", accBalance))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "0284C7"))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(MoneTheme.bgCardBlue(isDark: isDarkMode))
        .clipShape(Capsule())
    }
    
    // MARK: - Account Selector Card
    private var accountSelectorCard: some View {
        Button {
            MoneHaptics.impact(.light)
            showAccountPickerModal = true
        } label: {
            HStack(spacing: 12) {
                if let acc = selectedAccount {
                    acc.bankInfo.badgeView(size: 40)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(acc.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        
                        Text(acc.accountNumber.isEmpty ? acc.bankName : "•••• \(acc.accountNumber)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                } else {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        .frame(width: 40, height: 40)
                    
                    Text("Select Bank Account")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white : MoneTheme.deepBlack)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                }
            }
            .whiteCard(cornerRadius: 20, padding: 14)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Type Selector
    private var typeSelector: some View {
        BlackPillSegmentedControl(
            items: [
                FluidSegmentItem(id: "EXPENSE", title: "Expense"),
                FluidSegmentItem(id: "INCOME", title: "Income"),
                FluidSegmentItem(id: "TRANSFER", title: "Transfer")
            ],
            selection: $type
        )
    }
    
    // MARK: - Amount Hero Card
    private var amountHeroCard: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("INR")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isDarkMode ? Color(hex: "1E2536") : MoneTheme.bgSegmentContainer)
                .clipShape(Capsule())
            
            Spacer()
            
            HStack(spacing: 2) {
                Text("₹")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                
                Text(amountString.isEmpty ? "0" : amountString)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                
                Rectangle()
                    .fill(Color(hex: "0284C7"))
                    .frame(width: 2.5, height: 30)
            }
        }
        .whiteCard(cornerRadius: 20, padding: 16)
    }
    
    // MARK: - Merchant Input Card
    private var merchantInputCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.line")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            TextField("Merchant or Payee note...", text: $merchant)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
        }
        .whiteCard(cornerRadius: 18, padding: 14)
    }
    
    // MARK: - Date Picker Card
    private var datePickerCard: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
        }
        .whiteCard(cornerRadius: 18, padding: 14)
    }
    
    // MARK: - Category Selector
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(defaultCategoriesForType(type)) { cat in
                    let isSelected = selectedCategory == cat.name
                    Button {
                        MoneHaptics.selection()
                        selectedCategory = cat.name
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconForCategory(cat.name))
                                .font(.system(size: 12, weight: .bold))
                            Text(cat.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textPrimary(isDark: isDarkMode))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "131722") : Color.white))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Numeric Keypad
    private var numericKeypad: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                keypadButton("1")
                keypadButton("2")
                keypadButton("3")
            }
            HStack(spacing: 8) {
                keypadButton("4")
                keypadButton("5")
                keypadButton("6")
            }
            HStack(spacing: 8) {
                keypadButton("7")
                keypadButton("8")
                keypadButton("9")
            }
            HStack(spacing: 8) {
                keypadButton(".")
                keypadButton("0")
                keypadDeleteButton
            }
        }
    }
    
    private func keypadButton(_ val: String) -> some View {
        Button {
            MoneHaptics.impact(.light)
            if val == "." {
                if !amountString.contains(".") {
                    amountString += amountString.isEmpty ? "0." : "."
                }
            } else {
                if amountString == "0" {
                    amountString = val
                } else if amountString.count < 9 {
                    amountString += val
                }
            }
        } label: {
            Text(val)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDarkMode ? Color(hex: "151926") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(isDarkMode ? 0.25 : 0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var keypadDeleteButton: some View {
        Button {
            MoneHaptics.impact(.medium)
            if !amountString.isEmpty {
                amountString.removeLast()
            }
        } label: {
            Image(systemName: "delete.backward")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDarkMode ? Color(hex: "151926") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(isDarkMode ? 0.25 : 0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 10) {
            // Save Button
            Button {
                updateTransaction()
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isDarkMode ? Color.white : MoneTheme.deepBlack)
                            .frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                    }
                    
                    Spacer()
                    
                    Text("Save Changes >>>")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(MoneTheme.bgCardBlue(isDark: isDarkMode))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "0284C7").opacity(0.15), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            
            // Delete Button
            Button {
                MoneHaptics.notification(.warning)
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                    Text("Delete This Transaction")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(MoneTheme.badgeRedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MoneTheme.badgeRedBg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var accountSelectionModal: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                Text("Select Bank Account")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(database.accounts) { acc in
                            let isSelected = (selectedAccountId == acc.id)
                            Button {
                                MoneHaptics.selection()
                                selectedAccountId = acc.id
                                showAccountPickerModal = false
                            } label: {
                                HStack(spacing: 12) {
                                    acc.bankInfo.badgeView(size: 38)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(acc.name)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                        Text(acc.bankName)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                    }
                                    
                                    Spacer()
                                    
                                    Text(acc.formattedBalance)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "0284C7"))
                                    }
                                }
                                .whiteCard(cornerRadius: 16, padding: 12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private var selectedAccount: MoneAccount? {
        if let id = selectedAccountId {
            return database.accounts.first(where: { $0.id == id })
        }
        return database.accounts.first
    }
    
    private func updateTransaction() {
        guard let amt = Double(amountString), amt > 0 else { return }
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory : merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let updatedTx = MoneTransaction(
            id: tx.id,
            merchant: cleanMerchant,
            category: selectedCategory,
            amount: amt,
            type: type,
            date: date,
            accountId: selectedAccountId
        )
        
        MoneHaptics.notification(.success)
        database.updateTransaction(updatedTx)
        dismiss()
    }
    
    private func defaultCategoriesForType(_ t: String) -> [MoneCategory] {
        if t == "INCOME" {
            return [
                MoneCategory(name: "Salary", type: "INCOME"),
                MoneCategory(name: "Creator payments", type: "INCOME"),
                MoneCategory(name: "Freelance", type: "INCOME"),
                MoneCategory(name: "Investment", type: "INCOME"),
                MoneCategory(name: "Other", type: "INCOME")
            ]
        }
        return [
            MoneCategory(name: "Food & Dining", type: "EXPENSE"),
            MoneCategory(name: "Shopping", type: "EXPENSE"),
            MoneCategory(name: "Subscription payments", type: "EXPENSE"),
            MoneCategory(name: "Transport", type: "EXPENSE"),
            MoneCategory(name: "Bills & Utilities", type: "EXPENSE"),
            MoneCategory(name: "Groceries", type: "EXPENSE"),
            MoneCategory(name: "Entertainment", type: "EXPENSE"),
            MoneCategory(name: "Other", type: "EXPENSE")
        ]
    }
    
    private func iconForCategory(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("food") { return "fork.knife" }
        if lower.contains("shop") { return "bag.fill" }
        if lower.contains("subscript") { return "creditcard.fill" }
        if lower.contains("transp") { return "car.fill" }
        if lower.contains("bill") { return "bolt.fill" }
        if lower.contains("groc") { return "cart.fill" }
        if lower.contains("entertain") { return "tv.fill" }
        if lower.contains("creator") { return "play.rectangle.fill" }
        if lower.contains("sal") { return "banknote.fill" }
        return "tag.fill"
    }
}
