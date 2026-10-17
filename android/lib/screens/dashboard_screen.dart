import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../models/family_member.dart';
import '../services/indian_banks.dart';
import '../theme/mone_theme.dart';
import '../widgets/apple_wallet_stack.dart';

// MARK: - Overview Dashboard View (1:1 with iOS OverviewDashboardView)
class DashboardScreen extends StatefulWidget {
  final Database database;
  final bool isDark;
  final String userName;
  final File? profilePhotoFile;
  final VoidCallback onProfileTap;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenMenu;
  final Function(int) onNavigateTab;
  final Function({Map<String, dynamic>? existingTx, int? memberId}) onAddTransaction;
  final VoidCallback onOpenManageFamily;
  final VoidCallback onOpenManageAccounts;
  final VoidCallback onOpenAllTransactions;
  final VoidCallback onOpenSetBudget;
  final Future<void> Function() onRefreshRequested;

  const DashboardScreen({
    super.key,
    required this.database,
    required this.isDark,
    required this.userName,
    this.profilePhotoFile,
    required this.onProfileTap,
    required this.onToggleTheme,
    required this.onOpenMenu,
    required this.onNavigateTab,
    required this.onAddTransaction,
    required this.onOpenManageFamily,
    required this.onOpenManageAccounts,
    required this.onOpenAllTransactions,
    required this.onOpenSetBudget,
    required this.onRefreshRequested,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _selectedFamilyMemberId;
  String _selectedFilter = 'ALL'; // ALL, EXPENSE, INCOME

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        widget.database.query('accounts'),
        widget.database.query('transactions', orderBy: 'date DESC'),
        widget.database.query('settings'),
        widget.database.query('family_members', orderBy: 'id ASC'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: MoneTheme.primaryBlue),
          );
        }

        final accounts = (snapshot.data![0] as List<Map<String, dynamic>>);
        final transactions = (snapshot.data![1] as List<Map<String, dynamic>>);
        final settings = (snapshot.data![2] as List<Map<String, dynamic>>);
        final familyRaw = (snapshot.data![3] as List<Map<String, dynamic>>);
        final familyMembers = familyRaw.map((m) => MoneFamilyMember.fromMap(m)).toList();

