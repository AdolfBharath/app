import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows the Mon–Sun streak tracker for the **current calendar week**.
/// An active day shows a glowing fire icon; today gets a special ring + glow.
class WeeklyFireTracker extends StatelessWidget {
  const WeeklyFireTracker({
    super.key,
    required this.loggedInOnDay,
    this.activeColor,
    this.inactiveColor,
    this.animateActive = true,
  });

  final bool Function(DateTime day) loggedInOnDay;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool animateActive;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fireColor = activeColor ?? const Color(0xFFFF8A00);
    final dimColor = inactiveColor ?? scheme.onSurface.withAlpha(60);

    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    // Monday of the current week
    final weekStart = todayNormalized.subtract(
      Duration(days: todayNormalized.weekday - DateTime.monday),
    );

    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (index) {
        final day = days[index];
        final lit = loggedInOnDay(day);
        final isToday = day.isAtSameMomentAs(todayNormalized);
        return _FireCell(
          label: _labels[index],
          lit: lit,
          isToday: isToday,
          fireColor: fireColor,
          dimColor: dimColor,
          animateActive: animateActive,
        );
      }),
    );
  }
}

class _FireCell extends StatelessWidget {
  const _FireCell({
    required this.label,
    required this.lit,
    required this.isToday,
    required this.fireColor,
    required this.dimColor,
    required this.animateActive,
  });

  final String label;
  final bool lit;
  final bool isToday;
  final Color fireColor;
  final Color dimColor;
  final bool animateActive;

  @override
  Widget build(BuildContext context) {
    final activeForeground =
        ThemeData.estimateBrightnessForColor(fireColor) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    Widget icon = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? fireColor : dimColor.withValues(alpha: 0.16),
        border: Border.all(
          color: isToday
              ? Colors.white.withValues(alpha: 0.92)
              : (lit
                  ? fireColor.withValues(alpha: 0.9)
                  : dimColor.withValues(alpha: 0.35)),
          width: isToday ? 2.5 : 1.0,
        ),
        boxShadow: lit && isToday
            ? [
                BoxShadow(
                  color: fireColor.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : lit
                ? [
                    BoxShadow(
                      color: fireColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ]
                : isToday
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.local_fire_department_rounded,
        size: 19,
        color: lit ? activeForeground : dimColor,
      ),
    );

    if (lit && animateActive) {
      icon = icon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.96, 0.96),
            end: const Offset(1.04, 1.04),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }

    return SizedBox(
      width: 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
              color: lit ? activeForeground : dimColor,
            ),
          ),
        ],
      ),
    );
  }
}
