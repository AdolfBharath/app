import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/batch.dart';
import '../models/course.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../models/shop_item.dart';
import '../providers/auth_provider.dart';
import '../providers/batch_provider.dart';
import '../providers/course_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/config_provider.dart';
import '../services/api_service.dart';
import 'active_courses_screen.dart';
import 'batch_details_screen.dart';
import 'batch_list_screen.dart';
import 'review_projects_screen.dart';

class AdminHomeDashboard extends StatefulWidget {
  const AdminHomeDashboard({super.key});

  @override
  State<AdminHomeDashboard> createState() => _AdminHomeDashboardState();
}

class _AdminHomeDashboardState extends State<AdminHomeDashboard> {
  bool _showStudents = true;
  String _searchQuery = '';
  int _pendingProjectCount = 0;
  int _reviewedProjectCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProjectCounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopProvider>().fetchShopItems();
      context.read<ConfigProvider>().loadConfig();
    });
  }

  Future<void> _loadProjectCounts() async {
    try {
      final projects = await ApiService.instance.getProjects();
      if (!mounted) return;

      var pending = 0;
      var reviewed = 0;

      for (final project in projects) {
        if (project.status == ProjectStatus.pending ||
            project.status == ProjectStatus.inReview) {
          pending++;
        } else if (project.status == ProjectStatus.reviewed) {
          reviewed++;
        }
      }

      setState(() {
        _pendingProjectCount = pending;
        _reviewedProjectCount = reviewed;
      });
    } catch (_) {
      // Keep dashboard usable even if project stats endpoint fails.
    }
  }

  Future<String?> _pickImageAsDataUrl() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    final ext = (file.extension ?? 'png').toLowerCase();
    final mime = ext == 'jpg' ? 'jpeg' : ext;
    return 'data:image/$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> _openShopItemEditor({ShopItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final priceController = TextEditingController(
      text: existing == null ? '' : existing.price.toString(),
    );
    final imageController = TextEditingController(text: existing?.imageUrl ?? '');
    final shop = context.read<ShopProvider>();
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> save() async {
                final name = nameController.text.trim();
                final price = int.tryParse(priceController.text.trim()) ?? -1;
                final imageUrl = imageController.text.trim();

                if (name.isEmpty || price < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter valid name and non-negative price')),
                  );
                  return;
                }

                setDialogState(() => saving = true);
                final ok = existing == null
                    ? await shop.createShopItem(name: name, price: price, imageUrl: imageUrl)
                    : await shop.updateShopItem(
                        itemId: existing.id,
                        name: name,
                        price: price,
                        imageUrl: imageUrl,
                      );
                if (!mounted) return;
                setDialogState(() => saving = false);
                if (ok) {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                  await shop.fetchShopItems();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(shop.errorMessage ?? 'Save failed')),
                  );
                }
              }

              Future<void> pickImage() async {
                final dataUrl = await _pickImageAsDataUrl();
                if (dataUrl == null) return;
                setDialogState(() {
                  imageController.text = dataUrl;
                });
              }

              return AlertDialog(
                title: Text(existing == null ? 'Add Shop Item' : 'Edit Shop Item'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Item Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (coins)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: imageController,
                        decoration: const InputDecoration(labelText: 'Image URL / Data URL'),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: saving ? null : pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Select Image'),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      priceController.dispose();
      imageController.dispose();
    }
  }

  Future<void> _confirmDeleteShopItem(ShopItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Delete "${item.name}" from shop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    final ok = await context.read<ShopProvider>().deleteShopItem(item.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<ShopProvider>().errorMessage ?? 'Delete failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final batchProvider = context.watch<BatchProvider>();
    final shopProvider = context.watch<ShopProvider>();

    final students = auth.students;
    final mentors = auth.mentors;
    final courses = courseProvider.courses;
    final batches = batchProvider.batches;
    final shopItems = shopProvider.items;

    final activeStudentsCount = students.length;
    final mentorsCount = mentors.length;
    final batchesCount = batches.length;
    final totalCourses = courses.length;

    // Revenue = sum of (course.price × number of enrolled students for that course).
    // We approximate enrolled count as the total student count since each student
    // is assigned to at least one course; replace with per-course enrollment data
    // once that endpoint is available.
    final double totalRevenue = courses.fold(0.0, (sum, course) {
      return sum + (course.price * activeStudentsCount);
    });
    final bool hasRevenue = totalRevenue > 0;

    final focusUsers = _showStudents ? students : mentors;

    List<AppUser> filteredUsers = focusUsers;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredUsers = focusUsers.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            (user.username?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    final AppUser? focusUser = filteredUsers.isNotEmpty
        ? filteredUsers.first
        : null;

    Batch? activeBatch;
    if (batches.isNotEmpty) {
      activeBatch = batches.firstWhere(
        (b) =>
            b.status == 'active' ||
            b.status == 'in_progress' ||
            b.status == 'ongoing',
        orElse: () => batches.first,
      );
    }

    return Container(
      color: LmsAdminTheme.backgroundLight,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                            'Admin Overview',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: LmsAdminTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Live platform statistics',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats grid — row 1: students + mentors
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.school_rounded,
                          title: 'ACTIVE STUDENTS',
                          value: activeStudentsCount.toString(),
                          growthLabel: 'Total',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.group_rounded,
                          title: 'MENTORS',
                          value: mentorsCount.toString(),
                          growthLabel: 'Total',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats grid — row 2: batches + courses
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.layers_rounded,
                          title: 'BATCHES',
                          value: batchesCount.toString(),
                          growthLabel: 'Running',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.menu_book_rounded,
                          title: 'COURSES',
                          value: totalCourses.toString(),
                          growthLabel: 'Available',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Revenue card — full width, green accent
                  _RevenueCard(
                    revenue: totalRevenue,
                    hasRevenue: hasRevenue,
                    courseCount: totalCourses,
                    studentCount: activeStudentsCount,
                  ),
                  const SizedBox(height: 32),
                  const _PlatformSettingsCard(),
                  const SizedBox(height: 32),

                  // Main Chart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Analytics',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: LmsAdminTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'LIVE',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _EnrollmentChartCard(batches: batches),

                  const SizedBox(height: 32),

                  // Students / Mentors search header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User Index',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: LmsAdminTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: 'Students',
                            selected: _showStudents,
                            onTap: () => setState(() => _showStudents = true),
                          ),
                        ),
                        Expanded(
                          child: _SegmentButton(
                            label: 'Mentors',
                            selected: !_showStudents,
                            onTap: () => setState(() => _showStudents = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: _showStudents
                          ? 'Search student directory...'
                          : 'Search mentor directory...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF9CA3AF),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.04),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.04),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _StudentAnalyticsCard(
                    user: focusUser,
                    isStudent: _showStudents,
                    searchQuery: _searchQuery,
                  ),

                  const SizedBox(height: 32),

                  GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(ReviewProjectsScreen.routeName),
                    child: _SectionHeader(
                      title: 'Review Projects',
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(ReviewProjectsScreen.routeName),
                    child: _ProjectReviewCard(
                      pendingCount: _pendingProjectCount,
                      reviewedCount: _reviewedProjectCount,
                    ),
                  ),

                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(ActiveCoursesScreen.routeName),
                    child: _SectionHeader(
                      title: 'Active Library',
                      trailing: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(ActiveCoursesScreen.routeName),
                    child: _ActiveLibraryCard(courses: courses),
                  ),

                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Active Batches',
                    trailing: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(BatchListScreen.routeName);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        'View All',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActiveBatchCard(batch: activeBatch),

                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Shop Management',
                    trailing: FilledButton.icon(
                      onPressed: () => _openShopItemEditor(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        'Add Item',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AdminShopPreview(
                    items: shopItems,
                    isLoading: shopProvider.isLoading,
                    onRefresh: () => context.read<ShopProvider>().fetchShopItems(),
                    onEdit: (item) => _openShopItemEditor(existing: item),
                    onDelete: _confirmDeleteShopItem,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollmentChartCard extends StatelessWidget {
  const _EnrollmentChartCard({required this.batches});

  final List<Batch> batches;

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(24),
        decoration: LmsAdminTheme.adminCardDecoration(context),
        child: Center(
          child: Text(
            'Create batches to view enrollment analytics.',
            style: GoogleFonts.poppins(color: LmsAdminTheme.textSecondary),
          ),
        ),
      );
    }

    // Generate spots based on actual batch enrollments
    final spots = <FlSpot>[];
    double maxEnrollment = 0;

    for (int i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final enrollment = batch.enrolledCount.toDouble();
      spots.add(FlSpot(i.toDouble(), enrollment));
      if (enrollment > maxEnrollment) {
        maxEnrollment = enrollment;
      }
    }

    // If max is very small or all 0, adjust to make chart look normal
    if (maxEnrollment < 5) maxEnrollment = 5;

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 16, left: 12, top: 24, bottom: 12),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxEnrollment / 4).ceilToDouble(),
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.black.withOpacity(0.04), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= batches.length)
                    return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      'B${index + 1}',
                      style: GoogleFonts.poppins(
                        color: LmsAdminTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxEnrollment / 4).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: GoogleFonts.poppins(
                      color: LmsAdminTheme.textSecondary,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
                reservedSize: 32,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (batches.length - 1).toDouble() > 0
              ? (batches.length - 1).toDouble()
              : 1,
          minY: 0,
          maxY: maxEnrollment + (maxEnrollment * 0.2),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: LmsAdminTheme.primaryBlue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: LmsAdminTheme.primaryBlue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Revenue summary card — full width, green gradient accent.
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.revenue,
    required this.hasRevenue,
    required this.courseCount,
    required this.studentCount,
  });

  final double revenue;
  final bool hasRevenue;
  final int courseCount;
  final int studentCount;

  String _formatRevenue(double v) {
    if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)}Cr';
    if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: hasRevenue
            ? const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasRevenue ? null : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: hasRevenue
            ? null
            : Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3),
                width: 1.5,
              ),
        boxShadow: [
          BoxShadow(
            color: hasRevenue
                ? const Color(0xFF059669).withOpacity(0.22)
                : Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasRevenue
                  ? Colors.white.withOpacity(0.2)
                  : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.currency_rupee_rounded,
              color: hasRevenue ? Colors.white : const Color(0xFF059669),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL REVENUE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: hasRevenue
                        ? Colors.white.withOpacity(0.85)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasRevenue ? _formatRevenue(revenue) : '—',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: hasRevenue ? Colors.white : const Color(0xFF374151),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasRevenue
                      ? '$courseCount priced course${courseCount == 1 ? '' : 's'} · $studentCount enrolled student${studentCount == 1 ? '' : 's'}'
                      : 'Set course prices to start tracking revenue',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: hasRevenue
                        ? Colors.white.withOpacity(0.75)
                        : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          if (hasRevenue)
            Icon(
              Icons.trending_up_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 32,
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.growthLabel,
  });

  final IconData icon;
  final String title;
  final String value;
  final String growthLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LmsAdminTheme.primaryBlueLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: LmsAdminTheme.primaryBlue, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: LmsAdminTheme.statusActiveBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  growthLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: LmsAdminTheme.statusActive,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: LmsAdminTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: LmsAdminTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  const _ActivityFeedCard({
    required this.recentStudents,
    required this.recentCourses,
    required this.recentBatches,
  });

  final List<AppUser> recentStudents;
  final List<Course> recentCourses;
  final List<Batch> recentBatches;

  @override
  Widget build(BuildContext context) {
    if (recentStudents.isEmpty &&
        recentCourses.isEmpty &&
        recentBatches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: LmsAdminTheme.adminCardDecoration(context),
        child: Center(
          child: Text(
            'No recent activity recorded.',
            style: GoogleFonts.poppins(color: LmsAdminTheme.textSecondary),
          ),
        ),
      );
    }

    final activities = <Widget>[];

    for (final student in recentStudents) {
      activities.add(
        _ActivityTile(
          icon: Icons.person_add_rounded,
          iconColor: Colors.blue,
          title: 'Student Registered',
          subtitle: '${student.name} (${student.email}) joined the platform',
          time: 'Recently',
        ),
      );
      activities.add(Divider(height: 1, color: Colors.black.withOpacity(0.04)));
    }

    for (final course in recentCourses) {
      activities.add(
        _ActivityTile(
          icon: Icons.publish_rounded,
          iconColor: Colors.green,
          title: 'Course Published',
          subtitle: '${course.title} is now available',
          time: 'Recently',
        ),
      );
      activities.add(Divider(height: 1, color: Colors.black.withOpacity(0.04)));
    }

    for (final batch in recentBatches) {
      activities.add(
        _ActivityTile(
          icon: Icons.layers_rounded,
          iconColor: Colors.amber,
          title: 'New Batch Running',
          subtitle: 'Batch ${batch.name} has been deployed',
          time: 'Recently',
        ),
      );
      activities.add(Divider(height: 1, color: Colors.black.withOpacity(0.04)));
    }

    if (activities.isNotEmpty) {
      activities.removeLast(); // Remove trailing divider
    }

    return Container(
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Column(children: activities),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: LmsAdminTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: LmsAdminTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: LmsAdminTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? LmsAdminTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : LmsAdminTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentAnalyticsCard extends StatelessWidget {
  const _StudentAnalyticsCard({
    required this.user,
    required this.isStudent,
    this.searchQuery = '',
  });

  final AppUser? user;
  final bool isStudent;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: LmsAdminTheme.adminCardDecoration(context),
        child: Center(
          child: Text(
            isStudent
                ? 'No students match your query.'
                : 'No mentors match your query.',
            style: GoogleFonts.poppins(color: LmsAdminTheme.textSecondary),
          ),
        ),
      );
    }

    final avatarLetter = user!.name.isNotEmpty
        ? user!.name[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: LmsAdminTheme.primaryBlueLight,
                child: Text(
                  avatarLetter,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: LmsAdminTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user!.name.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: LmsAdminTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user!.email} · ID: #${user!.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: LmsAdminTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: _MiniStatBox(label: 'AVG. SCORE', value: '88%'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(label: 'COMPLETION', value: '94%'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(label: 'ACTIVE', value: '12h/w'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: LmsAdminTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: LmsAdminTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: LmsAdminTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LmsAdminTheme.textDark,
              ),
            ),
          ],
        ),
        trailing,
      ],
    );
  }
}

