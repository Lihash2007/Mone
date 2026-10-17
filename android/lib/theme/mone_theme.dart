import 'package:flutter/material.dart';

// MARK: - Mone Bespoke Design System & Theme Tokens (1:1 with iOS)
class MoneTheme {
  // 1. Ice-Blue / Pastel Frost Canvas & Surfaces
  static const Color bgCanvasLight = Color(0xFFEDF4F9);
  static const Color bgCanvasDark = Color(0xFF090B10);

  static const LinearGradient bgCanvasGradientLight = LinearGradient(
    colors: [Color(0xFFF6F9FB), Color(0xFFEAF2F8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient bgCanvasGradientDark = LinearGradient(
    colors: [Color(0xFF0E1119), Color(0xFF07090F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient bgCanvasGradient(bool isDark) {
    return isDark ? bgCanvasGradientDark : bgCanvasGradientLight;
  }

  static Color bgCanvas(bool isDark) {
    return isDark ? bgCanvasDark : bgCanvasLight;
  }

  // Cards & Surfaces
  static Color cardBg(bool isDark) {
    return isDark ? const Color(0xFF131722) : Colors.white;
  }

  static Color cardBorder(bool isDark) {
    return isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04);
  }

  static Color bgCardBlue(bool isDark) {
    return isDark ? const Color(0xFF172435) : const Color(0xFFD8EBF7);
  }

  static Color bgSegmentContainer(bool isDark) {
    return isDark ? const Color(0xFF1B212D) : const Color(0xFFE2EDF5);
  }

  static Color activePillBg(bool isDark) {
    return isDark ? Colors.white : const Color(0xFF12141A);
  }

  static Color activePillText(bool isDark) {
    return isDark ? const Color(0xFF10141D) : Colors.white;
  }

  static Color dockBg(bool isDark) {
    return isDark ? const Color(0xFF131722).withValues(alpha: 0.94) : Colors.white.withValues(alpha: 0.94);
  }

  // Core Contrast Accents
  static const Color deepBlack = Color(0xFF12141A);
  static const Color primaryBlue = Color(0xFF0284C7);
  static const Color cyanAccent = Color(0xFF38BDF8);
  static const Color emerald = Color(0xFF10B981);
  static const Color rose = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);

  // Typography Colors
  static Color textPrimary(bool isDark) {
    return isDark ? const Color(0xFFF3F6FA) : const Color(0xFF10141D);
  }

  static Color textSecondary(bool isDark) {
    return isDark ? const Color(0xFF94A3B8) : const Color(0xFF68768A);
  }

  static Color textMuted(bool isDark) {
    return isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  }

  // Semantic Badges
  static const Color badgeGreenBg = Color(0xFFDDF7E8);
  static const Color badgeGreenText = Color(0xFF0D9488);
  static const Color badgeGreenBorder = Color(0xFFBBEFCE);
  static const Color badgeRedBg = Color(0xFFFFEBEA);
  static const Color badgeRedText = Color(0xFFE11D48);
  static const Color badgeRedBorder = Color(0xFFFECACA);
  static const Color badgeBlueBg = Color(0xFFCCE7F8);
  static const Color badgeBlueText = Color(0xFF0284C7);
  static const Color badgeBlueBorder = Color(0xFFBAE6FD);
  static const Color badgeAmberBg = Color(0xFFFEF3C7);
  static const Color badgeAmberText = Color(0xFFD97706);
  static const Color badgeAmberBorder = Color(0xFFFDE68A);

  // Card Decorations
  static BoxDecoration whiteCardDecoration({
    required bool isDark,
    double radius = 20,
    bool hasShadow = true,
    Color? customBg,
  }) {
    return BoxDecoration(
      color: customBg ?? cardBg(isDark),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: cardBorder(isDark),
        width: 1.0,
      ),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );
  }
}
