import 'indian_banks.dart';

class ParsedSmsResult {
  final bool isValid;
  final String type; // 'EXPENSE' or 'INCOME'
  final double amount;
  final double? availableBalance;
  final String merchant;
  final String category;
  final String? accountEndingDigits;
  final bool isCreditCard;
  final String? referenceNumber;
  final String rawBody;

  ParsedSmsResult({
    required this.isValid,
    this.type = 'EXPENSE',
    this.amount = 0.0,
    this.availableBalance,
    this.merchant = 'Bank SMS',
    this.category = 'Other',
    this.accountEndingDigits,
    this.isCreditCard = false,
    this.referenceNumber,
    required this.rawBody,
  });

  @override
  String toString() {
    return 'ParsedSmsResult(valid: $isValid, type: $type, amount: $amount, avlBal: $availableBalance, merchant: $merchant, cat: $category, acc: $accountEndingDigits, card: $isCreditCard)';
  }
}

class SmsTransactionParser {
  // 1. Known brand to category mapping
  static final Map<String, String> _merchantToCategory = {
    // Food & Dining
    'swiggy': 'Food',
    'zomato': 'Food',
    'dominos': 'Food',
    'mcdonalds': 'Food',
    'starbucks': 'Food',
    'chaipoint': 'Food',
    'eats': 'Food',
    'eatclub': 'Food',
    'kfc': 'Food',
    'subway': 'Food',
    'burgerking': 'Food',
    'pizzahut': 'Food',
    'haldiram': 'Food',
    'faasos': 'Food',
    'behrouz': 'Food',
    'box8': 'Food',

    // Groceries & Quick Commerce
    'blinkit': 'Groceries',
    'zepto': 'Groceries',
    'instamart': 'Groceries',
    'bigbasket': 'Groceries',
    'dmart': 'Groceries',
    'naturebasket': 'Groceries',
    'milkbasket': 'Groceries',
    'dunzo': 'Groceries',
    'countrydelight': 'Groceries',
    'spencer': 'Groceries',
    'more retail': 'Groceries',

    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'meesho': 'Shopping',
    'nykaa': 'Shopping',
    'tatacliq': 'Shopping',
    'zara': 'Shopping',
    'h&m': 'Shopping',
    'decathlon': 'Shopping',
    'croma': 'Shopping',
    'reliancedigital': 'Shopping',
    'relianceretail': 'Shopping',
    'westside': 'Shopping',
    'trends': 'Shopping',
    'pantaloons': 'Shopping',
    'ikea': 'Shopping',
    'lenskart': 'Shopping',

    // Transport & Mobility
    'uber': 'Transport',
    'ola': 'Transport',
    'rapido': 'Transport',
    'metro': 'Transport',
    'namma metro': 'Transport',
    'irctc': 'Transport',
    'makemytrip': 'Transport',
    'goibibo': 'Transport',
    'cleartrip': 'Transport',
    'yatra': 'Transport',
    'redbus': 'Transport',
    'abhibus': 'Transport',
    'indigo': 'Transport',
    'airindia': 'Transport',
    'fastag': 'Transport',
    'chalo': 'Transport',
    'petrol': 'Transport',
    'fuel': 'Transport',
    'indian oil': 'Transport',
    'bharat petroleum': 'Transport',
    'hpcl': 'Transport',

    // Entertainment
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'prime': 'Entertainment',
    'hotstar': 'Entertainment',
    'sonyliv': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'pvr': 'Entertainment',
    'inox': 'Entertainment',
    'youtube': 'Entertainment',
    'zee5': 'Entertainment',
    'apple': 'Entertainment',
    'google play': 'Entertainment',

    // Utilities & Bills
    'jio': 'Utilities',
    'airtel': 'Utilities',
    'vi': 'Utilities',
    'vodafone': 'Utilities',
    'bescom': 'Utilities',
    'tneb': 'Utilities',
    'tatapower': 'Utilities',
    'adani': 'Utilities',
    'billdesk': 'Utilities',
    'actcorp': 'Utilities',
    'hathway': 'Utilities',

    // Investments & Wealth
    'zerodha': 'Investment',
    'groww': 'Investment',
    'angelone': 'Investment',
    'upstox': 'Investment',
    'indmoney': 'Investment',
    'smallcase': 'Investment',
    'kuvera': 'Investment',
    'coin': 'Investment',
    'mutual fund': 'Investment',
  };

