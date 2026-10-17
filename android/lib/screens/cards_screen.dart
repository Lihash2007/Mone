import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../services/indian_banks.dart';
import '../theme/mone_theme.dart';
import '../widgets/apple_wallet_stack.dart';
import '../main.dart' show AnalyticsScreen;

class CardsScreen extends StatefulWidget {
  final Database database;
  final bool isDark;
  final String userName;
  final VoidCallback onAddAccountRequested;
  final Function(Map<String, dynamic> acc) onEditAccountRequested;
  final Function({Map<String, dynamic>? existingTx}) onAddRequested;
  final VoidCallback onTransactionChanged;

  const CardsScreen({
    super.key,
    required this.database,
    required this.isDark,
    required this.userName,
    required this.onAddAccountRequested,
    required this.onEditAccountRequested,
    required this.onAddRequested,
    required this.onTransactionChanged,
  });

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        widget.database.query('accounts'),
        widget.database.query('transactions'),
        widget.database.rawQuery('''
          SELECT strftime('%Y-%m', date) as month, SUM(amount) as total
          FROM transactions
          WHERE type = 'EXPENSE'
          GROUP BY month
          ORDER BY month DESC
          LIMIT 6
        '''),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snapshot.data![0] as List<Map<String, dynamic>>;
        final allTxs = snapshot.data![1] as List<Map<String, dynamic>>;
        final trendsData = snapshot.data![2] as List<Map<String, dynamic>>;

        // Compute balances
        Map<int, double> computedBalances = {};
        for (var acc in accounts) {
          int id = acc['id'] as int;
          computedBalances[id] = (acc['initial_balance'] as num?)?.toDouble() ??
              (acc['balance'] as num?)?.toDouble() ??
              0.0;
        }
        for (var t in allTxs) {
          int? accId = t['account_id'] as int?;
          if (accId != null && computedBalances.containsKey(accId)) {
            double amt = (t['amount'] as num).toDouble();
            if (t['type'] == 'INCOME' || t['type'] == 'TRANSFER_IN') {
              computedBalances[accId] = computedBalances[accId]! + amt;
            } else if (t['type'] == 'EXPENSE' || t['type'] == 'TRANSFER_OUT') {
              computedBalances[accId] = computedBalances[accId]! - amt;
            }
          }
        }

        List<AppleWalletCardItem> cardItems = [];

        for (var acc in accounts) {
          double bal = computedBalances[acc['id'] as int] ?? 0.0;
          var copy = Map<String, dynamic>.from(acc);
          copy['balance'] = bal;
          cardItems.add(AppleWalletCardItem.fromMap(copy));
        }

        return Container(
          decoration: BoxDecoration(
            gradient: MoneTheme.bgCanvasGradient(widget.isDark),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BANKING & LEDGERS',
                          style: TextStyle(
                            color: MoneTheme.textSecondary(widget.isDark),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cards & Accounts',
                          style: TextStyle(
                            color: MoneTheme.textPrimary(widget.isDark),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    // Add Account Pill
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onAddAccountRequested();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: MoneTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: MoneTheme.primaryBlue.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Add Card',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Apple Wallet Cards Section
                AppleWalletCardsSection(
                  accounts: cardItems,
                  isDark: widget.isDark,
                  onCardTap: (card) {
                    final accMatch = accounts.firstWhere((a) => a['id'] == card.id);
                    widget.onEditAccountRequested(accMatch);
                  },
                  onAddAccount: widget.onAddAccountRequested,
                ),

                const SizedBox(height: 24),

                // Account Roster Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: MoneTheme.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.account_balance_rounded, color: MoneTheme.primaryBlue, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'ACTIVE ACCOUNTS (${accounts.length})',
                                style: TextStyle(
                                  color: MoneTheme.textPrimary(widget.isDark),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Tap to edit',
                            style: TextStyle(
                              color: MoneTheme.textMuted(widget.isDark),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...accounts.map((acc) {
                        int id = acc['id'] as int;
                        double bal = computedBalances[id] ?? 0.0;
                        int include = (acc['include_in_total'] as int?) ?? 1;
                        bool isCash = acc['type'] == 'CASH';
                        BankInfo b = isCash
                            ? IndianBankDirectory.getBankById('cash')
                            : IndianBankDirectory.findBankByName(
                                acc['bank_code'] ?? acc['bank_name'] ?? '');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onEditAccountRequested(acc);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : MoneTheme.bgCanvas(false),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: MoneTheme.cardBorder(widget.isDark),
                                ),
                              ),
                              child: Row(
                                children: [
                                  b.buildBadge(size: 34),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                acc['name'] ?? 'Account',
                                                style: TextStyle(
                                                  color: MoneTheme.textPrimary(widget.isDark),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (include == 0) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'EXCLUDED',
                                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          acc['account_number'] != null && acc['account_number'].toString().isNotEmpty
                                              ? '${b.shortName} •• ${acc['account_number']}'
                                              : (isCash ? 'Physical Cash' : b.name),
                                          style: TextStyle(
                                            color: MoneTheme.textMuted(widget.isDark),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${bal.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: MoneTheme.textPrimary(widget.isDark),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Historical Monthly Spending Trends
                if (trendsData.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.trending_up_rounded, color: Color(0xFF8B5CF6), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'MONTHLY SPENDING TRENDS',
                                  style: TextStyle(
                                    color: MoneTheme.textPrimary(widget.isDark),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Last 6 Months',
                              style: TextStyle(
                                color: MoneTheme.textMuted(widget.isDark),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(builder: (context) {
                          double maxTotal = 0;
                          for (var row in trendsData) {
                            double total = (row['total'] as num).toDouble();
                            if (total > maxTotal) maxTotal = total;
                          }

                          return Column(
                            children: trendsData.map((row) {
                              String raw = row['month'] as String;
                              double total = (row['total'] as num).toDouble();
                              List<String> parts = raw.split('-');
                              if (parts.length != 2) return const SizedBox();
                              int m = int.parse(parts[1]);
                              const monthNames = [
                                'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                              ];
                              String name = '${monthNames[m - 1]} ${parts[0]}';
                              double pct = maxTotal > 0 ? (total / maxTotal) : 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) => Scaffold(
                                          backgroundColor: MoneTheme.bgCanvas(widget.isDark),
                                          appBar: AppBar(
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            leading: IconButton(
                                              icon: Icon(Icons.arrow_back, color: MoneTheme.textPrimary(widget.isDark)),
                                              onPressed: () => Navigator.pop(ctx),
                                            ),
                                          ),
                                          body: AnalyticsScreen(
                                            database: widget.database,
                                            timePeriod: 'Monthly',
                                            onResolveRollover: (a, b) {},
                                            onAddRequested: widget.onAddRequested,
                                            onTransactionChanged: widget.onTransactionChanged,
                                            overrideMonth: raw,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: MoneTheme.textPrimary(widget.isDark),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '₹${total.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: MoneTheme.badgeRedText,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor: widget.isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.grey.withValues(alpha: 0.15),
                                          color: const Color(0xFF8B5CF6),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
