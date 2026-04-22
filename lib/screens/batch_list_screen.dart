import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/batch.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../providers/batch_provider.dart';
import '../providers/course_provider.dart';
import '../providers/auth_provider.dart';
import 'batch_details_screen.dart';

class BatchListScreen extends StatefulWidget {
  static const routeName = '/admin/batch-list';

  const BatchListScreen({super.key});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  String _searchQuery = '';

  int _computeProgressPercent(Batch batch) {
    if (batch.progress > 0) {
      return (batch.progress * 100).clamp(0, 100).round();
    }
    if (batch.capacity != null && batch.capacity! > 0) {
      return ((batch.enrolledCount / batch.capacity!) * 100)
          .clamp(0, 100)
          .round();
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Active Batches',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search batches...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Batch list
          Expanded(
            child: Consumer3<BatchProvider, CourseProvider, AuthProvider>(
              builder:
                  (context, batchProvider, courseProvider, authProvider, _) {
                    final batches = batchProvider.batches
                        .where(
                          (batch) => batch.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();

                    if (batches.isEmpty) {
                      return _buildEmptyState();
                    }

                    return RefreshIndicator(
                      onRefresh: () => batchProvider.loadBatches(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: batches.length,
                        itemBuilder: (context, index) {
                          final batch = batches[index];
                          final course = courseProvider.getById(batch.courseId);
                          final mentor = authProvider.mentors
                              .where((m) => m.id == batch.mentorId)
                              .firstOrNull;
                          final studentCount = authProvider.students
                              .where((s) => s.batchId == batch.id)
                              .length;

                          return _buildBatchCard(
                            batch,
                            course,
                            mentor,
                            studentCount,
                          );
                        },
                      ),
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(
    Batch batch,
    Course? course,
    AppUser? mentor,
    int studentCount,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(
              context,
            ).pushNamed(BatchDetailsScreen.routeName, arguments: batch.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.group,
                        color: Colors.white,
                        size: 24,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            course?.title ?? 'Unknown Course',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          Icons.person_outline,
                          'Mentor',
                          mentor?.name ?? 'Not assigned',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFE5E7EB),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          Icons.people_outline,
                          'Enrolled',
                          batch.capacity != null
                              ? '${batch.enrolledCount}/${batch.capacity}'
                              : '${batch.enrolledCount}',
                        ),
                      ),
                      if (batch.enrollLimit != null &&
                          batch.enrollLimit! > 0) ...[
                        Container(
                          width: 1,
                          height: 30,
                          color: const Color(0xFFE5E7EB),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            Icons.lock_outline,
                            'Limit',
                            batch.enrollLimit.toString(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _computeProgressPercent(batch) / 100,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_computeProgressPercent(batch)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(
            'No batches found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Create your first batch to get started'
                : 'Try adjusting your search',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