  /// Parses an incoming SMS text and extracts financial parameters
  static ParsedSmsResult parse({String? senderAddress, required String body}) {
    final text = body.trim();
    final lower = text.toLowerCase();

    if (text.isEmpty) {
      return ParsedSmsResult(isValid: false, rawBody: text);
    }

    // STEP 1: Non-transaction & Security filter
    if (_isNonTransaction(lower)) {
      return ParsedSmsResult(isValid: false, rawBody: text);
    }

    // STEP 2: Determine Transaction Direction (Income vs Expense)
    final direction = _determineDirection(lower);
    if (direction == null) {
      return ParsedSmsResult(isValid: false, rawBody: text);
    }

    // STEP 3: Context-Aware Amount Extraction
    final amount = _extractTransactionAmount(lower);
    if (amount == null || amount <= 0) {
      return ParsedSmsResult(isValid: false, rawBody: text);
    }

    // STEP 4: Ground-Truth Available Balance Extraction (if present)
    final availableBalance = _extractAvailableBalance(lower, excludeAmount: amount);

    // STEP 5: Account & Card Details
    final accountDigits = _extractAccountDigits(lower);
    final isCreditCard = _detectIfCreditCard(lower);

    // STEP 6: Entity / Merchant Extraction & Category Assignment
    final merchant = _extractMerchant(text, lower, senderAddress);
    final category = _determineCategory(merchant, lower, isIncome: direction == 'INCOME');

    // STEP 7: Reference Number (UPI Ref / RRN)
    final refNo = _extractReferenceNumber(lower);

    return ParsedSmsResult(
      isValid: true,
      type: direction,
      amount: amount,
      availableBalance: availableBalance,
      merchant: merchant,
      category: category,
      accountEndingDigits: accountDigits,
      isCreditCard: isCreditCard,
      referenceNumber: refNo,
      rawBody: text,
    );
  }

  /// Filters out OTPs, bill alerts, pre-approved loan spams, failed txns
  static bool _isNonTransaction(String lower) {
    // 1. Security / OTP
    if (lower.contains('otp') ||
        lower.contains('one time password') ||
        lower.contains('verification code') ||
        lower.contains('security code') ||
        lower.contains('login code') ||
        lower.contains('do not share')) {
      return true;
    }

    // 2. Failed / Declined
    if (lower.contains('declined') ||
        lower.contains('failed') ||
        lower.contains('insufficient balance') ||
        lower.contains('unsuccessful') ||
        lower.contains('cancelled') ||
        lower.contains('timed out')) {
      return true;
    }

    // 3. Bill / Statement alerts (upcoming reminders, not actual completed spend)
    if (lower.contains('is due on') ||
        lower.contains('bill due date') ||
        lower.contains('statement generated') ||
        lower.contains('bill generated') ||
        lower.contains('minimum amount due') ||
        lower.contains('total amount due') ||
        lower.contains('pre-approved') ||
        lower.contains('loan offer') ||
        lower.contains('mandate created') ||
        lower.contains('e-mandate') ||
        lower.contains('request has been received') ||
        lower.contains('will be credited within') ||
        lower.contains('will be processed within')) {
      return true;
    }

    return false;
  }

  /// Determines whether the SMS represents an INCOME or EXPENSE
  static String? _determineDirection(String lower) {
    bool hasCredit = lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('refund') ||
        lower.contains('received') ||
        lower.contains('cr to') ||
        lower.contains('cr.') ||
        lower.contains(' cr ') ||
        lower.contains('salary') ||
        lower.contains('cashback received');

    bool hasDebit = lower.contains('debited') ||
        lower.contains('spent') ||
        lower.contains('paid') ||
        lower.contains('withdrawn') ||
        lower.contains('sent') ||
        lower.contains('transferred') ||
        lower.contains('transfer to') ||
        lower.contains('vpa') ||
        lower.contains('purchase') ||
        lower.contains('dr to') ||
        lower.contains('dr.') ||
        lower.contains(' dr ') ||
        lower.contains('txn of') ||
        lower.contains('transaction of');

    if (hasCredit && !hasDebit) return 'INCOME';
    if (hasDebit && !hasCredit) return 'EXPENSE';

    // Disambiguate when both words appear (e.g. "debited for refund... credited to")
    if (hasCredit && hasDebit) {
      int debitPos = _firstIndexOfAny(lower, ['debited', 'spent', 'paid', 'withdrawn', 'sent', 'dr to', 'dr.']);
      int creditPos = _firstIndexOfAny(lower, ['credited', 'deposited', 'refund', 'received', 'cr to', 'cr.']);
      if (debitPos != -1 && creditPos != -1) {
        return debitPos < creditPos ? 'EXPENSE' : 'INCOME';
      }
      return 'EXPENSE';
    }

    return null;
  }

