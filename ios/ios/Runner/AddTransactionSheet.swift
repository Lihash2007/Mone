import SwiftUI
import PhotosUI

// MARK: - Add / Quick Log Transaction Sheet (Commercial FinTech Edition)
public struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var database = MoneDatabase.shared
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var type: String = "EXPENSE"
    @State private var amountString: String = ""
    @State private var merchant: String = ""
    @State private var selectedCategory: String = "Food & Dining"
    @State private var selectedAccountId: Int64? = nil
    @State private var targetAccountId: Int64? = nil // For transfers
    @State private var date: Date = Date()
    @State private var selectedPaymentMode: String = "UPI"
    @State private var selectedTags: Set<String> = []
    
    @State private var showAccountPickerModal: Bool = false
    @State private var pickingTransferTarget: TransferTarget = .from
    @State private var showDatePickerModal: Bool = false
    @State private var selectedReceiptItem: PhotosPickerItem? = nil
    @State private var receiptImageData: Data? = nil
    @State private var showDigitalReceipt: Bool = false
    
    // Calculator State
    @State private var previousOperand: Double? = nil
    @State private var pendingOperator: String? = nil
    
    public var prefillMerchant: String? = nil
    public var prefillAmount: Double? = nil
    public var prefillCategory: String? = nil
    public var prefillType: String? = nil
    public var prefillAccountId: Int64? = nil
    
    public enum TransferTarget {
        case from, to
    }
    
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
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                navHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // 1. Balance Pill Badge
                        sourceBalancePill
                        
                        // 2. Type Selector: Expense / Income / Transfer
                        typeSelector
                        
                        // 3. Account Card / Transfer Visual Flow
                        if type == "TRANSFER" {
                            transferVisualizerCard
                        } else {
                            accountSelectorCard
                        }
                        
                        // 4. Large Currency & Amount Display (with Category Atmospheric Halo & Brand Morphing)
                        ZStack {
                            categoryAtmosphericGlow
                            amountHeroCard
                        }
                        
                        // 5. Quick Preset Amount Chips ("Fast Add")
                        quickAmountChips
                        
                        // 6. Interactive Amount Dial / Quick Stepper
                        amountScrubberDial
                        
                        // 7. Merchant / Note Input
                        merchantInputCard
                        
                        // 8. Date & Time Backdating Pill
                        datePickerCard
                        
                        // 9. Payment Mode Selector
                        paymentModeSelector
                        
                        // 10. Category Chips (if not Transfer)
                        if type != "TRANSFER" {
                            categorySelector
                        }
                        
                        // 11. Tags & Reimbursable Flag
                        tagsSelector
                        
                        // 12. Optional Receipt Attachment Preview
                        receiptAttachmentCard
                        
                        // 13. Digital Receipt Slip Preview Trigger
                        digitalReceiptTriggerCard
                        
                        // 14. Liquid Glass Keypad with Calculator Bar
                        numericKeypadSection
                            .padding(.top, 4)
                        
                        // 15. Interactive "Slide-to-Confirm" Bottom Slider
                        SlideToConfirmButton(
                            title: type == "INCOME" ? "Swift to record income >>>" : (type == "TRANSFER" ? "Swift to transfer >>>" : "Swift to record expense >>>"),
                            isDark: isDarkMode
                        ) {
                            saveTransaction()
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 28)
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
        .sheet(isPresented: $showDatePickerModal) {
            datePickerSheet
                .presentationDetents([.fraction(0.45)])
        }
        .sheet(isPresented: $showDigitalReceipt) {
            DigitalReceiptSlipSheet(
                merchant: merchant.isEmpty ? (type == "TRANSFER" ? "Account Transfer" : selectedCategory) : merchant,
                amount: Double(amountString) ?? 0.0,
                category: selectedCategory,
                type: type,
                accountId: selectedAccountId,
                date: date,
                paymentMode: selectedPaymentMode,
                tags: Array(selectedTags)
            )
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
        if database.accounts.count > 1 {
            targetAccountId = database.accounts.first(where: { $0.id != selectedAccountId })?.id
        }
    }
    
    // MARK: - 1. Top Header
    private var navHeader: some View {
        HStack {
            Button {
                MoneHaptics.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .frame(width: 38, height: 38)
                    .background(isDarkMode ? Color(hex: "151926") : Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1))
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(type == "INCOME" ? "Record Income" : (type == "TRANSFER" ? "Transfer Funds" : "Record Expense"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            
            Spacer()
            
            // Clear / Reset Button
            Button {
                MoneHaptics.impact(.light)
                amountString = ""
                merchant = ""
                previousOperand = nil
                pendingOperator = nil
            } label: {
                Text("Clear")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "0284C7"))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 2. Source Balance Pill
    private var sourceBalancePill: some View {
        let currentBal = selectedAccount?.balance ?? database.totalBalance
        return HStack(spacing: 6) {
            Text("Balance is")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(isDarkMode ? Color(hex: "94A3B8") : MoneTheme.textSecondary)
            Text(String(format: "₹ %.2f", currentBal))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "0284C7"))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(MoneTheme.bgCardBlue(isDark: isDarkMode))
        .clipShape(Capsule())
    }
    
    // MARK: - 3. Type Selector
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
    
    // MARK: - 4. Account Selector Card (Single Account)
    private var accountSelectorCard: some View {
        let acc = selectedAccount ?? database.accounts.first
        return Button {
            MoneHaptics.impact(.light)
            pickingTransferTarget = .from
            showAccountPickerModal = true
        } label: {
            HStack(spacing: 12) {
                if let a = acc {
                    a.bankInfo.badgeView(size: 38)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                        
                        Text(a.accountNumber.isEmpty ? a.bankName : "\(a.bankName) •••• \(a.accountNumber.suffix(4))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    }
                } else {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                    Text("Select Bank Account")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
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
    
    // MARK: - 5. Visual "From ➔ To" Transfer Flow
    private var transferVisualizerCard: some View {
        let fromAcc = selectedAccount ?? database.accounts.first
        let toAcc = targetAccount ?? database.accounts.last
        
        return HStack(spacing: 8) {
            // FROM card
            Button {
                pickingTransferTarget = .from
                showAccountPickerModal = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FROM")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                    HStack(spacing: 6) {
                        fromAcc?.bankInfo.badgeView(size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(fromAcc?.name ?? "Select")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                .lineLimit(1)
                            Text("₹\(Int(fromAcc?.balance ?? 0))")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(isDarkMode ? Color(hex: "181D2A") : Color(hex: "F3F7FA"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // Swap Button
            Button {
                MoneHaptics.selection()
                let temp = selectedAccountId
                selectedAccountId = targetAccountId
                targetAccountId = temp
            } label: {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white : MoneTheme.deepBlack)
                        .frame(width: 34, height: 34)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                }
            }
            .buttonStyle(.plain)
            
            // TO card
            Button {
                pickingTransferTarget = .to
                showAccountPickerModal = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TO")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(MoneTheme.badgeGreenText)
                    HStack(spacing: 6) {
                        toAcc?.bankInfo.badgeView(size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(toAcc?.name ?? "Select")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                .lineLimit(1)
                            Text("₹\(Int(toAcc?.balance ?? 0))")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(isDarkMode ? Color(hex: "181D2A") : Color(hex: "F3F7FA"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .whiteCard(cornerRadius: 20, padding: 12)
    }
    
    // MARK: - 6. Amount Hero Card with Brand Halo Morphing
    private var amountHeroCard: some View {
        let brandHalo = brandColor(for: merchant)
        return HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Text("INR")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                
                if let bColor = brandHalo {
                    Circle()
                        .fill(bColor)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isDarkMode ? Color(hex: "1B212D") : MoneTheme.bgSegmentContainer)
            .clipShape(Capsule())
            
            Spacer()
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(brandHalo ?? (isDarkMode ? Color(hex: "60A5FA") : MoneTheme.textPrimary(isDark: isDarkMode)))
                
                Text(amountString.isEmpty ? "0" : amountString)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                
                // Active cursor
                Rectangle()
                    .fill(brandHalo ?? Color(hex: "0284C7"))
                    .frame(width: 2.5, height: 28)
                    .opacity(0.85)
            }
        }
        .whiteCard(cornerRadius: 22, padding: 18, shadowRadius: 8)
    }
    
    // MARK: - 7. Quick Amount Chips ("Fast Add")
    private var quickAmountChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([100, 250, 500, 1000, 2000, 5000], id: \.self) { preset in
                    Button {
                        MoneHaptics.impact(.light)
                        let current = Double(amountString) ?? 0.0
                        amountString = String(format: "%.0f", current + Double(preset))
                    } label: {
                        Text("+₹\(preset)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(isDarkMode ? Color.white : MoneTheme.deepBlack)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isDarkMode ? Color(hex: "181E2B") : Color(hex: "E4EFF7"))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Category Atmospheric Halo Glow
    private var categoryAtmosphericGlow: some View {
        let glowColor: Color = {
            let cat = selectedCategory.lowercased()
            if cat.contains("food") || cat.contains("dining") { return Color(hex: "F97316") }
            if cat.contains("shopping") { return Color(hex: "EC4899") }
            if cat.contains("transport") { return Color(hex: "06B6D4") }
            if cat.contains("bills") || cat.contains("utilities") { return Color(hex: "3B82F6") }
            if cat.contains("salary") { return Color(hex: "10B981") }
            if cat.contains("entertainment") { return Color(hex: "8B5CF6") }
            if cat.contains("groceries") { return Color(hex: "F59E0B") }
            return Color(hex: "0284C7")
        }()
        
        return RadialGradient(
            gradient: Gradient(colors: [
                glowColor.opacity(isDarkMode ? 0.32 : 0.16),
                Color.clear
            ]),
            center: .center,
            startRadius: 20,
            endRadius: 180
        )
        .frame(height: 120)
        .blur(radius: 16)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.35), value: selectedCategory)
    }
    
    // MARK: - Amount Scrubber Dial / Stepper
    private var amountScrubberDial: some View {
        HStack(spacing: 8) {
            quickStepButton(delta: -500, label: "−₹500")
            quickStepButton(delta: -100, label: "−₹100")
            
            // Center Tactile Scrubber Indicator
            HStack(spacing: 4) {
                ForEach(0..<5) { idx in
                    Capsule()
                        .fill(MoneTheme.textSecondary(isDark: isDarkMode).opacity(idx == 2 ? 0.9 : 0.3))
                        .frame(width: 3, height: idx == 2 ? 14 : 7)
                }
            }
            .frame(maxWidth: .infinity)
            
            quickStepButton(delta: 100, label: "+₹100")
            quickStepButton(delta: 500, label: "+₹500")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isDarkMode ? Color(hex: "121622") : Color(hex: "F1F5F9"))
        .clipShape(Capsule())
    }
    
    private func quickStepButton(delta: Double, label: String) -> some View {
        Button {
            MoneHaptics.selection()
            let current = Double(amountString) ?? 0.0
            let next = max(current + delta, 0.0)
            amountString = String(format: "%.0f", next)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(delta > 0 ? Color(hex: "0284C7") : MoneTheme.textSecondary(isDark: isDarkMode))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isDarkMode ? Color(hex: "181D2A") : Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 8. Merchant / Note Input
    private var merchantInputCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.line")
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            
            TextField("Note / Payee (e.g. Swiggy, Starbucks, Rent)", text: $merchant)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
            
            if !merchant.isEmpty {
                Button {
                    merchant = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                }
            }
        }
        .whiteCard(cornerRadius: 18, padding: 14, shadowRadius: 6)
    }
    
    // MARK: - 9. Date & Time Backdating Card
    private var datePickerCard: some View {
        Button {
            MoneHaptics.impact(.light)
            showDatePickerModal = true
        } label: {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(Color(hex: "0284C7"))
                    Text(formattedDate(date))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                }
                
                Spacer()
                
                Text("Change Date")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "0284C7"))
            }
            .whiteCard(cornerRadius: 18, padding: 14)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 10. Payment Mode Selector
    private var paymentModeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["UPI", "Credit Card", "Debit Card", "Cash", "Net Banking"], id: \.self) { mode in
                    let isSelected = selectedPaymentMode == mode
                    Button {
                        MoneHaptics.selection()
                        selectedPaymentMode = mode
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: iconForPaymentMode(mode))
                                .font(.system(size: 11, weight: .bold))
                            Text(mode)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textSecondary(isDark: isDarkMode))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "151926") : Color.white))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1))
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - 11. Category Chips
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
                        .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "151926") : Color.white))
                        .foregroundColor(isSelected ? (isDarkMode ? Color(hex: "10141D") : .white) : MoneTheme.textSecondary(isDark: isDarkMode))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1))
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.2 : 0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - 12. Tags & Reimbursable
    private var tagsSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["#Personal", "#Work", "#Trip", "#Family", "🔖 Reimbursable"], id: \.self) { tag in
                    let isSelected = selectedTags.contains(tag)
                    Button {
                        MoneHaptics.selection()
                        if isSelected {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    } label: {
                        Text(tag)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? Color(hex: "0284C7") : MoneTheme.textSecondary(isDark: isDarkMode))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? (isDarkMode ? Color(hex: "172A3D") : Color(hex: "D8EBF7")) : (isDarkMode ? Color(hex: "151926") : Color.white))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isDarkMode ? Color.white.opacity(0.06) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - 13. Receipt Photo Attachment
    private var receiptAttachmentCard: some View {
        HStack {
            PhotosPicker(selection: $selectedReceiptItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(Color(hex: "0284C7"))
                    Text(receiptImageData == nil ? "Attach Receipt / Bill" : "Receipt Attached ✓")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                }
            }
            .buttonStyle(.plain)
            .onChange(of: selectedReceiptItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        receiptImageData = data
                        MoneHaptics.notification(.success)
                    }
                }
            }
            
            Spacer()
            
            if let data = receiptImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .whiteCard(cornerRadius: 16, padding: 12)
    }
    
    // MARK: - 13. Digital Receipt Slip Trigger Card
    private var digitalReceiptTriggerCard: some View {
        Button {
            MoneHaptics.selection()
            showDigitalReceipt = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "0284C7"))
                Text("Preview Digital Slip / Perforated Receipt")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            }
        }
        .buttonStyle(.plain)
        .whiteCard(cornerRadius: 16, padding: 12)
    }
    
    // MARK: - 14. Keypad with Calculator Bar
    private var numericKeypadSection: some View {
        VStack(spacing: 8) {
            // Calculator Operator Bar
            HStack(spacing: 6) {
                calcOperatorButton("+")
                calcOperatorButton("−")
                calcOperatorButton("×")
                calcOperatorButton("÷")
                calcOperatorButton("%")
                calcOperatorButton("C")
            }
            
            // 4x3 Number Pad
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
    
    private func calcOperatorButton(_ op: String) -> some View {
        Button {
            MoneHaptics.impact(.light)
            handleCalculatorOperator(op)
        } label: {
            Text(op)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "0284C7"))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(isDarkMode ? Color(hex: "172435") : Color(hex: "E8F2FA"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func keypadButton(_ char: String) -> some View {
        Button {
            MoneHaptics.impact(.light)
            handleKeyPress(char)
        } label: {
            Text(char)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDarkMode ? Color(hex: "151926") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isDarkMode ? Color.black.opacity(0.35) : Color(hex: "0D2040").opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isDarkMode ? Color(hex: "151926") : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isDarkMode ? Color.black.opacity(0.35) : Color(hex: "0D2040").opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Keypad Handling
    private func handleKeyPress(_ char: String) {
        if char == "." {
            if !amountString.contains(".") {
                amountString += amountString.isEmpty ? "0." : "."
            }
        } else {
            if amountString == "0" {
                amountString = char
            } else if amountString.count < 9 {
                amountString += char
            }
        }
    }
    
    private func handleCalculatorOperator(_ op: String) {
        if op == "C" {
            amountString = ""
            previousOperand = nil
            pendingOperator = nil
            return
        }
        
        let current = Double(amountString) ?? 0.0
        if let prev = previousOperand, let pending = pendingOperator {
            var result: Double = current
            switch pending {
            case "+": result = prev + current
            case "−": result = prev - current
            case "×": result = prev * current
            case "÷": result = current != 0 ? prev / current : prev
            case "%": result = prev * (current / 100.0)
            default: break
            }
            amountString = String(format: "%.0f", result)
            previousOperand = result
        } else {
            previousOperand = current
            amountString = ""
        }
        pendingOperator = op
    }
    
    // MARK: - Date Picker Sheet
    private var datePickerSheet: some View {
        VStack {
            HStack {
                Text("Select Transaction Date")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                Spacer()
                Button("Done") { showDatePickerModal = false }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "0284C7"))
            }
            .padding()
            
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
            
            Spacer()
        }
        .background(MoneTheme.bgCanvasGradient(isDark: isDarkMode))
    }
    
    // MARK: - Account Selection Modal
    private var accountSelectionModal: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                Text(pickingTransferTarget == .to ? "Select Destination Account" : "Select Bank Account")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(database.accounts) { acc in
                            let isSelected = (pickingTransferTarget == .to ? targetAccountId == acc.id : selectedAccountId == acc.id)
                            Button {
                                MoneHaptics.selection()
                                if pickingTransferTarget == .to {
                                    targetAccountId = acc.id
                                } else {
                                    selectedAccountId = acc.id
                                }
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
    
    // MARK: - Save Action
    private func saveTransaction() {
        guard let amt = Double(amountString), amt > 0 else { return }
        var cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanMerchant.isEmpty {
            cleanMerchant = type == "TRANSFER" ? "Account Transfer" : selectedCategory
        }
        
        // Append active tags if any
        if !selectedTags.isEmpty {
            cleanMerchant += " " + selectedTags.joined(separator: " ")
        }
        
        if type == "TRANSFER", let fromId = selectedAccountId, let toId = targetAccountId {
            // Log outgoing transfer
            database.addTransaction(MoneTransaction(
                merchant: "Transfer to \(targetAccount?.name ?? "Account")",
                category: "Transfer",
                amount: amt,
                type: "EXPENSE",
                date: date,
                accountId: fromId
            ))
            // Log incoming transfer
            database.addTransaction(MoneTransaction(
                merchant: "Transfer from \(selectedAccount?.name ?? "Account")",
                category: "Transfer",
                amount: amt,
                type: "INCOME",
                date: date,
                accountId: toId
            ))
        } else {
            let tx = MoneTransaction(
                merchant: cleanMerchant,
                category: selectedCategory,
                amount: amt,
                type: type,
                date: date,
                accountId: selectedAccountId
            )
            database.addTransaction(tx)
        }
        let bankId = selectedAccount?.bankInfo.id
        let prefix = type == "INCOME" ? "+" : (type == "TRANSFER" ? "⇄" : "-")
        MoneHUDManager.shared.show(
            title: "\(prefix)₹\(String(format: "%.0f", amt)) Recorded",
            subtitle: "\(cleanMerchant) • \(selectedAccount?.name ?? "Account")",
            bankId: bankId
        )
        
        MoneHaptics.notification(.success)
        dismiss()
    }
    
    // MARK: - Helpers
    private var selectedAccount: MoneAccount? {
        if let id = selectedAccountId {
            return database.accounts.first(where: { $0.id == id })
        }
        return database.accounts.first
    }
    
    private var targetAccount: MoneAccount? {
        if let id = targetAccountId {
            return database.accounts.first(where: { $0.id == id })
        }
        return database.accounts.first(where: { $0.id != selectedAccountId }) ?? database.accounts.last
    }
    
    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d • h:mm a"
        return f.string(from: d)
    }
    
    private func brandColor(for text: String) -> Color? {
        let l = text.lowercased()
        if l.contains("swiggy") { return Color(hex: "FC8019") }
        if l.contains("zomato") { return Color(hex: "CB202D") }
        if l.contains("starbucks") { return Color(hex: "006241") }
        if l.contains("uber") { return Color(hex: "000000") }
        if l.contains("amazon") { return Color(hex: "FF9900") }
        if l.contains("netflix") { return Color(hex: "E50914") }
        if l.contains("spotify") { return Color(hex: "1DB954") }
        if l.contains("apple") { return Color(hex: "A2AAAD") }
        return nil
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
    
    private func iconForPaymentMode(_ mode: String) -> String {
        switch mode {
        case "UPI": return "iphone.gen3"
        case "Credit Card": return "creditcard.fill"
        case "Debit Card": return "creditcard"
        case "Cash": return "banknote.fill"
        default: return "globe"
        }
    }
}

// MARK: - Interactive Slide-to-Confirm Slider (Apple Pay Style)
public struct SlideToConfirmButton: View {
    public let title: String
    public let isDark: Bool
    public let onConfirm: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isConfirmed: Bool = false
    
    public init(title: String, isDark: Bool, onConfirm: @escaping () -> Void) {
        self.title = title
        self.isDark = isDark
        self.onConfirm = onConfirm
    }
    
    public var body: some View {
        GeometryReader { geo in
            let maxDrag = max(geo.size.width - 56, 1)
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(isDark ? Color(hex: "172435") : Color(hex: "D8EBF7"))
                
                // Active Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "0284C7"), Color(hex: "38BDF8")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(dragOffset + 50, 0))
                    .opacity(dragOffset > 0 ? 0.35 : 0)
                
                // Track Label
                HStack {
                    Spacer()
                    Text(isConfirmed ? "Recorded!" : title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0284C7"))
                    Spacer()
                }
                
                // Draggable Thumb Capsule
                ZStack {
                    Circle()
                        .fill(isDark ? Color.white : MoneTheme.deepBlack)
                        .frame(width: 48, height: 48)
                        .shadow(color: (isDark ? Color.white : MoneTheme.deepBlack).opacity(0.3), radius: 6, y: 2)
                    
                    Image(systemName: isConfirmed ? "checkmark" : "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isDark ? Color(hex: "10141D") : .white)
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { val in
                            if !isConfirmed {
                                dragOffset = min(max(val.translation.width, 0), maxDrag)
                            }
                        }
                        .onEnded { val in
                            if dragOffset >= maxDrag * 0.70 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = maxDrag
                                    isConfirmed = true
                                }
                                MoneHaptics.notification(.success)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    onConfirm()
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .clipShape(Capsule())
            .onTapGesture {
                // 1-Tap fallback
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    dragOffset = maxDrag
                    isConfirmed = true
                }
                MoneHaptics.notification(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onConfirm()
                }
            }
        }
        .frame(height: 52)
    }
}

// MARK: - Edit Transaction Sheet
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
    @State private var showDigitalReceipt: Bool = false
    
    public init(tx: MoneTransaction) {
        self.tx = tx
    }
    
    public var body: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 0) {
                navHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        sourceBalancePill
                        accountSelectorCard
                        typeSelector
                        amountHeroCard
                        merchantInputCard
                        datePickerCard
                        digitalReceiptButton
                        if type != "TRANSFER" {
                            categorySelector
                        }
                        numericKeypad
                            .padding(.top, 4)
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
        .sheet(isPresented: $showDigitalReceipt) {
            DigitalReceiptSlipSheet(
                merchant: merchant.isEmpty ? selectedCategory : merchant,
                amount: Double(amountString) ?? tx.amount,
                category: selectedCategory,
                type: type,
                accountId: selectedAccountId,
                date: date
            )
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
                    .background(isDarkMode ? Color(hex: "151926") : Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1))
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
                    .background(isDarkMode ? Color(hex: "151926") : Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1))
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
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
    
    private var amountHeroCard: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("INR")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isDarkMode ? Color(hex: "1B212D") : MoneTheme.bgSegmentContainer)
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
    
    private var digitalReceiptButton: some View {
        Button {
            MoneHaptics.selection()
            showDigitalReceipt = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "0284C7"))
                Text("View Digital Slip / Perforated Receipt")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            }
        }
        .buttonStyle(.plain)
        .whiteCard(cornerRadius: 16, padding: 12)
    }
    
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
                        .background(isSelected ? (isDarkMode ? Color.white : MoneTheme.deepBlack) : (isDarkMode ? Color(hex: "151926") : Color.white))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1))
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.05), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
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
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
                )
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
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isDarkMode ? 0.25 : 0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var bottomActions: some View {
        VStack(spacing: 10) {
            SlideToConfirmButton(
                title: "Swift to save changes >>>",
                isDark: isDarkMode
            ) {
                updateTransaction()
            }
            
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
        
        let bankId = selectedAccount?.bankInfo.id
        let prefix = type == "INCOME" ? "+" : "-"
        MoneHUDManager.shared.show(
            title: "\(prefix)₹\(String(format: "%.0f", amt)) Updated",
            subtitle: "\(cleanMerchant) • \(selectedAccount?.name ?? "Account")",
            bankId: bankId
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

// MARK: - Perforated Digital Receipt Slip Sheet
public struct DigitalReceiptSlipSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @ObservedObject private var database = MoneDatabase.shared
    
    public let merchant: String
    public let amount: Double
    public let category: String
    public let type: String
    public let accountId: Int64?
    public let date: Date
    public let paymentMode: String
    public let tags: [String]
    
    @State private var showShareSheet: Bool = false
    
    public init(
        merchant: String,
        amount: Double,
        category: String,
        type: String,
        accountId: Int64?,
        date: Date = Date(),
        paymentMode: String = "UPI Instant",
        tags: [String] = []
    ) {
        self.merchant = merchant
        self.amount = amount
        self.category = category
        self.type = type
        self.accountId = accountId
        self.date = date
        self.paymentMode = paymentMode
        self.tags = tags
    }
    
    public init(tx: MoneTransaction) {
        self.merchant = tx.merchant
        self.amount = tx.amount
        self.category = tx.category
        self.type = tx.type
        self.accountId = tx.accountId
        self.date = tx.date
        self.paymentMode = "UPI Instant"
        self.tags = []
    }
    
    private var account: MoneAccount? {
        if let id = accountId {
            return database.accounts.first(where: { $0.id == id })
        }
        return database.accounts.first
    }
    
    public var body: some View {
        ZStack {
            MoneTheme.bgCanvasGradient(isDark: isDarkMode).ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Top close bar
                HStack {
                    Text("Digital Receipt Slip")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                            .padding(8)
                            .background(isDarkMode ? Color(hex: "151926") : Color.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Perforated Top Tear Notch
                        perforatedTopHeader
                        
                        // Main Receipt Body
                        VStack(spacing: 16) {
                            // Bank Logo & Verified Header
                            HStack(spacing: 12) {
                                if let acc = account {
                                    acc.bankInfo.badgeView(size: 38)
                                } else {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: "0284C7"))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(merchant.isEmpty ? "Direct Payment" : merchant)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                    Text("VERIFIED TRANSACTION")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundColor(Color(hex: "10B981"))
                                        .tracking(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "10B981"))
                            }
                            
                            // Amount Hero
                            VStack(spacing: 4) {
                                Text("TOTAL PAID")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
                                    .tracking(1.5)
                                
                                Text(String(format: "₹ %.2f", amount))
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isDarkMode ? Color(hex: "111520") : Color(hex: "F8FAFC"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            
                            // Dotted tear divider
                            dashedSeparator
                            
                            // Line item metadata
                            VStack(spacing: 10) {
                                receiptRow(title: "Date & Time", value: formattedDate(date))
                                receiptRow(title: "Payment Channel", value: paymentMode)
                                if let acc = account {
                                    receiptRow(title: "Debited From", value: "\(acc.bankName) •••• \(acc.accountNumber.suffix(4))")
                                }
                                receiptRow(title: "Category", value: category)
                                receiptRow(title: "Auth Reference", value: "TXN-\(abs(merchant.hashValue % 900000) + 100000)-MONE")
                                if !tags.isEmpty {
                                    receiptRow(title: "Tags", value: tags.joined(separator: " "))
                                }
                            }
                            
                            // Dotted tear divider
                            dashedSeparator
                            
                            // Barcode simulation
                            barcodeView
                            
                            Text("ENCRYPTED ON-DEVICE • MONE ENGINE V8")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(MoneTheme.textMuted(isDark: isDarkMode))
                                .tracking(1)
                        }
                        .padding(20)
                        .background(isDarkMode ? Color(hex: "151926") : Color.white)
                        
                        // Perforated Bottom Scallop
                        perforatedBottomFooter
                    }
                    .padding(.horizontal, 24)
                    .shadow(color: Color.black.opacity(isDarkMode ? 0.4 : 0.08), radius: 16, y: 8)
                    
                    // Share Receipt Button
                    Button {
                        MoneHaptics.selection()
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                            Text("Share Receipt")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(isDarkMode ? Color(hex: "10141D") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isDarkMode ? Color.white : MoneTheme.deepBlack)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [shareableReceiptText])
        }
    }
    
    private var perforatedTopHeader: some View {
        HStack(spacing: 6) {
            ForEach(0..<18, id: \.self) { _ in
                Circle()
                    .fill(isDarkMode ? Color(hex: "090B10") : Color(hex: "EDF4F9"))
                    .frame(width: 10, height: 10)
                    .offset(y: -5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 8)
        .background(isDarkMode ? Color(hex: "151926") : Color.white)
        .clipped()
    }
    
    private var perforatedBottomFooter: some View {
        HStack(spacing: 6) {
            ForEach(0..<18, id: \.self) { _ in
                Circle()
                    .fill(isDarkMode ? Color(hex: "090B10") : Color(hex: "EDF4F9"))
                    .frame(width: 10, height: 10)
                    .offset(y: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 8)
        .background(isDarkMode ? Color(hex: "151926") : Color.white)
        .clipped()
    }
    
    private var dashedSeparator: some View {
        MoneDashedLine()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundColor(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.12))
            .frame(height: 1)
    }
    
    private func receiptRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(MoneTheme.textSecondary(isDark: isDarkMode))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(MoneTheme.textPrimary(isDark: isDarkMode))
                .lineLimit(1)
        }
    }
    
    private var barcodeView: some View {
        HStack(spacing: 2) {
            ForEach(0..<42, id: \.self) { idx in
                Rectangle()
                    .fill(isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.8))
                    .frame(width: idx % 3 == 0 ? 3 : (idx % 2 == 0 ? 2 : 1), height: 36)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formattedDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy, hh:mm a"
        return f.string(from: d)
    }
    
    private var shareableReceiptText: String {
        """
        🧾 MONE TRANSACTION RECEIPT
        Merchant: \(merchant)
        Amount: ₹\(String(format: "%.2f", amount))
        Account: \(account?.name ?? "Bank") (\(account?.bankName ?? "Bank"))
        Category: \(category)
        Date: \(formattedDate(date))
        Payment Mode: \(paymentMode)
        Auth: TXN-\(abs(merchant.hashValue % 900000) + 100000)-MONE
        Verified by Mone Engine
        """
    }
}

// MARK: - MoneDashedLine Shape
public struct MoneDashedLine: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
