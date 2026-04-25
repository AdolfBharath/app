import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../screens/login_screen.dart';
import '../providers/mentor_provider.dart';
import '../widgets/mentor_bottom_nav.dart';
import '../widgets/project_review_card.dart';
import '../widgets/question_card.dart';
import 'manage_batch_screen.dart';
import 'manage_course_screen.dart';
import 'mentor_create_announcement_screen.dart';
import 'mentor_notifications_screen.dart';
import 'mentor_notifications_screen.dart';
import 'mentor_profile_screen.dart';
import '../../../../models/question.dart';
import '../../../../config/theme.dart';

class MentorHomeScreen extends StatefulWidget {
  const MentorHomeScreen({super.key});

  static const routeName = '/mentor';

  @override
  State<MentorHomeScreen> createState() => _MentorHomeScreenState();
}

class _MentorHomeScreenState extends State<MentorHomeScreen> {
  int _currentIndex = 2; // Home as default (index 2 in bottom nav)

  @override
  void initState() {
    super.initState();
    // Kick off mentor data loading once the widget is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      () async {
        final auth = context.read<AuthProvider>();
        await auth.refreshCurrentUser();
        if (!mounted) return;
        await context.read<MentorProvider>().loadAll();
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().currentUser;
    final mentorProvider = context.watch<MentorProvider>();
    final username = authUser?.username ?? authUser?.name ?? 'Mentor';

    final pages = [
      ManageCourseScreen(username: username),
      ManageBatchScreen(username: username),
      _MentorDashboard(username: username, provider: mentorProvider),
      MentorProfileScreen(username: username),
    ];

    return Scaffold(
      backgroundColor: LmsAdminTheme.backgroundLight,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: MentorBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          context.read<MentorProvider>().loadAll();
        },
      ),
    );
  }
}

class _MentorDashboard extends StatefulWidget {
  const _MentorDashboard({required this.username, required this.provider});

  final String username;
  final MentorProvider provider;

  @override
  State<_MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<_MentorDashboard> {
  String _questionFilter = 'Pending';
  String _projectFilter = 'Pending';

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final username = widget.username;
    final authUser = context.watch<AuthProvider>().currentUser;
    final expertise = authUser?.expertise ?? const <String>[];

    final filteredQuestions = provider.questions.where((q) {
      if (_questionFilter == 'Pending') return q.status == QuestionStatus.pending;
      if (_questionFilter == 'Replied') return q.status == QuestionStatus.replied;
      return true;
    }).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: provider.loadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                              'Mentor Dashboard',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: LmsAdminTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Platform overview & management',
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
                            _HeaderActionIcon(
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
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _HeaderActionIcon(
                                  icon: Icons.notifications_none_rounded,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const MentorNotificationsScreen(),
                                      ),
                                    );
                                  },
                                ),
                                if (provider.notifications.isNotEmpty)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            _HeaderActionIcon(
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
                    const SizedBox(height: 20),
                    Text(
                      'Welcome back, $username 👋',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ExpertiseCard(username: username, expertise: expertise),
                    const SizedBox(height: 28),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Recent Questions',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: LmsAdminTheme.textDark,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Pending',
                            isSelected: _questionFilter == 'Pending',
                            onSelected: (val) {
                              setState(() => _questionFilter = 'Pending');
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Replied',
                            isSelected: _questionFilter == 'Replied',
                            onSelected: (val) {
                              setState(() => _questionFilter = 'Replied');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: filteredQuestions.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: LmsAdminTheme.adminCardDecoration(context),
                        child: Column(
                          children: [
                            Icon(Icons.question_answer_outlined, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'No ${_questionFilter.toLowerCase()} questions',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            QuestionCard(question: filteredQuestions[index]),
                        childCount: filteredQuestions.length,
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: Row(
                  children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Projects to Review',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: LmsAdminTheme.textDark,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Pending',
                        isSelected: _projectFilter == 'Pending',
                        onSelected: (val) {
                          setState(() => _projectFilter = 'Pending');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Completed',
                        isSelected: _projectFilter == 'Completed',
                        onSelected: (val) {
                          setState(() => _projectFilter = 'Completed');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      ProjectReviewCard(project: provider.projects[index]),
                  childCount: provider.projects.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ExpertiseCard extends StatelessWidget {
  const _ExpertiseCard({required this.username, required this.expertise});

  final String username;
  final List<String> expertise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              color: Color(0xFF3B82F6),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: LmsAdminTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Professional Mentor',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: LmsAdminTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (expertise.isEmpty
                          ? const <String>['Verified Mentor']
                          : expertise.take(4).toList())
                      .map(_TagChip.new)
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1E40AF),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!isSelected),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B), 
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderActionIcon extends StatelessWidget {
  const _HeaderActionIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}
