import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/indian_banks.dart';
import '../theme/mone_theme.dart';

class AppleWalletCardItem {
  final int id;
  final String name;
  final String? bankName;
  final String? bankCode;
  final String? accountNumber;
  final double balance;
  final String type;
  final BankInfo bankInfo;
  final int? memberId;

  AppleWalletCardItem({
    required this.id,
    required this.name,
    this.bankName,
    this.bankCode,
    this.accountNumber,
    required this.balance,
    required this.type,
    required this.bankInfo,
    this.memberId,
  });

  factory AppleWalletCardItem.fromMap(Map<String, dynamic> map) {
    final bName = map['bank_name'] as String?;
    final bCode = map['bank_code'] as String?;
    final aType = (map['type'] as String?) ?? 'BANK';
    final name = (map['name'] as String?) ?? 'Account';
    
    // Resolve BankInfo
    BankInfo info;
    if (aType.toUpperCase() == 'CASH') {
      info = const BankInfo(
        id: 'cash',
        name: 'Physical Cash',
        shortName: 'CASH',
        gradientColors: [Color(0xFF0F766E), Color(0xFF134E4A)],
        accentColor: Color(0xFF2DD4BF),
        smsSenderCodes: [],
        keywords: ['cash'],
        isCash: true,
      );
    } else {
      info = IndianBankDirectory.getBankById(bCode);
      if (info.id == 'cash' || info.id == IndianBankDirectory.allBanks.last.id) {
        info = IndianBankDirectory.findBankByName(bName ?? name);
      }
    }

    return AppleWalletCardItem(
      id: (map['id'] as num).toInt(),
      name: name,
      bankName: bName,
      bankCode: bCode,
      accountNumber: map['account_number'] as String?,
      balance: ((map['balance'] as num?) ?? 0.0).toDouble(),
      type: aType,
      bankInfo: info,
      memberId: map['member_id'] as int?,
    );
  }
}

class AppleWalletCardsSection extends StatefulWidget {
  final List<AppleWalletCardItem> accounts;
  final bool isDark;
  final Function(AppleWalletCardItem) onCardTap;
  final VoidCallback onAddAccount;

  const AppleWalletCardsSection({
    super.key,
    required this.accounts,
    required this.isDark,
    required this.onCardTap,
    required this.onAddAccount,
  });

  @override
  State<AppleWalletCardsSection> createState() => _AppleWalletCardsSectionState();
}

class _AppleWalletCardsSectionState extends State<AppleWalletCardsSection> {
  int? _focusedCardId;

  static const double cardHeight = 195.0;

  double get dynamicPeekHeight {
    final count = widget.accounts.length;
    if (count <= 1) return cardHeight;
    if (count == 2) return 55.0;
    if (count == 3) return 50.0;
    return 44.0;
  }

  double get totalStackHeight {
    final count = widget.accounts.length;
    if (count == 0) return 140.0;
    return ((count - 1) * dynamicPeekHeight) + cardHeight + 14.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accounts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: MoneTheme.whiteCardDecoration(isDark: widget.isDark),
        child: Column(
          children: [
            Icon(Icons.credit_card_rounded, size: 48, color: MoneTheme.textMuted(widget.isDark)),
            const SizedBox(height: 12),
            Text(
              "No Accounts Added Yet",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MoneTheme.textPrimary(widget.isDark),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Link your Indian bank accounts or track cash",
              style: TextStyle(
                fontSize: 12,
                color: MoneTheme.textSecondary(widget.isDark),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onAddAccount,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Add Bank Account"),
              style: ElevatedButton.styleFrom(
                backgroundColor: MoneTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      );
    }

    final accounts = List<AppleWalletCardItem>.from(widget.accounts);

    // Reorder so focused card is on top
    if (_focusedCardId != null) {
      final focusedIndex = accounts.indexWhere((a) => a.id == _focusedCardId);
      if (focusedIndex != -1) {
        final focusedItem = accounts.removeAt(focusedIndex);
        accounts.add(focusedItem);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.style_rounded, size: 18, color: MoneTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    "BANK CARDS & WALLET",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: MoneTheme.textSecondary(widget.isDark),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: widget.onAddAccount,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MoneTheme.badgeBlueBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 14, color: MoneTheme.badgeBlueText),
                      const SizedBox(width: 4),
                      Text(
                        "Add Card",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: MoneTheme.badgeBlueText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stack Container with dynamic natural downward height
        SizedBox(
          height: totalStackHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(accounts.length, (index) {
              final acc = accounts[index];
              final isTopCard = index == accounts.length - 1;
              final topOffset = index * dynamicPeekHeight;

              return AnimatedPositioned(
                key: ValueKey(acc.id),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                top: topOffset,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (_focusedCardId == acc.id) {
                        _focusedCardId = null;
                      } else {
                        _focusedCardId = acc.id;
                      }
                    });
                    widget.onCardTap(acc);
                  },
                  child: _buildPhysicalCard(acc, isTopCard),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPhysicalCard(AppleWalletCardItem acc, bool isTopCard) {
    final colors = acc.bankInfo.gradientColors;
    final last4 = (acc.accountNumber != null && acc.accountNumber!.length >= 4)
        ? acc.accountNumber!.substring(acc.accountNumber!.length - 4)
        : '••••';

    return Container(
      height: cardHeight,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isTopCard ? 0.35 : 0.20),
            blurRadius: isTopCard ? 16 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient glossy glow
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Bank Badge + Name + Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        acc.bankInfo.buildBadge(size: 34),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc.bankInfo.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              acc.name,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Chip Emblem
                    Container(
                      width: 32,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Center(
                        child: Icon(Icons.memory_rounded, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ),
                  ],
                ),

                // Middle: Account Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Available Balance",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.65),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "₹${acc.balance.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                // Bottom Row: Masked Number + Network Brand
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "•••• •••• •••• $last4",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      acc.bankInfo.defaultCardNetwork,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
