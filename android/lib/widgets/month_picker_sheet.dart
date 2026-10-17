import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mone_theme.dart';

class MonthPickerSheet extends StatefulWidget {
  final DateTime selectedDate;
  final bool isDark;
  final Function(DateTime) onMonthSelected;
  final Function(int)? onYearSelected;

  MonthPickerSheet({
    super.key,
    DateTime? selectedDate,
    DateTime? initialDate,
    required this.isDark,
    required this.onMonthSelected,
    this.onYearSelected,
  }) : selectedDate = selectedDate ?? initialDate ?? DateTime.now();

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _pickerYear;

  final List<Map<String, dynamic>> _months = const [
    {"num": 1, "short": "Jan", "full": "January"},
    {"num": 2, "short": "Feb", "full": "February"},
    {"num": 3, "short": "Mar", "full": "March"},
    {"num": 4, "short": "Apr", "full": "April"},
    {"num": 5, "short": "May", "full": "May"},
    {"num": 6, "short": "Jun", "full": "June"},
    {"num": 7, "short": "Jul", "full": "July"},
    {"num": 8, "short": "Aug", "full": "August"},
    {"num": 9, "short": "Sep", "full": "September"},
    {"num": 10, "short": "Oct", "full": "October"},
    {"num": 11, "short": "Nov", "full": "November"},
    {"num": 12, "short": "Dec", "full": "December"},
  ];

  @override
  void initState() {
    super.initState();
    _pickerYear = widget.selectedDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MoneTheme.cardBg(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sheet Grabber Pill
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Pinned Top Header (Clear Title & Prominent Done Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select Month",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: MoneTheme.textPrimary(widget.isDark),
                        ),
                      ),
                      Text(
                        "Pick a period or view yearly analytics",
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
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white : MoneTheme.deepBlack,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Done",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? const Color(0xFF10141D) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    // Year Stepper Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _pickerYear--);
                          },
                          icon: Icon(Icons.chevron_left_rounded, color: MoneTheme.textPrimary(widget.isDark)),
                          style: IconButton.styleFrom(
                            backgroundColor: MoneTheme.bgCardBlue(widget.isDark),
                            shape: const CircleBorder(),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              "$_pickerYear",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: MoneTheme.textPrimary(widget.isDark),
                              ),
                            ),
                            const Text(
                              "Year",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: MoneTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _pickerYear++);
                          },
                          icon: Icon(Icons.chevron_right_rounded, color: MoneTheme.textPrimary(widget.isDark)),
                          style: IconButton.styleFrom(
                            backgroundColor: MoneTheme.bgCardBlue(widget.isDark),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 12-Month Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: _months.length,
                      itemBuilder: (context, index) {
                        final m = _months[index];
                        final mNum = m['num'] as int;
                        final isSelected = widget.selectedDate.month == mNum && widget.selectedDate.year == _pickerYear;
                        final isCurrentMonth = DateTime.now().month == mNum && DateTime.now().year == _pickerYear;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onMonthSelected(DateTime(_pickerYear, mNum, 1));
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (widget.isDark ? Colors.white : MoneTheme.deepBlack)
                                  : (widget.isDark ? const Color(0xFF1B212D) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isCurrentMonth ? MoneTheme.primaryBlue : Colors.transparent),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    m['short'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                                          : MoneTheme.textPrimary(widget.isDark),
                                    ),
                                  ),
                                  if (isCurrentMonth) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? (widget.isDark ? const Color(0xFF10141D) : Colors.white)
                                            : MoneTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // Jump to Current Month Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onMonthSelected(DateTime.now());
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.today_rounded, size: 16),
                        label: Text(
                          "Jump to Current Month (${DateTime.now().month}/${DateTime.now().year})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: MoneTheme.badgeBlueBg,
                          foregroundColor: MoneTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
