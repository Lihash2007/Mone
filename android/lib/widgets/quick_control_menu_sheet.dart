import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mone_theme.dart';

// MARK: - Quick Control Menu Sheet (1:1 with iOS QuickControlMenuSheet)
class QuickControlMenuSheet extends StatelessWidget {
  final bool isDark;
  final bool isBiometricEnabled;
  final VoidCallback onOpenFamily;
  final VoidCallback onOpenAllTransactions;
  final VoidCallback onAddAccount;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleBiometrics;
  final VoidCallback onExportCsv;
  final VoidCallback onOpenCategoryLimits;
  final VoidCallback onOpenSettings;

  const QuickControlMenuSheet({
    super.key,
    required this.isDark,
    required this.isBiometricEnabled,
    required this.onOpenFamily,
    required this.onOpenAllTransactions,
    required this.onAddAccount,
    required this.onToggleTheme,
    required this.onToggleBiometrics,
    required this.onExportCsv,
    required this.onOpenCategoryLimits,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MoneTheme.bgCanvas(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 28, left: 20, right: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grabber
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Quick Control',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MoneTheme.textPrimary(isDark),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),

            _buildMenuItem(
              icon: Icons.people_alt_rounded,
              title: 'Family & Household',
              subtitle: 'Multi-member accounts & allowances',
              onTap: () {
                Navigator.pop(context);
                onOpenFamily();
              },
            ),
            _buildMenuItem(
              icon: Icons.receipt_long_rounded,
              title: 'All Transactions',
              subtitle: 'Search, filter & manage history',
              onTap: () {
                Navigator.pop(context);
                onOpenAllTransactions();
              },
            ),
            _buildMenuItem(
              icon: Icons.account_balance_rounded,
              title: 'Add Bank Account',
              subtitle: 'Link new Indian bank directory',
              onTap: () {
                Navigator.pop(context);
                onAddAccount();
              },
            ),
            _buildMenuItem(
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              title: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              subtitle: 'Toggle appearance',
              onTap: () {
                Navigator.pop(context);
                onToggleTheme();
              },
            ),
            _buildMenuItem(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Protection',
              subtitle: isBiometricEnabled ? 'Enabled • Protected on app pause' : 'Disabled • Direct access',
              onTap: () {
                Navigator.pop(context);
                onToggleBiometrics();
              },
            ),
            _buildMenuItem(
              icon: Icons.file_upload_outlined,
              title: 'Export Statement (CSV)',
              subtitle: 'Share transaction history',
              onTap: () {
                Navigator.pop(context);
                onExportCsv();
              },
            ),
            _buildMenuItem(
              icon: Icons.pie_chart_rounded,
              title: 'Category Limits',
              subtitle: 'Budgets & category caps',
              onTap: () {
                Navigator.pop(context);
                onOpenCategoryLimits();
              },
            ),
            _buildMenuItem(
              icon: Icons.settings_rounded,
              title: 'App Settings',
              subtitle: 'Android engine, shortcuts, profile',
              onTap: () {
                Navigator.pop(context);
                onOpenSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: MoneTheme.whiteCardDecoration(isDark: isDark, radius: 18, hasShadow: false),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2737) : MoneTheme.bgCardBlue(isDark),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: MoneTheme.textPrimary(isDark), size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: MoneTheme.textPrimary(isDark),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: MoneTheme.textSecondary(isDark),
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: MoneTheme.textSecondary(isDark), size: 20),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }
}
