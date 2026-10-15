import 'package:flutter/material.dart';

class BankInfo {
  final String id;
  final String name;
  final String shortName;
  final List<Color> gradientColors;
  final Color accentColor;
  final List<String> smsSenderCodes;
  final List<String> keywords;
  final String defaultCardNetwork;
  final bool isCash;

  const BankInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.gradientColors,
    required this.accentColor,
    required this.smsSenderCodes,
    required this.keywords,
    this.defaultCardNetwork = 'RUPAY / VISA',
    this.isCash = false,
  });

  String get logoAsset => 'assets/banks/$id.png';
  bool get hasLogoAsset => !isCash && id != 'other';

  Widget buildBadge({double size = 36, bool showBorder = true}) {
    if (isCash) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: showBorder ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(Icons.payments_rounded, color: Colors.white, size: size * 0.52),
      );
    }

    Widget fallbackBadge() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: showBorder ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: id == 'other'
              ? Icon(Icons.account_balance_rounded, color: Colors.white, size: size * 0.52)
              : Text(
                  shortName.length > 5 ? shortName.substring(0, 4) : shortName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.32,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      );
    }

    if (!hasLogoAsset) {
      return fallbackBadge();
    }

    // Official Bank Logo Badge:
    // A crisp, executive container with a clean white backing and subtle border
    // ensuring authentic institution branding is instantly identifiable on any card background.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: showBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.13),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.16),
          child: Image.asset(
            logoAsset,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => fallbackBadge(),
          ),
        ),
      ),
    );
  }
}

