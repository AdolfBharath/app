import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../features/student/presentation/screens/batch_chat_screen.dart';
import '../../../../models/batch.dart';
import '../../../../models/user.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../screens/login_screen.dart';
import '../../../../screens/batch_tasks_screen.dart';
import 'mentor_create_announcement_screen.dart';
import 'mentor_notifications_screen.dart';
import '../providers/mentor_provider.dart';
import '../../../../config/theme.dart';

class ManageBatchScreen extends StatelessWidget {
  const ManageBatchScreen({super.key, required this.username});

  final String username;

  void _showBatchDetails(BuildContext context, Batch batch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BatchActionBottomSheet(
        title: 'Batch Details - ${batch.name}',
        content: 'Student List and Top Performers go here.',
      ),
    );
  }

  void _showAssignTask(BuildContext context, Batch batch) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchTasksScreen(
          batchId: batch.id,
          batchName: batch.name,
          canCreate: true,
          canReview: true,
        ),
      ),
    );
  }

  void _showChatMonitor(BuildContext context, Batch batch) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchChatScreen(batchId: batch.id, batchName: batch.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mentorProvider = context.watch<MentorProvider>();
    final batches = mentorProvider.batches;

    return SafeArea(
      child: Scaffold(
        backgroundColor: LmsAdminTheme.backgroundLight,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 4,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batches',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: LmsAdminTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Student batches & performance',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _BatchActionIcon(
                              icon: Icons.campaign_outlined,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MentorCreateAnnouncementScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _BatchActionIcon(
                              icon: Icons.notifications_none_rounded,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MentorNotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _BatchActionIcon(
                              icon: Icons.logout_rounded,
                              onTap: () {
                                final auth = context.read<AuthProvider>();
                                auth.logout();
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  LoginScreen.routeName,
                                  (route) => false,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: LmsAdminTheme.adminCardDecoration(context),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.layers_rounded,
                              color: Color(0xFF3B82F6),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Batches',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${batches.length} batches • ${batches.fold(0, (sum, b) => sum + b.enrolledCount)} students',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (batches.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.layers_outlined,
                          color: Color(0xFF3B82F6),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No batches assigned',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Batches will appear here once assigned',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final batch = batches[index];
                    return _BatchCard(
                      batch: batch,
                      onView: () => _showBatchDetails(context, batch),
                      onAssign: () => _showAssignTask(context, batch),
                      onChat: () => _showChatMonitor(context, batch),
                    );
                  }, childCount: batches.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final VoidCallback onView;
  final VoidCallback onAssign;
  final VoidCallback onChat;

  const _BatchCard({
    required this.batch,
    required this.onView,
    required this.onAssign,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    color: Color(0xFF3B82F6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        batch.startDate != null
                            ? 'Started ${batch.startDate!.toLocal().toString().split(' ')[0]}'
                            : 'Start Date: TBD',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${batch.enrolledCount}/${batch.capacity ?? '∞'}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BatchActionButton(
                    label: 'View',
                    icon: Icons.visibility_outlined,
                    onTap: onView,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BatchActionButton(
                    label: 'Assign',
                    icon: Icons.assignment_outlined,
                    onTap: onAssign,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _BatchActionButton(
                    label: 'Chat',
                    icon: Icons.chat_bubble_outline,
                    onTap: onChat,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _BatchActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BatchActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}

class _BatchActionBottomSheet extends StatelessWidget {
  final String title;
  final String content;

  const _BatchActionBottomSheet({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
