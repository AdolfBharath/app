import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/theme.dart';
import '../../../../models/batch.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/batch_provider.dart';
import '../../../../providers/config_provider.dart';
import '../../../../screens/login_screen.dart';
import '../providers/student_nav_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_header_row.dart';
import '../widgets/student_hero_card.dart';
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
      context.read<ConfigProvider>().loadConfig();
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<StudentProvider>().fetchPurchasedItems(
          auth.currentUser!.id,
        );
      }
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

  String _referenceIdFor({
    required String? referralKey,
    required String? adminNo,
    required String? userId,
    required String fallback,
  }) {
    final savedReferralKey = referralKey?.trim();
    if (savedReferralKey != null && savedReferralKey.isNotEmpty) {
      return savedReferralKey;
    }
    final savedReference = adminNo?.trim();
    if (savedReference != null && savedReference.isNotEmpty) {
      return savedReference;
    }
    final savedUserId = userId?.trim();
    if (savedUserId != null && savedUserId.isNotEmpty) {
      final compact = savedUserId.replaceAll('-', '').toUpperCase();
      return 'JNV-${compact.substring(0, compact.length < 8 ? compact.length : 8)}';
    }
    final seed = fallback.trim();
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return 'JNV-${hash.toRadixString(36).toUpperCase().padLeft(6, '0')}';
  }

  Future<void> _openGoogleForm(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      _showBanner(
        'Student reference form link is not configured yet.',
        isError: true,
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!opened && mounted) {
      _showBanner('Unable to open student reference form.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final student = context.watch<StudentProvider>();
    final auth = context.watch<AuthProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final formUrl = context.watch<ConfigProvider>().studentReferenceFormUrl;
    final user = auth.currentUser;

    final displayName = user?.username ?? user?.name ?? widget.username;
    final displayEmail = user?.email ?? widget.email;
    final displayPhone = user?.phone?.trim().isNotEmpty == true
        ? user!.phone!
        : '—';
    final referenceId = _referenceIdFor(
      referralKey: user?.referralKey,
      adminNo: user?.adminNo,
      userId: user?.id,
      fallback: displayEmail,
    );

    Batch? batch;
    if (user?.batchId != null) {
      try {
        batch = batchProvider.batches.firstWhere((b) => b.id == user!.batchId);
      } catch (_) {
        batch = null;
      }
    }

    // Build items list imperatively to avoid web "elements is not iterable"
    final items = <Widget>[];

    // ── Header ──────────────────────────────────
    items.add(
      StudentHeaderRow(
        showProfile: false,
        showLogout: true,
        onNotificationsTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudentNotificationsScreen()),
        ),
        onLogoutTap: () {
          auth.logout();
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(LoginScreen.routeName, (r) => false);
        },
      ),
    );
    items.add(const SizedBox(height: 16));

    // Title + edit button
    items.add(
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                  .push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const StudentEditProfileScreen(),
                    ),
                  )
                  .then((updated) {
                    if (!mounted) return;
                    if (updated == true) {
                      _showBanner('Profile updated successfully.');
                    }
                  });
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Edit Profile'),
          ),
        ],
      ),
    );
    items.add(const SizedBox(height: 18));

    // ── Hero card ────────────────────────────────
    items.add(
      StudentHeroCard(
        username: displayName,
        subtitle: displayEmail,
        coins: student.coins,
        streakDays: student.streakCount,
        gender: student.gender,
        profileImageBytes: student.profileImageBytes,
        profilePicUrl: user?.profilePic,
        footer: HeroWeeklyFooter(
          loggedInOnDay: student.loggedInOnDay,
          streakCount: student.streakCount,
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
    );
    items.add(const SizedBox(height: 22));

    // ── Quick access ─────────────────────────────
    items.add(Text('Quick Access', style: theme.textTheme.titleSmall));
    items.add(const SizedBox(height: 12));
    items.add(
      Row(
        children: <Widget>[
          Expanded(
            child: _QuickTile(
              icon: Icons.school_outlined,
              label: 'My Courses',
              sub: 'View enrolled',
              color: scheme.primary,
              onTap: () => context.read<StudentNavProvider>().setIndex(1),
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
                MaterialPageRoute(builder: (_) => const StudentRewardsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
    items.add(const SizedBox(height: 10));
    items.add(
      Row(
        children: <Widget>[
          Expanded(
            child: _QuickTile(
              icon: Icons.groups_2_outlined,
              label: 'Batch',
              sub: batch?.name ?? 'Not assigned',
              color: const Color(0xFF8B5CF6),
              onTap: () => context.read<StudentNavProvider>().setIndex(2),
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
                MaterialPageRoute(builder: (_) => const StudentSupportScreen()),
              ),
            ),
          ),
        ],
      ),
    );
    items.add(const SizedBox(height: 10));
    items.add(
      Row(
        children: <Widget>[
          Expanded(
            child: _QuickTile(
              icon: Icons.question_answer_outlined,
              label: 'My Questions',
              sub: 'Replies & history',
              color: const Color(0xFFF43F5E),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StudentQuestionsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ReferenceQuickTile(
              referenceId: referenceId,
              formUrl: formUrl,
              onOpenForm: () => _openGoogleForm(formUrl),
            ),
          ),
        ],
      ),
    );
    items.add(const SizedBox(height: 22));

    // ── Batch info card ──────────────────────────
    items.add(Text('Batch Info', style: theme.textTheme.titleSmall));
    items.add(const SizedBox(height: 12));
    items.add(
      _InfoCard(
        child: Row(
          children: <Widget>[
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
                children: <Widget>[
                  Text(
                    batch?.name ?? 'No batch assigned',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
          ],
        ),
      ),
    );
    items.add(const SizedBox(height: 22));

    // ── Learning history ─────────────────────────
    if (student.enrolledCourses.isNotEmpty) {
      items.add(Text('Learning History', style: theme.textTheme.titleSmall));
      items.add(const SizedBox(height: 12));
      final courseWidgets = <Widget>[];
      for (final course in student.enrolledCourses.take(3)) {
        courseWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Recently viewed',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: scheme.onSurface.withAlpha(120),
                ),
              ],
            ),
          ),
        );
      }
      items.add(_InfoCard(child: Column(children: courseWidgets)));
      items.add(const SizedBox(height: 22));
    }

    // ── My Rewards ───────────────────────────────
    if (student.purchasedItems.isNotEmpty) {
      items.add(Text('My Rewards', style: theme.textTheme.titleSmall));
      items.add(const SizedBox(height: 12));
      final rewardWidgets = <Widget>[];
      for (final item in student.purchasedItems) {
        rewardWidgets.add(
          Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12, bottom: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.onSurface.withAlpha(8)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: theme.shadowColor.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Owned',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      items.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: rewardWidgets),
        ),
      );
      items.add(const SizedBox(height: 22));
    }

    // ── Account settings ─────────────────────────
    items.add(Text('Account Settings', style: theme.textTheme.titleSmall));
    items.add(const SizedBox(height: 12));
    items.add(
      _InfoCard(
        child: Column(
          children: <Widget>[
            _AccountField(label: 'Username', value: displayName),
            _Divider(),
            _AccountField(label: 'Email', value: displayEmail),
            _Divider(),
            _AccountField(label: 'Phone', value: displayPhone),
            _Divider(),
            _AccountField(label: 'Batch', value: batch?.name ?? '—'),
            _Divider(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  auth.logout();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    LoginScreen.routeName,
                    (r) => false,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: scheme.error.withAlpha(14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          color: scheme.error,
                          size: 18,
                        ),
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
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: scheme.error,
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
    items.add(const SizedBox(height: 100));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          itemCount: items.length,
          itemBuilder: (context, index) => items[index],
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
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: scheme.onSurface.withAlpha(140),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Info card wrapper ────────────────────────────────────────────────────────
class _ReferenceQuickTile extends StatelessWidget {
  const _ReferenceQuickTile({
    required this.referenceId,
    required this.formUrl,
    required this.onOpenForm,
  });

  final String referenceId;
  final String formUrl;
  final VoidCallback onOpenForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasForm = formUrl.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenForm,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.primary.withAlpha(45)),
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
                  color: scheme.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.primary.withAlpha(35)),
                ),
                child: Icon(
                  Icons.badge_outlined,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Reference',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      referenceId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      hasForm
                          ? 'Refer friends • cashback up to Rs.3000'
                          : 'Form not set',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasForm ? Icons.open_in_new_rounded : Icons.link_off_rounded,
                size: 15,
                color: hasForm
                    ? scheme.primary
                    : scheme.onSurface.withAlpha(120),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
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