class IndianBankDirectory {
  static const List<BankInfo> allBanks = [
    // 1. State Bank of India
    BankInfo(
      id: 'sbi',
      name: 'State Bank of India',
      shortName: 'SBI',
      gradientColors: [Color(0xFF0A65A4), Color(0xFF003056)],
      accentColor: Color(0xFF4DB5FF),
      smsSenderCodes: ['sbin', 'sbi', 'sbiinb', 'sbipsg', 'sbiupi', 'sbicrd'],
      keywords: ['sbi', 'state bank of india', 'state bank'],
      defaultCardNetwork: 'RUPAY GLOBAL',
    ),
    // 2. HDFC Bank
    BankInfo(
      id: 'hdfc',
      name: 'HDFC Bank',
      shortName: 'HDFC',
      gradientColors: [Color(0xFF004C8F), Color(0xFF002244)],
      accentColor: Color(0xFFED1C24),
      smsSenderCodes: ['hdfc', 'hdfcbk', 'hdfcup', 'hdfcbnk', 'hdfccc'],
      keywords: ['hdfc', 'hdfc bank'],
      defaultCardNetwork: 'VISA SIGNATURE',
    ),
    // 3. ICICI Bank
    BankInfo(
      id: 'icici',
      name: 'ICICI Bank',
      shortName: 'ICICI',
      gradientColors: [Color(0xFFBA281E), Color(0xFFE86B19)],
      accentColor: Color(0xFFFF944D),
      smsSenderCodes: ['icici', 'icicib', 'icicip', 'icicim', 'icicic'],
      keywords: ['icici', 'icici bank'],
      defaultCardNetwork: 'VISA PLATINUM',
    ),
    // 4. Axis Bank
    BankInfo(
      id: 'axis',
      name: 'Axis Bank',
      shortName: 'AXIS',
      gradientColors: [Color(0xFF861F41), Color(0xFF4C081F)],
      accentColor: Color(0xFFFF5277),
      smsSenderCodes: ['axis', 'axisbk', 'axisin', 'axisb', 'axiscd'],
      keywords: ['axis', 'axis bank'],
      defaultCardNetwork: 'MASTERCARD WORLD',
    ),
    // 5. Kotak Mahindra Bank
    BankInfo(
      id: 'kotak',
      name: 'Kotak Mahindra Bank',
      shortName: 'KOTAK',
      gradientColors: [Color(0xFFE31B23), Color(0xFF0A2E5C)],
      accentColor: Color(0xFF3B82F6),
      smsSenderCodes: ['kotak', 'kotakb', 'kmbl', 'kotakm'],
      keywords: ['kotak', 'kotak mahindra', 'kmbl'],
      defaultCardNetwork: 'VISA SIGNATURE',
    ),
    // 6. Punjab National Bank
    BankInfo(
      id: 'pnb',
      name: 'Punjab National Bank',
      shortName: 'PNB',
      gradientColors: [Color(0xFFA20036), Color(0xFF5B001F)],
      accentColor: Color(0xFFFFC20E),
      smsSenderCodes: ['pnb', 'pnbsms', 'punbnb'],
      keywords: ['pnb', 'punjab national'],
      defaultCardNetwork: 'RUPAY PLATINUM',
    ),
    // 7. Bank of Baroda
    BankInfo(
      id: 'bob',
      name: 'Bank of Baroda',
      shortName: 'BOB',
      gradientColors: [Color(0xFFF26522), Color(0xFF9E3808)],
      accentColor: Color(0xFFFF9E66),
      smsSenderCodes: ['bob', 'bobtxn', 'baroda', 'bobcr'],
      keywords: ['bob', 'bank of baroda', 'baroda'],
      defaultCardNetwork: 'RUPAY SELECT',
    ),
    // 8. Canara Bank
    BankInfo(
      id: 'canara',
      name: 'Canara Bank',
      shortName: 'CANARA',
      gradientColors: [Color(0xFF0091D5), Color(0xFF004D73)],
      accentColor: Color(0xFFFFCE00),
      smsSenderCodes: ['canara', 'canbnk', 'cnrbnk'],
      keywords: ['canara', 'canara bank'],
      defaultCardNetwork: 'RUPAY CLASSIC',
    ),
    // 9. Union Bank of India
    BankInfo(
      id: 'union',
      name: 'Union Bank of India',
      shortName: 'UNION',
      gradientColors: [Color(0xFFD61A22), Color(0xFF004B8C)],
      accentColor: Color(0xFF5AB0FF),
      smsSenderCodes: ['union', 'unionb', 'ubisms', 'ubi'],
      keywords: ['union bank', 'union', 'ubi'],
      defaultCardNetwork: 'RUPAY PLATINUM',
    ),
    // 10. IndusInd Bank
    BankInfo(
      id: 'indusind',
      name: 'IndusInd Bank',
      shortName: 'INDUS',
      gradientColors: [Color(0xFF851421), Color(0xFF4C060E)],
      accentColor: Color(0xFFE2B158),
      smsSenderCodes: ['indus', 'indbnk', 'indusind'],
      keywords: ['indusind', 'indus'],
      defaultCardNetwork: 'VISA SIGNATURE',
    ),
    // 11. IDFC FIRST Bank
    BankInfo(
      id: 'idfc',
      name: 'IDFC FIRST Bank',
      shortName: 'IDFC',
      gradientColors: [Color(0xFF9D2235), Color(0xFF56101B)],
      accentColor: Color(0xFFFF7588),
      smsSenderCodes: ['idfc', 'idfcfb', 'idfcbk'],
      keywords: ['idfc', 'idfc first', 'first bank'],
      defaultCardNetwork: 'VISA INFINITE',
    ),
    // 12. Yes Bank
    BankInfo(
      id: 'yes',
      name: 'Yes Bank',
      shortName: 'YES',
      gradientColors: [Color(0xFF004B87), Color(0xFF8B0D18)],
      accentColor: Color(0xFF4EA5FF),
      smsSenderCodes: ['yes', 'yesbnk', 'yesbk'],
      keywords: ['yes bank', 'yes'],
      defaultCardNetwork: 'MASTERCARD WORLD',
    ),
    // 13. Federal Bank
    BankInfo(
      id: 'federal',
      name: 'Federal Bank',
      shortName: 'FED',
      gradientColors: [Color(0xFF003366), Color(0xFF9E5C00)],
      accentColor: Color(0xFFFFB347),
      smsSenderCodes: ['fed', 'fedbnk', 'federal'],
      keywords: ['federal', 'federal bank'],
      defaultCardNetwork: 'VISA PLATINUM',
    ),
    // 14. Indian Bank
    BankInfo(
      id: 'indian',
      name: 'Indian Bank',
      shortName: 'INDIAN',
      gradientColors: [Color(0xFF002B66), Color(0xFF8F3900)],
      accentColor: Color(0xFFFF8533),
      smsSenderCodes: ['indbank', 'indianbk', 'indianb'],
      keywords: ['indian bank'],
      defaultCardNetwork: 'RUPAY PLATINUM',
    ),
    // 15. Bank of India
    BankInfo(
      id: 'boi',
      name: 'Bank of India',
      shortName: 'BOI',
      gradientColors: [Color(0xFFDF5818), Color(0xFF002855)],
      accentColor: Color(0xFFFF8A50),
      smsSenderCodes: ['boi', 'boisms'],
      keywords: ['bank of india', 'boi'],
      defaultCardNetwork: 'RUPAY SELECT',
    ),
    // 16. Central Bank of India
    BankInfo(
      id: 'cbi',
      name: 'Central Bank of India',
      shortName: 'CBI',
      gradientColors: [Color(0xFF0055A5), Color(0xFF7A0E12)],
      accentColor: Color(0xFF5EAAFF),
      smsSenderCodes: ['cbi', 'cbisms'],
      keywords: ['central bank', 'cbi'],
      defaultCardNetwork: 'RUPAY CLASSIC',
    ),
    // 17. Indian Overseas Bank
    BankInfo(
      id: 'iob',
      name: 'Indian Overseas Bank',
      shortName: 'IOB',
      gradientColors: [Color(0xFF004F9E), Color(0xFF8B1A1E)],
      accentColor: Color(0xFF64B5F6),
      smsSenderCodes: ['iob', 'iobchn'],
      keywords: ['indian overseas bank', 'iob'],
      defaultCardNetwork: 'RUPAY PLATINUM',
    ),
    // 18. UCO Bank
    BankInfo(
      id: 'uco',
      name: 'UCO Bank',
      shortName: 'UCO',
      gradientColors: [Color(0xFF005B94), Color(0xFF9C4909)],
      accentColor: Color(0xFFFF9800),
      smsSenderCodes: ['uco', 'ucobnk'],
      keywords: ['uco bank', 'uco'],
      defaultCardNetwork: 'RUPAY CLASSIC',
    ),
    // 19. Punjab & Sind Bank
    BankInfo(
      id: 'psb',
      name: 'Punjab & Sind Bank',
      shortName: 'PSB',
      gradientColors: [Color(0xFFD35400), Color(0xFF002B49)],
      accentColor: Color(0xFFFF8A65),
      smsSenderCodes: ['psb', 'psbbank'],
      keywords: ['punjab & sind', 'psb'],
      defaultCardNetwork: 'RUPAY PLATINUM',
    ),
    // 20. RBL Bank
    BankInfo(
      id: 'rbl',
      name: 'RBL Bank',
      shortName: 'RBL',
      gradientColors: [Color(0xFF003366), Color(0xFF006699)],
      accentColor: Color(0xFF00A3E0),
      smsSenderCodes: ['rbl', 'rblbnk'],
      keywords: ['rbl', 'rbl bank', 'ratnakar'],
      defaultCardNetwork: 'MASTERCARD BLACK',
    ),
    // 21. Bandhan Bank
    BankInfo(
      id: 'bandhan',
      name: 'Bandhan Bank',
      shortName: 'BANDHAN',
      gradientColors: [Color(0xFFC71419), Color(0xFF002E5C)],
      accentColor: Color(0xFFFF6B6B),
      smsSenderCodes: ['bandhan', 'bndhan'],
      keywords: ['bandhan', 'bandhan bank'],
      defaultCardNetwork: 'VISA PLATINUM',
    ),
    // 22. Paytm Payments Bank
    BankInfo(
      id: 'paytm',
      name: 'Paytm Payments Bank',
      shortName: 'PAYTM',
      gradientColors: [Color(0xFF002E6E), Color(0xFF00A2D3)],
      accentColor: Color(0xFF00BAF2),
      smsSenderCodes: ['paytm', 'paytmb'],
      keywords: ['paytm', 'paytm payments'],
      defaultCardNetwork: 'RUPAY DIGITAL',
    ),
    // 23. Airtel Payments Bank
    BankInfo(
      id: 'airtel',
      name: 'Airtel Payments Bank',
      shortName: 'AIRTEL',
      gradientColors: [Color(0xFFC40000), Color(0xFF5A0000)],
      accentColor: Color(0xFFFF5252),
      smsSenderCodes: ['airtel', 'airtelb'],
      keywords: ['airtel', 'airtel bank', 'airtel payments'],
      defaultCardNetwork: 'MASTERCARD DIGITAL',
    ),
    // 24. Jupiter (Federal Bank)
    BankInfo(
      id: 'jupiter',
      name: 'Jupiter Money',
      shortName: 'JUPITER',
      gradientColors: [Color(0xFFFF5252), Color(0xFF28183F)],
      accentColor: Color(0xFFFF7676),
      smsSenderCodes: ['jupitr', 'jupiter'],
      keywords: ['jupiter', 'jupiter money'],
      defaultCardNetwork: 'VISA SIGNATURE',
    ),
    // 25. Fi Money (Federal Bank)
    BankInfo(
      id: 'fi',
      name: 'Fi Money',
      shortName: 'FI',
      gradientColors: [Color(0xFF00BFA5), Color(0xFF131A26)],
      accentColor: Color(0xFF00E676),
      smsSenderCodes: ['fimoney', 'fi'],
      keywords: ['fi', 'fi money', 'epi'],
      defaultCardNetwork: 'VISA PLATINUM',
    ),
    // 26. Standard Chartered India
    BankInfo(
      id: 'sc',
      name: 'Standard Chartered',
      shortName: 'STAN-C',
      gradientColors: [Color(0xFF007A3D), Color(0xFF004B87)],
      accentColor: Color(0xFF2EBD6E),
      smsSenderCodes: ['scbl', 'stanb'],
      keywords: ['standard chartered', 'stanc', 'scb'],
      defaultCardNetwork: 'VISA INFINITE',
    ),
    // 27. Citibank India
    BankInfo(
      id: 'citi',
      name: 'Citibank India',
      shortName: 'CITI',
      gradientColors: [Color(0xFF003B70), Color(0xFF9E0B0F)],
      accentColor: Color(0xFF29B6F6),
      smsSenderCodes: ['citi', 'citibk'],
      keywords: ['citibank', 'citi'],
      defaultCardNetwork: 'MASTERCARD PREMIER',
    ),
    // 28. HSBC India
    BankInfo(
      id: 'hsbc',
      name: 'HSBC India',
      shortName: 'HSBC',
      gradientColors: [Color(0xFFB7121F), Color(0xFF1C191A)],
      accentColor: Color(0xFFFF5252),
      smsSenderCodes: ['hsbc', 'hsbcin'],
      keywords: ['hsbc', 'hsbc bank'],
      defaultCardNetwork: 'VISA PREMIER',
    ),
    // 29. Cash Wallet
    BankInfo(
      id: 'cash',
      name: 'Cash / Wallet',
      shortName: 'CASH',
      gradientColors: [Color(0xFF0F5A3C), Color(0xFF072B1D)],
      accentColor: Color(0xFF10B981),
      smsSenderCodes: [],
      keywords: ['cash', 'physical cash', 'wallet'],
      defaultCardNetwork: 'PHYSICAL CASH',
      isCash: true,
    ),
    // 30. Other / Custom Bank
    BankInfo(
      id: 'other',
      name: 'Other Bank / Account',
      shortName: 'BANK',
      gradientColors: [Color(0xFF374151), Color(0xFF111827)],
      accentColor: Color(0xFF9CA3AF),
      smsSenderCodes: [],
      keywords: ['other', 'bank'],
      defaultCardNetwork: 'DEBIT / CREDIT',
    ),
  ];

