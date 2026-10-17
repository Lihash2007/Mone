import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mone_theme.dart';

class FloatingCapsuleDock extends StatelessWidget {
  final int selectedIndex;
  final bool isDark;
  final Function(int) onTabSelected;
  final VoidCallback onAddRequested;

  const FloatingCapsuleDock({
    super.key,
    required this.selectedIndex,
    required this.isDark,
    required this.onTabSelected,
    required this.onAddRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      height: 68,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: MoneTheme.dockBg(isDark),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: MoneTheme.cardBorder(isDark),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(0, Icons.account_balance_wallet_rounded, "Dashboard"),
                _buildTabItem(1, Icons.query_stats_rounded, "Analytics"),
                
                // Central Quick Add Action Button (Solid circular pill)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAddRequested();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : MoneTheme.deepBlack,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: isDark ? MoneTheme.deepBlack : Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),

                _buildTabItem(2, Icons.credit_card_rounded, "Cards"),
                _buildTabItem(3, Icons.settings_rounded, "Settings"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTabSelected(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.15) : MoneTheme.bgCardBlue(false))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isSelected
              ? MoneTheme.primaryBlue
              : MoneTheme.textSecondary(isDark),
        ),
      ),
    );
  }
}
