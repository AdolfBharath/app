import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/mentor/presentation/screens/mentor_notifications_screen.dart';
import '../features/student/presentation/providers/student_provider.dart';
import '../features/student/presentation/screens/student_notifications_screen.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/batch_provider.dart';
import '../providers/course_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'course_detail_screen.dart';
import 'login_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  static const routeName = '/';
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  bool _loaded = false;
  bool _isLoading = false;
  String? _batchesLoadedForUserId;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = _MarketplaceCategories.all;
  int _selectedBottomIndex = 0;
  bool _featuredOnly = false;
  bool _trendingOnly = false;
  _MarketplaceSort _sortMode = _MarketplaceSort.rating;
  final Set<CourseDifficulty> _difficultyFilters = {};

  /// Only fetch the public course catalogue here.
  /// Batches and user lists are JWT-protected and are loaded by each
  /// role's home screen after a successful login.
  Future<void> _loadCourses(BuildContext context) async {
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    setState(() => _isLoading = true);
    await courseProvider.loadCourses();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadBatchesIfAuthed(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) return;
    await Provider.of<BatchProvider>(context, listen: false).loadBatches();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    if (!_loaded) {
      _loaded = true;
      _loadCourses(context);
    }

    final currentUserId = auth.currentUser?.id;
    if (auth.isLoggedIn && currentUserId != null && _batchesLoadedForUserId != currentUserId) {
      _batchesLoadedForUserId = currentUserId;
      _loadBatchesIfAuthed(context);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    final courses = context.watch<CourseProvider>().courses;
    final batches = context.watch<BatchProvider>().batches;
    final student = context.watch<StudentProvider>();

    final query = _searchController.text.trim().toLowerCase();

    final enrolledCourseIds = auth.currentUser?.courseIds.toSet() ?? <String>{};
    final enrolledCountByCourse = <String, int>{};
    for (final b in batches) {
      enrolledCountByCourse.update(
        b.courseId,
        (value) => value + b.enrolledCount,
        ifAbsent: () => b.enrolledCount,
      );
    }

    final categories = _MarketplaceCategories.fromCourses(courses);
    final effectiveSelectedCategory =
        categories.contains(_selectedCategory) ? _selectedCategory : _MarketplaceCategories.all;
    final orbitLabels = _MarketplaceCategories.orbitFromCourses(
      courses,
      selected: effectiveSelectedCategory,
      maxItems: 7,
    );
    final orbitItems = orbitLabels.map(_OrbitItem.fromLabel).toList(growable: false);
    final selectedCategoryIndex = orbitItems.indexWhere((i) => i.label == effectiveSelectedCategory);

    final searched = courses.where((c) {
      if (query.isEmpty) return true;
      final haystack =
          '${c.title} ${c.description} ${c.category} ${c.instructorName}'.toLowerCase();
      return haystack.contains(query);
    }).toList();

    final categoryFiltered = searched.where((c) {
      if (effectiveSelectedCategory == _MarketplaceCategories.all) return true;
      return c.category.trim().toLowerCase() == effectiveSelectedCategory.trim().toLowerCase();
    }).toList();

    final visibleCourses = categoryFiltered.where((c) {
      if (_featuredOnly && !(c.isFeatured)) return false;
      if (_trendingOnly && !_isTrending(c)) return false;
      if (_difficultyFilters.isNotEmpty && !_difficultyFilters.contains(c.difficulty)) {
        return false;
      }
      return true;
    }).toList();

    final trending = _sortCourses(visibleCourses, _sortMode);
    final topCourse = trending.isNotEmpty ? trending.first : null;
    final myCourses = courses.where((c) => enrolledCourseIds.contains(c.id)).toList();
    final profileTitle = auth.currentUser?.name ?? auth.currentUser?.username ?? 'Guest';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _selectedBottomIndex == 0
                  ? _buildHomeTab(
                      context,
                      auth,
                      orbitItems,
                      selectedCategoryIndex >= 0 ? selectedCategoryIndex : 0,
                      visibleCourses,
                      trending,
                      topCourse,
                      enrolledCountByCourse,
                      enrolledCourseIds,
                      _isLoading,
                    )
                  : _selectedBottomIndex == 1
                      ? _buildMyCoursesTab(context, auth, myCourses, enrolledCountByCourse)
                      : _buildProfileTab(context, auth, profileTitle, student.coins),
            ),
            _MarketplaceBottomNav(
              currentIndex: _selectedBottomIndex,
              onHome: () => setState(() => _selectedBottomIndex = 0),
              onCourses: () => setState(() => _selectedBottomIndex = 1),
              onProfile: () {
                setState(() => _selectedBottomIndex = 2);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    AuthProvider auth,
    List<_OrbitItem> orbitItems,
    int selectedCategoryIndex,
    List<Course> visibleCourses,
    List<Course> trending,
    Course? topCourse,
    Map<String, int> enrolledCountByCourse,
    Set<String> enrolledCourseIds,
    bool isLoading,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        _MarketplaceHeaderRow(
          isLoggedIn: auth.isLoggedIn,
          onLoginTap: () => Navigator.of(context).pushNamed(LoginScreen.routeName),
          onNotificationsTap: () => _openNotifications(context, auth),
          onThemeToggle: () => context.read<ThemeProvider>().toggle(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 10)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: scheme.onSurface.withValues(alpha: 160)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search courses, skills...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 42,
                height: 42,
                child: IconButton(
                  onPressed: _openFilters,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surface,
                    foregroundColor: scheme.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: scheme.onSurface.withValues(alpha: 10)),
                  ),
                  icon: Icon(
                    _featuredOnly || _difficultyFilters.isNotEmpty || _trendingOnly
                        ? Icons.tune_rounded
                        : Icons.tune_outlined,
                  ),
                  tooltip: 'Filters',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Discover Learning',
          style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, fontStyle: FontStyle.italic),
        ),
        Text(
          'Select a path to start your journey',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 20),
        Center(
          child: _CategoryOrbit(
            items: orbitItems,
            selectedIndex: selectedCategoryIndex,
            onSelect: (index) {
              if (index < 0 || index >= orbitItems.length) return;
              setState(() => _selectedCategory = orbitItems[index].label);
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Trending Now',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontStyle: FontStyle.italic),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _openCourseListSheet('Trending Now', trending),
              child: Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading && topCourse == null)
          _skeletonFeaturedCard(context)
        else if (topCourse == null)
          _emptyCard(context, 'No courses found for current filters.')
        else
          _featuredCourseCard(
            context,
            topCourse,
            enrolledCount: enrolledCountByCourse[topCourse.id] ?? 0,
            enrolled: enrolledCourseIds.contains(topCourse.id),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Explore Courses',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '${visibleCourses.length}',
              style: text.labelLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 160)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading && visibleCourses.isEmpty)
          ...List.generate(3, (_) => _skeletonListTile(context))
        else if (visibleCourses.isEmpty)
          _emptyCard(context, 'Try changing search or filter settings.')
        else
          ...visibleCourses.take(4).map(
                (c) => _compactCourseCard(
                  context,
                  c,
                  enrolledCount: enrolledCountByCourse[c.id] ?? 0,
                  enrolled: enrolledCourseIds.contains(c.id),
                ),
              ),
      ],
    );
  }

  Widget _buildMyCoursesTab(
    BuildContext context,
    AuthProvider auth,
    List<Course> myCourses,
    Map<String, int> enrolledCountByCourse,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(
          'My Courses',
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          auth.isLoggedIn
              ? 'Continue where you left off'
              : 'Log in to save and continue your enrolled courses',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (!auth.isLoggedIn)
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(LoginScreen.routeName),
            child: const Text('Log in to continue'),
          ),
        if (auth.isLoggedIn && myCourses.isEmpty)
          _emptyCard(context, 'No enrolled courses yet. Explore and enroll in a course.'),
        if (auth.isLoggedIn)
          ...myCourses.map(
            (c) => _compactCourseCard(
              context,
              c,
              enrolledCount: enrolledCountByCourse[c.id] ?? 0,
              enrolled: true,
              actionLabel: 'View',
            ),
          ),
        if (auth.isLoggedIn && myCourses.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Tip: Tap a course to open details.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 160),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileTab(
    BuildContext context,
    AuthProvider auth,
    String profileTitle,
    int coins,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(
          'Profile',
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 12)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primary.withValues(alpha: 12),
                child: Icon(Icons.person_outline_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileTitle,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      auth.isLoggedIn ? 'Logged in' : 'Guest user',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed(LoginScreen.routeName),
                child: Text(auth.isLoggedIn ? 'Account' : 'Log in'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 12)),
          ),
          child: Row(
            children: [
              Icon(Icons.toll_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Coins', style: theme.textTheme.titleSmall),
              ),
              Text(
                '$coins',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, {required String label}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 10)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  String _formatLearners(int count) {
    if (count >= 1000) {
      final v = (count / 1000);
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}k Students';
    }
    return '$count Students';
  }

  Widget _emptyCard(BuildContext context, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 12)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _featuredCourseCard(
    BuildContext context,
    Course topCourse, {
    required int enrolledCount,
    required bool enrolled,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final durationTag = (topCourse.duration.isNotEmpty ? topCourse.duration : 'Course').toUpperCase();
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(
        CourseDetailScreen.routeName,
        arguments: topCourse.id,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 10)),
        ),
        child: Row(
          children: [
            Container(
              width: 76,
              height: 92,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 10),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: topCourse.thumbnailUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: Image.network(topCourse.thumbnailUrl, fit: BoxFit.cover),
                    )
                  : Icon(Icons.trending_up_rounded, color: scheme.primary, size: 28),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _pill(context, label: topCourse.isFeatured ? 'New' : 'Popular'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            durationTag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface.withValues(alpha: 160),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topCourse.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: scheme.tertiary),
                        const SizedBox(width: 4),
                        Text(
                          topCourse.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.groups_rounded, size: 16, color: scheme.onSurface.withValues(alpha: 160)),
                        const SizedBox(width: 4),
                        Text(
                          _formatLearners(enrolledCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 180),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.onSurface.withValues(alpha: 10)),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurface.withValues(alpha: 170),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactCourseCard(
    BuildContext context,
    Course course, {
    required int enrolledCount,
    required bool enrolled,
    String? actionLabel,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 12)),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).pushNamed(
          CourseDetailScreen.routeName,
          arguments: course.id,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 46,
            height: 46,
            color: scheme.primary.withValues(alpha: 10),
            child: course.thumbnailUrl.isNotEmpty
                ? Image.network(course.thumbnailUrl, fit: BoxFit.cover)
                : Icon(Icons.school_rounded, color: scheme.primary),
          ),
        ),
        title: Text(
          course.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${course.category.isNotEmpty ? course.category : 'General'}  •  ${course.rating.toStringAsFixed(1)} ★  •  $enrolledCount learners',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: FilledButton.tonal(
          onPressed: () => _handlePrimaryAction(context, course, enrolled: enrolled),
          child: Text(actionLabel ?? _primaryActionLabel(course, enrolled: enrolled)),
        ),
      ),
    );
  }

  bool _isTrending(Course course) {
    if (course.isFeatured) return true;
    return course.rating >= 4.6;
  }

  List<Course> _sortCourses(List<Course> items, _MarketplaceSort mode) {
    final out = [...items];
    switch (mode) {
      case _MarketplaceSort.rating:
        out.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _MarketplaceSort.title:
        out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _MarketplaceSort.price:
        out.sort((a, b) => a.price.compareTo(b.price));
        break;
    }
    return out;
  }

  Future<void> _openFilters() async {
    final courses = Provider.of<CourseProvider>(context, listen: false).courses;
    final categories = _MarketplaceCategories.fromCourses(courses);

    var featuredOnly = _featuredOnly;
    var trendingOnly = _trendingOnly;
    var sortMode = _sortMode;
    var selectedCategory = _selectedCategory;
    final localDifficulty = Set<CourseDifficulty>.from(_difficultyFilters);

    final applied = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => StatefulBuilder(
            builder: (context, setModalState) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace Filters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categories.contains(selectedCategory)
                        ? selectedCategory
                        : _MarketplaceCategories.all,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(growable: false),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedCategory = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<_MarketplaceSort>(
                    initialValue: sortMode,
                    decoration: const InputDecoration(labelText: 'Sort by'),
                    items: const [
                      DropdownMenuItem(value: _MarketplaceSort.rating, child: Text('Top rated')),
                      DropdownMenuItem(value: _MarketplaceSort.title, child: Text('Title A-Z')),
                      DropdownMenuItem(value: _MarketplaceSort.price, child: Text('Price low-high')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => sortMode = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: CourseDifficulty.values.map((d) {
                      final selected = localDifficulty.contains(d);
                      final label = d.name[0].toUpperCase() + d.name.substring(1);
                      return FilterChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (on) {
                          setModalState(() {
                            if (on) {
                              localDifficulty.add(d);
                            } else {
                              localDifficulty.remove(d);
                            }
                          });
                        },
                      );
                    }).toList(growable: false),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Trending / Popular only'),
                    value: trendingOnly,
                    onChanged: (v) => setModalState(() => trendingOnly = v),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Featured only'),
                    value: featuredOnly,
                    onChanged: (v) => setModalState(() => featuredOnly = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            featuredOnly = false;
                            trendingOnly = false;
                            sortMode = _MarketplaceSort.rating;
                            selectedCategory = _MarketplaceCategories.all;
                            localDifficulty.clear();
                          });
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;

    if (!mounted || !applied) return;
    setState(() {
      _featuredOnly = featuredOnly;
      _trendingOnly = trendingOnly;
      _sortMode = sortMode;
      _selectedCategory = selectedCategory;
      _difficultyFilters
        ..clear()
        ..addAll(localDifficulty);
    });
  }

  Future<void> _openCourseListSheet(String title, List<Course> courses) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: courses.isEmpty
                    ? Center(
                        child: Text(
                          'No courses available',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: courses.length,
                        itemBuilder: (context, i) {
                          final c = courses[i];
                          final auth = context.read<AuthProvider>();
                          final enrolled = auth.currentUser?.courseIds.contains(c.id) ?? false;
                          final batches = context.read<BatchProvider>().batches;
                          var enrolledCount = 0;
                          for (final b in batches) {
                            if (b.courseId == c.id) enrolledCount += b.enrolledCount;
                          }
                          return _compactCourseCard(
                            context,
                            c,
                            enrolledCount: enrolledCount,
                            enrolled: enrolled,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context, AuthProvider auth) {
    if (!auth.isLoggedIn) {
      Navigator.of(context).pushNamed(LoginScreen.routeName);
      return;
    }

    switch (auth.currentRole) {
      case UserRole.student:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudentNotificationsScreen()),
        );
        return;
      case UserRole.mentor:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MentorNotificationsScreen()),
        );
        return;
      case UserRole.admin:
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin inbox is available in the Admin Home screen.')),
        );
        return;
    }
  }

  String _primaryActionLabel(Course course, {required bool enrolled}) {
    if (enrolled) return 'View';
    if (course.price <= 0) return 'Enroll';
    return 'Buy';
  }

  Future<void> _handlePrimaryAction(
    BuildContext context,
    Course course, {
    required bool enrolled,
  }) async {
    final auth = context.read<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (enrolled) {
      Navigator.of(context).pushNamed(CourseDetailScreen.routeName, arguments: course.id);
      return;
    }

    if (!auth.isLoggedIn) {
      Navigator.of(context).pushNamed(LoginScreen.routeName);
      return;
    }

    if (auth.currentRole != UserRole.student) {
      Navigator.of(context).pushNamed(CourseDetailScreen.routeName, arguments: course.id);
      return;
    }

    final costCoins = course.price.round();
    final student = context.read<StudentProvider>();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolled in ${course.title}')),
      );
    } catch (e) {
      if (costCoins > 0) {
        // Best-effort rollback if API fails.
        await student.addCoins(costCoins);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enroll failed: $e')),
      );
    }
  }

  Widget _skeletonFeaturedCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurface.withValues(alpha: 8);
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 12)),
      ),
      child: Row(
        children: [
          Container(
            width: 104,
            height: double.infinity,
            decoration: BoxDecoration(
              color: base,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 90, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 10),
                  Container(height: 18, width: double.infinity, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 8),
                  Container(height: 18, width: 160, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                  const Spacer(),
                  Container(height: 34, width: 110, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonListTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurface.withValues(alpha: 8);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 200, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(height: 34, width: 72, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16))),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceHeaderRow extends StatelessWidget {
  const _MarketplaceHeaderRow({
    required this.isLoggedIn,
    required this.onLoginTap,
    required this.onNotificationsTap,
    required this.onThemeToggle,
  });

  final bool isLoggedIn;
  final VoidCallback onLoginTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.flash_on_rounded, color: scheme.onPrimary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          'Jenovate',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        const Spacer(),
        if (!isLoggedIn)
          TextButton.icon(
            onPressed: onLoginTap,
            icon: Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.primary),
            label: Text(
              'Log in',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else ...[
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: onThemeToggle,
            icon: Icon(
              context.watch<ThemeProvider>().isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: scheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}

class _MarketplaceCategories {
  static const all = 'All';

  static List<String> fromCourses(List<Course> courses) {
    final seen = <String>{};
    final out = <String>[all];
    for (final c in courses) {
      final cat = c.category.trim();
      if (cat.isEmpty) continue;
      final key = cat.toLowerCase();
      if (seen.add(key)) {
        out.add(cat);
      }
    }
    return out;
  }

  /// Stable orbit list: All + top categories by frequency.
  /// Keeps [selected] visible even if it isn't in the top list.
  static List<String> orbitFromCourses(
    List<Course> courses, {
    required String selected,
    int maxItems = 7,
  }) {
    final counts = <String, int>{};
    final original = <String, String>{};
    for (final c in courses) {
      final cat = c.category.trim();
      if (cat.isEmpty) continue;
      final key = cat.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      original.putIfAbsent(key, () => cat);
    }

    final sortedKeys = counts.keys.toList(growable: false)
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

    final out = <String>[all];
    for (final key in sortedKeys) {
      if (out.length >= maxItems) break;
      out.add(original[key] ?? key);
    }

    final selectedTrimmed = selected.trim();
    if (selectedTrimmed.isNotEmpty && selectedTrimmed.toLowerCase() != all.toLowerCase()) {
      final hasSelected = out.any((c) => c.trim().toLowerCase() == selectedTrimmed.toLowerCase());
      if (!hasSelected) {
        if (out.length >= maxItems) {
          out.removeLast();
        }
        out.add(selectedTrimmed);
      }
    }

    return out;
  }
}

class _MarketplaceBottomNav extends StatelessWidget {
  const _MarketplaceBottomNav({
    required this.currentIndex,
    required this.onHome,
    required this.onCourses,
    required this.onProfile,
  });

  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onCourses;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 12))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: _BottomItem(
              icon: currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
              label: 'Home',
              active: currentIndex == 0,
              onTap: onHome,
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: currentIndex == 1 ? Icons.menu_book_rounded : Icons.menu_book_outlined,
              label: 'My Courses',
              active: currentIndex == 1,
              onTap: onCourses,
            ),
          ),
          Expanded(
            child: _BottomItem(
              icon: currentIndex == 2 ? Icons.person_rounded : Icons.person_outline_rounded,
              label: 'Profile',
              active: currentIndex == 2,
              onTap: onProfile,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurface.withValues(alpha: 160);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryOrbit extends StatefulWidget {
  const _CategoryOrbit({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_OrbitItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<_CategoryOrbit> createState() => _CategoryOrbitState();
}

class _CategoryOrbitState extends State<_CategoryOrbit> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double size = 280;
    const double radius = 108;
    const double itemSize = 72;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rotationDegrees = _controller.value * 360;
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(260, 260),
                painter: _DottedCirclePainter(
                  color: scheme.onSurface.withValues(alpha: 18),
                  dotRadius: 1.2,
                  gap: 7.0,
                ),
              ),
              CustomPaint(
                size: const Size(188, 188),
                painter: _DottedCirclePainter(
                  color: scheme.onSurface.withValues(alpha: 14),
                  dotRadius: 1.1,
                  gap: 8.5,
                ),
              ),
              Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  border: Border.all(color: scheme.onPrimary.withValues(alpha: 18)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_border_rounded, color: scheme.onPrimary, size: 30),
                      Text(
                        'COURSE',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              for (int i = 0; i < widget.items.length; i++)
                _orbitChild(
                  center: size / 2,
                  radius: radius,
                  angle: -90 + ((360 / widget.items.length) * i) + rotationDegrees,
                  child: _OrbitNode(
                    item: widget.items[i],
                    size: itemSize,
                    selected: widget.selectedIndex == i,
                    onTap: () => widget.onSelect(i),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _orbitChild({
    required double center,
    required double radius,
    required double angle,
    required Widget child,
  }) {
    final radians = angle * pi / 180;
    final x = center + radius * (cos(radians)) - 36;
    final y = center + radius * (sin(radians)) - 36;
    return Positioned(left: x, top: y, child: child);
  }
}

class _DottedCirclePainter extends CustomPainter {
  _DottedCirclePainter({
    required this.color,
    required this.dotRadius,
    required this.gap,
  });

  final Color color;
  final double dotRadius;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final circumference = 2 * pi * radius;
    final dotDiameter = dotRadius * 2;
    final step = (dotDiameter + gap);
    final count = (circumference / step).floor();
    for (int i = 0; i < count; i++) {
      final t = (i / count) * 2 * pi;
      final p = Offset(
        center.dx + radius * cos(t),
        center.dy + radius * sin(t),
      );
      canvas.drawCircle(p, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dotRadius != dotRadius || oldDelegate.gap != gap;
  }
}

class _OrbitNode extends StatelessWidget {
  const _OrbitNode({
    required this.item,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final _OrbitItem item;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = selected
        ? scheme.primary.withValues(alpha: 14)
        : scheme.onSurface.withValues(alpha: 6);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 14),
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Icon(item.icon, color: scheme.primary, size: 30),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 90,
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitItem {
  const _OrbitItem({required this.label, required this.icon});

  factory _OrbitItem.fromLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == _MarketplaceCategories.all.toLowerCase()) {
      return const _OrbitItem(label: _MarketplaceCategories.all, icon: Icons.apps_rounded);
    }
    if (normalized.contains('ai') || normalized.contains('tech') || normalized.contains('data')) {
      return _OrbitItem(label: label, icon: Icons.memory_rounded);
    }
    if (normalized.contains('program') || normalized.contains('code') || normalized.contains('dev')) {
      return _OrbitItem(label: label, icon: Icons.code_rounded);
    }
    if (normalized.contains('design') || normalized.contains('ui') || normalized.contains('ux')) {
      return _OrbitItem(label: label, icon: Icons.palette_outlined);
    }
    if (normalized.contains('market') || normalized.contains('seo') || normalized.contains('brand')) {
      return _OrbitItem(label: label, icon: Icons.trending_up_rounded);
    }
    if (normalized.contains('ar') || normalized.contains('vr')) {
      return _OrbitItem(label: label, icon: Icons.language_rounded);
    }
    return _OrbitItem(label: label, icon: Icons.category_outlined);
  }

  final String label;
  final IconData icon;
}

enum _MarketplaceSort { rating, title, price }