  static int _firstIndexOfAny(String text, List<String> targets) {
    int minIndex = -1;
    for (var t in targets) {
      int idx = text.indexOf(t);
      if (idx != -1 && (minIndex == -1 || idx < minIndex)) {
        minIndex = idx;
      }
    }
    return minIndex;
  }

  /// Contextually extracts the transaction amount, ignoring balance figures
  static double? _extractTransactionAmount(String text) {
    // Priority 1: Amounts tightly bound to transaction verbs
    // e.g. "debited by Rs. 450", "spent INR 1,200.50", "credited with Rs 5000", "txn of Rs 99"
    final contextualPatterns = [
      RegExp(r'(?:debited|spent|paid|withdrawn|sent|transferred|credited|received|txn of|transaction of|purchase of)\s*(?:by|for|with|of)?\s*(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:debited|spent|paid|credited|received|withdrawn)', caseSensitive: false),
    ];

    for (var pattern in contextualPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (val != null && val > 0) return val;
      }
    }

    // Priority 2: Standard currency amounts that are NOT preceded by Avl Bal / Balance
    final amountPattern = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final matches = amountPattern.allMatches(text);

    for (var m in matches) {
      final start = m.start;
      // Look back 25 characters to check if preceded by balance keywords
      final lookbackStart = (start - 25).clamp(0, text.length);
      final lookback = text.substring(lookbackStart, start).toLowerCase();

      if (lookback.contains('bal') ||
          lookback.contains('balance') ||
          lookback.contains('limit') ||
          lookback.contains('due')) {
        continue; // Skip balance amounts
      }

      final rawAmt = m.group(1);
      if (rawAmt != null) {
        final parsed = double.tryParse(rawAmt.replaceAll(',', ''));
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    // Fallback: reverse notation (e.g. "450.00 Rs")
    final reversePattern = RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:rs\.?|inr|₹)', caseSensitive: false);
    final revMatch = reversePattern.firstMatch(text);
    if (revMatch != null && revMatch.group(1) != null) {
      return double.tryParse(revMatch.group(1)!.replaceAll(',', ''));
    }

    return null;
  }

  /// Extracts the Ground-Truth available balance if present in the message
  static double? _extractAvailableBalance(String text, {double? excludeAmount}) {
    final balancePatterns = [
      RegExp(r'(?:avl(?:\.|\s+)?bal(?:ance)?|avail(?:able)?\s+bal(?:ance)?|bal(?:ance)?|total\s+bal)\s*[:\s\-]*?(?:is)?\s*(?:inr|rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:inr|rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)\s*(?:is\s+your\s+avl|avl|available\s+bal)', caseSensitive: false),
    ];

    for (var pattern in balancePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (val != null && val > 0 && (excludeAmount == null || (val - excludeAmount).abs() > 0.01)) {
          return val;
        }
      }
    }

