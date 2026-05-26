import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/batch.dart';
import '../../../../models/batch_detail.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/batch_provider.dart';
import '../../../../screens/batch_tasks_screen.dart';
import '../../../../services/api_service.dart';
import '../providers/student_nav_provider.dart';
import '../widgets/student_header_row.dart';
import 'batch_chat_screen.dart';
import 'student_notifications_screen.dart';
import 'package:my_app/utils/ui_utils.dart';

class StudentBatchScreen extends StatefulWidget {
  const StudentBatchScreen({super.key});

  @override
  State<StudentBatchScreen> createState() => _StudentBatchScreenState();
}

class _StudentBatchScreenState extends State<StudentBatchScreen> {
  bool _loaded = false;
  String? _selectedBatchId;
  final Map<String, BatchDetail> _batchDetails = <String, BatchDetail>{};
  final Set<String> _loadingDetails = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  Future<void> _loadBatchDetails(String batchId) async {
    if (batchId.trim().isEmpty ||
        _batchDetails.containsKey(batchId) ||
        _loadingDetails.contains(batchId)) {
      return;
    }
    if (!mounted) return;
    setState(() => _loadingDetails.add(batchId));
    try {
      final detail = await ApiService.instance.getBatchDetails(batchId);
      if (!mounted) return;
      setState(() => _batchDetails[batchId] = detail);
    } catch (_) {
      // Keep the page usable when leaderboard data is temporarily unavailable.
    } finally {
      if (mounted) setState(() => _loadingDetails.remove(batchId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final user = auth.currentUser;

    final assignedBatchIds = <String>{
      ...?user?.batchIds,
      if (user?.batchId?.trim().isNotEmpty == true) user!.batchId!,
    };
    final assigned = batchProvider.batches
        .where((b) => assignedBatchIds.contains(b.id))
        .toList(growable: false);
    if ((_selectedBatchId == null ||
            !assigned.any((b) => b.id == _selectedBatchId)) &&
        assigned.isNotEmpty) {
      _selectedBatchId = assigned.first.id;
    }
    Batch? myBatch;
    for (final batch in assigned) {
      if (batch.id == _selectedBatchId) {
        myBatch = batch;
        break;
      }
    }
    myBatch ??= assigned.isNotEmpty ? assigned.first : null;
    if (myBatch != null &&
        !_batchDetails.containsKey(myBatch.id) &&
        !_loadingDetails.contains(myBatch.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadBatchDetails(myBatch!.id);
      });
    }
    final selectedDetail = myBatch == null ? null : _batchDetails[myBatch.id];
    final leaderboard =
        selectedDetail?.topPerformers ?? const <StudentPerformance>[];
    final isLeaderboardLoading =
        myBatch != null && _loadingDetails.contains(myBatch.id);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<BatchProvider>().loadBatches();
            if (!mounted) return;
            final batchId = _selectedBatchId;
            if (batchId != null) {
              setState(() => _batchDetails.remove(batchId));
              await _loadBatchDetails(batchId);
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header
                    StudentHeaderRow(
                      onNotificationsTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentNotificationsScreen(),
                        ),
                      ),
                      onProfileTap: () =>
                          context.read<StudentNavProvider>().setIndex(4),
                    ),
                    const SizedBox(height: 16),
                    Text('My Batch', style: theme.textTheme.titleLarge),
                    Text(
                      'Connect, learn and grow together',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withAlpha(160),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Active batch hero card ──────────────────────────
                    _BatchHeroCard(myBatch: myBatch)
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.08, end: 0),

                    if (assigned.length > 1) ...[
                      const SizedBox(height: 12),
                      _BatchSwitcher(
                        batches: assigned,
                        selectedBatchId: myBatch?.id,
                        onSelected: (batchId) {
                          setState(() => _selectedBatchId = batchId);
                          _loadBatchDetails(batchId);
                        },
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Quick actions ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Batch Chat',
                            subtitle: 'Stay in sync',
                            gradient: LmsStudentTheme.heroGradientFor(context),
                            onTap: () {
                              final selectedBatch = myBatch;
                              if (selectedBatch == null) {
                                showTopNotification(
                                  context,
                                  'No batch assigned yet',
                                );
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BatchChatScreen(
                                    batchId: selectedBatch.id,
                                    batchName: selectedBatch.name,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.checklist_rounded,
                            title: 'To-Do List',
                            subtitle: 'Track tasks',
                            gradient: const [
                              Color(0xFF10B981),
                              Color(0xFF06B6D4),
                            ],
                            onTap: () {
                              final selectedBatch = myBatch;
                              if (selectedBatch == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No batch assigned yet',
                                      style: GoogleFonts.inter(),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BatchTasksScreen(
                                    batchId: selectedBatch.id,
                                    batchName: selectedBatch.name,
                                    canSubmit: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Top performers ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Top Performers',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'Leaderboard',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _LeaderboardCard(
                      performers: leaderboard,
                      isLoading: isLeaderboardLoading,
                    ),

                    const SizedBox(height: 24),

                    // ── All batches ────────────────────────────────────
                    Text('All Batches', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    if (batchProvider.batches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.groups_2_outlined,
                                size: 40,
                                color: scheme.onSurface.withAlpha(80),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No batches available yet',
                                style: GoogleFonts.inter(
                                  color: scheme.onSurface.withAlpha(160),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: batchProvider.batches.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final batch = batchProvider.batches[index];
                          final isMine = assignedBatchIds.contains(batch.id);
                          return _BatchListCard(batch: batch, isMine: isMine)
                              .animate(
                                delay: Duration(milliseconds: index * 60),
                              )
                              .fadeIn(duration: 280.ms)
                              .slideX(begin: 0.04, end: 0);
                        },
                      ),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Batch hero card ──────────────────────────────────────────────────────────
class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.performers,
    required this.isLoading,
  });

  final List<StudentPerformance> performers;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = performers.take(5).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withAlpha(10)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : visible.isEmpty
          ? Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: LmsAdminTheme.coinGold,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Leaderboard will appear here once batch performance data is available.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withAlpha(160),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: visible.map((item) {
                final progressPercent = (item.progress * 100).round();
                final subtitle = item.totalAssignments > 0
                    ? '$progressPercent% progress'
                    : 'Progress pending';
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: item == visible.last ? 0 : 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: LmsAdminTheme.coinGold.withAlpha(32),
                        child: Text(
                          '${item.rank}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: LmsAdminTheme.coinGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item.score.toStringAsFixed(0)} pts',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
    );
  }
}

class _BatchHeroCard extends StatelessWidget {
  const _BatchHeroCard({required this.myBatch});

  final dynamic myBatch;

  @override
  Widget build(BuildContext context) {
    final gradColors = LmsStudentTheme.heroGradientFor(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradColors[0].withAlpha(70),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: Text(
              myBatch != null ? 'Active Batch' : 'No Batch Assigned',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            myBatch?.name ?? 'You\'ll be assigned soon',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBubble(
                  icon: Icons.groups_2_rounded,
                  label: 'Students',
                  value: '${myBatch?.enrolledCount ?? 0}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBubble(
                  icon: Icons.auto_graph_rounded,
                  label: 'Progress',
                  value: '${((myBatch?.progress ?? 0.0) * 100).round()}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  const _StatBubble({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(36)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick action card ────────────────────────────────────────────────────────
class _BatchSwitcher extends StatelessWidget {
  const _BatchSwitcher({
    required this.batches,
    required this.selectedBatchId,
    required this.onSelected,
  });

  final List<Batch> batches;
  final String? selectedBatchId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: batches.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final batch = batches[index];
          final selected = batch.id == selectedBatchId;
          return ChoiceChip(
            selected: selected,
            label: Text(
              batch.name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : scheme.onSurface,
              ),
            ),
            avatar: Icon(
              Icons.groups_2_outlined,
              size: 16,
              color: selected ? Colors.white : scheme.primary,
            ),
            selectedColor: scheme.primary,
            backgroundColor: scheme.surface,
            side: BorderSide(
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.12),
            ),
            onSelected: (_) => onSelected(batch.id),
          );
        },
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withAlpha(10)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withAlpha(8),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface.withAlpha(160),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Batch list card ──────────────────────────────────────────────────────────
class _BatchListCard extends StatelessWidget {
  const _BatchListCard({required this.batch, required this.isMine});

  final dynamic batch;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = isMine ? const Color(0xFF10B981) : scheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMine ? accent.withAlpha(40) : scheme.onSurface.withAlpha(10),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withAlpha(18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isMine ? Icons.verified_rounded : Icons.group_outlined,
            color: accent,
            size: 22,
          ),
        ),
        title: Text(
          batch.name,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          isMine ? '✓ Your current batch' : 'Available batch',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isMine ? accent : scheme.onSurface.withAlpha(140),
          ),
        ),
        trailing: isMine
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withAlpha(16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              )
            : Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: scheme.onSurface.withAlpha(140),
              ),
      ),
    );
  }
}
