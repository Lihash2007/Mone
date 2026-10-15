import SwiftUI

// MARK: - Bank Information Model
public struct BankInfo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let shortName: String
    public let gradientColors: [Color]
    public let accentColor: Color
    public let keywords: [String]
    public let isCash: Bool
    
    public init(
        id: String,
        name: String,
        shortName: String,
        gradientColors: [Color],
        accentColor: Color,
        keywords: [String],
        isCash: Bool = false
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.gradientColors = gradientColors
        self.accentColor = accentColor
        self.keywords = keywords
        self.isCash = isCash
    }
    
    @ViewBuilder
    public func badgeView(size: CGFloat = 34) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: isCash ? size / 2 : size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isCash ? size / 2 : size * 0.28, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: gradientColors.first?.opacity(0.35) ?? .clear, radius: 4, x: 0, y: 2)
            
            if isCash {
                Image(systemName: "banknote.fill")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text(shortName.prefix(3).uppercased())
                    .font(.system(size: size * 0.32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .padding(2)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Indian Bank Directory
public struct IndianBankDirectory {
    public static let hdfc = BankInfo(
        id: "hdfc",
        name: "HDFC Bank",
        shortName: "HDFC",
        gradientColors: [Color(hex: "004C8F"), Color(hex: "002855")],
        accentColor: Color(hex: "ED232A"),
        keywords: ["hdfc", "hdfcbk"]
    )
    
    public static let sbi = BankInfo(
        id: "sbi",
        name: "State Bank of India",
        shortName: "SBI",
        gradientColors: [Color(hex: "280071"), Color(hex: "0091DF")],
        accentColor: Color(hex: "00A859"),
        keywords: ["sbi", "sbin", "state bank"]
    )
    
    public static let icici = BankInfo(
        id: "icici",
        name: "ICICI Bank",
        shortName: "ICICI",
        gradientColors: [Color(hex: "B02A30"), Color(hex: "F37021")],
        accentColor: Color(hex: "F58220"),
        keywords: ["icici", "icicib"]
    )
    
    public static let axis = BankInfo(
        id: "axis",
        name: "Axis Bank",
        shortName: "Axis",
        gradientColors: [Color(hex: "97144D"), Color(hex: "5A082D")],
        accentColor: Color(hex: "97144D"),
        keywords: ["axis", "axisbk"]
    )
    
    public static let kotak = BankInfo(
        id: "kotak",
        name: "Kotak Mahindra Bank",
        shortName: "Kotak",
        gradientColors: [Color(hex: "ED1C24"), Color(hex: "003366")],
        accentColor: Color(hex: "ED1C24"),
        keywords: ["kotak", "kmbl"]
    )
    
    public static let pnb = BankInfo(
        id: "pnb",
        name: "Punjab National Bank",
        shortName: "PNB",
        gradientColors: [Color(hex: "A21834"), Color(hex: "FFC20E")],
        accentColor: Color(hex: "A21834"),
        keywords: ["pnb", "punjab"]
    )
    
    public static let canara = BankInfo(
        id: "canara",
        name: "Canara Bank",
        shortName: "Canara",
        gradientColors: [Color(hex: "0072BC"), Color(hex: "ED1C24")],
        accentColor: Color(hex: "0072BC"),
        keywords: ["canara", "cnrb"]
    )
    
    public static let bob = BankInfo(
        id: "bob",
        name: "Bank of Baroda",
        shortName: "BOB",
        gradientColors: [Color(hex: "F26522"), Color(hex: "0054A6")],
        accentColor: Color(hex: "F26522"),
        keywords: ["baroda", "bob"]
    )
    
    public static let indusind = BankInfo(
        id: "indusind",
        name: "IndusInd Bank",
        shortName: "IndusInd",
        gradientColors: [Color(hex: "8B1A1A"), Color(hex: "D32F2F")],
        accentColor: Color(hex: "8B1A1A"),
        keywords: ["indusind", "indus"]
    )
    
    public static let idfc = BankInfo(
        id: "idfc",
        name: "IDFC FIRST Bank",
        shortName: "IDFC",
        gradientColors: [Color(hex: "9E1B32"), Color(hex: "5A0B1A")],
        accentColor: Color(hex: "9E1B32"),
        keywords: ["idfc", "first bank"]
    )
    
    public static let paytm = BankInfo(
        id: "paytm",
        name: "Paytm Payments Bank",
        shortName: "Paytm",
        gradientColors: [Color(hex: "002E6E"), Color(hex: "00BAF2")],
        accentColor: Color(hex: "00BAF2"),
        keywords: ["paytm"]
    )
    
    public static let cred = BankInfo(
        id: "cred",
        name: "CRED Garage / Pay",
        shortName: "CRED",
        gradientColors: [Color(hex: "171717"), Color(hex: "262626")],
        accentColor: Color(hex: "FFFFFF"),
        keywords: ["cred"]
    )
    
    public static let jupiter = BankInfo(
        id: "jupiter",
        name: "Jupiter Money",
        shortName: "Jupiter",
        gradientColors: [Color(hex: "FF6D00"), Color(hex: "FF9E80")],
        accentColor: Color(hex: "FF6D00"),
        keywords: ["jupiter"]
    )
    
    public static let fi = BankInfo(
        id: "fi",
        name: "Fi Money (Federal Bank)",
        shortName: "Fi",
        gradientColors: [Color(hex: "00C897"), Color(hex: "005B41")],
        accentColor: Color(hex: "00C897"),
        keywords: ["fi money", "epiifi"]
    )
    
    public static let cash = BankInfo(
        id: "cash",
        name: "Cash in Hand",
        shortName: "Cash",
        gradientColors: [Color(hex: "059669"), Color(hex: "10B981")],
        accentColor: Color(hex: "10B981"),
        keywords: ["cash", "wallet"],
        isCash: true
    )
    
    public static let other = BankInfo(
        id: "other",
        name: "Other Bank",
        shortName: "Bank",
        gradientColors: [Color(hex: "4B5563"), Color(hex: "1F2937")],
        accentColor: Color(hex: "9CA3AF"),
        keywords: ["other", "bank"]
    )
    
    public static let allBanks: [BankInfo] = [
        hdfc, sbi, icici, axis, kotak, pnb, canara, bob, indusind, idfc, paytm, cred, jupiter, fi, cash, other
    ]
    
    public static func findBank(codeOrName: String) -> BankInfo {
        let clean = codeOrName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.isEmpty { return other }
        if clean == "cash" { return cash }
        
        for bank in allBanks {
            if bank.id == clean || bank.shortName.lowercased() == clean || bank.name.lowercased() == clean {
                return bank
            }
            for kw in bank.keywords {
                if clean.contains(kw) || kw.contains(clean) {
                    return bank
                }
            }
        }
        return other
    }
}
