import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../config/theme.dart';
import '../../../../models/course.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../screens/course_detail_screen.dart';
import '../providers/student_nav_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_header_row.dart';
import '../widgets/student_hero_card.dart';
import 'student_chat_screen.dart';
import 'student_notifications_screen.dart';

enum _CourseSortMode { top, popular, recent }

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, required this.username});
  final String username;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Top';
  bool _showStreakPopup = true;
  final Set<String> _categoryFilters = {};
  final Set<CourseDifficulty> _difficultyFilters = {};
  _CourseSortMode _sortMode = _CourseSortMode.top;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showStreakPopup = false);
    });
  }

  bool get _hasActiveFilters =>
      _categoryFilters.isNotEmpty ||
      _difficultyFilters.isNotEmpty ||
      _sortMode != _CourseSortMode.top;

  Future<void> _openFilters(List<_CategoryItem> categories) async {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final allCategoryLabels = categories
        .where((c) => c.label != 'Top')
        .map((c) => c.label)
        .toList(growable: false);

    var selectedCategories = Set<String>.from(_categoryFilters);
    var selectedDifficulties = Set<CourseDifficulty>.from(_difficultyFilters);
    var sortMode = _sortMode;
    var applied = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20, 8, 20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter Courses',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  _FilterSection(
                    title: 'Sort by',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _CourseSortMode.values)
                          _FilterChip(
                            label: m.name[0].toUpperCase() + m.name.substring(1),
                            selected: sortMode == m,
                            onTap: () => setModalState(() => sortMode = m),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FilterSection(
                    title: 'Categories',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allCategoryLabels.map((label) {
                        final sel = selectedCategories.contains(label);
                        return _FilterChip(
                          label: label,
                          selected: sel,
                          onTap: () => setModalState(() =>
                              sel ? selectedCategories.remove(label) : selectedCategories.add(label)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FilterSection(
                    title: 'Difficulty',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CourseDifficulty.beginner,
                        CourseDifficulty.intermediate,
                        CourseDifficulty.advanced,
                      ].map((level) {
                        final label = level.name[0].toUpperCase() + level.name.substring(1);
                        final sel = selectedDifficulties.contains(level);
                        return _FilterChip(
                          label: label,
                          selected: sel,
                          onTap: () => setModalState(() =>
                              sel ? selectedDifficulties.remove(level) : selectedDifficulties.add(level)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setModalState(() {
                          selectedCategories.clear();
                          selectedDifficulties.clear();
                          sortMode = _CourseSortMode.top;
                        }),
                        child: const Text('Clear all'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          applied = true;
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Apply Filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!mounted || !applied) return;
    setState(() {
      _categoryFilters..clear()..addAll(selectedCategories);
      _difficultyFilters..clear()..addAll(selectedDifficulties);
      _sortMode = sortMode;
      _selectedCategory =
          _categoryFilters.length == 1 ? _categoryFilters.first : 'Top';
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>();
    final courses = student.allCourses;
    final enrolledCourses = student.enrolledCourses;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final categories = _buildCategories(courses);
    final categoryLabels = categories.map((c) => c.label).toSet();
    if (!categoryLabels.contains(_selectedCategory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedCategory = 'Top');
      });
    }

    final filteredCourses = _filterCourses(courses);
    final popularCourses = [...courses]
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudentChatScreen()),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.smart_toy_outlined),
        label: Text('Ask AI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final p = context.read<StudentProvider>();
            final auth = context.read<AuthProvider>();
            await auth.refreshCurrentUser();
            final assignedCourseIds = auth.currentUser?.courseIds ?? const <String>[];
            await p.fetchCourses(assignedCourseIds: assignedCourseIds);
            await p.fetchNotifications();
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
                        MaterialPageRoute(builder: (_) => const StudentNotificationsScreen()),
                      ),
                      onProfileTap: () => context.read<StudentNavProvider>().setIndex(4),
                    ),
                    const SizedBox(height: 16),

                    if (_showStreakPopup) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8D4FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.military_tech_rounded, color: Color(0xFF9333EA), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Streak Updated',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6B21A8),
                                    ),
                                  ),
                                  Text(
                                    '+1 Coin',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF9333EA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showStreakPopup = false),
                              child: const Icon(Icons.close_rounded, color: Color(0xFF9333EA), size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Hero card with embedded weekly tracker
                    StudentHeroCard(
                      username: widget.username,
                      subtitle: 'Ready to learn something new today?',
                      coins: student.coins,
                      streakDays: student.streakCount,
                      gender: student.gender,
                      profileImageBytes: student.profileImageBytes,
                      onTap: () => context.read<StudentNavProvider>().setIndex(4),
                      footer: HeroWeeklyFooter(
                        loggedInOnDay: student.loggedInOnDay,
                        streakCount: student.streakCount,
                      ),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),

                    const SizedBox(height: 20),

                    // Search & Filter
                    Row(
                      children: [
                        Expanded(
                          child: _SearchBar(
                            hintText: 'Search courses...',
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _FilterButton(
                          active: _hasActiveFilters,
                          onTap: () => _openFilters(categories),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Categories
                    _SectionHeader(title: 'Categories', action: 'See All', onAction: () {}),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(categories.length > 8 ? 8 : categories.length, (i) {
                        final item = categories[i];
                        return _CategoryCard(
                          label: item.label,
                          icon: item.icon,
                          color: _categoryColor(scheme, i),
                          onTap: () => setState(() {
                            _selectedCategory = item.label;
                            _categoryFilters
                              ..clear()
                              ..addAll(item.label == 'Top' ? const [] : [item.label]);
                          }),
                        );
                      }),
                    ),

                    const SizedBox(height: 22),

                    // Your courses
                    _SectionHeader(
                      title: 'Your Courses',
                      badge: '${enrolledCourses.length} Active',
                      badgeColor: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                    if (enrolledCourses.isEmpty)
                      _EmptyState(
                        icon: Icons.school_outlined,
                        message: 'No enrolled courses yet',
                        sub: 'Browse categories below to get started',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: enrolledCourses.length > 2 ? 2 : enrolledCourses.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final course = enrolledCourses[i];
                          return _CourseDiscoveryCard(
                            course: course,
                            index: i,
                            onTap: () => Navigator.of(context)
                                .pushNamed(CourseDetailScreen.routeName, arguments: course.id),
                          );
                        },
                      ),

                    const SizedBox(height: 22),

                    // Filtered / category section
                    _SectionHeader(title: _selectedCategory),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: filteredCourses.isEmpty
                          ? _EmptyState(
                              key: ValueKey('empty_$_selectedCategory'),
                              icon: Icons.search_off_rounded,
                              message: 'No courses found',
                            )
                          : ListView.separated(
                              key: ValueKey('list_$_selectedCategory'),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  filteredCourses.length > 3 ? 3 : filteredCourses.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final course = filteredCourses[i];
                                return _CourseDiscoveryCard(
                                  course: course,
                                  index: i,
                                  onTap: () => Navigator.of(context).pushNamed(
                                    CourseDetailScreen.routeName,
                                    arguments: course.id,
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 22),

                    // Popular courses
                    _SectionHeader(title: 'Popular Courses', action: 'Explore', onAction: () {}),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount:
                            popularCourses.length > 10 ? 10 : popularCourses.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final course = popularCourses[i];
                          return _PopularCourseCard(
                            course: course,
                            studentCount: 1200 + (i * 245),
                            onTap: () => Navigator.of(context).pushNamed(
                              CourseDetailScreen.routeName,
                              arguments: course.id,
                            ),
                          );
                        },
                      ),
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

  // ── helpers ──────────────────────────────────────────────────────────────
  List<Course> _filterCourses(List<Course> courses) {
    final query = _searchQuery.trim().toLowerCase();

    bool matchesSearch(Course c) {
      if (query.isEmpty) return true;
      return c.title.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }

    bool matchesCategory(Course c) {
      if (_categoryFilters.isEmpty) return true;
      final category = _normalizedCategory(c);
      return _categoryFilters
          .any((l) => l.toLowerCase() == category.toLowerCase());
    }

    bool matchesDifficulty(Course c) {
      if (_difficultyFilters.isEmpty) return true;
      return _difficultyFilters.contains(c.difficulty);
    }

    final list = courses
        .where((c) => matchesSearch(c) && matchesCategory(c) && matchesDifficulty(c))
        .toList();

    switch (_sortMode) {
      case _CourseSortMode.top:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _CourseSortMode.popular:
        list.sort((a, b) {
          final f = (b.isFeatured ? 1 : 0) - (a.isFeatured ? 1 : 0);
          if (f != 0) return f;
          final r = b.rating.compareTo(a.rating);
          if (r != 0) return r;
          return a.title.compareTo(b.title);
        });
      case _CourseSortMode.recent:
        break;
    }
    return list;
  }

  Color _categoryColor(ColorScheme scheme, int index) {
    final options = [
      scheme.primary,
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFFF59E0B),
    ];
    return options[index % options.length];
  }

  List<_CategoryItem> _buildCategories(List<Course> courses) {
    final Set<String> raw = {};
    var sawUncategorized = false;

    for (final c in courses) {
      final cat = c.category.trim();
      if (cat.isEmpty) {
        sawUncategorized = true;
      } else {
        raw.add(cat);
      }
    }

    final preferredOrder = <String>[
      'UI/UX', 'Web Development', 'Mobile Development', 'AI', 'General',
    ];

    final List<String> ordered = raw.toList()
      ..sort((a, b) {
        final ai = preferredOrder.indexOf(a);
        final bi = preferredOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    if (sawUncategorized && !raw.contains('General')) {
      ordered.add('General');
    }

    final items = <_CategoryItem>[
      const _CategoryItem('Top', Icons.trending_up_rounded),
    ];
    items.addAll(ordered.map((l) => _CategoryItem(l, _iconForCategory(l))));
    return items;
  }

  String _normalizedCategory(Course course) {
    final cat = course.category.trim();
    return cat.isEmpty ? 'General' : cat;
  }

  IconData _iconForCategory(String label) {
    switch (label.toLowerCase()) {
      case 'ui/ux':              return Icons.palette_outlined;
      case 'web development':   return Icons.language_rounded;
      case 'mobile development':return Icons.phone_iphone_rounded;
      case 'ai':                 return Icons.auto_awesome_rounded;
      case 'general':            return Icons.category_rounded;
      default:                   return Icons.category_outlined;
    }
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _CategoryItem {
  const _CategoryItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

// Section header with optional badge or action link
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.badge,
    this.badgeColor,
    this.action,
    this.onAction,
  });

  final String title;
  final String? badge;
  final Color? badgeColor;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (badgeColor ?? scheme.primary).withValues(alpha: 18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeColor ?? scheme.primary,
              ),
            ),
          ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// Search bar
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF1F2937),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF9CA3AF),
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24), // fully rounded pill
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.tune_rounded,
          color: active ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
          size: 20,
        ),
      ),
    );
  }
}

// Category card strictly following image
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24), // Circular/Squircle match image
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label == 'Top' ? 'All' : label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

// Course discovery card (horizontal)
class _CourseDiscoveryCard extends StatefulWidget {
  const _CourseDiscoveryCard({
    required this.course,
    required this.onTap,
    required this.index,
  });

  final Course course;
  final VoidCallback onTap;
  final int index;

  @override
  State<_CourseDiscoveryCard> createState() => _CourseDiscoveryCardState();
}

class _CourseDiscoveryCardState extends State<_CourseDiscoveryCard> {
  bool _pressed = false;

  static const _diffColors = [
    Color(0xFF10B981), // beginner – green
    Color(0xFFF59E0B), // intermediate – amber
    Color(0xFFEF4444), // advanced – red
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final course = widget.course;

    final diffColor = switch (course.difficulty) {
      CourseDifficulty.beginner     => _diffColors[0],
      CourseDifficulty.intermediate => _diffColors[1],
      CourseDifficulty.advanced     => _diffColors[2],
    };
    final badgeBg = diffColor.withValues(alpha: 28);
    final badgeTextColor =
        ThemeData.estimateBrightnessForColor(badgeBg) == Brightness.dark
            ? Colors.white
            : const Color(0xFF1F2937);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.98 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 10)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 8),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                child: SizedBox(
                  width: 100,
                  height: 88,
                  child: course.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          course.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _ThumbPlaceholder(
                              color: scheme.primary.withValues(alpha: 20),
                              icon: Icons.play_circle_outline_rounded,
                              iconColor: scheme.primary),
                        )
                      : _ThumbPlaceholder(
                          color: scheme.primary.withValues(alpha: 20),
                          icon: Icons.play_circle_outline_rounded,
                          iconColor: scheme.primary),
                ),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: diffColor.withValues(alpha: 65)),
                            ),
                            child: Text(
                              course.difficulty.name[0].toUpperCase() +
                                  course.difficulty.name.substring(1),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                          if (course.isFeatured) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.star_rounded, size: 13, color: LmsAdminTheme.coinGold),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: scheme.onSurface.withValues(alpha: 140)),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 60))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