class _ActiveLibraryCard extends StatelessWidget {
  const _ActiveLibraryCard({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final int liveCount = courses
        .where((c) => c.isFeatured || c.isMyCourse)
        .length;
    final int draftCount = courses.length - liveCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${courses.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    height: 1,
                  ),
                ),
                Text(
                  'Total Courses',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$liveCount LIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$draftCount draft',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveBatchCard extends StatelessWidget {
  const _ActiveBatchCard({required this.batch});

  final Batch? batch;

  @override
  Widget build(BuildContext context) {
    if (batch == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: LmsAdminTheme.adminCardDecoration(context),
        child: Text(
          'No active batches yet',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      );
    }

    final progress = batch!.progress > 0
        ? batch!.progress.clamp(0.0, 1.0)
        : (batch!.capacity != null && batch!.capacity! > 0)
        ? (batch!.enrolledCount / batch!.capacity!).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        batch!.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF34D399)),
                      ),
                      child: Text(
                        batch!.status.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Syllabus Progress',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF3B82F6),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups_2_outlined,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${batch!.enrolledCount}${batch!.capacity != null ? '/${batch!.capacity}' : ''} enrolled',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      BatchDetailsScreen.routeName,
                      arguments: batch!.id,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    'View Batch',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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

class _ProjectReviewCard extends StatelessWidget {
  const _ProjectReviewCard({
    required this.pendingCount,
    required this.reviewedCount,
  });

  final int pendingCount;
  final int reviewedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Review Pending',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Project Submissions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review and approve student project submissions',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENDING',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pendingCount',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REVIEWED',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$reviewedCount',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminShopPreview extends StatelessWidget {
  const _AdminShopPreview({
    required this.items,
    required this.isLoading,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ShopItem> items;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final ValueChanged<ShopItem> onEdit;
  final ValueChanged<ShopItem> onDelete;

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: LmsAdminTheme.adminCardDecoration(context),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No shop items yet. Add your first item.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ),
        ...items.take(6).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdminShopItemTile(
                  item: item,
                  onEdit: () => onEdit(item),
                  onDelete: () => onDelete(item),
                ),
              ),
            ),
      ],
    );
  }
}

