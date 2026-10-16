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