// Popular course card (vertical, horizontal scroll)
class _PopularCourseCard extends StatefulWidget {
  const _PopularCourseCard({
    required this.course,
    required this.studentCount,
    required this.onTap,
  });

  final Course course;
  final int studentCount;
  final VoidCallback onTap;

  @override
  State<_PopularCourseCard> createState() => _PopularCourseCardState();
}

class _PopularCourseCardState extends State<_PopularCourseCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final course = widget.course;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1.0,
        child: SizedBox(
          width: 220,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.onSurface.withValues(alpha: 10)),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 8),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: course.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            course.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ThumbPlaceholder(
                                color: scheme.primary.withValues(alpha: 20),
                                icon: Icons.play_circle_outline_rounded,
                                iconColor: scheme.primary),
                          )
                        : _ThumbPlaceholder(
                            color: scheme.primary.withValues(alpha: 20),
                            icon: Icons.play_circle_outline_rounded,
                            iconColor: scheme.primary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14, color: LmsAdminTheme.coinGold),
                          const SizedBox(width: 3),
                          Text(
                            course.rating.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.people_alt_outlined,
                              size: 14,
                              color: const Color(0xFF9CA3AF)),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.studentCount}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
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
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  final Color color;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Center(child: Icon(icon, color: iconColor, size: 32)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.icon, required this.message, this.sub});

  final IconData icon;
  final String message;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.onSurface.withValues(alpha: 80)),
          const SizedBox(height: 8),
          Text(message,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 160))),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 120))),
          ],
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 200))),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 14),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : scheme.onSurface.withValues(alpha: 200),
          ),
        ),
      ),
    );
  }
}