class _AdminShopItemTile extends StatelessWidget {
  const _AdminShopItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ShopItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: _ShopImageThumb(imageUrl: item.imageUrl),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.price} coins',
          style: GoogleFonts.poppins(
            color: const Color(0xFFB7791F),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit item',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete item',
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopImageThumb extends StatelessWidget {
  const _ShopImageThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    final isDataUrl = imageUrl.startsWith('data:image/');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: const Color(0xFFE2E8F0),
        child: hasImage
            ? isDataUrl
                ? Image.memory(
                    _decodeDataUrl(imageUrl) ?? Uint8List(0),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                  )
            : const Icon(Icons.inventory_2_outlined),
      ),
    );
  }
}

Uint8List? _decodeDataUrl(String input) {
  final comma = input.indexOf(',');
  if (comma < 0 || comma + 1 >= input.length) return null;
  try {
    return base64Decode(input.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class _PlatformSettingsCard extends StatefulWidget {
  const _PlatformSettingsCard();

  @override
  State<_PlatformSettingsCard> createState() => _PlatformSettingsCardState();
}

class _PlatformSettingsCardState extends State<_PlatformSettingsCard> {
  final _formUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _formUrlController.text = context.read<ConfigProvider>().registrationFormUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = context.watch<ConfigProvider>().registrationFormUrl;
    if (_formUrlController.text.isEmpty && url.isNotEmpty) {
      _formUrlController.text = url;
    }
  }

  @override
  void dispose() {
    _formUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _formUrlController.text.trim();
    final ok = await context.read<ConfigProvider>().updateRegistrationFormUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Settings saved successfully' : 'Failed to save settings')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: LmsAdminTheme.adminCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                'Platform Settings',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LmsAdminTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Registration Form URL (Google Form)',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LmsAdminTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _formUrlController,
            decoration: InputDecoration(
              hintText: 'https://forms.gle/xxxxx',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withOpacity(0.04)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: config.isLoading ? null : _save,
              icon: config.isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
              label: Text(
                config.isLoading ? 'Saving...' : 'Save Settings',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