    return null;
  }

  /// Extracts account or card ending digits (e.g. XX1234 -> "1234")
  static String? _extractAccountDigits(String text) {
    final patterns = [
      RegExp(r'(?:a\/c|acct|ac|account|card)\s*(?:no\.?)?\s*[:\s]*[xX*.\-_]*(\d{2,6})', caseSensitive: false),
      RegExp(r'ending\s*(?:with|in)?\s*[:\s]*[xX*.\-_]*(\d{2,6})', caseSensitive: false),
      RegExp(r'[xX*]{2,}(\d{2,6})'),
    ];

    for (var p in patterns) {
      final m = p.firstMatch(text);
      if (m != null && m.group(1) != null) {
        return m.group(1);
      }
    }
    return null;
  }

  /// Detects whether the SMS refers to a Credit Card
  static bool _detectIfCreditCard(String text) {
    return text.contains('credit card') ||
        text.contains('card ending') ||
        text.contains('creditcard') ||
        text.contains('card ending in');
  }

  /// Extracts the clean merchant / counterparty name
  static String _extractMerchant(String raw, String lower, String? senderAddress) {
    // 1. Direct match with our extensive Indian merchant dictionary
    for (var keyword in _merchantToCategory.keys) {
      if (lower.contains(keyword)) {
        return _formatBrandName(keyword);
      }
    }

    // 2. UPI VPA Extraction (e.g. "VPA swiggy@icici", "to VPA rahul.kumar@okhdfcbank")
    final upiVpaRegex = RegExp(r'(?:to|at|vpa)\s*(?:vpa)?\s*[:\s]*([a-zA-Z0-9.\-_]+)@([a-zA-Z0-9]+)', caseSensitive: false);
    final upiMatch = upiVpaRegex.firstMatch(raw);
    if (upiMatch != null && upiMatch.group(1) != null) {
      String handle = upiMatch.group(1)!;
      // Clean dots and numbers (e.g. swiggy.pay -> Swiggy)
      String cleanHandle = handle.split('.').first;
      cleanHandle = cleanHandle.replaceAll(RegExp(r'\d+$'), '');
      if (cleanHandle.length >= 3) {
        return _formatBrandName(cleanHandle);
      }
    }

    // 3. UPI P2M / P2A tag (e.g. "UPI/P2M/429102/Swiggy")
    final upiTagRegex = RegExp(r'upi\/(?:p2m|p2a)\/\d+\/([a-zA-Z0-9\s._\-]+)', caseSensitive: false);
    final upiTagMatch = upiTagRegex.firstMatch(raw);
    if (upiTagMatch != null && upiTagMatch.group(1) != null) {
      String name = upiTagMatch.group(1)!.trim();
      if (name.length >= 2) return _cleanMerchantName(name);
    }

    // 4. POS terminal / merchant swipe (e.g. "at STARBUCKS BANGALORE on")
    final atRegex = RegExp(r'(?:at|to|info\/|pos)\s+([a-zA-Z0-9\s._\-]{3,30}?)(?:\s+on|\s+dated|\s+avl|\s+bal|\s+ref|\.|\,|$)', caseSensitive: false);
    final atMatch = atRegex.firstMatch(raw);
    if (atMatch != null && atMatch.group(1) != null) {
      String cand = atMatch.group(1)!.trim();
      if (!cand.toLowerCase().startsWith('vpa') && !cand.toLowerCase().startsWith('rs') && cand.length >= 3) {
        return _cleanMerchantName(cand);
      }
    }

    // 5. Beneficiary "transferred to / received from"
    final personRegex = RegExp(r'(?:transferred to|sent to|received from)\s+([a-zA-Z\s]{3,25})', caseSensitive: false);
    final personMatch = personRegex.firstMatch(raw);
    if (personMatch != null && personMatch.group(1) != null) {
      return _cleanMerchantName(personMatch.group(1)!.trim());
    }

    // 6. Fallback to Bank / Sender
    if (senderAddress != null && senderAddress.isNotEmpty) {
      BankInfo? bank = IndianBankDirectory.detectBankFromSms(senderAddress, raw);
      if (bank != null) {
        return '${bank.shortName} Transaction';
      }
      return 'SMS: $senderAddress';
    }

    return 'Bank Transaction';
  }

  /// Determines category from merchant and text context
  static String _determineCategory(String merchant, String lower, {required bool isIncome}) {
    if (isIncome) {
      if (lower.contains('salary')) return 'Salary';
      if (lower.contains('freelance') || lower.contains('consulting')) return 'Freelance';
      if (lower.contains('dividend') || lower.contains('interest')) return 'Investment';
      return 'Income';
    }

    final mLower = merchant.toLowerCase();
    for (var key in _merchantToCategory.keys) {
      if (mLower.contains(key) || lower.contains(key)) {
        return _merchantToCategory[key]!;
      }
    }

    if (lower.contains('food') || lower.contains('restaurant') || lower.contains('cafe')) return 'Food';
    if (lower.contains('fuel') || lower.contains('petrol') || lower.contains('toll')) return 'Transport';
    if (lower.contains('bill') || lower.contains('recharge') || lower.contains('electricity')) return 'Utilities';
    if (lower.contains('grocery') || lower.contains('mart')) return 'Groceries';
    if (lower.contains('movie') || lower.contains('show')) return 'Entertainment';

    return 'Other';
  }

  /// Extracts reference / UTR / RRN number
  static String? _extractReferenceNumber(String lower) {
    final refPatterns = [
      RegExp(r'(?:ref(?:\s+no)?|rrn|utr|txn\s+id)\s*[:\s\-]*([a-zA-Z0-9]{6,16})', caseSensitive: false),
    ];
    for (var p in refPatterns) {
      final m = p.firstMatch(lower);
      if (m != null && m.group(1) != null) return m.group(1);
    }
    return null;
  }

  static String _cleanMerchantName(String name) {
    String cleaned = name
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length > 25) cleaned = cleaned.substring(0, 25).trim();
    return _formatBrandName(cleaned);
  }

  static String _formatBrandName(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }
}
