import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';
import '../services/analytics_service.dart';

// ============================================================================
// OBSIDIAN KINETIC DESIGN TOKENS (Directly matching StitchMCP)
// ============================================================================
class StitchColors {
  static const Color background = Color(0xFF0F131C);
  static const Color surfaceDim = Color(0xFF0B0F17);
  static const Color surfaceContainerLowest = Color(0xFF0A0E16);
  static const Color surfaceContainerLow = Color(0xFF181C24);
  static const Color surfaceContainer = Color(0xFF1C2028);
  static const Color surfaceContainerHigh = Color(0xFF262A33);
  static const Color surfaceContainerHighest = Color(0xFF31353E);
  static const Color surfaceBright = Color(0xFF353942);

  // Brand & Accent Tokens
  static const Color primary = Color(0xFFC0C1FF); // Lavender Intelligence
  static const Color primaryContainer = Color(0xFF8083FF);
  static const Color onPrimaryContainer = Color(0xFF0D0096);
  static const Color onPrimary = Color(0xFF1000A9);

  static const Color secondary = Color(0xFF4EDEA3); // Precision Emerald Growth
  static const Color secondaryContainer = Color(0xFF00A572);
  static const Color onSecondary = Color(0xFF003824);

  static const Color tertiary = Color(0xFFFFB2B7); // Burn & Risk Rose
  static const Color tertiaryContainer = Color(0xFFFF516A);
  static const Color onTertiary = Color(0xFF67001B);

  static const Color outline = Color(0xFF908FA0);
  static const Color outlineVariant = Color(0xFF464554);

  static const Color onSurface = Color(0xFFDFE2EE);
  static const Color onSurfaceVariant = Color(0xFFC7C4D7);
}