  static List<BankInfo> get popularBanks {
    const popularIds = ['sbi', 'hdfc', 'icici', 'axis', 'kotak', 'bob', 'pnb', 'idfc', 'paytm', 'cash'];
    return allBanks.where((b) => popularIds.contains(b.id)).toList();
  }

  static BankInfo getBankById(String? id) {
    if (id == null || id.isEmpty) return allBanks.last;
    return allBanks.firstWhere(
      (b) => b.id.toLowerCase() == id.toLowerCase(),
      orElse: () => findBankByName(id),
    );
  }

  static BankInfo findBankByName(dynamic name) {
    String clean = (name ?? '').toString().toLowerCase().trim();
    if (clean.isEmpty) return allBanks.last;

    for (var b in allBanks) {
      if (b.name.toLowerCase() == clean || b.shortName.toLowerCase() == clean || b.id == clean) {
        return b;
      }
      for (var kw in b.keywords) {
        if (clean.contains(kw) || kw.contains(clean)) {
          return b;
        }
      }
    }
    return allBanks.last;
  }

  /// Detects the Indian bank from the SMS sender header (e.g. VK-HDFCBK-S, AD-ICICIB, BZ-BOBTXN)
  /// and from mentions inside the message body.
  static BankInfo? detectBankFromSms(String? senderAddress, String messageBody) {
    String addr = (senderAddress ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    String body = messageBody.toLowerCase();

    // 1. Try sender address matching first (Most accurate in India due to TRAI headers)
    if (addr.isNotEmpty) {
      for (var bank in allBanks) {
        if (bank.isCash || bank.id == 'other') continue;
        for (var code in bank.smsSenderCodes) {
          if (addr.contains(code)) {
            return bank;
          }
        }
      }
    }

    // 2. Try body text patterns
    for (var bank in allBanks) {
      if (bank.isCash || bank.id == 'other') continue;
      // Search for specific bank keyword in body
      for (var code in bank.smsSenderCodes) {
        // e.g. "hdfc bank:" or "sbi:" or "from icici"
        if (body.contains(' $code ') || body.contains('$code:') || body.contains('$code-')) {
          return bank;
        }
      }
      for (var kw in bank.keywords) {
        if (body.contains(kw)) {
          return bank;
        }
      }
    }

    return null;
  }

  /// Intelligently resolves the target account from the incoming SMS:
  /// 1. Finds the Bank from sender address or body text.
  /// 2. Extracts account number digits mentioned in the SMS (e.g. "A/C ending 4821", "A/C XX1234").
  /// 3. Cross-matches with user's configured accounts.
  static int? matchAccountFromSms({
    required String? senderAddress,
    required String messageBody,
    required List<Map<String, dynamic>> accounts,
  }) {
    if (accounts.isEmpty) return null;

    BankInfo? detectedBank = detectBankFromSms(senderAddress, messageBody);
    String body = messageBody.toLowerCase();

    // Extract potential account number candidates from text
    // Handles formats like: "A/C ending 4821", "A/C XX4821", "A/c ...4821", "Account 4821"
    List<String> accountNumCandidates = [];
    final acctPatterns = [
      RegExp(r'(?:a\/c|acct|ac|account|card)\s*(?:no\.?)?\s*[:\s]*[xX*.\-_]*(\d{2,6})', caseSensitive: false),
      RegExp(r'ending\s*(?:with|in)?\s*[:\s]*[xX*.\-_]*(\d{2,6})', caseSensitive: false),
      RegExp(r'[xX*]{2,}(\d{2,6})'),
    ];

    for (var pattern in acctPatterns) {
      for (var m in pattern.allMatches(body)) {
        if (m.group(1) != null) {
          accountNumCandidates.add(m.group(1)!);
        }
      }
    }

    // If no regex candidate found, extract all number tokens with 2-6 digits
    if (accountNumCandidates.isEmpty) {
      for (var m in RegExp(r'\b\d{2,6}\b').allMatches(body)) {
        accountNumCandidates.add(m.group(0)!);
      }
    }

    // Priority 1: Match BOTH Bank AND Account Number
    if (detectedBank != null) {
      var bankAccounts = accounts.where((acc) {
        String bankCode = (acc['bank_code'] ?? '').toString().toLowerCase();
        String bankName = (acc['bank_name'] ?? '').toString().toLowerCase();
        return bankCode == detectedBank.id ||
            bankName.contains(detectedBank.shortName.toLowerCase()) ||
            bankName.contains(detectedBank.name.toLowerCase());
      }).toList();

      if (bankAccounts.isNotEmpty) {
        // Look for digit match among this bank's accounts
        for (var acc in bankAccounts) {
          String accNum = (acc['account_number'] ?? '').toString().trim();
          if (accNum.isNotEmpty) {
            for (var cand in accountNumCandidates) {
              if (accNum.endsWith(cand) || cand.endsWith(accNum) || accNum == cand) {
                return acc['id'] as int;
              }
            }
          }
        }
        // If the user only has 1 account with this bank, it's virtually certain!
        if (bankAccounts.length == 1) {
          return bankAccounts.first['id'] as int;
        }
      }
    }

    // Priority 2: Account Number digit match across ALL accounts
    for (var acc in accounts) {
      String accNum = (acc['account_number'] ?? '').toString().trim();
      if (accNum.isNotEmpty && accNum.length >= 2) {
        for (var cand in accountNumCandidates) {
          if (accNum.endsWith(cand) || cand.endsWith(accNum) || accNum == cand) {
            return acc['id'] as int;
          }
        }
      }
    }

    // Priority 3: Fallback to first non-cash account, or first account
    var firstBank = accounts.firstWhere(
      (a) => (a['type'] ?? '').toString().toUpperCase() != 'CASH',
      orElse: () => accounts.first,
    );
    return firstBank['id'] as int;
  }
}

Future<BankInfo?> showIndianBankPicker(BuildContext context, {BankInfo? selectedBank}) {
  return showModalBottomSheet<BankInfo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BankPickerModal(initialSelected: selectedBank),
  );
}

