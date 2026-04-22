import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows the Mon–Sun streak tracker for the **current calendar week**.
/// An active day shows a glowing fire icon; today gets a special ring.
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
    final fireColor  = activeColor  ?? const Color(0xFFFF8A00); // warm orange
    final dimColor   = inactiveColor ?? scheme.onSurface.withValues(alpha: 60);

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
        final day    = days[index];
        final lit    = loggedInOnDay(day);

        return _FireCell(
          label: _labels[index],
          lit: lit,
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
    required this.fireColor,
    required this.dimColor,
    required this.animateActive,
  });

  final String label;
  final bool lit;
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
          color: lit ? fireColor.withValues(alpha: 0.9) : dimColor.withValues(alpha: 0.35),
          width: 1,
        ),
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
              fontWeight: FontWeight.w700,
              color: lit ? activeForeground : dimColor,
            ),
          ),
        ],
      ),
    );
  }
}
