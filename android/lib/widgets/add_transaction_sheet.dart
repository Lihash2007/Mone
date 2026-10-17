import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../models/family_member.dart';
import '../services/indian_banks.dart';
import '../theme/mone_theme.dart';

// MARK: - Add / Quick Log Transaction Sheet (1:1 with iOS AddTransactionSheet)
class AddTransactionSheet extends StatefulWidget {
  final Database database;
  final bool isDark;
  final Map<String, dynamic>? existingTx;
  final VoidCallback onSaved;
  final int? prefillMemberId;

  const AddTransactionSheet({
    super.key,
    required this.database,
    required this.isDark,
    this.existingTx,
    required this.onSaved,
    this.prefillMemberId,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late String _type;
  late TextEditingController _amountCtrl;
  late TextEditingController _merchantCtrl;
  late DateTime _selectedDate;

  String _selectedCategory = 'Food & Dining';
  int? _selectedAccountId;
  int? _targetAccountId; // for transfers
  int? _selectedMemberId;

  List<String> _expenseCats = [];
  List<String> _incomeCats = [];
  List<Map<String, dynamic>> _accounts = [];
  List<MoneFamilyMember> _familyMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _type = widget.existingTx?['type'] ?? 'EXPENSE';
    _amountCtrl = TextEditingController(text: widget.existingTx?['amount']?.toString() ?? '');
    _merchantCtrl = TextEditingController(text: widget.existingTx?['merchant'] ?? '');
    _selectedDate = (widget.existingTx != null && widget.existingTx!['date'] != null)
        ? DateTime.parse(widget.existingTx!['date'])
        : DateTime.now();

    _selectedAccountId = widget.existingTx?['account_id'];
    _selectedMemberId = widget.existingTx?['member_id'] ?? widget.prefillMemberId;

    _loadMetadata();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _merchantCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final catsRaw = await widget.database.query('categories');
    final accountsRaw = await widget.database.query('accounts');
    final famRaw = await widget.database.query('family_members', orderBy: 'id ASC');

    final expCats = catsRaw.where((c) => c['type'] == 'EXPENSE').map((c) => c['name'] as String).toList();
    final incCats = catsRaw.where((c) => c['type'] == 'INCOME').map((c) => c['name'] as String).toList();
    final members = famRaw.map((m) => MoneFamilyMember.fromMap(m)).toList();

    String cat = widget.existingTx?['category'] ?? (expCats.isNotEmpty ? expCats.first : 'Other');

    int? accId = _selectedAccountId;
    if (accId == null && accountsRaw.isNotEmpty) {
      accId = accountsRaw.first['id'] as int;
    }

    int? toAccId;
    if (accountsRaw.length > 1) {
      toAccId = accountsRaw.firstWhere((a) => (a['id'] as int) != accId, orElse: () => accountsRaw.last)['id'] as int;
    }

    if (mounted) {
      setState(() {
        _expenseCats = expCats;
        _incomeCats = incCats;
        _accounts = accountsRaw;
        _familyMembers = members;
        _selectedCategory = cat;
        _selectedAccountId = accId;
        _targetAccountId = toAccId;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveRecord() async {
    final cleanAmount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    if (cleanAmount <= 0) {
      HapticFeedback.heavyImpact();
      return;
    }

    String cleanMerchant = _merchantCtrl.text.trim();
    if (cleanMerchant.isEmpty) {
      cleanMerchant = _type == 'TRANSFER' ? 'Internal Transfer' : _selectedCategory;
    }

    final dateStr = _selectedDate.toIso8601String().substring(0, 19).replaceAll('T', ' ');

    if (_type == 'TRANSFER') {
      // Create transfer debit & credit
      final fromAcc = _selectedAccountId;
      final toAcc = _targetAccountId;
      if (fromAcc == null || toAcc == null || fromAcc == toAcc) {
        return;
      }

      await widget.database.insert('transactions', {
        'merchant': cleanMerchant,
        'category': 'Transfer',
        'amount': cleanAmount,
        'type': 'TRANSFER_OUT',
        'date': dateStr,
        'account_id': fromAcc,
        'member_id': _selectedMemberId,
      });

      await widget.database.insert('transactions', {
        'merchant': cleanMerchant,
        'category': 'Transfer',
        'amount': cleanAmount,
        'type': 'TRANSFER_IN',
        'date': dateStr,
        'account_id': toAcc,
        'member_id': _selectedMemberId,
      });
    } else {
      final values = {
        'merchant': cleanMerchant,
        'category': _selectedCategory,
        'amount': cleanAmount,
        'type': _type,
        'date': dateStr,
        'account_id': _selectedAccountId,
        'member_id': _selectedMemberId,
        'needs_review': 0,
      };

      if (widget.existingTx != null) {
        await widget.database.update('transactions', values, where: 'id = ?', whereArgs: [widget.existingTx!['id']]);
      } else {
        await widget.database.insert('transactions', values);
      }
    }

    HapticFeedback.mediumImpact();
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 380,
        decoration: BoxDecoration(
          color: MoneTheme.cardBg(widget.isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(child: CircularProgressIndicator(color: MoneTheme.primaryBlue)),
      );
    }

    // Selected account info
    final currentAcc = _accounts.firstWhere(
      (a) => a['id'] == _selectedAccountId,
      orElse: () => _accounts.isNotEmpty ? _accounts.first : {'name': 'Default', 'balance': 0.0},
    );
    final accBalance = (currentAcc['balance'] as num?)?.toDouble() ?? 0.0;
    final bankInfo = IndianBankDirectory.findBankByName(
      (currentAcc['bank_code'] ?? currentAcc['bank_name'] ?? (currentAcc['type'] == 'CASH' ? 'cash' : '')).toString(),
    );

    final isExpense = _type == 'EXPENSE';
    final isIncome = _type == 'INCOME';
    final isTransfer = _type == 'TRANSFER';

    return Container(
      decoration: BoxDecoration(
        color: MoneTheme.bgCanvas(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 14,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet Grabber
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top Nav Bar
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
                    widget.existingTx == null ? 'Track Record' : 'Edit Record',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MoneTheme.textPrimary(widget.isDark),
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: _saveRecord,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white : MoneTheme.deepBlack,
                        borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 16),

              // 1. Balance Pill Badge & Date Stamp Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MoneTheme.badgeGreenBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MoneTheme.badgeGreenBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, size: 12, color: MoneTheme.badgeGreenText),
                        const SizedBox(width: 5),
                        Text(
                          'Bal: ₹${accBalance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: MoneTheme.badgeGreenText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1B212D) : const Color(0xFFE2EDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: MoneTheme.textSecondary(widget.isDark)),
                          const SizedBox(width: 5),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: MoneTheme.textPrimary(widget.isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Type Selector: Expense / Income / Transfer
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF161A24) : const Color(0xFFE5EDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _buildTypeButton('Expense', 'EXPENSE', const Color(0xFFEF4444), isExpense),
                    _buildTypeButton('Income', 'INCOME', const Color(0xFF10B981), isIncome),
                    _buildTypeButton('Transfer', 'TRANSFER', const Color(0xFF0284C7), isTransfer),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Amount Display Hero Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 22),
                child: Row(
                  children: [
                    Text(
                      '₹',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isExpense
                            ? const Color(0xFFEF4444)
                            : (isIncome ? const Color(0xFF10B981) : const Color(0xFF0284C7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autofocus: widget.existingTx == null,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: MoneTheme.textPrimary(widget.isDark),
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: MoneTheme.textMuted(widget.isDark),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Merchant / Description Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 18),
                child: TextField(
                  controller: _merchantCtrl,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MoneTheme.textPrimary(widget.isDark),
                  ),
                  decoration: InputDecoration(
                    hintText: isTransfer ? 'Transfer description (optional)' : 'Merchant, store, or note',
                    hintStyle: TextStyle(
                      color: MoneTheme.textMuted(widget.isDark),
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    icon: Icon(Icons.edit_note_rounded, color: MoneTheme.textSecondary(widget.isDark), size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Account Selector (or Transfer Visualizer Flow)
              if (isTransfer) ...[
                _buildTransferAccountRow(),
              ] else ...[
                _buildSingleAccountRow(bankInfo, currentAcc),
              ],
              const SizedBox(height: 14),

              // 6. Family Member Selector Strip
              if (_familyMembers.isNotEmpty) ...[
                Text(
                  'Assign To Family Member',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildMemberPill(null, 'Shared / All', '👨‍👩‍👧'),
                      ..._familyMembers.map((m) => _buildMemberPill(m.id, m.name, m.avatarEmoji, m.accentColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 7. Category Strip (Horizontal 1-row scroll, if not Transfer)
              if (!isTransfer) ...[
                Text(
                  'Select Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textSecondary(widget.isDark),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: (isExpense ? _expenseCats : _incomeCats).map((c) {
                      final isSelected = _selectedCategory == c;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategory = c);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
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
                            c,
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
                const SizedBox(height: 20),
              ],

              // 8. Solid 1-Tap Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDark ? Colors.white : MoneTheme.deepBlack,
                    foregroundColor: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isExpense ? Icons.arrow_downward_rounded : (isIncome ? Icons.arrow_upward_rounded : Icons.swap_horiz_rounded),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isExpense
                            ? 'Record Expense'
                            : (isIncome ? 'Record Income' : 'Confirm Transfer'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String value, Color accent, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _type = value;
            if (_type == 'EXPENSE' && _expenseCats.isNotEmpty) {
              _selectedCategory = _expenseCats.first;
            } else if (_type == 'INCOME' && _incomeCats.isNotEmpty) {
              _selectedCategory = _incomeCats.first;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                  : MoneTheme.textSecondary(widget.isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleAccountRow(BankInfo bankInfo, Map<String, dynamic> currentAcc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 18),
      child: Row(
        children: [
          bankInfo.buildBadge(size: 24, showBorder: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textSecondary(widget.isDark),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${currentAcc['name']}${currentAcc['account_number'] != null && currentAcc['account_number'].toString().isNotEmpty ? " (•• ${currentAcc['account_number']})" : ""}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: MoneTheme.textPrimary(widget.isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          DropdownButton<int>(
            value: _selectedAccountId,
            dropdownColor: MoneTheme.cardBg(widget.isDark),
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down_rounded, color: MoneTheme.textSecondary(widget.isDark)),
            items: _accounts.map((a) {
              final b = IndianBankDirectory.findBankByName((a['bank_code'] ?? a['bank_name'] ?? (a['type'] == 'CASH' ? 'cash' : '')).toString());
              return DropdownMenuItem<int>(
                value: a['id'] as int,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    b.buildBadge(size: 18, showBorder: false),
                    const SizedBox(width: 8),
                    Text(
                      a['name'].toString(),
                      style: TextStyle(
                        color: MoneTheme.textPrimary(widget.isDark),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAccountId = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransferAccountRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark, radius: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From Account',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MoneTheme.textSecondary(widget.isDark)),
                ),
                DropdownButton<int>(
                  value: _selectedAccountId,
                  isExpanded: true,
                  dropdownColor: MoneTheme.cardBg(widget.isDark),
                  underline: const SizedBox(),
                  items: _accounts.map((a) {
                    return DropdownMenuItem<int>(
                      value: a['id'] as int,
                      child: Text(
                        a['name'].toString(),
                        style: TextStyle(color: MoneTheme.textPrimary(widget.isDark), fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, color: MoneTheme.primaryBlue, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To Account',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MoneTheme.textSecondary(widget.isDark)),
                ),
                DropdownButton<int>(
                  value: _targetAccountId,
                  isExpanded: true,
                  dropdownColor: MoneTheme.cardBg(widget.isDark),
                  underline: const SizedBox(),
                  items: _accounts.map((a) {
                    return DropdownMenuItem<int>(
                      value: a['id'] as int,
                      child: Text(
                        a['name'].toString(),
                        style: TextStyle(color: MoneTheme.textPrimary(widget.isDark), fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _targetAccountId = val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberPill(int? memberId, String name, String emoji, [Color? accent]) {
    final isSelected = _selectedMemberId == memberId;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMemberId = memberId);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
              : MoneTheme.cardBg(widget.isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : MoneTheme.cardBorder(widget.isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                    : (accent ?? MoneTheme.textPrimary(widget.isDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
