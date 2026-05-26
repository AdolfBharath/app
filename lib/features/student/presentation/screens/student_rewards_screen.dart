import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_header_row.dart';
import '../widgets/weekly_fire_tracker.dart';

class StudentRewardsScreen extends StatefulWidget {
  const StudentRewardsScreen({super.key});

  @override
  State<StudentRewardsScreen> createState() => _StudentRewardsScreenState();
}

class _StudentRewardsScreenState extends State<StudentRewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<StudentProvider>().fetchPurchasedItems(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final student = context.watch<StudentProvider>();
    final completedCourses = student.enrolledCourses
      .where((c) => student.getCourseProgress(c.id) >= 0.999)
      .length;
    final achievements = <String>[];
    if (student.streakCount >= 1) achievements.add('First Login');
    if (student.streakCount >= 7) achievements.add('7-day Streak');
    if (completedCourses >= 1) achievements.add('Course Explorer');
    if (completedCourses >= 3) achievements.add('Course Finisher');
    if (student.coins >= 100) achievements.add('Coin Collector');

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StudentHeaderRow(showProfile: false),
              const SizedBox(height: 12),
              Text(
                'Rewards',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your streaks and achievements',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface.withAlpha(160),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.onSurface.withAlpha(12)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withAlpha(10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Weekly Fire',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          'Streak: ${student.streakCount}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    WeeklyFireTracker(
                      loggedInOnDay: student.loggedInOnDay,
                      activeColor: scheme.secondary,
                      inactiveColor: scheme.onSurface.withAlpha(70),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.monetization_on_outlined, color: scheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Coins: ${student.coins}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Achievements',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              achievements.isEmpty
                  ? Text(
                      'No achievements yet. Keep learning to unlock badges.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: scheme.onSurface.withAlpha(120),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: achievements
                          .map((label) => _BadgeChip(label))
                          .toList(growable: false),
                    ),
              const SizedBox(height: 24),
              Text(
                'My Items',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              student.purchasedItems.isEmpty
                  ? Text(
                      'No items bought yet. Visit the shop!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: scheme.onSurface.withAlpha(120),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: student.purchasedItems.length,
                      itemBuilder: (context, index) {
                        final item = student.purchasedItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: scheme.onSurface.withAlpha(8)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withAlpha(10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.inventory_2_outlined,
                                    color: Color(0xFF3B82F6)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Purchased with ${item.price} coins',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: scheme.onSurface.withAlpha(140),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.check_circle,
                                  color: scheme.primary, size: 20),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