class _BankPickerModal extends StatefulWidget {
  final BankInfo? initialSelected;
  const _BankPickerModal({Key? key, this.initialSelected}) : super(key: key);

  @override
  State<_BankPickerModal> createState() => _BankPickerModalState();
}

class _BankPickerModalState extends State<_BankPickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<BankInfo> all = IndianBankDirectory.allBanks;
    List<BankInfo> popular = IndianBankDirectory.popularBanks;

    List<BankInfo> filtered = _filter.isEmpty
        ? all
        : all.where((b) {
            final f = _filter.toLowerCase();
            return b.name.toLowerCase().contains(f) ||
                b.shortName.toLowerCase().contains(f) ||
                b.keywords.any((k) => k.toLowerCase().contains(f));
          }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF10121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFF262A38), width: 1.2),
          left: BorderSide(color: Color(0xFF1E2230), width: 1),
          right: BorderSide(color: Color(0xFF1E2230), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Your Bank',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select from 25+ verified Indian banks & institutions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _filter = val),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8), size: 20),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                hintText: 'Search by bank name or symbol (e.g. SBI, HDFC)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                ),
              ),
            ),
          ),
          // Popular quick pills (only show if no filter)
          if (_filter.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 8),
              child: Text(
                'POPULAR IN INDIA',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: popular.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final b = popular[index];
                  bool isSel = widget.initialSelected?.id == b.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(context, b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel ? const Color(0xFF818CF8) : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          b.buildBadge(size: 20, showBorder: false),
                          const SizedBox(width: 8),
                          Text(
                            b.shortName,
                            style: TextStyle(
                              color: isSel ? Colors.white : Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          // All banks heading
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              _filter.isEmpty ? 'ALL BANKS & WALLETS (${filtered.length})' : 'RESULTS (${filtered.length})',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          // Bank list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E212D), height: 1),
              itemBuilder: (context, index) {
                final b = filtered[index];
                bool isSel = widget.initialSelected?.id == b.id;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(context, b),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isSel ? const Color(0xFF6366F1).withOpacity(0.12) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        b.buildBadge(size: 42),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b.shortName,
                                      style: TextStyle(
                                        color: b.accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    b.defaultCardNetwork,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isSel)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22)
                        else
                          Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.25), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

