import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';
import '../services/analytics_service.dart';

class ModernAnalyticsScreen extends StatefulWidget {
  final Database database;
  final String? initialTimePeriod;
  final Function({Map<String, dynamic>? existingTx})? onAddRequested;

  const ModernAnalyticsScreen({
    Key? key,
    required this.database,
    this.initialTimePeriod,
    this.onAddRequested,
  }) : super(key: key);

  @override
  State<ModernAnalyticsScreen> createState() => _ModernAnalyticsScreenState();
}

class _ModernAnalyticsScreenState extends State<ModernAnalyticsScreen> {
  String _timeHorizon = 'This Month'; // 'This Month', 'Last 30D', 'YTD'
  String? _customMonth;
  int _touchedPieIndex = -1;
  String? _selectedCategoryDrilldown;

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return const Color(0xFF10B981);
      case 'shopping':
        return const Color(0xFF8B5CF6);
      case 'transport':
        return const Color(0xFF3B82F6);
      case 'entertainment':
        return const Color(0xFFEF4444);
      case 'utilities':
      case 'bills':
        return const Color(0xFF14B8A6);
      case 'groceries':
        return const Color(0xFFF59E0B);
      case 'salary':
        return const Color(0xFF6366F1);
      default:
        final hash = category.hashCode;
        final r = (hash & 0xFF0000) >> 16;
        final g = (hash & 0x00FF00) >> 8;
        final b = (hash & 0x0000FF);
        return Color.fromRGBO(r, g, b, 1.0);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'food & dining':
        return Icons.fastfood_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'utilities':
      case 'bills':
        return Icons.lightbulb_rounded;
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'salary':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  String _formatAmount(double amount, {bool isSigned = false, bool isPositive = false}) {
    String prefix = '';
    if (isSigned) {
      prefix = isPositive ? '+₹' : '-₹';
    } else {
      prefix = '₹';
    }
    return '$prefix${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsData>(
      future: AnalyticsService.calculate(
        db: widget.database,
        timeHorizon: _timeHorizon,
        customMonth: _customMonth,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }

        final data = snapshot.data!;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTimeHorizonSelector(),
              const SizedBox(height: 24),
              _buildAdaptivePacerHero(data),
              const SizedBox(height: 24),
              _buildExecutiveKpiGrid(data),
              const SizedBox(height: 24),
              _buildSmartHacksSection(data),
              const SizedBox(height: 24),
              if (_selectedCategoryDrilldown != null) ...<Widget>[
                _buildInPlaceCategoryDrilldown(data),
                const SizedBox(height: 24),
              ],
              _buildBurnTrajectoryCard(data),
              const SizedBox(height: 24),
              _buildSpendingDistributionCard(data),
              const SizedBox(height: 24),
              if (data.subscriptions.isNotEmpty) ...<Widget>[
                _buildSubscriptionsCard(data),
                const SizedBox(height: 24),
              ],
              if (data.topMerchants.isNotEmpty) ...<Widget>[
                _buildTopMerchantsCard(data),
                const SizedBox(height: 24),
              ],
              _buildQuickActionDock(data),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'MONE • INTELLIGENCE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Financial Diagnostics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        // Live Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.25),
              width: 1.2,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_rounded,
                color: Color(0xFF10B981),
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'LIVE LEDGER',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeHorizonSelector() {
    final horizons = ['This Month', 'Last 30D', 'YTD'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: horizons.map((h) {
          final isSelected = _timeHorizon == h && _customMonth == null;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _timeHorizon = h;
                  _customMonth = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  h,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdaptivePacerHero(AnalyticsData data) {
    bool isOptimal = data.dailyBurnRate <= data.safeDailyAllowance || data.baseBudget == 0;
    double progressRatio = data.safeDailyAllowance > 0
        ? (data.dailyBurnRate / data.safeDailyAllowance).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6366F1).withOpacity(0.12),
            const Color(0xFF18181B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Color(0xFF6366F1).withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6366F1).withOpacity(0.15),
            blurRadius: 28,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFF818CF8), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Adaptive Daily Pacer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOptimal ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOptimal ? 'Velocity: Optimal' : 'Velocity: Caution',
                  style: TextStyle(
                    color: isOptimal ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Circular / Dial Gauge Centerpiece
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progressRatio,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOptimal ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatAmount(data.safeDailyAllowance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Safe Today',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Weekend Vault status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.savings_rounded, color: Color(0xFF818CF8), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Weekend Vault Surplus',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatAmount(data.weekendSurplus, isSigned: true, isPositive: true),
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveKpiGrid(AnalyticsData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Total Inflow',
                amount: _formatAmount(data.totalInflow),
                badgeText: 'Liquid Gains',
                accentColor: const Color(0xFF10B981),
                icon: Icons.arrow_downward_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Total Burn',
                amount: _formatAmount(data.totalOutflow),
                badgeText: 'Outflow',
                accentColor: const Color(0xFFF43F5E),
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Savings Rate',
                amount: '${data.netSavingsRate.toStringAsFixed(1)}%',
                badgeText: data.netSavingsRate >= 20 ? 'Strong Pacing' : 'Caution',
                accentColor: const Color(0xFF818CF8),
                icon: Icons.savings_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'EOM Projected',
                amount: _formatAmount(data.projectedEomBalance),
                badgeText: 'Runway Forecast',
                accentColor: const Color(0xFF38BDF8),
                icon: Icons.timeline_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String badgeText,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: accentColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartHacksSection(AnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFF818CF8), size: 18),
            const SizedBox(width: 8),
            Text(
              'FINANCIAL INTELLIGENCE & VAULTS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Anomaly: Subscription Price Hike Alert
        if (data.subscriptionHikeAlert != null) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF43F5E).withOpacity(0.15),
                  const Color(0xFF18181B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.35), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'RECURRING COST ANOMALY',
                        style: TextStyle(color: Color(0xFFF43F5E), fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data.subscriptionHikeAlert!,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Micro-Savings Round-Up Vault
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withOpacity(0.12),
                const Color(0xFF18181B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Micro-Savings Auto-Vault',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatAmount(data.spareChangeRoundUps)} Available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${data.roundUpCount} transactions rounded up to nearest ₹10',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showSweepDialog(data.spareChangeRoundUps);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Auto-Deposit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSweepDialog(double amount) async {
    final goals = await widget.database.query('goals');
    if (goals.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active savings goals found! Add a goal first.')),
        );
      }
      return;
    }

    int selectedGoalId = goals.first['id'] as int;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF18181B),
            title: const Text('Sweep Spare Change', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sweep ₹${amount.toStringAsFixed(0)} into your savings goal:',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGoalId,
                  dropdownColor: const Color(0xFF18181B),
                  style: const TextStyle(color: Colors.white),
                  items: goals.map((g) => DropdownMenuItem(value: g['id'] as int, child: Text(g['title'].toString()))).toList(),
                  onChanged: (val) => setDialogState(() => selectedGoalId = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  var goal = goals.firstWhere((g) => g['id'] == selectedGoalId);
                  double currentSaved = (goal['saved'] as num?)?.toDouble() ?? 0.0;
                  await widget.database.update('goals', {'saved': currentSaved + amount}, where: 'id = ?', whereArgs: [selectedGoalId]);
                  Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('₹${amount.toStringAsFixed(0)} swept into ${goal['title']}!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text('Confirm Sweep', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInPlaceCategoryDrilldown(AnalyticsData data) {
    final catName = _selectedCategoryDrilldown!;
    final catItem = data.categoryBreakdown.firstWhere(
      (c) => c.category == catName,
      orElse: () => CategorySpending(category: catName, amount: 0, percentage: 0),
    );
    final limit = catItem.limit ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _getCategoryColor(catName).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_getCategoryIcon(catName), color: _getCategoryColor(catName), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    catName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                onPressed: () => setState(() => _selectedCategoryDrilldown = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Spent: ${_formatAmount(catItem.amount)} • Current Limit: ₹${limit.toStringAsFixed(0)}',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    double newLimit = math.max(0.0, limit - 500.0);
                    await widget.database.insert(
                      'budgets',
                      {'category': catName, 'limit_amount': newLimit},
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                    setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('− ₹500', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    double newLimit = limit + 500.0;
                    await widget.database.insert(
                      'budgets',
                      {'category': catName, 'limit_amount': newLimit},
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('+ ₹500', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBurnTrajectoryCard(AnalyticsData data) {
    final points = data.burnTrajectory;
    final maxSpent = points.isNotEmpty ? points.last.cumulativeActual : 0.0;
    final maxCeiling = points.isNotEmpty ? points.last.cumulativeBudgetCeiling : 0.0;
    final maxY = math.max(1000.0, math.max(maxSpent, maxCeiling) * 1.15);

    List<FlSpot> actualSpots = [];
    List<FlSpot> ceilingSpots = [];
    for (var p in points) {
      actualSpots.add(FlSpot(p.day.toDouble(), p.cumulativeActual));
      ceilingSpots.add(FlSpot(p.day.toDouble(), p.cumulativeBudgetCeiling));
    }

    bool isWithinSafeZone = data.baseBudget == 0 || maxSpent <= maxCeiling;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Burn Trajectory vs Ceiling',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Day ${data.daysElapsed} of ${data.totalDaysInPeriod}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isWithinSafeZone ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isWithinSafeZone ? 'Safe Pace' : 'Above Ceiling',
                  style: TextStyle(
                    color: isWithinSafeZone ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: data.totalDaysInPeriod.toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (data.totalDaysInPeriod / 4).clamp(1.0, 10.0),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'D${value.toInt()}',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    color: const Color(0xFF6366F1),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF6366F1).withOpacity(0.35),
                          Color(0xFF6366F1).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  if (data.baseBudget > 0)
                    LineChartBarData(
                      spots: ceilingSpots,
                      isCurved: false,
                      color: Colors.white.withOpacity(0.3),
                      barWidth: 1.5,
                      dashArray: [5, 5],
                      dotData: FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Actual Spend', const Color(0xFF6366F1)),
              const SizedBox(width: 24),
              _buildLegendItem('Safe Ceiling', Colors.white.withOpacity(0.4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSpendingDistributionCard(AnalyticsData data) {
    final breakdown = data.categoryBreakdown;
    List<PieChartSectionData> pieSections = [];

    for (int i = 0; i < breakdown.length; i++) {
      final c = breakdown[i];
      final isTouched = i == _touchedPieIndex;
      final radius = isTouched ? 46.0 : 38.0;
      final color = _getCategoryColor(c.category);

      pieSections.add(
        PieChartSectionData(
          color: color,
          value: c.amount,
          radius: radius,
          showTitle: false,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spending Distribution',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Tap to Drilldown',
                style: TextStyle(
                  color: const Color(0xFF818CF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (pieSections.isNotEmpty) ...[
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sections: pieSections,
                      centerSpaceRadius: 55,
                      sectionsSpace: 3,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            if (_touchedPieIndex >= 0 && _touchedPieIndex < breakdown.length) {
                              _selectedCategoryDrilldown = breakdown[_touchedPieIndex].category;
                              HapticFeedback.selectionClick();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'TOTAL BURN',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatAmount(data.totalOutflow),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
          ...breakdown.map((cat) {
            final color = _getCategoryColor(cat.category);
            final delta = cat.momDeltaPercent;
            final isIncrease = delta != null && delta > 0;
            final isSelected = _selectedCategoryDrilldown == cat.category;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategoryDrilldown = isSelected ? null : cat.category;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color.withOpacity(0.4) : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getCategoryIcon(cat.category), color: color, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${cat.percentage.toStringAsFixed(1)}% of total',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatAmount(cat.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            if (delta != null) ...[
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isIncrease ? const Color(0xFFF43F5E) : const Color(0xFF10B981)).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${isIncrease ? '+' : ''}${delta.toStringAsFixed(0)}% MoM',
                                  style: TextStyle(
                                    color: isIncrease ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (cat.percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        color: color,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsCard(AnalyticsData data) {
    double totalSubs = data.subscriptions.fold(0.0, (sum, item) => sum + item.monthlyAmount);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fixed Outflows & Subscriptions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${_formatAmount(totalSubs)}/mo',
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...data.subscriptions.map((sub) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.repeat_rounded, color: Color(0xFF818CF8), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sub.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    _formatAmount(sub.monthlyAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTopMerchantsCard(AnalyticsData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Merchants by Volume',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...data.topMerchants.map((m) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      m.merchant.isNotEmpty ? m.merchant[0].toUpperCase() : 'M',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.merchant,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${m.count} transactions',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatAmount(m.totalAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildQuickActionDock(AnalyticsData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTION DOCK',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.calculate_rounded,
                  label: 'Simulate Buy',
                  onTap: () => _showSimulatePurchaseDialog(data),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.tune_rounded,
                  label: 'Adjust Ceiling',
                  onTap: () => _showAdjustCeilingDialog(data),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF818CF8), size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showSimulatePurchaseDialog(AnalyticsData data) {
    final ctrl = TextEditingController();
    double simulatedAllowance = data.safeDailyAllowance;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF18181B),
            title: const Text('Simulate Purchase Impact', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter an expense amount to preview how it affects your daily safe allowance for the rest of the month:',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    hintText: 'e.g. 5000',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onChanged: (val) {
                    final entered = double.tryParse(val) ?? 0.0;
                    final daysLeft = math.max(1, data.totalDaysInPeriod - data.daysElapsed);
                    final rem = math.max(0.0, (data.baseBudget - data.totalOutflow - entered));
                    setDialogState(() {
                      simulatedAllowance = rem / daysLeft;
                    });
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New Daily Runway:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '₹${simulatedAllowance.toStringAsFixed(0)}/day',
                        style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            ],
          );
        },
      ),
    );
  }

  void _showAdjustCeilingDialog(AnalyticsData data) {
    final ctrl = TextEditingController(text: data.baseBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Adjust Monthly Budget Ceiling', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newBudget = double.tryParse(ctrl.text) ?? data.baseBudget;
              await widget.database.insert(
                'settings',
                {'key': 'total_budget', 'value': newBudget},
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              Navigator.pop(ctx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Save Ceiling', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
