import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/batch.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/batch_provider.dart';
import '../../../../screens/login_screen.dart';
import '../providers/student_nav_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_header_row.dart';
import '../widgets/student_hero_card.dart';
import '../widgets/weekly_fire_tracker.dart';
import 'student_edit_profile_screen.dart';
import 'student_notifications_screen.dart';
import 'student_rewards_screen.dart';
import 'student_support_screen.dart';
import 'student_questions_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({
    super.key,
    required this.username,
    required this.email,
  });

  final String username;
  final String email;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  void _showBanner(String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: isError ? scheme.errorContainer : scheme.surface,
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isError ? scheme.onErrorContainer : scheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('OK'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!context.mounted) return;
      messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final student = context.watch<StudentProvider>();
    final auth = context.watch<AuthProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final user = auth.currentUser;

    final displayName = user?.username ?? user?.name ?? widget.username;
    final displayEmail = user?.email ?? widget.email;
    final displayPhone =
        user?.phone?.trim().isNotEmpty == true ? user!.phone! : '—';

    Batch? batch;
    if (user?.batchId != null) {
      try {
        batch = batchProvider.batches.firstWhere((b) => b.id == user!.batchId);
      } catch (_) {
        batch = null;
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Header ──────────────────────────────────
                  StudentHeaderRow(
                    showProfile: false,
                    showLogout: true,
                    onNotificationsTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const StudentNotificationsScreen()),
                    ),
                    onLogoutTap: () {
                      auth.logout();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          LoginScreen.routeName, (r) => false);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Title + edit button
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Profile', style: theme.textTheme.titleLarge),
                            Text(
                              'Manage your account & preferences',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withAlpha(160),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context)
                              .push<bool>(MaterialPageRoute(
                            builder: (_) => const StudentEditProfileScreen(),
                          ))
                              .then((updated) {
                            if (!mounted) return;
                            if (updated == true) {
                              _showBanner('Profile updated successfully.');
                            }
                          });
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── Hero card ────────────────────────────────
                  StudentHeroCard(
                    username: displayName,
                    subtitle: displayEmail,
                    coins: student.coins,
                    streakDays: student.streakCount,
                    gender: student.gender,
                    profileImageBytes: student.profileImageBytes,
                    footer: HeroWeeklyFooter(
                      loggedInOnDay: student.loggedInOnDay,
                      streakCount: student.streakCount,
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),

                  const SizedBox(height: 22),

                  // ── Quick access ─────────────────────────────
                  Text('Quick Access', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.school_outlined,
                          label: 'My Courses',
                          sub: 'View enrolled',
                          color: scheme.primary,
                          onTap: () =>
                              context.read<StudentNavProvider>().setIndex(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.emoji_events_outlined,
                          label: 'Rewards',
                          sub: 'Coins & streak',
                          color: LmsAdminTheme.coinGold,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const StudentRewardsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.groups_2_outlined,
                          label: 'Batch',
                          sub: batch?.name ?? 'Not assigned',
                          color: const Color(0xFF8B5CF6),
                          onTap: () =>
                              context.read<StudentNavProvider>().setIndex(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.support_agent_outlined,
                          label: 'Support',
                          sub: 'Get help',
                          color: const Color(0xFF10B981),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const StudentSupportScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickTile(
                          icon: Icons.question_answer_outlined,
                          label: 'My Questions',
                          sub: 'Replies & history',
                          color: const Color(0xFFF43F5E),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const StudentQuestionsScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ── Batch info card ──────────────────────────
                  Text('Batch Info', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _InfoCard(
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.group_outlined, color: scheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch?.name ?? 'No batch assigned',
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                batch == null
                                    ? 'You will be assigned to a batch soon.'
                                    : 'Mentor: ${batch.mentorId != null ? 'Assigned' : 'TBD'}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface.withAlpha(160),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (batch != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Active',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Learning history ─────────────────────────
                  if (student.enrolledCourses.isNotEmpty) ...[
                    Text('Learning History', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    _InfoCard(
                      child: Column(
                        children: [
                          ...student.enrolledCourses.take(3).map((course) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withAlpha(14),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.menu_book_outlined,
                                          color: scheme.primary, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            course.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            'Recently viewed',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: scheme.onSurface
                                                  .withAlpha(140),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios_rounded,
                                        size: 13,
                                        color:
                                            scheme.onSurface.withAlpha(120)),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // ── Account settings ─────────────────────────
                  Text('Account Settings', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _InfoCard(
                    child: Column(
                      children: [
                        _AccountField(label: 'Username', value: displayName),
                        _Divider(),
                        _AccountField(label: 'Email', value: displayEmail),
                        _Divider(),
                        _AccountField(label: 'Phone', value: displayPhone),
                        _Divider(),
                        _AccountField(
                            label: 'Batch', value: batch?.name ?? '—'),
                        _Divider(),
                        // Logout row
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              auth.logout();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  LoginScreen.routeName, (r) => false);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color:
                                          scheme.error.withAlpha(14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.logout_rounded,
                                        color: scheme.error, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Log Out',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.error,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 13, color: scheme.error),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick access tile ────────────────────────────────────────────────────────
class _QuickTile extends StatefulWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.onSurface.withAlpha(10)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withAlpha(7),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color.withAlpha(35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(widget.icon, color: widget.color, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(widget.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface.withAlpha(140),
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: scheme.onSurface.withAlpha(140)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info card wrapper ────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withAlpha(8)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(7),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Account field ────────────────────────────────────────────────────────────
class _AccountField extends StatelessWidget {
  const _AccountField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: scheme.onSurface.withAlpha(120),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.onSurface.withAlpha(8),
    );
  }
}
