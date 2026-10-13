import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';

class DailySpendPoint {
  final int day;
  final double cumulativeActual;
  final double cumulativeBudgetCeiling;

  DailySpendPoint({
    required this.day,
    required this.cumulativeActual,
    required this.cumulativeBudgetCeiling,
  });
}

class CategorySpending {
  final String category;
  final double amount;
  final double percentage;
  final double? limit;
  final double? momDeltaPercent; // e.g. +18.4% or -4.2%

  CategorySpending({
    required this.category,
    required this.amount,
    required this.percentage,
    this.limit,
    this.momDeltaPercent,
  });
}

class SubscriptionItem {
  final String name;
  final double monthlyAmount;
  final DateTime lastDate;
  final int frequencyMonths;

  SubscriptionItem({
    required this.name,
    required this.monthlyAmount,
    required this.lastDate,
    this.frequencyMonths = 1,
  });
}

class MerchantSpendItem {
  final String merchant;
  final int count;
  final double totalAmount;

  MerchantSpendItem({
    required this.merchant,
    required this.count,
    required this.totalAmount,
  });
}

class AnalyticsData {
  final double totalInflow;
  final double totalOutflow;
  final double netSavingsRate;
  final double baseBudget;
  final double projectedEomBalance;
  final double dailyBurnRate;
  final double safeDailyAllowance;
  final int daysElapsed;
  final int totalDaysInPeriod;
  final List<DailySpendPoint> burnTrajectory;
  final List<CategorySpending> categoryBreakdown;
  final List<SubscriptionItem> subscriptions;
  final List<MerchantSpendItem> topMerchants;
  final String? anomalyInsight;
  final double spareChangeRoundUps;
  final int roundUpCount;
  final String? subscriptionHikeAlert;
  final double weekendSurplus;

  AnalyticsData({
    required this.totalInflow,
    required this.totalOutflow,
    required this.netSavingsRate,
    required this.baseBudget,
    required this.projectedEomBalance,
    required this.dailyBurnRate,
    required this.safeDailyAllowance,
    required this.daysElapsed,
    required this.totalDaysInPeriod,
    required this.burnTrajectory,
    required this.categoryBreakdown,
    required this.subscriptions,
    required this.topMerchants,
    this.anomalyInsight,
    this.spareChangeRoundUps = 0.0,
    this.roundUpCount = 0,
    this.subscriptionHikeAlert,
    this.weekendSurplus = 0.0,
  });
}

