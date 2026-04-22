import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';

import '../../../../config/theme.dart';
import 'student_animated_avatar.dart';
import 'weekly_fire_tracker.dart';

class StudentHeroCard extends StatelessWidget {
  const StudentHeroCard({
    super.key,
    required this.username,
    required this.coins,
    required this.streakDays,
    required this.gender,
    this.profileImageBytes,
    this.subtitle,
    this.onTap,
    this.footer,
  });

  final String username;
  final int coins;
  final int streakDays;
  final String gender;
  final Uint8List? profileImageBytes;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);

    final gradientColors = LmsStudentTheme.heroGradientFor(context);

    Widget card = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: isDark ? 40 : 50),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ──────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Left
                StudentAnimatedAvatar(
                  gender: gender,
                  size: 56,
                  onPrimaryContext: true,
                  imageBytes: profileImageBytes,
                ),
                const SizedBox(width: 16),
                
                // Name & Subtitle middle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hi, $username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Coins Right pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on_rounded, size: 16, color: LmsStudentTheme.coinGold(context)),
                      const SizedBox(width: 6),
                      Text(
                        '$coins',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // ── Bottom tracker (embedded directly, no box) ────────────────────
          if (footer != null) ...[
            footer!,
            const SizedBox(height: 20),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

// ── Shared Weekly Activity footer used on Home + Profile ────────────────────
class HeroWeeklyFooter extends StatelessWidget {
  const HeroWeeklyFooter({
    super.key,
    required this.loggedInOnDay,
    required this.streakCount,
  });

  final bool Function(DateTime) loggedInOnDay;
  final int streakCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   const Icon(
                    Icons.water_drop_outlined,
                    color: Color(0xFFFF8A00),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$streakCount Day Streak',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ]
              ),
              Text(
                'WEEKLY PROGRESS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WeeklyFireTracker(
            loggedInOnDay: loggedInOnDay,
            activeColor: const Color(0xFFFF8A00),
            inactiveColor: Colors.white.withValues(alpha: 80),
          ),
        ],
      ),
    );
  }
}

