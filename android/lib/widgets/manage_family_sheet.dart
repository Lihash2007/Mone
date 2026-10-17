import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../models/family_member.dart';
import '../theme/mone_theme.dart';

// MARK: - Manage Family Sheet (1:1 with iOS ManageFamilySheet)
class ManageFamilySheet extends StatefulWidget {
  final Database database;
  final bool isDark;
  final VoidCallback onFamilyChanged;

  const ManageFamilySheet({
    super.key,
    required this.database,
    required this.isDark,
    required this.onFamilyChanged,
  });

  @override
  State<ManageFamilySheet> createState() => _ManageFamilySheetState();
}

class _ManageFamilySheetState extends State<ManageFamilySheet> {
  List<MoneFamilyMember> _members = [];
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final famRaw = await widget.database.query('family_members', orderBy: 'id ASC');
    final accRaw = await widget.database.query('accounts');
    final txRaw = await widget.database.query('transactions');

    if (mounted) {
      setState(() {
        _members = famRaw.map((m) => MoneFamilyMember.fromMap(m)).toList();
        _accounts = accRaw;
        _transactions = txRaw;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMember(MoneFamilyMember member) async {
    if (member.id == null) return;
    await widget.database.delete('family_members', where: 'id = ?', whereArgs: [member.id]);
    await widget.database.execute('UPDATE accounts SET member_id = NULL WHERE member_id = ?', [member.id]);
    await widget.database.execute('UPDATE transactions SET member_id = NULL WHERE member_id = ?', [member.id]);
    widget.onFamilyChanged();
    await _loadData();
  }

  void _openEditMemberModal([MoneFamilyMember? member]) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditFamilyMemberModal(
        database: widget.database,
        isDark: widget.isDark,
        member: member,
        onSaved: () {
          widget.onFamilyChanged();
          _loadData();
        },
      ),
    );
  }

  void _confirmDelete(MoneFamilyMember member) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MoneTheme.cardBg(widget.isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete Family Member?',
          style: TextStyle(
            color: MoneTheme.textPrimary(widget.isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Their accounts and transactions will be unassigned but preserved in your app.',
          style: TextStyle(
            color: MoneTheme.textSecondary(widget.isDark),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: MoneTheme.textSecondary(widget.isDark))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMember(member);
            },
            child: const Text('Delete', style: TextStyle(color: MoneTheme.badgeRedText, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          color: MoneTheme.cardBg(widget.isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(child: CircularProgressIndicator(color: MoneTheme.primaryBlue)),
      );
    }

    double totalBalance = 0.0;
    for (var a in _accounts) {
      totalBalance += (a['balance'] as num?)?.toDouble() ?? 0.0;
    }

    double totalAllowance = 0.0;
    for (var m in _members) {
      totalAllowance += m.monthlyAllowance;
    }

    return Container(
      decoration: BoxDecoration(
        color: MoneTheme.bgCanvas(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Sheet Grabber
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family & Household',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: MoneTheme.textPrimary(widget.isDark),
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'Multi-member accounts & monthly allowances',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: MoneTheme.textSecondary(widget.isDark),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white : MoneTheme.deepBlack,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06), height: 1),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Household Overview Card
                    _buildHouseholdSummaryCard(totalBalance, totalAllowance),
                    const SizedBox(height: 20),

                    // Section Title + Add Member Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Family Members (${_members.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: MoneTheme.textPrimary(widget.isDark),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openEditMemberModal(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: widget.isDark ? Colors.white : MoneTheme.deepBlack,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 13,
                                  color: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Member',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Members List
                    ..._members.map((member) => _buildMemberRow(member)),

                    const SizedBox(height: 16),

                    // Information Banner
                    _buildInfoBanner(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdSummaryCard(double totalBalance, double totalAllowance) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MoneTheme.primaryBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded, color: MoneTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Household Hub',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MoneTheme.textPrimary(widget.isDark),
                    ),
                  ),
                  Text(
                    '${_members.length} Active Members • Option A Local',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: MoneTheme.textSecondary(widget.isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Family Balance',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: MoneTheme.textSecondary(widget.isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${totalBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: MoneTheme.textPrimary(widget.isDark),
                    ),
                  ),
                ],
              ),
              if (totalAllowance > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Monthly Allowances',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: MoneTheme.textSecondary(widget.isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${totalAllowance.toStringAsFixed(0)}/mo',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: MoneTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(MoneFamilyMember member) {
    final memberAccounts = _accounts.where((a) => a['member_id'] == member.id).toList();
    double memberBalance = 0.0;
    for (var a in memberAccounts) {
      memberBalance += (a['balance'] as num?)?.toDouble() ?? 0.0;
    }

    // Monthly spent for this member
    final now = DateTime.now();
    double memberMonthSpent = 0.0;
    final memberAccIds = memberAccounts.map((a) => a['id'] as int).toSet();

    for (var tx in _transactions) {
      if (tx['date'] == null) continue;
      try {
        final d = DateTime.parse(tx['date'].toString());
        if (d.month == now.month && d.year == now.year && tx['type'] == 'EXPENSE') {
          if (tx['member_id'] == member.id || (tx['account_id'] != null && memberAccIds.contains(tx['account_id']))) {
            memberMonthSpent += (tx['amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: member.accentColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: member.accentColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    member.avatarEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: MoneTheme.textPrimary(widget.isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: member.accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            member.role,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: member.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${memberAccounts.length} Linked Cards • ₹${memberBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MoneTheme.textSecondary(widget.isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, size: 16, color: MoneTheme.textPrimary(widget.isDark)),
                    style: IconButton.styleFrom(
                      backgroundColor: widget.isDark ? const Color(0xFF1F2737) : const Color(0xFFF3F6FA),
                      padding: const EdgeInsets.all(8),
                    ),
                    onPressed: () => _openEditMemberModal(member),
                  ),
                  if (_members.length > 1) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: MoneTheme.badgeRedText),
                      style: IconButton.styleFrom(
                        backgroundColor: MoneTheme.badgeRedBg,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => _confirmDelete(member),
                    ),
                  ],
                ],
              ),
            ],
          ),

          if (member.monthlyAllowance > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Allowance',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                ),
                Text(
                  '₹${memberMonthSpent.toStringAsFixed(0)} / ₹${member.monthlyAllowance.toStringAsFixed(0)} (${(member.monthlyAllowance - memberMonthSpent).clamp(0, double.infinity).toStringAsFixed(0)} left)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: memberMonthSpent > member.monthlyAllowance ? MoneTheme.badgeRedText : MoneTheme.badgeGreenText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (memberMonthSpent / member.monthlyAllowance).clamp(0.0, 1.0),
                backgroundColor: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  memberMonthSpent > member.monthlyAllowance ? MoneTheme.badgeRedText : member.accentColor,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoneTheme.badgeBlueBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: MoneTheme.primaryBlue, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Option A: Household Multi-Member Architecture',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.deepBlack,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'All family accounts, allowances, and transactions are stored 100% locally on device in SQLite with zero cloud dependencies and zero subscription fees.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: MoneTheme.primaryBlue,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// MARK: - Edit / Add Family Member Modal (1:1 with iOS EditFamilyMemberModal)
class EditFamilyMemberModal extends StatefulWidget {
  final Database database;
  final bool isDark;
  final MoneFamilyMember? member;
  final VoidCallback onSaved;

  const EditFamilyMemberModal({
    super.key,
    required this.database,
    required this.isDark,
    this.member,
    required this.onSaved,
  });

  @override
  State<EditFamilyMemberModal> createState() => _EditFamilyMemberModalState();
}

class _EditFamilyMemberModalState extends State<EditFamilyMemberModal> {
  late TextEditingController _nameCtrl;
  late TextEditingController _allowanceCtrl;
  late String _role;
  late String _avatarEmoji;
  late String _colorHex;

  final List<String> _rolePresets = const ["Primary", "Spouse", "Child", "Parent", "Sibling", "Other"];
  final List<String> _emojiPresets = const ["👤", "👩", "👨", "👧", "👦", "👵", "👴", "🐱", "🐶", "💼", "🎓", "👑", "⭐", "🚀"];
  final List<String> _colorPresets = const [
    "0284C7", // Sky Blue
    "10B981", // Emerald
    "6366F1", // Indigo
    "EC4899", // Rose Pink
    "F59E0B", // Amber Gold
    "8B5CF6", // Purple
    "14B8A6", // Teal
    "EF4444", // Coral Red
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.member?.name ?? '');
    _allowanceCtrl = TextEditingController(
      text: (widget.member != null && widget.member!.monthlyAllowance > 0)
          ? widget.member!.monthlyAllowance.toStringAsFixed(0)
          : '',
    );
    _role = widget.member?.role ?? 'Spouse';
    _avatarEmoji = widget.member?.avatarEmoji ?? '👩';
    _colorHex = widget.member?.colorHex ?? '0284C7';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _allowanceCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return MoneTheme.primaryBlue;
    }
  }

  Future<void> _save() async {
    final cleanName = _nameCtrl.text.trim();
    if (cleanName.isEmpty) return;
    final allowance = double.tryParse(_allowanceCtrl.text.trim()) ?? 0.0;

    if (widget.member != null) {
      final updated = widget.member!.copyWith(
        name: cleanName,
        role: _role,
        avatarEmoji: _avatarEmoji,
        colorHex: _colorHex,
        monthlyAllowance: allowance,
      );
      await widget.database.update('family_members', updated.toMap(), where: 'id = ?', whereArgs: [updated.id]);
    } else {
      final newMember = MoneFamilyMember(
        name: cleanName,
        role: _role,
        avatarEmoji: _avatarEmoji,
        colorHex: _colorHex,
        monthlyAllowance: allowance,
      );
      await widget.database.insert('family_members', newMember.toMap());
    }

    HapticFeedback.lightImpact();
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _parseColor(_colorHex);

    return Container(
      decoration: BoxDecoration(
        color: MoneTheme.bgCanvas(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Nav Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: MoneTheme.textSecondary(widget.isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  widget.member == null ? 'New Member' : 'Edit Member',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textPrimary(widget.isDark),
                  ),
                ),
                GestureDetector(
                  onTap: _save,
                  child: Text(
                    'Save',
                    style: const TextStyle(
                      color: MoneTheme.primaryBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Avatar Preview
            Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: selectedColor, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: selectedColor.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(_avatarEmoji, style: const TextStyle(fontSize: 38)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nameCtrl.text.isEmpty ? 'Member Name' : _nameCtrl.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MoneTheme.textPrimary(widget.isDark),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _role,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: selectedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name Input
            Text(
              'Member Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MoneTheme.textSecondary(widget.isDark),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                color: MoneTheme.textPrimary(widget.isDark),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Sarah, Dad, Emma',
                hintStyle: TextStyle(color: MoneTheme.textMuted(widget.isDark)),
                filled: true,
                fillColor: MoneTheme.cardBg(widget.isDark),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: MoneTheme.cardBorder(widget.isDark)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: MoneTheme.cardBorder(widget.isDark)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: MoneTheme.primaryBlue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Role Picker Strip
            Text(
              'Household Role',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MoneTheme.textSecondary(widget.isDark),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _rolePresets.map((r) {
                  final isSelected = _role == r;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _role = r;
                        if (widget.member == null) {
                          if (r == "Spouse") {
                            _avatarEmoji = "👩";
                          } else if (r == "Child") {
                            _avatarEmoji = "👧";
                          } else if (r == "Parent") {
                            _avatarEmoji = "👵";
                          }
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
                            : MoneTheme.cardBg(widget.isDark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : MoneTheme.cardBorder(widget.isDark),
                        ),
                      ),
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                              : MoneTheme.textPrimary(widget.isDark),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Avatar Emoji Presets
            Text(
              'Avatar Icon',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MoneTheme.textSecondary(widget.isDark),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _emojiPresets.map((em) {
                  final isSelected = _avatarEmoji == em;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _avatarEmoji = em);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? selectedColor.withValues(alpha: 0.2) : MoneTheme.cardBg(widget.isDark),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? selectedColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(em, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Color Swatch Picker
            Text(
              'Theme Color',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MoneTheme.textSecondary(widget.isDark),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _colorPresets.map((c) {
                final isSelected = _colorHex == c;
                final clr = _parseColor(c);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _colorHex = c);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: clr,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: clr.withValues(alpha: isSelected ? 0.4 : 0.1),
                          blurRadius: isSelected ? 6 : 2,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Monthly Allowance Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Allowance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                ),
                Text(
                  'Optional • 0 for none',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: MoneTheme.textMuted(widget.isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _allowanceCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: MoneTheme.textPrimary(widget.isDark),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                  color: MoneTheme.textPrimary(widget.isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                hintText: 'e.g. 10000',
                hintStyle: TextStyle(color: MoneTheme.textMuted(widget.isDark)),
                filled: true,
                fillColor: MoneTheme.cardBg(widget.isDark),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: MoneTheme.cardBorder(widget.isDark)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: MoneTheme.cardBorder(widget.isDark)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: MoneTheme.primaryBlue, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDark ? Colors.white : MoneTheme.deepBlack,
                  foregroundColor: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(
                  widget.member == null ? 'Add Family Member' : 'Save Changes',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