class AnalyticsService {
  static Future<AnalyticsData> calculate({
    required Database db,
    String timeHorizon = 'This Month', // 'This Month', 'Last 30D', 'YTD', 'Custom'
    String? customMonth, // e.g. '2026-09'
  }) async {
    final DateTime now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;
    late DateTime prevStartDate;
    late DateTime prevEndDate;

    if (customMonth != null) {
      final parts = customMonth.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      startDate = DateTime(y, m, 1);
      endDate = DateTime(y, m + 1, 1);
      prevStartDate = DateTime(y, m - 1, 1);
      prevEndDate = DateTime(y, m, 1);
    } else if (timeHorizon == 'Last 30D') {
      endDate = now;
      startDate = now.subtract(const Duration(days: 30));
      prevEndDate = startDate;
      prevStartDate = startDate.subtract(const Duration(days: 30));
    } else if (timeHorizon == 'YTD') {
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year + 1, 1, 1);
      prevStartDate = DateTime(now.year - 1, 1, 1);
      prevEndDate = DateTime(now.year, 1, 1);
    } else {
      // 'This Month' default
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 1);
      prevStartDate = DateTime(now.year, now.month - 1, 1);
      prevEndDate = DateTime(now.year, now.month, 1);
    }

    final startIso = startDate.toIso8601String();
    final endIso = endDate.toIso8601String();
    final prevStartIso = prevStartDate.toIso8601String();
    final prevEndIso = prevEndDate.toIso8601String();

    // 1. Current period transactions
    final currentTxs = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startIso, endIso],
      orderBy: 'date ASC',
    );

    // 2. Previous period transactions (for MoM delta calculation)
    final prevTxs = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [prevStartIso, prevEndIso],
    );

    // 3. Settings & Budgets
    final settingsRows = await db.query('settings');
    final budgetsRows = await db.query('budgets');

    double baseBudget = 0.0;
    for (var s in settingsRows) {
      if (s['key'] == 'total_budget') {
        baseBudget = (s['value'] as num?)?.toDouble() ?? 0.0;
      }
    }

    Map<String, double> categoryLimits = {};
    for (var b in budgetsRows) {
      categoryLimits[b['category'] as String] = (b['limit_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Calculations
    double totalInflow = 0.0;
    double totalOutflow = 0.0;
    Map<String, double> catSpent = {};
    Map<String, int> merchantCounts = {};
    Map<String, double> merchantTotals = {};

    for (var t in currentTxs) {
      final type = t['type'] as String;
      final amt = (t['amount'] as num).toDouble();
      final cat = (t['category'] as String?) ?? 'Other';
      final merchant = (t['merchant'] as String?) ?? 'Unknown';

      if (type == 'INCOME' || type == 'TRANSFER_IN') {
        totalInflow += amt;
      } else if (type == 'EXPENSE' || type == 'GOAL_TRANSFER' || type == 'TRANSFER_OUT') {
        totalOutflow += amt;
        catSpent[cat] = (catSpent[cat] ?? 0.0) + amt;

        merchantCounts[merchant] = (merchantCounts[merchant] ?? 0) + 1;
        merchantTotals[merchant] = (merchantTotals[merchant] ?? 0.0) + amt;
      }
    }

    // Previous period category spending
    Map<String, double> prevCatSpent = {};
    for (var t in prevTxs) {
      final type = t['type'] as String;
      if (type == 'EXPENSE' || type == 'GOAL_TRANSFER' || type == 'TRANSFER_OUT') {
        final amt = (t['amount'] as num).toDouble();
        final cat = (t['category'] as String?) ?? 'Other';
        prevCatSpent[cat] = (prevCatSpent[cat] ?? 0.0) + amt;
      }
    }

    // Net Savings Rate
    double netSavingsRate = 0.0;
    if (totalInflow > 0) {
      netSavingsRate = ((totalInflow - totalOutflow) / totalInflow) * 100.0;
    }

    // Days calculation
    final daysInPeriod = endDate.difference(startDate).inDays;
    final int daysElapsed = math.max(1, math.min(daysInPeriod, now.difference(startDate).inDays + 1));
    final int daysRemaining = math.max(1, daysInPeriod - daysElapsed);

    final double dailyBurnRate = daysElapsed > 0 ? totalOutflow / daysElapsed : 0.0;
    final double remainingBudget = baseBudget > totalOutflow ? (baseBudget - totalOutflow) : 0.0;
    final double safeDailyAllowance = daysRemaining > 0 ? remainingBudget / daysRemaining : 0.0;
    final double projectedEomBalance = totalInflow - (dailyBurnRate * daysInPeriod);

    // Burn Trajectory & Cumulative Spend
    List<DailySpendPoint> burnTrajectory = [];
    double cumulative = 0.0;
    final double linearDailyBudget = baseBudget > 0 ? baseBudget / daysInPeriod : 0.0;

    // Group actual expenses by day offset (1 to daysInPeriod)
    Map<int, double> dailyActualSum = {};
    for (var t in currentTxs) {
      final type = t['type'] as String;
      if (type == 'EXPENSE' || type == 'GOAL_TRANSFER' || type == 'TRANSFER_OUT') {
        final d = DateTime.tryParse(t['date'] as String) ?? startDate;
        final dayIndex = math.max(1, math.min(daysInPeriod, d.difference(startDate).inDays + 1));
        dailyActualSum[dayIndex] = (dailyActualSum[dayIndex] ?? 0.0) + (t['amount'] as num).toDouble();
      }
    }

    int curveDays = (timeHorizon == 'This Month' && customMonth == null) ? daysElapsed : daysInPeriod;
    for (int d = 1; d <= curveDays; d++) {
      cumulative += (dailyActualSum[d] ?? 0.0);
      burnTrajectory.add(DailySpendPoint(
        day: d,
        cumulativeActual: cumulative,
        cumulativeBudgetCeiling: linearDailyBudget * d,
      ));
    }

    // Category Breakdown with MoM % Delta
    List<CategorySpending> categoryBreakdown = [];
    final allCategories = {...catSpent.keys, ...categoryLimits.keys};
    final sortedCats = allCategories.toList()..sort((a, b) => (catSpent[b] ?? 0.0).compareTo(catSpent[a] ?? 0.0));

    for (var cat in sortedCats) {
      final spent = catSpent[cat] ?? 0.0;
      if (spent == 0.0 && !(categoryLimits.containsKey(cat) && categoryLimits[cat]! > 0)) {
        continue;
      }
      final pct = totalOutflow > 0 ? (spent / totalOutflow) * 100.0 : 0.0;
      final prevSpent = prevCatSpent[cat] ?? 0.0;

      double? momDelta;
      if (prevSpent > 0) {
        momDelta = ((spent - prevSpent) / prevSpent) * 100.0;
      } else if (spent > 0 && prevSpent == 0) {
        momDelta = 100.0;
      }

      categoryBreakdown.add(CategorySpending(
        category: cat,
        amount: spent,
        percentage: pct,
        limit: categoryLimits[cat],
        momDeltaPercent: momDelta,
      ));
    }

    // Top Merchants
    List<MerchantSpendItem> topMerchants = [];
    final sortedMerchants = merchantTotals.keys.toList()
      ..sort((a, b) => (merchantTotals[b] ?? 0.0).compareTo(merchantTotals[a] ?? 0.0));

    for (var m in sortedMerchants.take(5)) {
      topMerchants.add(MerchantSpendItem(
        merchant: m,
        count: merchantCounts[m] ?? 1,
        totalAmount: merchantTotals[m] ?? 0.0,
      ));
    }

    // Automated Recurring Subscriptions Detection Heuristic
    // Look across the last 90 days for identical merchant charges recurring monthly
    List<SubscriptionItem> subscriptions = [];
    String? subscriptionHikeAlert;
    try {
      final ninetyDaysAgo = now.subtract(const Duration(days: 90)).toIso8601String();
      final subTxs = await db.query(
        'transactions',
        where: 'type = ? AND date >= ?',
        whereArgs: ['EXPENSE', ninetyDaysAgo],
        orderBy: 'date DESC',
      );

      Map<String, List<Map<String, dynamic>>> merchantOccurrences = {};
      for (var t in subTxs) {
        final m = (t['merchant'] as String?)?.trim().toLowerCase() ?? '';
        if (m.isNotEmpty && m != 'bank sms' && !m.startsWith('sms:')) {
          merchantOccurrences.putIfAbsent(m, () => []).add(t);
        }
      }

      for (var entry in merchantOccurrences.entries) {
        final list = entry.value;
        if (list.length >= 2) {
          final firstAmt = (list[0]['amount'] as num).toDouble();
          final secondAmt = (list[1]['amount'] as num).toDouble();
          if ((firstAmt - secondAmt).abs() < 5.0) {
            final latestDate = DateTime.parse(list[0]['date'] as String);
            final merchantName = list[0]['merchant'] as String;
            subscriptions.add(SubscriptionItem(
              name: merchantName,
              monthlyAmount: firstAmt,
              lastDate: latestDate,
            ));
          } else if (firstAmt > secondAmt + 20.0 && subscriptionHikeAlert == null) {
            final merchantName = list[0]['merchant'] as String;
            final diff = firstAmt - secondAmt;
            final pct = ((diff / secondAmt) * 100).toInt();
            subscriptionHikeAlert = 'Price Hike: $merchantName charged ₹${firstAmt.toStringAsFixed(0)} (was ₹${secondAmt.toStringAsFixed(0)}, +$pct%)';
          }
        }
      }
    } catch (_) {}

    // Spare Change Round-Ups Calculation
    double spareChange = 0.0;
    int roundUpCount = 0;
    for (var t in currentTxs) {
      final type = t['type'] as String;
      if (type == 'EXPENSE' || type == 'GOAL_TRANSFER' || type == 'TRANSFER_OUT') {
        final amt = (t['amount'] as num).toDouble();
        double remainder = amt % 10.0;
        double roundDiff = remainder > 0 ? (10.0 - remainder) : 0.0;
        if (roundDiff > 0) {
          spareChange += roundDiff;
          roundUpCount++;
        }
      }
    }

    // Banked Surplus calculation
    double bankedBudget = (baseBudget > 0) ? (baseBudget / daysInPeriod) * daysElapsed : 0.0;
    double weekendSurplus = math.max(0.0, bankedBudget - totalOutflow);

    // Smart Anomaly / Outlier Flag
    String? anomalyInsight;
    if (categoryBreakdown.isNotEmpty) {
      final highestSpike = categoryBreakdown.firstWhere(
        (c) => (c.momDeltaPercent ?? 0.0) >= 20.0 && c.amount > 300.0,
        orElse: () => categoryBreakdown.first,
      );

      if ((highestSpike.momDeltaPercent ?? 0.0) >= 20.0) {
        anomalyInsight = '${highestSpike.category} spending is +${highestSpike.momDeltaPercent!.toStringAsFixed(0)}% higher than last period. Tap to set a safety limit.';
      } else if (dailyBurnRate * daysInPeriod > baseBudget && baseBudget > 0) {
        final overAmt = (dailyBurnRate * daysInPeriod) - baseBudget;
        anomalyInsight = 'At current burn rate (₹${dailyBurnRate.toStringAsFixed(0)}/day), you are on pace to exceed budget by ₹${overAmt.toStringAsFixed(0)}.';
      }
    }

    return AnalyticsData(
      totalInflow: totalInflow,
      totalOutflow: totalOutflow,
      netSavingsRate: netSavingsRate,
      baseBudget: baseBudget,
      projectedEomBalance: projectedEomBalance,
      dailyBurnRate: dailyBurnRate,
      safeDailyAllowance: safeDailyAllowance,
      daysElapsed: daysElapsed,
      totalDaysInPeriod: daysInPeriod,
      burnTrajectory: burnTrajectory,
      categoryBreakdown: categoryBreakdown,
      subscriptions: subscriptions,
      topMerchants: topMerchants,
      anomalyInsight: anomalyInsight,
      spareChangeRoundUps: spareChange,
      roundUpCount: roundUpCount,
      subscriptionHikeAlert: subscriptionHikeAlert,
      weekendSurplus: weekendSurplus,
    );
  }
}
