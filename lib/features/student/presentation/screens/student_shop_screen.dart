import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/course.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/course_provider.dart';
import '../../../../services/api_service.dart';
import '../providers/student_nav_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_header_row.dart';
import '../widgets/student_hero_card.dart';
import 'student_notifications_screen.dart';

class StudentShopScreen extends StatefulWidget {
  const StudentShopScreen({super.key});

  @override
  State<StudentShopScreen> createState() => _StudentShopScreenState();
}

class _StudentShopScreenState extends State<StudentShopScreen> {
  int _selectedFilter = 0;
  final _filters = const ['All Items', 'Courses', 'Merchandise'];

  Future<void> _buyCourse(BuildContext context, Course course) async {
    final scheme = Theme.of(context).colorScheme;
    final auth = context.read<AuthProvider>();
    final student = context.read<StudentProvider>();
    final courses = context.read<CourseProvider>();

    final costCoins = course.price.round();
    if (costCoins > 0) {
      final ok = await student.spendCoins(costCoins);
      if (!ok) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough coins. Need $costCoins.'),
            backgroundColor: scheme.error,
          ),
        );
        return;
      }
    }

    try {
      await ApiService.instance.enrollInCourse(course.id);
      await auth.refreshCurrentUser();
      if (!context.mounted) return;

      final assignedCourseIds = auth.currentUser?.courseIds ?? const <String>[];
      await student.fetchCourses(assignedCourseIds: assignedCourseIds);
      await courses.loadCourses();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolled in ${course.title}')),
      );
    } catch (e) {
      if (costCoins > 0) {
        await student.addCoins(costCoins);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enroll failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final student = context.watch<StudentProvider>();
    final username =
        auth.currentUser?.username ?? auth.currentUser?.name ?? 'Student';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header + hero card ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  StudentHeaderRow(
                    onNotificationsTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const StudentNotificationsScreen()),
                    ),
                    onProfileTap: () =>
                        context.read<StudentNavProvider>().setIndex(4),
                  ),
                  const SizedBox(height: 14),
                  StudentHeroCard(
                    username: username,
                    subtitle: 'Redeem coins for courses & merchandise',
                    coins: student.coins,
                    streakDays: student.streakCount,
                    gender: student.gender,
                    profileImageBytes: student.profileImageBytes,
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 14),

                  // ── Promo banner ──────────────────────────
                  _PromoBanner(),
                  const SizedBox(height: 14),

                  // ── Filter chips ──────────────────────────
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _ShopFilterChip(
                        label: _filters[i],
                        selected: _selectedFilter == i,
                        onTap: () => setState(() => _selectedFilter = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Section header ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text('Available Courses',
                            style: theme.textTheme.titleSmall),
                      ),
                      Icon(Icons.local_offer_outlined,
                          size: 14,
                          color: scheme.onSurface.withValues(alpha: 160)),
                      const SizedBox(width: 4),
                      Consumer2<CourseProvider, StudentProvider>(
                        builder: (_, courseP, studentP, __) {
                          final count = courseP.courses
                              .where((c) => !studentP.enrolledCourses
                                  .any((e) => e.id == c.id))
                              .length;
                          return Text(
                            '$count Items',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface.withValues(alpha: 160),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Shop grid ─────────────────────────────────────
            Expanded(
              child: Consumer2<CourseProvider, StudentProvider>(
                builder: (context, courseProvider, studentP, _) {
                  final available = courseProvider.courses
                      .where((c) =>
                          !studentP.enrolledCourses.any((e) => e.id == c.id))
                      .toList();

                  if (available.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 48,
                              color: scheme.onSurface.withValues(alpha: 80)),
                          const SizedBox(height: 12),
                          Text(
                            'Nothing to purchase right now',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withValues(alpha: 160),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final course = available[index];
                      final priceCoins = course.price.round();
                      return _ShopCard(
                        course: course,
                        priceCoins: priceCoins,
                        index: index,
                        coins: studentP.coins,
                        onBuy: () {
                          _buyCourse(context, course);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Promo banner ─────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gradColors = LmsStudentTheme.heroGradientFor(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradColors[0].withValues(alpha: 60),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🎉 Special Offer',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gear Up for Success!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use reward coins for courses & merch',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 210),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.local_fire_department_rounded,
              color: LmsAdminTheme.coinGold, size: 40),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────
class _ShopFilterChip extends StatelessWidget {
  const _ShopFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected ? scheme.primary : scheme.onSurface.withValues(alpha: 14),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 40),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : scheme.onSurface.withValues(alpha: 200),
          ),
        ),
      ),
    );
  }
}

// ─── Shop item card ───────────────────────────────────────────────────────────
class _ShopCard extends StatefulWidget {
  const _ShopCard({
    required this.course,
    required this.priceCoins,
    required this.index,
    required this.coins,
    required this.onBuy,
  });

  final Course course;
  final int priceCoins;
  final int index;
  final int coins;
  final VoidCallback onBuy;

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canAfford = widget.coins >= widget.priceCoins;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onBuy,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 10)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 8),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    width: double.infinity,
                    child: widget.course.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            widget.course.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ShopThumbnailPlaceholder(
                              color: scheme.primary,
                            ),
                          )
                        : _ShopThumbnailPlaceholder(color: scheme.primary),
                  ),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(Icons.monetization_on_rounded,
                            size: 14, color: LmsAdminTheme.coinGold),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.priceCoins}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: LmsAdminTheme.coinGold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onBuy,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: canAfford
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: canAfford
                                  ? Colors.white
                                  : scheme.onSurface.withValues(alpha: 100),
                              size: 18,
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
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 50))
        .fadeIn(duration: 280.ms)
        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1));
  }
}

class _ShopThumbnailPlaceholder extends StatelessWidget {
  const _ShopThumbnailPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 18),
      child: Center(
        child: Icon(Icons.play_lesson_outlined,
            color: color.withValues(alpha: 160), size: 32),
      ),
    );
  }
}