class StitchStyles {
  // Monospace font styling for data figures
  static TextStyle dataMetricLg({Color color = StitchColors.onSurface}) => TextStyle(
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle dataMetricHero({Color color = StitchColors.onSurface}) => TextStyle(
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: color,
      );

  static TextStyle dataMetricMd({Color color = StitchColors.onSurface}) => TextStyle(
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle dataMetricSm({Color color = StitchColors.onSurface}) => TextStyle(
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: color,
      );

  static TextStyle labelCaps({Color color = StitchColors.outline, double fontSize = 10}) => TextStyle(
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      );

  static TextStyle headlineSm({Color color = StitchColors.onSurface}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle headlineMd({Color color = StitchColors.onSurface}) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle bodySm({Color color = StitchColors.onSurfaceVariant}) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: color,
      );

  static TextStyle bodyMd({Color color = StitchColors.onSurfaceVariant}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  static BoxDecoration obsidianCard({
    Color backgroundColor = StitchColors.surfaceContainerLow,
    Color borderColor = StitchColors.outlineVariant,
    double borderAlpha = 0.35,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: backgroundColor.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor.withValues(alpha: borderAlpha),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.40),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

// ============================================================================
// MAIN ANALYTICS SCREEN WITH STITCH TOP SWITCHER
// ============================================================================
class ModernAnalyticsScreen extends StatefulWidget {
  final Database database;
  final String? initialTimePeriod;
  final Function({Map<String, dynamic>? existingTx})? onAddRequested;

  const ModernAnalyticsScreen({
    super.key,
    required this.database,
    this.initialTimePeriod,
    this.onAddRequested,
  });

  @override
  State<ModernAnalyticsScreen> createState() => _ModernAnalyticsScreenState();
}

class _ModernAnalyticsScreenState extends State<ModernAnalyticsScreen> {
  // Top Executive Switcher between Screen 1 and Screen 2
  // 'cockpit' = Screen 1: "Smart Cockpit & Controls"
  // 'intelligence' = Screen 2: "Financial Intelligence & Analytics"
  String _activeViewMode = 'intelligence';

  // Common Filters
  String _timeHorizon = 'This Month'; // 'This Month', 'Last 30D', 'YTD', 'Custom Range'
  String? _customMonth;

  // Cockpit Mode State
  bool _isShieldActive = true;
  bool _isCamouflageActive = false;
  double _customPacerTarget = 1450.0;
  double _categoryLimitDelta = 0.0;
  String _selectedCockpitCategory = 'Dining & Drinks';
  bool _isVaultSwept = false;

  // Intelligence Mode State
  int _touchedPieIndex = -1;

  String _formatCurrency(double amount, {bool allowMasking = true}) {
    if (!allowMasking) {
      return '₹${amount.toStringAsFixed(0)}';
    }
    if (_activeViewMode == 'cockpit' && !_isShieldActive) {
      return '₹ ••••';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'dining & drinks':
      case 'food':
      case 'food & dining':
        return const Color(0xFFFF516A);
      case 'groceries':
        return const Color(0xFF00A572);
      case 'shopping & tech':
      case 'shopping':
        return const Color(0xFF8083FF);
      case 'utilities & living':
      case 'utilities':
      case 'bills':
        return const Color(0xFFC0C1FF);
      case 'subscriptions':
        return const Color(0xFF4EDEA3);
      case 'transport':
      case 'fuel':
        return const Color(0xFF38BDF8);
      case 'entertainment':
        return const Color(0xFFF43F5E);
      default:
        final hash = category.hashCode;
        final r = (hash & 0xFF0000) >> 16;
        final g = (hash & 0x00FF00) >> 8;
        final b = (hash & 0x0000FF);
        return Color.fromRGBO(r, g, b, 1.0);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dining & drinks':
      case 'food':
      case 'food & dining':
        return Icons.restaurant_rounded;
      case 'groceries':
        return Icons.shopping_basket_rounded;
      case 'shopping & tech':
      case 'shopping':
        return Icons.devices_rounded;
      case 'utilities & living':
      case 'utilities':
      case 'bills':
        return Icons.home_rounded;
      case 'subscriptions':
        return Icons.sync_rounded;
      case 'transport':
      case 'fuel':
        return Icons.local_taxi_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsData>(
      future: AnalyticsService.calculate(
        db: widget.database,
        timeHorizon: _timeHorizon,
        customMonth: _customMonth,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: StitchColors.primary),
          );
        }

        final data = snapshot.data!;

        return Container(
          color: StitchColors.background,
          child: Column(
            children: [
              // 0. Top Executive View Switcher Pill
              _buildExecutiveTopSwitcher(),

              // Scrollable Canvas Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _activeViewMode == 'cockpit'
                        ? _buildCockpitView(data)
                        : _buildIntelligenceView(data),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // TOP EXECUTIVE MODE SWITCHER (Cockpit vs Intelligence)
  // ==========================================================================
  Widget _buildExecutiveTopSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: StitchColors.surfaceDim.withValues(alpha: 0.90),
        border: Border(
          bottom: BorderSide(
            color: StitchColors.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Container(
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: StitchColors.surfaceContainerHigh.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: StitchColors.outlineVariant.withValues(alpha: 0.30),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeViewMode = 'intelligence');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _activeViewMode == 'intelligence'
                        ? StitchColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: _activeViewMode == 'intelligence'
                        ? [
                            BoxShadow(
                              color: StitchColors.primaryContainer.withValues(alpha: 0.35),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 15,
                        color: _activeViewMode == 'intelligence'
                            ? Colors.white
                            : StitchColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Financial Intelligence',
                        style: TextStyle(
                          color: _activeViewMode == 'intelligence'
                              ? Colors.white
                              : StitchColors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeViewMode = 'cockpit');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _activeViewMode == 'cockpit'
                        ? StitchColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: _activeViewMode == 'cockpit'
                        ? [
                            BoxShadow(
                              color: StitchColors.primaryContainer.withValues(alpha: 0.35),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        size: 15,
                        color: _activeViewMode == 'cockpit'
                            ? Colors.white
                            : StitchColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cockpit & Controls',
                        style: TextStyle(
                          color: _activeViewMode == 'cockpit'
                              ? Colors.white
                              : StitchColors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SCREEN 1: SMART COCKPIT & CONTROLS (Obsidian Kinetic)
  // ==========================================================================
  Widget _buildCockpitView(AnalyticsData data) {
    return Column(
      key: const ValueKey('cockpit_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCockpitHeader(),
        const SizedBox(height: 16),
        _buildCockpitHeroPacer(data),
        const SizedBox(height: 18),
        _buildCockpitCategoryDrilldown(data),
        const SizedBox(height: 18),
        _buildCockpitSmartHacks(data),
        const SizedBox(height: 18),
        _buildCockpitQuickActions(data),
      ],
    );
  }

  Widget _buildCockpitHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: StitchColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: StitchColors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: StitchColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONE • COCKPIT',
                  style: StitchStyles.labelCaps(color: StitchColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Smart Cockpit & Controls',
                  style: StitchStyles.headlineSm(),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Interactive Privacy Shield Toggle Pill
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isShieldActive = !_isShieldActive);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isShieldActive
                      ? StitchColors.secondaryContainer.withValues(alpha: 0.18)
                      : StitchColors.surfaceContainerHigh.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isShieldActive
                        ? StitchColors.secondary.withValues(alpha: 0.40)
                        : StitchColors.outlineVariant.withValues(alpha: 0.40),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isShieldActive ? Icons.shield_rounded : Icons.shield_outlined,
                      size: 13,
                      color: _isShieldActive ? StitchColors.secondary : StitchColors.outline,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isShieldActive ? 'Shield Active' : 'Masked',
                      style: StitchStyles.labelCaps(
                        color: _isShieldActive ? StitchColors.secondary : StitchColors.outline,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Quick Settings Glass Icon Button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showAdjustCeilingModal();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: StitchColors.surfaceContainerHigh.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: StitchColors.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: StitchColors.onSurfaceVariant,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCockpitHeroPacer(AnalyticsData data) {
    final double safeToday = data.safeDailyAllowance > 0 ? data.safeDailyAllowance : 1450.0;
    final double displayedTarget = _customPacerTarget;
    final bool isOptimal = data.dailyBurnRate <= safeToday || data.baseBudget == 0;
    final double gaugeRatio = (displayedTarget / 3500.0).clamp(0.15, 1.0);

    return Container(
      decoration: StitchStyles.obsidianCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HERO PACING ENGINE',
                style: StitchStyles.labelCaps(color: StitchColors.onSurfaceVariant),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: StitchColors.secondaryContainer.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: StitchColors.secondary.withValues(alpha: 0.30),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: StitchColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE PACER',
                      style: StitchStyles.labelCaps(color: StitchColors.secondary, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 175,
              height: 175,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(175, 175),
                    painter: RadialPacerGaugePainter(progress: gaugeRatio),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SAFE TO SPEND',
                        style: StitchStyles.labelCaps(
                          color: StitchColors.onSurfaceVariant,
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isShieldActive
                            ? '₹${displayedTarget.toStringAsFixed(0)}'
                            : '₹ ••••',
                        style: StitchStyles.dataMetricHero(),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Today's Remaining",
                        style: TextStyle(
                          color: StitchColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: StitchColors.surfaceContainer.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: StitchColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: StitchColors.secondaryContainer.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          color: StitchColors.secondary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VELOCITY',
                              style: StitchStyles.labelCaps(fontSize: 8.5),
                            ),
                            Text(
                              isOptimal ? 'Optimal Pacing' : 'Caution Pace',
                              style: TextStyle(
                                color: isOptimal ? StitchColors.secondary : StitchColors.tertiary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: StitchColors.surfaceContainer.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: StitchColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: StitchColors.primaryContainer.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.savings_rounded,
                          color: StitchColors.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WEEKEND VAULT',
                              style: StitchStyles.labelCaps(fontSize: 8.5),
                            ),
                            Text(
                              _isShieldActive
                                  ? '+₹${data.weekendSurplus > 0 ? data.weekendSurplus.toStringAsFixed(0) : '620'} Banked'
                                  : '+₹•••',
                              style: StitchStyles.dataMetricSm(color: StitchColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: StitchColors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DYNAMIC TARGET RUNWAY',
                      style: StitchStyles.labelCaps(fontSize: 9),
                    ),
                    Text(
                      'Target: ₹${_customPacerTarget.toStringAsFixed(0)}',
                      style: StitchStyles.dataMetricSm(color: StitchColors.onSurface),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: StitchColors.primary,
                    inactiveTrackColor: StitchColors.surfaceContainerHighest,
                    trackHeight: 4,
                    thumbColor: StitchColors.primary,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayColor: StitchColors.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _customPacerTarget.clamp(500.0, 3500.0),
                    min: 500.0,
                    max: 3500.0,
                    divisions: 60,
                    onChanged: (val) {
                      setState(() => _customPacerTarget = val);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MIN ₹500', style: StitchStyles.labelCaps(fontSize: 8.5)),
                    Text('MAX ₹3,500', style: StitchStyles.labelCaps(fontSize: 8.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPresetButton(
                        label: '₹1,000',
                        isSelected: _customPacerTarget == 1000.0,
                        onTap: () => setState(() => _customPacerTarget = 1000.0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPresetButton(
                        label: '₹1,450 (Paced)',
                        isSelected: _customPacerTarget == 1450.0,
                        onTap: () => setState(() => _customPacerTarget = 1450.0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPresetButton(
                        label: '₹2,000',
                        isSelected: _customPacerTarget == 2000.0,
                        onTap: () => setState(() => _customPacerTarget = 2000.0),
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

  Widget _buildPresetButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? StitchColors.primaryContainer.withValues(alpha: 0.3)
              : StitchColors.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? StitchColors.primary.withValues(alpha: 0.6)
                : StitchColors.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isSelected ? StitchColors.primary : StitchColors.onSurface,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCockpitCategoryDrilldown(AnalyticsData data) {
    final selectedCat = data.categoryBreakdown.firstWhere(
      (c) => c.category.toLowerCase() == _selectedCockpitCategory.toLowerCase(),
      orElse: () => data.categoryBreakdown.isNotEmpty
          ? data.categoryBreakdown.first
          : CategorySpending(category: 'Dining & Drinks', amount: 1420.0, percentage: 71.0, limit: 2000.0),
    );

    final double baseLimit = selectedCat.limit != null && selectedCat.limit! > 0
        ? selectedCat.limit!
        : 2000.0;
    final double activeLimit = math.max(500.0, baseLimit + _categoryLimitDelta);
    final double spent = selectedCat.amount > 0 ? selectedCat.amount : 1420.0;
    final int pct = ((spent / activeLimit) * 100).round();
    final double bufferLeft = math.max(0.0, activeLimit - spent);

    return Container(
      decoration: StitchStyles.obsidianCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<String>(
                color: StitchColors.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: StitchColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                onSelected: (val) {
                  setState(() {
                    _selectedCockpitCategory = val;
                    _categoryLimitDelta = 0.0;
                  });
                },
                itemBuilder: (context) {
                  return data.categoryBreakdown.map((c) {
                    return PopupMenuItem<String>(
                      value: c.category,
                      child: Row(
                        children: [
                          Icon(_getCategoryIcon(c.category), color: _getCategoryColor(c.category), size: 16),
                          const SizedBox(width: 8),
                          Text(c.category, style: const TextStyle(color: StitchColors.onSurface, fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: StitchColors.surfaceContainerHigh.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: StitchColors.outlineVariant.withValues(alpha: 0.40),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(selectedCat.category),
                        color: StitchColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedCat.category,
                        style: const TextStyle(
                          color: StitchColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more_rounded,
                        color: StitchColors.onSurfaceVariant,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('MONTHLY CAP', style: StitchStyles.labelCaps(fontSize: 8.5)),
                  const SizedBox(height: 1),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatCurrency(spent),
                          style: StitchStyles.dataMetricMd(color: StitchColors.secondary),
                        ),
                        const TextSpan(
                          text: ' / ',
                          style: TextStyle(color: StitchColors.outlineVariant, fontSize: 13),
                        ),
                        TextSpan(
                          text: _formatCurrency(activeLimit),
                          style: StitchStyles.dataMetricMd(color: StitchColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pct% Utilized',
                style: TextStyle(
                  color: pct > 80 ? StitchColors.tertiary : StitchColors.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${bufferLeft.toStringAsFixed(0)} Buffer Left',
                style: StitchStyles.bodySm(color: StitchColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 9,
              color: StitchColors.surfaceContainerHighest,
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            StitchColors.secondary,
                            pct > 80 ? StitchColors.tertiary : StitchColors.primaryContainer,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: StitchColors.surfaceContainer.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: StitchColors.outlineVariant.withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildStepperBtn(
                      label: '− ₹500',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _categoryLimitDelta -= 500);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildStepperBtn(
                      label: '+ ₹500',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _categoryLimitDelta += 500);
                      },
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _categoryLimitDelta = 0.0);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: StitchColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: StitchColors.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restart_alt_rounded,
                          color: StitchColors.onSurfaceVariant,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reset Base',
                          style: StitchStyles.labelCaps(
                            color: StitchColors.onSurfaceVariant,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: StitchColors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('TODAY', style: StitchStyles.labelCaps(fontSize: 8.5)),
                      const SizedBox(height: 2),
                      Text('₹180', style: StitchStyles.dataMetricSm()),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: StitchColors.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('WEEK AVG', style: StitchStyles.labelCaps(fontSize: 8.5)),
                      const SizedBox(height: 2),
                      Text('₹410/d', style: StitchStyles.dataMetricSm()),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: StitchColors.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('RUNWAY', style: StitchStyles.labelCaps(fontSize: 8.5)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_rounded, color: StitchColors.secondary, size: 12),
                          SizedBox(width: 3),
                          Text(
                            'On Track',
                            style: TextStyle(
                              color: StitchColors.secondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _buildStepperBtn({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: StitchColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: StitchColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: StitchStyles.dataMetricSm(color: StitchColors.onSurface),
        ),
      ),
    );
  }

  Widget _buildCockpitSmartHacks(AnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: StitchColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'SMART HACKS & AUTOMATIONS',
                  style: StitchStyles.labelCaps(
                    color: StitchColors.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: StitchColors.primaryContainer.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: StitchColors.primary.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: StitchColors.primary, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    '2 ACTIVE',
                    style: StitchStyles.labelCaps(color: StitchColors.primary, fontSize: 8.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Hack Card 1: Subscription Creep Alert
        Container(
          decoration: BoxDecoration(
            color: StitchColors.surfaceContainerLow.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: StitchColors.tertiaryContainer.withValues(alpha: 0.40),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: StitchColors.tertiaryContainer.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: StitchColors.tertiary.withValues(alpha: 0.40),
                          ),
                        ),
                        child: const Icon(
                          Icons.notification_important_rounded,
                          color: StitchColors.tertiary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Subscription Creep', style: StitchStyles.headlineSm()),
                          Text('Streaming & Content', style: StitchStyles.bodySm()),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: StitchColors.tertiaryContainer.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: StitchColors.tertiary.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up_rounded, color: StitchColors.tertiary, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          'Price Hike Detected',
                          style: StitchStyles.labelCaps(color: StitchColors.tertiary, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: StitchStyles.bodyMd(),
                  children: [
                    TextSpan(
                      text: _isCamouflageActive ? 'N•••••• (Scrambled)' : 'Netflix',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: StitchColors.onSurface),
                    ),
                    const TextSpan(text: ' charged '),
                    TextSpan(
                      text: '₹799/mo',
                      style: StitchStyles.dataMetricSm(color: StitchColors.tertiary),
                    ),
                    const TextSpan(text: ' (previously ₹649/mo, +23% hike without notice).'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Subscription Audit opened.')),
                        );
                      },
                      icon: const Icon(Icons.policy_rounded, size: 14, color: StitchColors.onSurface),
                      label: Text(
                        'Review Audit',
                        style: StitchStyles.labelCaps(color: StitchColors.onSurface, fontSize: 9.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: StitchColors.surfaceContainerHigh.withValues(alpha: 0.9),
                        side: BorderSide(color: StitchColors.outlineVariant.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reminder set for renewal cycle.')),
                        );
                      },
                      icon: const Icon(Icons.alarm_rounded, size: 14, color: StitchColors.tertiary),
                      label: Text(
                        'Set Reminder',
                        style: StitchStyles.labelCaps(color: StitchColors.tertiary, fontSize: 9.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: StitchColors.tertiaryContainer.withValues(alpha: 0.2),
                        side: BorderSide(color: StitchColors.tertiary.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Hack Card 2: Spare Change Round-Up Micro Vault
        Container(
          decoration: BoxDecoration(
            color: StitchColors.surfaceContainerLow.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: StitchColors.secondaryContainer.withValues(alpha: 0.40),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: StitchColors.secondaryContainer.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: StitchColors.secondary.withValues(alpha: 0.40),
                          ),
                        ),
                        child: const Icon(
                          Icons.toll_rounded,
                          color: StitchColors.secondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Round-Up Micro Vault', style: StitchStyles.headlineSm()),
                          Text('Algorithmic Frictionless Stash', style: StitchStyles.bodySm()),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: StitchColors.secondaryContainer.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: StitchColors.secondary.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Text(
                      'Auto-Stash',
                      style: StitchStyles.labelCaps(color: StitchColors.secondary, fontSize: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: StitchColors.surfaceContainer.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: StitchColors.outlineVariant.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ACCUMULATED THIS CYCLE', style: StitchStyles.labelCaps(fontSize: 8)),
                        const SizedBox(height: 2),
                        Text(
                          _isVaultSwept
                              ? '₹0'
                              : (_isShieldActive
                                  ? (data.spareChangeRoundUps > 0
                                      ? '₹${data.spareChangeRoundUps.toStringAsFixed(0)}'
                                      : '₹1,840')
                                  : '₹ ••••'),
                          style: StitchStyles.dataMetricLg(color: StitchColors.secondary),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('TXN VOLUMETRICS', style: StitchStyles.labelCaps(fontSize: 8)),
                        const SizedBox(height: 2),
                        Text(
                          '${data.roundUpCount > 0 ? data.roundUpCount : 46} txns round to ₹10',
                          style: StitchStyles.dataMetricSm(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _isVaultSwept = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Swept ₹1,840 to Emergency Savings Goal!')),
                    );
                  },
                  icon: Icon(
                    _isVaultSwept ? Icons.check_circle_rounded : Icons.move_to_inbox_rounded,
                    size: 16,
                    color: _isVaultSwept ? Colors.black : StitchColors.onPrimary,
                  ),
                  label: Text(
                    _isVaultSwept ? 'Vault Cleared & Banked' : 'Sweep to Emergency Goal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isVaultSwept ? Colors.black : StitchColors.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isVaultSwept ? StitchColors.secondary : StitchColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Camouflage Public Mode Tile
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: StitchColors.surfaceContainerLow.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: StitchColors.outlineVariant.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: StitchColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      color: StitchColors.primary,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Camouflage Public Mode',
                        style: TextStyle(
                          color: StitchColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        'Auto-scramble merchant names in public view',
                        style: TextStyle(
                          color: StitchColors.outline,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _isCamouflageActive,
                activeThumbColor: StitchColors.secondary,
                activeTrackColor: StitchColors.secondary.withValues(alpha: 0.4),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: StitchColors.surfaceContainerHighest,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  setState(() => _isCamouflageActive = val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCockpitQuickActions(AnalyticsData data) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionDockItem(
            icon: Icons.download_rounded,
            label: 'Export Report',
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting Obsidian Analytics Report (CSV/PDF)...')),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionDockItem(
            icon: Icons.tune_rounded,
            label: 'Adjust Ceiling',
            onTap: () {
              HapticFeedback.lightImpact();
              _showAdjustCeilingModal();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionDockItem(
            icon: Icons.auto_awesome_rounded,
            label: 'Simulate Buy',
            onTap: () {
              HapticFeedback.lightImpact();
              _showSimulatePurchaseModal(data);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionDockItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: StitchColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: StitchColors.outlineVariant.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: StitchColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: StitchColors.primary, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: StitchStyles.labelCaps(color: StitchColors.onSurface, fontSize: 8.5),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SCREEN 2: FINANCIAL INTELLIGENCE & ANALYTICS (Obsidian Kinetic)
  // ==========================================================================
  Widget _buildIntelligenceView(AnalyticsData data) {
    return Column(
      key: const ValueKey('intelligence_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIntelligenceHeader(),
        const SizedBox(height: 12),
        _buildIntelligenceTimeRangePills(),
        const SizedBox(height: 18),
        _buildExecutiveKpiCards(data),
        const SizedBox(height: 18),
        _buildBurnTrajectorySection(data),
        const SizedBox(height: 18),
        _buildSpendingDistributionSection(data),
        const SizedBox(height: 18),
        _buildCopilotAnomalyCard(data),
        const SizedBox(height: 18),
        _buildSubscriptionsSection(data),
        const SizedBox(height: 18),
        _buildTopMerchantsSection(data),
      ],
    );
  }

  Widget _buildIntelligenceHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: StitchColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: StitchColors.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: StitchColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONE • INTEL',
                  style: StitchStyles.labelCaps(color: StitchColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Financial Intelligence',
                  style: StitchStyles.headlineSm(),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildHeaderIconButton(
              icon: Icons.calendar_today_rounded,
              onTap: () {
                HapticFeedback.lightImpact();
                _showMonthPicker();
              },
            ),
            const SizedBox(width: 6),
            _buildHeaderIconButton(
              icon: Icons.download_rounded,
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading Analytics Report...')),
                );
              },
            ),
            const SizedBox(width: 6),
            _buildHeaderIconButton(
              icon: Icons.notifications_rounded,
              color: StitchColors.primary,
              onTap: () {
                HapticFeedback.lightImpact();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    Color color = StitchColors.onSurfaceVariant,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: StitchColors.surfaceContainerHigh.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: StitchColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildIntelligenceTimeRangePills() {
    final ranges = ['This Month', 'Last 30D', 'YTD', 'Custom Range'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ranges.map((r) {
          final isSelected = _timeHorizon == r;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (r == 'Custom Range') {
                  _showMonthPicker();
                } else {
                  setState(() {
                    _timeHorizon = r;
                    _customMonth = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? StitchColors.primaryContainer
                      : StitchColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? StitchColors.primary.withValues(alpha: 0.6)
                        : StitchColors.outlineVariant.withValues(alpha: 0.30),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: StitchColors.primaryContainer.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  r == 'Custom Range' && _customMonth != null ? _customMonth! : r,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : StitchColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExecutiveKpiCards(AnalyticsData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildExecutiveKpiItem(
                label: 'TOTAL INFLOW',
                value: _formatCurrency(data.totalInflow, allowMasking: false),
                delta: '+14.2%',
                isPositiveDelta: true,
                subtitle: 'vs previous period',
                accentColor: StitchColors.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildExecutiveKpiItem(
                label: 'TOTAL BURN',
                value: _formatCurrency(data.totalOutflow, allowMasking: false),
                delta: '-5.1%',
                isPositiveDelta: false,
                subtitle: 'Velocity controlled',
                accentColor: StitchColors.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildExecutiveKpiItem(
                label: 'SAVINGS RATE',
                value: '${data.netSavingsRate.toStringAsFixed(1)}%',
                delta: 'PACE +38%',
                isPositiveDelta: true,
                subtitle: 'Target: 50.0%',
                accentColor: StitchColors.secondary,
                isPercentMetric: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildExecutiveKpiItem(
                label: 'PROJECTED EOM',
                value: _formatCurrency(data.projectedEomBalance, allowMasking: false),
                delta: 'ON TRACK',
                isPositiveDelta: true,
                subtitle: 'Safety margin: 92%',
                accentColor: StitchColors.secondary,
                isStatusPill: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExecutiveKpiItem({
    required String label,
    required String value,
    required String delta,
    required bool isPositiveDelta,
    required String subtitle,
    required Color accentColor,
    bool isPercentMetric = false,
    bool isStatusPill = false,
  }) {
    return Container(
      decoration: StitchStyles.obsidianCard(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: StitchStyles.labelCaps(fontSize: 8.5)),
              if (isStatusPill)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: StitchColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      delta,
                      style: StitchStyles.labelCaps(color: StitchColors.secondary, fontSize: 8),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPositiveDelta
                        ? StitchColors.secondaryContainer.withValues(alpha: 0.20)
                        : StitchColors.tertiaryContainer.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositiveDelta ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 9,
                        color: isPositiveDelta ? StitchColors.secondary : StitchColors.tertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        delta,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: isPositiveDelta ? StitchColors.secondary : StitchColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: isPercentMetric
                ? StitchStyles.dataMetricLg(color: accentColor)
                : StitchStyles.dataMetricLg(),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: StitchStyles.bodySm(color: StitchColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildBurnTrajectorySection(AnalyticsData data) {
    final points = data.burnTrajectory;
    final maxSpent = points.isNotEmpty ? points.last.cumulativeActual : 0.0;
    final maxCeiling = points.isNotEmpty ? points.last.cumulativeBudgetCeiling : 0.0;
    final maxY = math.max(1000.0, math.max(maxSpent, maxCeiling) * 1.15);

    List<FlSpot> actualSpots = [];
    List<FlSpot> ceilingSpots = [];
    for (var p in points) {
      actualSpots.add(FlSpot(p.day.toDouble(), p.cumulativeActual));
      ceilingSpots.add(FlSpot(p.day.toDouble(), p.cumulativeBudgetCeiling));
    }

    final double bufferDiff = maxCeiling - maxSpent;

    return Container(
      decoration: StitchStyles.obsidianCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('BURN TRAJECTORY', style: StitchStyles.labelCaps(fontSize: 8.5)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: StitchColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Day ${data.daysElapsed} of ${data.totalDaysInPeriod}',
                          style: StitchStyles.labelCaps(color: StitchColors.onSurface, fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Spend vs Safe Ceiling', style: StitchStyles.headlineSm()),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StitchColors.secondaryContainer.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: StitchColors.secondary.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  bufferDiff >= 0
                      ? 'Safe Zone: +₹${bufferDiff.toStringAsFixed(0)}'
                      : 'Exceeded: -₹${bufferDiff.abs().toStringAsFixed(0)}',
                  style: StitchStyles.labelCaps(color: StitchColors.secondary, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: data.totalDaysInPeriod.toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: StitchColors.outlineVariant.withValues(alpha: 0.25),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: StitchColors.primaryContainer,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          StitchColors.primaryContainer.withValues(alpha: 0.38),
                          StitchColors.primaryContainer.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  if (data.baseBudget > 0)
                    LineChartBarData(
                      spots: ceilingSpots,
                      isCurved: false,
                      color: StitchColors.tertiary,
                      barWidth: 1.2,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: StitchColors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DAY 01 (₹0)', style: StitchStyles.labelCaps(fontSize: 8.5)),
                Text(
                  'MAX CEILING: ₹${data.baseBudget.toStringAsFixed(0)}',
                  style: StitchStyles.labelCaps(color: StitchColors.tertiary, fontSize: 8.5),
                ),
                Text('DAY ${data.totalDaysInPeriod} (EOM)', style: StitchStyles.labelCaps(fontSize: 8.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingDistributionSection(AnalyticsData data) {
    final breakdown = data.categoryBreakdown;
    List<PieChartSectionData> pieSections = [];

    for (int i = 0; i < breakdown.length; i++) {
      final c = breakdown[i];
      final isTouched = i == _touchedPieIndex;
      final radius = isTouched ? 36.0 : 30.0;
      final color = _getCategoryColor(c.category);

      pieSections.add(
        PieChartSectionData(
          color: color,
          value: c.amount,
          radius: radius,
          showTitle: false,
        ),
      );
    }

    return Container(
      decoration: StitchStyles.obsidianCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ALLOCATION MATRIX', style: StitchStyles.labelCaps(fontSize: 8.5)),
                  const SizedBox(height: 2),
                  Text('Spending Distribution', style: StitchStyles.headlineSm()),
                ],
              ),
              Text(
                '${breakdown.length} categories',
                style: StitchStyles.bodySm(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pieSections.isNotEmpty) ...[
            Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: pieSections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 3,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedPieIndex = -1;
                                return;
                              }
                              _touchedPieIndex =
                                  pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('TOTAL', style: StitchStyles.labelCaps(fontSize: 8.5)),
                        Text(
                          '₹${data.totalOutflow.toStringAsFixed(0)}',
                          style: StitchStyles.dataMetricMd(),
                        ),
                        Text(
                          '100% OK',
                          style: StitchStyles.labelCaps(color: StitchColors.secondary, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...breakdown.map((cat) {
            final color = _getCategoryColor(cat.category);
            final delta = cat.momDeltaPercent;
            final isIncrease = delta != null && delta > 0;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: StitchColors.outlineVariant.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(_getCategoryIcon(cat.category), color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.category,
                          style: const TextStyle(
                            color: StitchColors.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (cat.percentage / 100.0).clamp(0.0, 1.0),
                                  backgroundColor: StitchColors.surfaceContainerHigh,
                                  color: color,
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${cat.percentage.toStringAsFixed(1)}%',
                              style: StitchStyles.labelCaps(fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${cat.amount.toStringAsFixed(0)}',
                        style: StitchStyles.dataMetricMd(),
                      ),
                      if (delta != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (isIncrease ? StitchColors.tertiaryContainer : StitchColors.secondaryContainer).withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${isIncrease ? '+' : ''}${delta.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: isIncrease ? StitchColors.tertiary : StitchColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCopilotAnomalyCard(AnalyticsData data) {
    return Container(
      decoration: BoxDecoration(
        color: StitchColors.surfaceContainerLow.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: StitchColors.primaryContainer.withValues(alpha: 0.40),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: StitchColors.primaryContainer.withValues(alpha: 0.08),
            blurRadius: 18,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: StitchColors.primaryContainer.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: StitchColors.primaryContainer.withValues(alpha: 0.40),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: StitchColors.primary,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MONE COPILOT • ANOMALY',
                    style: StitchStyles.labelCaps(color: StitchColors.primary, fontSize: 9.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: StitchColors.tertiaryContainer.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HIGH IMPACT',
                  style: StitchStyles.labelCaps(color: StitchColors.tertiary, fontSize: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.anomalyInsight ??
                'Weekend dining was 24% higher than your historical baseline (+ ₹285 over 3 days).',
            style: StitchStyles.bodyMd(color: StitchColors.onSurface),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: StitchColors.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECOMMENDED AUTOMATION',
                  style: StitchStyles.labelCaps(fontSize: 8.5),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Auto-cap applied to Dining for 7 days!')),
                    );
                  },
                  icon: const Icon(Icons.bolt_rounded, size: 13, color: StitchColors.onPrimary),
                  label: const Text(
                    'Auto-cap Dining (7D)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: StitchColors.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StitchColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsSection(AnalyticsData data) {
    final subs = data.subscriptions.isNotEmpty
        ? data.subscriptions
        : [
            SubscriptionItem(name: 'Figma Pro', monthlyAmount: 1250, lastDate: DateTime.now()),
            SubscriptionItem(name: 'AWS Cloud', monthlyAmount: 2400, lastDate: DateTime.now()),
            SubscriptionItem(name: 'Spotify Duo', monthlyAmount: 179, lastDate: DateTime.now()),
            SubscriptionItem(name: 'Netflix 4K', monthlyAmount: 649, lastDate: DateTime.now()),
          ];

    final double totalScheduled = subs.fold(0.0, (s, i) => s + i.monthlyAmount);

    return Container(
      decoration: StitchStyles.obsidianCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RECURRING COMMITMENTS', style: StitchStyles.labelCaps(fontSize: 8.5)),
                  const SizedBox(height: 2),
                  Text('Fixed Costs & Subscriptions', style: StitchStyles.headlineSm()),
                ],
              ),
              Text(
                'MANAGE',
                style: StitchStyles.labelCaps(color: StitchColors.primary, fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${subs.length} Active • ₹${totalScheduled.toStringAsFixed(0)}/mo scheduled',
            style: StitchStyles.bodySm(),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: subs.map((s) {
                final String initial = s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S';
                return Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: StitchColors.surfaceContainerHigh.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: StitchColors.outlineVariant.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: StitchColors.primaryContainer.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: StitchColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            'Active',
                            style: StitchStyles.labelCaps(color: StitchColors.secondary, fontSize: 8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.name,
                        style: const TextStyle(
                          color: StitchColors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '₹${s.monthlyAmount.toStringAsFixed(0)}',
                              style: StitchStyles.dataMetricSm(color: StitchColors.onSurface),
                            ),
                            TextSpan(
                              text: '/mo',
                              style: StitchStyles.labelCaps(fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMerchantsSection(AnalyticsData data) {
    final merchants = data.topMerchants.isNotEmpty
        ? data.topMerchants.take(4).toList()
        : [
            MerchantSpendItem(merchant: 'Swiggy & Instamart', count: 14, totalAmount: 3450),
            MerchantSpendItem(merchant: 'Amazon Services', count: 6, totalAmount: 2890),
            MerchantSpendItem(merchant: 'Uber Rides', count: 18, totalAmount: 1820),
            MerchantSpendItem(merchant: 'Starbucks Coffee', count: 8, totalAmount: 1240),
          ];

    return Container(
      decoration: StitchStyles.obsidianCard(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONCENTRATION METRIC', style: StitchStyles.labelCaps(fontSize: 8.5)),
                  const SizedBox(height: 2),
                  Text('Top Merchants', style: StitchStyles.headlineSm()),
                ],
              ),
              Text('RANKED 1 - ${merchants.length}', style: StitchStyles.labelCaps(fontSize: 8.5)),
            ],
          ),
          const SizedBox(height: 12),
          ...merchants.asMap().entries.map((entry) {
            final int rank = entry.key + 1;
            final m = entry.value;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: StitchColors.outlineVariant.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    child: Text(
                      '$rank',
                      style: StitchStyles.labelCaps(color: StitchColors.onSurfaceVariant, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: StitchColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: StitchColors.outlineVariant.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: StitchColors.secondary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCamouflageActive ? '${m.merchant[0]}•••••• (Scrambled)' : m.merchant,
                          style: const TextStyle(
                            color: StitchColors.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${m.count} orders',
                          style: StitchStyles.bodySm(),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${m.totalAmount.toStringAsFixed(0)}',
                    style: StitchStyles.dataMetricMd(),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: StitchColors.onSurfaceVariant,
                    size: 16,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER MODALS & DIALOGS
  // ==========================================================================
  void _showMonthPicker() async {
    final now = DateTime.now();
    List<String> months = [];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: StitchColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Analytical Range', style: StitchStyles.headlineSm()),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: months.map((m) {
                  return ChoiceChip(
                    label: Text(m, style: const TextStyle(fontFamily: 'monospace')),
                    selected: _customMonth == m,
                    selectedColor: StitchColors.primaryContainer,
                    backgroundColor: StitchColors.surfaceContainerHigh,
                    onSelected: (selected) {
                      Navigator.pop(ctx);
                      setState(() {
                        _timeHorizon = 'Custom Range';
                        _customMonth = m;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdjustCeilingModal() {
    final ctrl = TextEditingController(text: '45000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StitchColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: StitchColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        title: Text('Adjust Monthly Ceiling', style: StitchStyles.headlineSm()),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: StitchStyles.dataMetricLg(),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: StitchStyles.dataMetricLg(color: StitchColors.primary),
            filled: true,
            fillColor: StitchColors.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: StitchColors.outline)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBudget = double.tryParse(ctrl.text) ?? 45000.0;
              await widget.database.insert(
                'settings',
                {'key': 'total_budget', 'value': newBudget},
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: StitchColors.primary),
            child: const Text('Save Ceiling', style: TextStyle(color: StitchColors.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showSimulatePurchaseModal(AnalyticsData data) {
    final ctrl = TextEditingController();
    double simulatedAllowance = data.safeDailyAllowance;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: StitchColors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: StitchColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            title: Text('Simulate Purchase Impact', style: StitchStyles.headlineSm()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview how an expense alters your daily safe allowance for this month:',
                  style: StitchStyles.bodySm(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: StitchStyles.dataMetricLg(),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: StitchStyles.dataMetricLg(color: StitchColors.primary),
                    hintText: 'e.g. 2500',
                    filled: true,
                    fillColor: StitchColors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    final entered = double.tryParse(val) ?? 0.0;
                    final daysLeft = math.max(1, data.totalDaysInPeriod - data.daysElapsed);
                    final rem = math.max(0.0, (data.baseBudget - data.totalOutflow - entered));
                    setDialogState(() {
                      simulatedAllowance = rem / daysLeft;
                    });
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: StitchColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Simulated Safe Pacer:', style: StitchStyles.bodySm()),
                      Text(
                        '₹${simulatedAllowance.toStringAsFixed(0)}/day',
                        style: StitchStyles.dataMetricSm(color: StitchColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done', style: TextStyle(color: StitchColors.primary)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// STITCH RADIAL PACER GAUGE PAINTER (Gradient Arc)
// ============================================================================
class RadialPacerGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  RadialPacerGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 18) / 2;
    const strokeWidth = 9.0;

    // 1. Background Track
    final bgPaint = Paint()
      ..color = StitchColors.surfaceContainerHighest.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 2. Active Gradient Arc
    final sweepAngle = 2 * math.pi * progress.clamp(0.01, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final activePaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          StitchColors.secondary,
          StitchColors.primary,
          StitchColors.primaryContainer,
        ],
        stops: [0.0, 0.7, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 2);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawArc(
      rect,
      0,
      sweepAngle,
      false,
      activePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RadialPacerGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