        // Total Monthly Budget from settings
        double totalMonthlyBudget = 0.0;
        for (var s in settings) {
          if (s['key'] == 'total_budget') {
            totalMonthlyBudget = (s['value'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // Account balances
        Map<int, double> computedBalances = {};
        for (var acc in accounts) {
          int id = acc['id'] as int;
          double initBal = (acc['initial_balance'] as num?)?.toDouble() ?? (acc['balance'] as num?)?.toDouble() ?? 0.0;
          computedBalances[id] = initBal;
        }
        for (var t in transactions) {
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

        // Selected family member
        final selectedMember = _selectedFamilyMemberId != null
            ? familyMembers.firstWhere((m) => m.id == _selectedFamilyMemberId, orElse: () => familyMembers.first)
            : null;

        // Filtered accounts for Apple Wallet Stack
        final filteredAccounts = accounts.where((acc) {
          if (_selectedFamilyMemberId == null) return true;
          return acc['member_id'] == _selectedFamilyMemberId;
        }).toList();

        List<AppleWalletCardItem> appleWalletCards = [];
        for (var acc in filteredAccounts) {
          double bal = computedBalances[acc['id'] as int] ?? 0.0;
          var copy = Map<String, dynamic>.from(acc);
          copy['balance'] = bal;
          appleWalletCards.add(AppleWalletCardItem.fromMap(copy));
        }

        // Financial calculations
        final now = DateTime.now();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final daysLeft = (daysInMonth - now.day) + 1;

        double monthlyIncome = 0.0;
        double monthlySpent = 0.0;
        double todaySpent = 0.0;
        double totalBal = 0.0;

        final memberAccIds = filteredAccounts.map((a) => a['id'] as int).toSet();

        for (var a in filteredAccounts) {
          int include = (a['include_in_total'] as int?) ?? 1;
          if (include == 1) {
            totalBal += computedBalances[a['id'] as int] ?? 0.0;
          }
        }

        for (var tx in transactions) {
          if (tx['date'] == null) continue;
          try {
            final d = DateTime.parse(tx['date'].toString());
            bool matchMember = true;
            if (_selectedFamilyMemberId != null) {
              matchMember = tx['member_id'] == _selectedFamilyMemberId ||
                  (tx['account_id'] != null && memberAccIds.contains(tx['account_id']));
            }
            if (!matchMember) continue;

            final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
            if (d.month == now.month && d.year == now.year) {
              if (tx['type'] == 'INCOME') monthlyIncome += amt;
              if (tx['type'] == 'EXPENSE') monthlySpent += amt;
            }
            if (d.day == now.day && d.month == now.month && d.year == now.year && tx['type'] == 'EXPENSE') {
              todaySpent += amt;
            }
          } catch (_) {}
        }

        final netFlow = monthlyIncome - monthlySpent;
        final hasAllowance = (selectedMember?.monthlyAllowance ?? 0) > 0;
        final budgetTarget = hasAllowance ? selectedMember!.monthlyAllowance : totalMonthlyBudget;
        final hasBudget = budgetTarget > 0;
        final isOverBudget = hasBudget && (monthlySpent > budgetTarget);
        final unspent = hasBudget ? (budgetTarget - monthlySpent).clamp(0.0, double.infinity) : 0.0;
        final dailySafeSpend = hasBudget ? (unspent / daysLeft) : 0.0;
        final pctLeft = hasBudget ? ((unspent / budgetTarget) * 100).round() : 0;

        return RefreshIndicator(
          onRefresh: widget.onRefreshRequested,
          color: MoneTheme.primaryBlue,
          backgroundColor: MoneTheme.cardBg(widget.isDark),
          displacement: 40,
          strokeWidth: 2.5,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Avatar + Appearance Toggle & Menu Drawer)
                _buildHeaderRow(),
                const SizedBox(height: 16),

                // 2. Greeting: "Hi, Lihash!"
                Text(
                  'Hi, ${widget.userName}!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Option A: Family Switcher Capsule Strip
                _buildFamilySwitcherSection(familyMembers),
                const SizedBox(height: 16),

                // 4. Apple Wallet Stacked Bank Cards Section
                AppleWalletCardsSection(
                  accounts: appleWalletCards,
                  isDark: widget.isDark,
                  onCardTap: (card) => widget.onOpenManageAccounts(),
                  onAddAccount: widget.onOpenManageAccounts,
                ),
                const SizedBox(height: 20),

                // 5. "Your financial insights" Headline
                Text(
                  'Your financial\ninsights',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: MoneTheme.textPrimary(widget.isDark),
                    height: 1.05,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 18),

                // 6. Dual KPI Cards: Balance & Save
                _buildDualKpiCards(
                  selectedMember: selectedMember,
                  totalBal: totalBal,
                  netFlow: netFlow,
                  linkedAccountsCount: filteredAccounts.length,
                  hasBudget: hasBudget,
                  hasAllowance: hasAllowance,
                  isOverBudget: isOverBudget,
                  pctLeft: pctLeft,
                  unspent: unspent,
                  monthlySpent: monthlySpent,
                  budgetTarget: budgetTarget,
                  dailySafeSpend: dailySafeSpend,
                  daysLeft: daysLeft,
                ),
                const SizedBox(height: 16),

                // 7. Action Bar: Solid Black "+ Add money" + 3 Action Buttons
                _buildQuickActionBar(),
                const SizedBox(height: 20),

                // 8. 2x2 Feature Grid: Optimize Budget, Smart Saving, Active Banks, Expense Flow
                _buildFeatureGrid(
                  totalMonthlyBudget: totalMonthlyBudget,
                  netFlow: netFlow,
                  accountsCount: accounts.length,
                  todaySpent: todaySpent,
                ),
                const SizedBox(height: 24),

                // 9. Recent Activity Section
                _buildRecentActivitySection(
                  transactions: transactions,
                  accounts: accounts,
                  familyMembers: familyMembers,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // MARK: - 1. Header Row
  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profile Avatar
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onProfileTap();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD9E6EF),
              image: widget.profilePhotoFile != null
                  ? DecorationImage(image: FileImage(widget.profilePhotoFile!), fit: BoxFit.cover)
                  : null,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.profilePhotoFile == null
                ? Center(
                    child: Text(
                      widget.userName.isNotEmpty ? widget.userName.substring(0, 1).toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF335C7A),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  )
                : null,
          ),
        ),

        // Dark/Light Toggle + Hamburger Quick Control Menu
        Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onToggleTheme();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1B212D) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                  size: 18,
                  color: widget.isDark ? const Color(0xFFF59E0B) : MoneTheme.textPrimary(widget.isDark),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onOpenMenu();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1B212D) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.menu_rounded,
                  size: 20,
                  color: MoneTheme.textPrimary(widget.isDark),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // MARK: - 3. Family Switcher Capsule Strip
  Widget _buildFamilySwitcherSection(List<MoneFamilyMember> familyMembers) {
    final isAllSelected = _selectedFamilyMemberId == null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // "All Family" pill
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedFamilyMemberId = null);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isAllSelected
                    ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
                    : (widget.isDark ? const Color(0xFF151926) : Colors.white),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("👨‍👩‍👧", style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    "All Family",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAllSelected
                          ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                          : MoneTheme.textPrimary(widget.isDark),
                    ),
                  ),
                  if (isAllSelected) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: MoneTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Individual Family Members
          ...familyMembers.map((member) {
            final isSelected = _selectedFamilyMemberId == member.id;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFamilyMemberId = member.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
                      : (widget.isDark ? const Color(0xFF151926) : Colors.white),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(member.avatarEmoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                            : MoneTheme.textPrimary(widget.isDark),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.25) : member.accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member.role,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? (widget.isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white)
                              : member.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Manage Family Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onOpenManageFamily();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MoneTheme.badgeBlueBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 14, color: MoneTheme.primaryBlue),
                  SizedBox(width: 4),
                  Text(
                    "Manage",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: MoneTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 6. Dual KPI Cards (Balance & Save)
  Widget _buildDualKpiCards({
    required MoneFamilyMember? selectedMember,
    required double totalBal,
    required double netFlow,
    required int linkedAccountsCount,
    required bool hasBudget,
    required bool hasAllowance,
    required bool isOverBudget,
    required int pctLeft,
    required double unspent,
    required double monthlySpent,
    required double budgetTarget,
    required double dailySafeSpend,
    required int daysLeft,
  }) {
    return Row(
      children: [
        // Balance Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: netFlow >= 0 ? MoneTheme.badgeGreenBg : MoneTheme.badgeRedBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            netFlow >= 0 ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                            size: 9,
                            color: netFlow >= 0 ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            netFlow == 0 ? "₹0 Net" : (netFlow > 0 ? "+₹${netFlow.toStringAsFixed(0)}" : "-₹${netFlow.abs().toStringAsFixed(0)}"),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: netFlow >= 0 ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selectedMember != null) Text(selectedMember.avatarEmoji, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  selectedMember != null ? "${selectedMember.name}'s Balance" : "Total Balance",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "₹${totalBal.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: MoneTheme.textPrimary(widget.isDark),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$linkedAccountsCount linked accounts",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: MoneTheme.textMuted(widget.isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Remaining Budget / Allowance Card
        Expanded(
          child: GestureDetector(
            onTap: widget.onOpenSetBudget,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasBudget
                              ? (isOverBudget ? MoneTheme.badgeRedBg : MoneTheme.badgeGreenBg)
                              : MoneTheme.badgeBlueBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasBudget
                                  ? (isOverBudget ? Icons.warning_amber_rounded : Icons.check_circle_rounded)
                                  : Icons.circle,
                              size: 9,
                              color: hasBudget
                                  ? (isOverBudget ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText)
                                  : MoneTheme.primaryBlue,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              hasBudget
                                  ? (isOverBudget ? (hasAllowance ? "Allowance Over" : "Over Budget") : "$pctLeft% Left")
                                  : "No Budget Set",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: hasBudget
                                    ? (isOverBudget ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText)
                                    : MoneTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasAllowance
                        ? (isOverBudget ? "Allowance Exceeded" : "Remaining Allowance")
                        : (hasBudget ? (isOverBudget ? "Budget Exceeded" : "Remaining Budget") : "Monthly Budget"),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: MoneTheme.textSecondary(widget.isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hasBudget ? "₹${(isOverBudget ? (monthlySpent - budgetTarget) : unspent).toStringAsFixed(2)}" : "₹0.00",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isOverBudget ? MoneTheme.badgeRedText : MoneTheme.textPrimary(widget.isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasBudget
                        ? (isOverBudget
                            ? "₹${monthlySpent.round()} spent of ₹${budgetTarget.round()}"
                            : "Safe: ₹${dailySafeSpend.round()}/day (${daysLeft}d left)")
                        : "Tap to set in Settings",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: MoneTheme.textMuted(widget.isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - 7. Action Bar: Solid Black "+ Add money" + 3 Action Buttons
  Widget _buildQuickActionBar() {
    return Row(
      children: [
        // Solid Pill "+ Add money"
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onAddTransaction(memberId: _selectedFamilyMemberId);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white : MoneTheme.deepBlack,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isDark ? Colors.white : MoneTheme.deepBlack).withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Add money",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 3 Square Action Buttons (Cards, Analytics, All Transactions)
        _buildActionSquareButton(
          icon: Icons.credit_card_rounded,
          onTap: () => widget.onNavigateTab(2),
        ),
        const SizedBox(width: 8),
        _buildActionSquareButton(
          icon: Icons.bar_chart_rounded,
          onTap: () => widget.onNavigateTab(1),
        ),
        const SizedBox(width: 8),
        _buildActionSquareButton(
          icon: Icons.receipt_long_rounded,
          onTap: widget.onOpenAllTransactions,
        ),
      ],
    );
  }

  Widget _buildActionSquareButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: MoneTheme.cardBg(widget.isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MoneTheme.cardBorder(widget.isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: MoneTheme.textPrimary(widget.isDark), size: 18),
      ),
    );
  }

  // MARK: - 8. 2x2 Feature Grid
  Widget _buildFeatureGrid({
    required double totalMonthlyBudget,
    required double netFlow,
    required int accountsCount,
    required double todaySpent,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        // 1. Optimize Budget
        _buildGridTile(
          icon: Icons.pie_chart_rounded,
          title: "Optimize\nBudget",
          subtitle: totalMonthlyBudget > 0 ? "₹${totalMonthlyBudget.toInt()} Limit" : "No Limit Set",
          subtitleColor: totalMonthlyBudget > 0 ? MoneTheme.badgeGreenText : MoneTheme.textSecondary(widget.isDark),
          onTap: () => widget.onNavigateTab(1),
        ),

        // 2. Net Cashflow
        _buildGridTile(
          icon: Icons.currency_rupee_rounded,
          title: "Net\nCashflow",
          subtitle: netFlow == 0 ? "₹0 Net" : (netFlow > 0 ? "+₹${netFlow.toInt()}" : "-₹${netFlow.abs().toInt()}"),
          subtitleColor: netFlow >= 0 ? MoneTheme.badgeGreenText : MoneTheme.badgeRedText,
          onTap: () => widget.onNavigateTab(1),
        ),

        // 3. Linked Accounts
        _buildGridTile(
          icon: Icons.account_balance_rounded,
          title: "Linked\nAccounts",
          subtitle: "$accountsCount Banks Active",
          subtitleColor: MoneTheme.badgeBlueText,
          onTap: () => widget.onNavigateTab(2),
        ),

        // 4. Expense Velocity
        _buildGridTile(
          icon: Icons.show_chart_rounded,
          title: "Expense\nVelocity",
          subtitle: todaySpent > 0 ? "₹${todaySpent.toInt()} Today" : "₹0 Spent Today",
          subtitleColor: todaySpent > 0 ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText,
          onTap: () => widget.onNavigateTab(1),
        ),
      ],
    );
  }

  Widget _buildGridTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1D2433) : const Color(0xFFF3F6FA),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: MoneTheme.textPrimary(widget.isDark), size: 16),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textPrimary(widget.isDark),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 9. Recent Activity Section
  Widget _buildRecentActivitySection({
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> accounts,
    required List<MoneFamilyMember> familyMembers,
  }) {
    final accountMap = {for (var a in accounts) a['id'] as int: a};
    final memberMap = {for (var m in familyMembers) m.id: m};

    final baseList = transactions.where((tx) {
      if (_selectedFamilyMemberId == null) return true;
      return tx['member_id'] == _selectedFamilyMemberId ||
          (tx['account_id'] != null && accountMap[tx['account_id']]?['member_id'] == _selectedFamilyMemberId);
    }).toList();

    final filteredTxs = baseList.where((tx) {
      if (_selectedFilter == 'EXPENSE') return tx['type'] == 'EXPENSE';
      if (_selectedFilter == 'INCOME') return tx['type'] == 'INCOME';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Activity",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MoneTheme.textPrimary(widget.isDark),
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onOpenAllTransactions();
              },
              child: const Text(
                "See all",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: MoneTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Segmented Control (All / Expense / Income)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF161A24) : const Color(0xFFE5EDF4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _buildFilterTab('ALL', 'All', Icons.grid_view_rounded),
              _buildFilterTab('EXPENSE', 'Expense', Icons.arrow_outward_rounded),
              _buildFilterTab('INCOME', 'Income', Icons.call_received_rounded),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (filteredTxs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 36, color: MoneTheme.textMuted(widget.isDark)),
                const SizedBox(height: 10),
                Text(
                  "No transactions logged yet",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: filteredTxs.take(10).map((tx) {
              return _buildTransactionRow(tx, accountMap, memberMap);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFilterTab(String id, String title, IconData icon) {
    final isSelected = _selectedFilter == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                    : MoneTheme.textSecondary(widget.isDark),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                      : MoneTheme.textSecondary(widget.isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionRow(
    Map<String, dynamic> tx,
    Map<int, Map<String, dynamic>> accountMap,
    Map<int?, MoneFamilyMember> memberMap,
  ) {
    final isExpense = tx['type'] == 'EXPENSE';
    final isTransfer = tx['type'] == 'TRANSFER_IN' || tx['type'] == 'TRANSFER_OUT';
    final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final category = (tx['category'] as String?) ?? 'Other';
    final merchant = (tx['merchant'] as String?) ?? category;

    // Date
    String dateStr = '';
    if (tx['date'] != null) {
      try {
        final d = DateTime.parse(tx['date'].toString());
        dateStr = '${d.day}/${d.month}';
      } catch (_) {}
    }

    // Account & Bank
    final acc = tx['account_id'] != null ? accountMap[tx['account_id']] : null;
    final bankInfo = acc != null
        ? IndianBankDirectory.findBankByName((acc['bank_code'] ?? acc['bank_name'] ?? (acc['type'] == 'CASH' ? 'cash' : '')).toString())
        : null;

    // Family Member
    final memberId = tx['member_id'] ?? acc?['member_id'];
    final member = memberMap[memberId];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onAddTransaction(existingTx: tx, memberId: memberId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 18),
        child: Row(
          children: [
            // Category Icon with overlapping bank badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isExpense
                        ? const Color(0xFFEF4444).withValues(alpha: 0.14)
                        : (isTransfer
                            ? const Color(0xFF0284C7).withValues(alpha: 0.14)
                            : const Color(0xFF10B981).withValues(alpha: 0.14)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpense
                        ? Icons.shopping_bag_outlined
                        : (isTransfer ? Icons.swap_horiz_rounded : Icons.account_balance_wallet_outlined),
                    size: 20,
                    color: isExpense
                        ? const Color(0xFFEF4444)
                        : (isTransfer ? const Color(0xFF0284C7) : const Color(0xFF10B981)),
                  ),
                ),
                if (bankInfo != null)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: bankInfo.buildBadge(size: 16, showBorder: true),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Merchant & details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: MoneTheme.textPrimary(widget.isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        category,
                        style: TextStyle(fontSize: 11, color: MoneTheme.textSecondary(widget.isDark)),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        Text(' • $dateStr', style: TextStyle(fontSize: 11, color: MoneTheme.textSecondary(widget.isDark))),
                      ],
                      if (member != null) ...[
                        Text(
                          ' • ${member.avatarEmoji} ${member.name}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: member.accentColor),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount & account
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpense
                        ? MoneTheme.badgeRedBg
                        : (isTransfer ? MoneTheme.badgeBlueBg : MoneTheme.badgeGreenBg),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    isExpense
                        ? '-₹${amt.toStringAsFixed(2)}'
                        : (isTransfer ? '₹${amt.toStringAsFixed(2)}' : '+₹${amt.toStringAsFixed(2)}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isExpense
                          ? MoneTheme.badgeRedText
                          : (isTransfer ? MoneTheme.badgeBlueText : MoneTheme.badgeGreenText),
                    ),
                  ),
                ),
                if (acc != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    acc['name'].toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: MoneTheme.textSecondary(widget.isDark),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
