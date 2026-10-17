import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../models/family_member.dart';
import '../services/indian_banks.dart';
import '../theme/mone_theme.dart';
import '../widgets/apple_wallet_stack.dart';

// MARK: - Overview Dashboard View with Card Stack Scrollytelling
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
  bool _hideBalance = false;

  // Scrollytelling State
  late final ScrollController _scrollController;
  double _scrollOffset = 0.0;
  AppleWalletCardItem? _activeCard;

  // Cached in-memory database data (prevents re-querying SQLite on every frame)
  bool _isLoading = true;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _settings = [];
  List<MoneFamilyMember> _familyMembers = [];
  Map<int, double> _computedBalances = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.database.query('accounts'),
        widget.database.query('transactions', orderBy: 'date DESC'),
        widget.database.query('settings'),
        widget.database.query('family_members', orderBy: 'id ASC'),
      ]);

      if (!mounted) return;

      final accounts = results[0] as List<Map<String, dynamic>>;
      final transactions = results[1] as List<Map<String, dynamic>>;
      final settings = results[2] as List<Map<String, dynamic>>;
      final familyRaw = results[3] as List<Map<String, dynamic>>;

      Map<int, double> computed = {};
      for (var acc in accounts) {
        int id = acc['id'] as int;
        double initBal = (acc['initial_balance'] as num?)?.toDouble() ??
            (acc['balance'] as num?)?.toDouble() ??
            0.0;
        computed[id] = initBal;
      }
      for (var t in transactions) {
        int? accId = t['account_id'] as int?;
        if (accId != null && computed.containsKey(accId)) {
          double amt = (t['amount'] as num).toDouble();
          if (t['type'] == 'INCOME' || t['type'] == 'TRANSFER_IN') {
            computed[accId] = computed[accId]! + amt;
          } else if (t['type'] == 'EXPENSE' || t['type'] == 'TRANSFER_OUT') {
            computed[accId] = computed[accId]! - amt;
          }
        }
      }

      setState(() {
        _accounts = accounts;
        _transactions = transactions;
        _settings = settings;
        _familyMembers = familyRaw.map((m) => MoneFamilyMember.fromMap(m)).toList();
        _computedBalances = computed;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    await widget.onRefreshRequested();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: MoneTheme.primaryBlue),
      );
    }

    // Total Monthly Budget from settings
    double totalMonthlyBudget = 0.0;
    for (var s in _settings) {
      if (s['key'] == 'total_budget') {
        totalMonthlyBudget = (s['value'] as num?)?.toDouble() ?? 0.0;
      }
    }

    // Selected family member
    final selectedMember = _selectedFamilyMemberId != null
        ? _familyMembers.firstWhere(
            (m) => m.id == _selectedFamilyMemberId,
            orElse: () => _familyMembers.first,
          )
        : null;

    // Filtered accounts
    final filteredAccounts = _accounts.where((acc) {
      if (_selectedFamilyMemberId == null) return true;
      return acc['member_id'] == _selectedFamilyMemberId;
    }).toList();

    List<AppleWalletCardItem> appleWalletCards = [];
    for (var acc in filteredAccounts) {
      double bal = _computedBalances[acc['id'] as int] ?? 0.0;
      var copy = Map<String, dynamic>.from(acc);
      copy['balance'] = bal;
      appleWalletCards.add(AppleWalletCardItem.fromMap(copy));
    }

    // Keep active card updated
    if (appleWalletCards.isNotEmpty) {
      _activeCard ??= appleWalletCards.first;
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
        totalBal += _computedBalances[a['id'] as int] ?? 0.0;
      }
    }

    for (var tx in _transactions) {
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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _handleRefresh,
          color: MoneTheme.primaryBlue,
          backgroundColor: MoneTheme.cardBg(widget.isDark),
          displacement: 40,
          strokeWidth: 2.5,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Avatar + Privacy Toggle + Menu Drawer)
                _buildHeaderRow(),
                const SizedBox(height: 16),

                // 2. Greeting Headline
                Text(
                  'Hi, ${widget.userName.isNotEmpty ? widget.userName : "there"}!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Family Switcher Capsule Strip
                _buildFamilySwitcherSection(_familyMembers),
                const SizedBox(height: 16),

                // 4. Hero Card Stack Carousel (Interactive 3D Deck)
                AppleWalletCardsSection(
                  accounts: appleWalletCards,
                  isDark: widget.isDark,
                  onCardTap: (card) {
                    setState(() => _activeCard = card);
                    widget.onOpenManageAccounts();
                  },
                  onAddAccount: widget.onOpenManageAccounts,
                  onCardSelected: (card) {
                    setState(() => _activeCard = card);
                  },
                ),
                const SizedBox(height: 18),

                // 5. Scrollytelling Chapter 1: The Safe-to-Spend Burn Story
                _buildBurnRateStory(
                  hasBudget: hasBudget,
                  budgetTarget: budgetTarget,
                  monthlySpent: monthlySpent,
                  dailySafeSpend: dailySafeSpend,
                  daysLeft: daysLeft,
                  pctLeft: pctLeft,
                  isOverBudget: isOverBudget,
                ),
                const SizedBox(height: 16),

                // 6. Scrollytelling Chapter 2: Financial Cockpit & Totals
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

                // 7. Scrollytelling Chapter 3: Quick Action Dock
                _buildQuickActionBar(),
                const SizedBox(height: 20),

                // 8. Scrollytelling Chapter 4: 2x2 Feature Cockpit
                _buildFeatureGrid(
                  totalMonthlyBudget: totalMonthlyBudget,
                  netFlow: netFlow,
                  accountsCount: _accounts.length,
                  todaySpent: todaySpent,
                ),
                const SizedBox(height: 22),

                // 9. Scrollytelling Chapter 5: Activity Narrative & Brand Timelines
                _buildRecentTransactionsSection(
                  transactions: _transactions,
                  accounts: _accounts,
                  familyMembers: _familyMembers,
                ),
              ],
            ),
          ),
        ),

        // Scrollytelling Floating Docked Card Capsule
        _buildDockedCardBar(_activeCard),
      ],
    );
  }

  // MARK: - Scrollytelling Floating Docked Card Bar
  Widget _buildDockedCardBar(AppleWalletCardItem? activeCard) {
    if (_scrollOffset < 220 || activeCard == null) return const SizedBox.shrink();

    final opacity = ((_scrollOffset - 220) / 60.0).clamp(0.0, 1.0);

    return Positioned(
      top: 10,
      left: 20,
      right: 20,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF141824).withValues(alpha: 0.94) : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.45 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              activeCard.bankInfo.buildBadge(size: 28, showBorder: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activeCard.bankInfo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MoneTheme.textPrimary(widget.isDark),
                      ),
                    ),
                    Text(
                      activeCard.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: MoneTheme.textSecondary(widget.isDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _hideBalance ? "••••••" : "₹${activeCard.balance.toStringAsFixed(0)}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: MoneTheme.textPrimary(widget.isDark),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onAddTransaction(memberId: _selectedFamilyMemberId);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: MoneTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - Scrollytelling Chapter 1: The Safe-to-Spend Burn Story
  Widget _buildBurnRateStory({
    required bool hasBudget,
    required double budgetTarget,
    required double monthlySpent,
    required double dailySafeSpend,
    required int daysLeft,
    required int pctLeft,
    required bool isOverBudget,
  }) {
    final statusColor = isOverBudget
        ? MoneTheme.badgeRedText
        : (pctLeft < 25 ? const Color(0xFFF59E0B) : MoneTheme.badgeGreenText);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_fire_department_rounded, size: 16, color: statusColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "BURN VELOCITY & SAFE SPEND",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: MoneTheme.textSecondary(widget.isDark),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOverBudget ? "OVER LIMIT" : "$pctLeft% SAFE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasBudget
                ? (isOverBudget
                    ? "Exceeded budget by ₹${(monthlySpent - budgetTarget).toStringAsFixed(0)}"
                    : "Safe: ₹${dailySafeSpend.round()}/day")
                : "No Monthly Budget Set",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isOverBudget ? MoneTheme.badgeRedText : MoneTheme.textPrimary(widget.isDark),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasBudget
                ? "$daysLeft days left in this month • ₹${monthlySpent.round()} spent of ₹${budgetTarget.round()}"
                : "Set a spending limit to activate daily burn rate guidance",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: MoneTheme.textSecondary(widget.isDark),
            ),
          ),
          const SizedBox(height: 12),
          // Gradient Burn Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 6,
              width: double.infinity,
              color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: hasBudget ? (monthlySpent / budgetTarget).clamp(0.0, 1.0) : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOverBudget
                          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                          : (pctLeft < 25
                              ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                              : [const Color(0xFF10B981), MoneTheme.primaryBlue]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - 1. Top Header Row
  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Avatar + User Details
        GestureDetector(
          onTap: widget.onProfileTap,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MoneTheme.primaryBlue,
                  boxShadow: [
                    BoxShadow(
                      color: MoneTheme.primaryBlue.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.profilePhotoFile != null && widget.profilePhotoFile!.existsSync()
                      ? Image.file(widget.profilePhotoFile!, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'M',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName.isNotEmpty ? widget.userName : 'My Space',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MoneTheme.textPrimary(widget.isDark),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "mone Active",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: MoneTheme.textSecondary(widget.isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Action icons: Privacy Eye, Theme Toggle, Menu Drawer
        Row(
          children: [
            // Hide/Show Balance Toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _hideBalance = !_hideBalance);
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
                  _hideBalance ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18,
                  color: MoneTheme.textPrimary(widget.isDark),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Theme Toggle Button
            GestureDetector(
              onTap: widget.onToggleTheme,
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
                  widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 18,
                  color: MoneTheme.textPrimary(widget.isDark),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Menu Drawer Button
            GestureDetector(
              onTap: widget.onOpenMenu,
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
                  selectedMember != null ? "${selectedMember.name}'s Net Worth" : "Total Net Worth",
                  style: TextStyle(
                    fontSize: 12,
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
                    _hideBalance ? "••••••" : "₹${totalBal.toStringAsFixed(2)}",
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOverBudget ? MoneTheme.badgeRedBg : MoneTheme.badgeGreenBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOverBudget ? "Over Budget" : "$pctLeft% Left",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isOverBudget ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText,
                          ),
                        ),
                      ),
                      Icon(Icons.tune_rounded, size: 14, color: MoneTheme.textMuted(widget.isDark)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasAllowance ? "Monthly Allowance" : "Remaining Budget",
                    style: TextStyle(
                      fontSize: 12,
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
                      _hideBalance
                          ? "••••••"
                          : (hasBudget ? "₹${(isOverBudget ? (monthlySpent - budgetTarget) : unspent).toStringAsFixed(2)}" : "₹0.00"),
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
                        : "Tap to set limit",
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
                    color: widget.isDark ? MoneTheme.deepBlack : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Add money",
                    style: TextStyle(
                      color: widget.isDark ? MoneTheme.deepBlack : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Action 1: Instant Sync
        _buildCircleActionButton(
          icon: Icons.sync_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            _handleRefresh();
          },
        ),
        const SizedBox(width: 8),

        // Action 2: Manage Family
        _buildCircleActionButton(
          icon: Icons.group_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onOpenManageFamily();
          },
        ),
        const SizedBox(width: 8),

        // Action 3: Analytics
        _buildCircleActionButton(
          icon: Icons.analytics_rounded,
          onTap: () => widget.onNavigateTab(1),
        ),
      ],
    );
  }

  Widget _buildCircleActionButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
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
      childAspectRatio: 1.25,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  // MARK: - 9. Recent Transactions Section
  Widget _buildRecentTransactionsSection({
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> accounts,
    required List<MoneFamilyMember> familyMembers,
  }) {
    final memberAccIds = accounts.map((a) => a['id'] as int).toSet();

    final filtered = transactions.where((t) {
      if (_selectedFamilyMemberId != null) {
        bool match = t['member_id'] == _selectedFamilyMemberId ||
            (t['account_id'] != null && memberAccIds.contains(t['account_id']));
        if (!match) return false;
      }
      if (_selectedFilter == 'EXPENSE') return t['type'] == 'EXPENSE' || t['type'] == 'TRANSFER_OUT';
      if (_selectedFilter == 'INCOME') return t['type'] == 'INCOME' || t['type'] == 'TRANSFER_IN';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent activity",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: MoneTheme.textPrimary(widget.isDark),
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: widget.onOpenAllTransactions,
              child: Text(
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

        // Filter Pills: All / Expenses / Income
        Row(
          children: [
            _buildFilterPill("ALL", "All"),
            const SizedBox(width: 8),
            _buildFilterPill("EXPENSE", "Expenses"),
            const SizedBox(width: 8),
            _buildFilterPill("INCOME", "Income"),
          ],
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 36, color: MoneTheme.textMuted(widget.isDark)),
                  const SizedBox(height: 8),
                  Text(
                    "No transactions recorded yet",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MoneTheme.textSecondary(widget.isDark),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.take(8).length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
              itemBuilder: (context, index) {
                final tx = filtered[index];
                return _buildTransactionRow(tx, accounts, familyMembers);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterPill(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = filterKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
              : (widget.isDark ? const Color(0xFF1B212D) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                : MoneTheme.textSecondary(widget.isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionRow(
    Map<String, dynamic> tx,
    List<Map<String, dynamic>> accounts,
    List<MoneFamilyMember> familyMembers,
  ) {
    final merchant = tx['merchant']?.toString() ?? 'Transaction';
    final category = tx['category']?.toString() ?? 'Other';
    final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final isExpense = tx['type'] == 'EXPENSE' || tx['type'] == 'TRANSFER_OUT';
    final isTransfer = tx['type'] == 'TRANSFER_IN' || tx['type'] == 'TRANSFER_OUT';

    // Bank resolution
    Map<String, dynamic>? acc;
    if (tx['account_id'] != null) {
      acc = accounts.firstWhere((a) => a['id'] == tx['account_id'], orElse: () => {});
    }

    final bankInfo = (acc != null && acc.isNotEmpty)
        ? IndianBankDirectory.findBankByName((acc['bank_code'] ?? acc['bank_name'] ?? (acc['type'] == 'CASH' ? 'cash' : '')).toString())
        : null;

    // Member resolution
    MoneFamilyMember? member;
    if (tx['member_id'] != null) {
      member = familyMembers.firstWhere((m) => m.id == tx['member_id'], orElse: () => familyMembers.first);
    }

    String dateStr = '';
    if (tx['date'] != null) {
      try {
        final d = DateTime.parse(tx['date'].toString());
        dateStr = "${d.day} ${_monthName(d.month)}";
      } catch (_) {}
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onAddTransaction(existingTx: tx);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Category Icon with Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isExpense
                        ? MoneTheme.badgeRedBg
                        : (isTransfer ? MoneTheme.badgeBlueBg : MoneTheme.badgeGreenBg),
                    borderRadius: BorderRadius.circular(14),
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
                  Text.rich(
                    TextSpan(
                      text: category,
                      style: TextStyle(fontSize: 11, color: MoneTheme.textSecondary(widget.isDark)),
                      children: [
                        if (dateStr.isNotEmpty)
                          TextSpan(
                            text: ' • $dateStr',
                            style: TextStyle(fontSize: 11, color: MoneTheme.textSecondary(widget.isDark)),
                          ),
                        if (member != null)
                          TextSpan(
                            text: ' • ${member.avatarEmoji} ${member.name}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: member.accentColor),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                if (acc != null && acc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      acc['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: MoneTheme.textSecondary(widget.isDark),
                      ),
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

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }
}
