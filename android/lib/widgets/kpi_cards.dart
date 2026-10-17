import 'package:flutter/material.dart';
import '../theme/mone_theme.dart';

class DualKpiCards extends StatelessWidget {
  final double totalBalance;
  final double monthlySpent;
  final double monthlyBudget;
  final bool isDark;
  final VoidCallback onBalanceTap;
  final VoidCallback onBudgetTap;

  const DualKpiCards({
    super.key,
    required this.totalBalance,
    required this.monthlySpent,
    required this.monthlyBudget,
    required this.isDark,
    required this.onBalanceTap,
    required this.onBudgetTap,
  });

  @override
  Widget build(BuildContext context) {
    final double budgetPercent = monthlyBudget > 0 ? (monthlySpent / monthlyBudget).clamp(0.0, 1.0) : 0.0;
    final bool isOverBudget = monthlyBudget > 0 && monthlySpent > monthlyBudget;

    return Row(
      children: [
        // 1. Total Net Worth / Balance Card
        Expanded(
          child: GestureDetector(
            onTap: onBalanceTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: MoneTheme.whiteCardDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "NET BALANCE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: MoneTheme.textSecondary(isDark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MoneTheme.badgeGreenBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_outward_rounded,
                          size: 12,
                          color: MoneTheme.badgeGreenText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "₹${totalBalance.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: MoneTheme.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MoneTheme.badgeBlueBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Liquid Cash & Banks",
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: MoneTheme.badgeBlueText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // 2. Monthly Spending & Budget Card
        Expanded(
          child: GestureDetector(
            onTap: onBudgetTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: MoneTheme.whiteCardDecoration(isDark: isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "MONTH SPENT",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: MoneTheme.textSecondary(isDark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isOverBudget ? MoneTheme.badgeRedBg : MoneTheme.badgeAmberBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.insights_rounded,
                          size: 12,
                          color: isOverBudget ? MoneTheme.badgeRedText : MoneTheme.badgeAmberText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "₹${monthlySpent.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: MoneTheme.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (monthlyBudget > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: budgetPercent,
                        minHeight: 5,
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverBudget ? MoneTheme.rose : MoneTheme.emerald,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MoneTheme.bgCardBlue(isDark),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Tap to set budget",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: MoneTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
