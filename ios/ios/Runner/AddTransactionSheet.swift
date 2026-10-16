import SwiftUI

// MARK: - Add / Edit Transaction Sheet
public struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    
    @State private var type: String = "EXPENSE"
    @State private var amountString: String = ""
    @State private var merchant: String = ""
    @State private var selectedCategory: String = "Food & Dining"
    @State private var selectedAccountId: Int64? = nil
    @State private var date: Date = Date()
    
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
        NavigationStack {
            ZStack {
                MoneTheme.bgDeepVoid.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Type Switcher
                        typeSelector
                        
                        // 2. Amount Input
                        amountHeroCard
                        
                        // 3. Category Selector
                        if type != "TRANSFER" {
                            categorySelector
                        }
                        
                        // 4. Account Picker
                        accountPicker
                        
                        // 5. Merchant / Note Input
                        merchantInputCard
                        
                        // 6. Date Picker Row
                        datePickerCard
                        
                        // 7. Log Button
                        logButton
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Track Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        MoneHaptics.selection()
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .onAppear {
                initializeDefaults()
            }
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
    private var typeSelector: some View {
        FluidSegmentedControl(
            items: [
                FluidSegmentItem(id: "EXPENSE", title: "Expense", icon: "arrow.down.right.circle.fill", accentColor: MoneTheme.rose),
                FluidSegmentItem(id: "INCOME", title: "Income", icon: "arrow.up.left.circle.fill", accentColor: MoneTheme.emerald),
                FluidSegmentItem(id: "TRANSFER", title: "Transfer", icon: "arrow.left.arrow.right.circle.fill", accentColor: MoneTheme.cyan)
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
    
    private var amountHeroCard: some View {
        let accent = type == "INCOME" ? MoneTheme.emerald : (type == "TRANSFER" ? MoneTheme.cyan : MoneTheme.rose)
        return VStack(spacing: 8) {
            Text(type == "INCOME" ? "AMOUNT RECEIVED" : (type == "TRANSFER" ? "AMOUNT TRANSFERRED" : "AMOUNT SPENT"))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .tracking(1.4)
            
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("₹")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(accent)
                
                TextField("0", text: $amountString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .spatialGlass(cornerRadius: 26, padding: 22, glow: accent, glowRadius: 14)
    }

    
    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            let cats = database.categories.filter { $0.type == type }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cats.isEmpty ? defaultCategoriesForType(type) : cats) { cat in
                        let isSelected = selectedCategory.lowercased() == cat.name.lowercased()
                        Button {
                            MoneHaptics.selection()
                            selectedCategory = cat.name
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: iconForCategory(cat.name))
                                    .font(.system(size: 12, weight: .bold))
                                Text(cat.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                isSelected ? MoneTheme.indigo : Color.white.opacity(0.06)
                            )
                            .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(isSelected ? 0.3 : 0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var accountPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(database.accounts) { acc in
                        let isSelected = selectedAccountId == acc.id
                        Button {
                            MoneHaptics.selection()
                            selectedAccountId = acc.id
                        } label: {
                            HStack(spacing: 10) {
                                acc.bankInfo.badgeView(size: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(acc.name)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(acc.formattedBalance)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                isSelected ? Color(hex: "232738") : Color.white.opacity(0.05)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? MoneTheme.indigo : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var merchantInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title / Merchant")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundColor(.white.opacity(0.4))
                
                TextField("e.g. Swiggy, Uber, Starbucks", text: $merchant)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var datePickerCard: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(MoneTheme.indigo)
                Text("Date & Time")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .colorScheme(.dark)
        }
        .glassCard(cornerRadius: 16, padding: 12)
    }
    
    private var logButton: some View {
        let isEnabled = !amountString.isEmpty && (Double(amountString) ?? 0) > 0
        let gradientColors = type == "INCOME" ? 
            [Color(hex: "059669"), Color(hex: "10E599")] : 
            (type == "TRANSFER" ? [Color(hex: "0284C7"), Color(hex: "00D2FF")] : [Color(hex: "6366F1"), Color(hex: "A855F7"), Color(hex: "FF2E63")])
        let shadowColor = type == "INCOME" ? MoneTheme.emerald : (type == "TRANSFER" ? MoneTheme.cyan : MoneTheme.indigo)
        
        return Button {
            saveTransaction()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                Text(type == "INCOME" ? "RECORD INCOME" : (type == "TRANSFER" ? "RECORD TRANSFER" : "RECORD EXPENSE"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: shadowColor.opacity(isEnabled ? 0.45 : 0.1), radius: 14, x: 0, y: 6)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
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
                MoneCategory(name: "Freelance", type: "INCOME"),
                MoneCategory(name: "Investment", type: "INCOME"),
                MoneCategory(name: "Other", type: "INCOME")
            ]
        }
        return [
            MoneCategory(name: "Food & Dining", type: "EXPENSE"),
            MoneCategory(name: "Shopping", type: "EXPENSE"),
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
        if lower.contains("transp") { return "car.fill" }
        if lower.contains("bill") { return "bolt.fill" }
        if lower.contains("groc") { return "cart.fill" }
        if lower.contains("entertain") { return "tv.fill" }
        if lower.contains("sal") { return "banknote.fill" }
        return "tag.fill"
    }
}
