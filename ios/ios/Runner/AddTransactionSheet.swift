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
        HStack(spacing: 8) {
            typeButton(title: "Expense", rawType: "EXPENSE", activeColor: MoneTheme.rose)
            typeButton(title: "Income", rawType: "INCOME", activeColor: MoneTheme.emerald)
            typeButton(title: "Transfer", rawType: "TRANSFER", activeColor: MoneTheme.cyan)
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func typeButton(title: String, rawType: String, activeColor: Color) -> some View {
        let isSelected = type == rawType
        return Button {
            MoneHaptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                type = rawType
                if rawType == "INCOME" {
                    selectedCategory = "Salary"
                } else if rawType == "EXPENSE" {
                    selectedCategory = "Food & Dining"
                }
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected ? activeColor.opacity(0.85) : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private var amountHeroCard: some View {
        VStack(spacing: 8) {
            Text(type == "INCOME" ? "AMOUNT RECEIVED" : "AMOUNT SPENT")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(type == "INCOME" ? MoneTheme.emerald : MoneTheme.rose)
                
                TextField("0", text: $amountString)
                    .keyboardType(.numberPad)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .glassCard(cornerRadius: 24, padding: 20)
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
        Button {
            saveTransaction()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(type == "INCOME" ? "Record Income" : "Record Expense")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: type == "INCOME" ? [Color(hex: "059669"), Color(hex: "10B981")] : [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: (type == "INCOME" ? MoneTheme.emerald : MoneTheme.indigo).opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .disabled(amountString.isEmpty || (Double(amountString) ?? 0) <= 0)
        .opacity((amountString.isEmpty || (Double(amountString) ?? 0) <= 0) ? 0.5 : 1.0)
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
