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
      info = IndianBankDirectory.allBanks.firstWhere(
        (b) => b.isCash,
        orElse: () => IndianBankDirectory.allBanks.last,
      );
    } else {
      info = IndianBankDirectory.getBankById(bCode);
      if (info.id == 'cash' || info.id == 'other') {
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
  final Function(AppleWalletCardItem)? onCardSelected;

  const AppleWalletCardsSection({
    super.key,
    required this.accounts,
    required this.isDark,
    required this.onCardTap,
    required this.onAddAccount,
    this.onCardSelected,
  });

  @override
  State<AppleWalletCardsSection> createState() => _AppleWalletCardsSectionState();
}

class _AppleWalletCardsSectionState extends State<AppleWalletCardsSection> {
  late final PageController _pageController;
  double _currentPage = 0.0;
  int _lastSnappedIndex = 0;

  static const double cardHeight = 205.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _pageController.addListener(() {
      final page = _pageController.page ?? 0.0;
      if (mounted) {
        setState(() {
          _currentPage = page;
        });
      }
      final rounded = page.round();
      if (rounded != _lastSnappedIndex && rounded >= 0 && rounded < widget.accounts.length) {
        _lastSnappedIndex = rounded;
        HapticFeedback.selectionClick();
        if (widget.onCardSelected != null) {
          widget.onCardSelected!(widget.accounts[rounded]);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    final activeIndex = _currentPage.round().clamp(0, widget.accounts.length - 1);
    final activeAccount = widget.accounts[activeIndex];
    final activeGlowColor = activeAccount.bankInfo.gradientColors.first;

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
                    "CARDS & WALLET DECK",
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
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: MoneTheme.badgeBlueText),
                      SizedBox(width: 4),
                      Text(
                        "Add Card",
                        style: TextStyle(
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

        // 3D Perspective Card Stack Carousel with Ambient Glow
        Stack(
          alignment: Alignment.center,
          children: [
            // Dynamic Ambient Back-Glow matching active bank card
            Positioned(
              top: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 260,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: activeGlowColor.withValues(alpha: widget.isDark ? 0.40 : 0.22),
                      blurRadius: 36,
                      spreadRadius: 8,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),

            // Horizontal 3D Page View
            SizedBox(
              height: cardHeight + 12,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.accounts.length,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final acc = widget.accounts[index];
                  final pageDiff = (_currentPage - index).abs();
                  final scale = (1.0 - (pageDiff * 0.08)).clamp(0.88, 1.0);
                  final opacity = (1.0 - (pageDiff * 0.20)).clamp(0.65, 1.0);
                  final isFocused = pageDiff < 0.5;

                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onCardTap(acc);
                        },
                        child: _buildPhysicalCard(acc, isFocused),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Deck Page Indicator Dots
        if (widget.accounts.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.accounts.length, (index) {
              final isSelected = index == activeIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeGlowColor
                      : (widget.isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
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
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isTopCard ? 0.35 : 0.15),
            blurRadius: isTopCard ? 18 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Realistic Brushed Sheen Diagonal Highlight
            Positioned(
              top: -80,
              right: -40,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 220,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Bank Badge + Name + Chip & Contactless
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            acc.bankInfo.buildBadge(size: 38, showBorder: true),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    acc.bankInfo.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    acc.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.78),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // EMV Gold Chip & Contactless Wave
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.contactless_rounded,
                            color: Colors.white.withValues(alpha: 0.70),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          // Authentic Metallic EMV Gold Chip
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.asset(
                                'assets/chip.png',
                                width: 36,
                                height: 29,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Middle: Available Balance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AVAILABLE BALANCE",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "₹${acc.balance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Bottom Row: Masked Number + Cardholder + Network Brand
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "•••• •••• •••• $last4",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            acc.bankInfo.defaultCardNetwork,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
