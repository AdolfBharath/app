import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/batch_detail.dart';
import '../services/api_service.dart';
import 'batch_tasks_screen.dart';
import 'student_list_card.dart';
import 'top_performer_card.dart';

class BatchDetailsScreen extends StatefulWidget {
  static const routeName = '/admin/batch-details';

  const BatchDetailsScreen({super.key});

  @override
  State<BatchDetailsScreen> createState() => _BatchDetailsScreenState();
}

class _BatchDetailsScreenState extends State<BatchDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  BatchDetail? _batchDetail;
  String? _errorMessage;
  String? _batchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_batchId == null) {
      _batchId = ModalRoute.of(context)?.settings.arguments as String?;
      if (_batchId != null) {
        _loadBatchDetails();
      }
    }
  }

  Future<void> _loadBatchDetails() async {
    if (_batchId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final details = await ApiService.instance.getBatchDetails(_batchId!);
      setState(() {
        _batchDetail = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _batchDetail?.batch.name ?? 'Batch Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        actions: [
          if (_batchDetail != null)
            IconButton(
              icon: const Icon(Icons.fact_check_outlined, color: Color(0xFF3B82F6)),
              tooltip: 'Review Tasks',
              onPressed: () {
                final batch = _batchDetail!.batch;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BatchTasksScreen(
                      batchId: batch.id,
                      batchName: batch.name,
                      canReview: true,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF3B82F6)),
            onPressed: _loadBatchDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : Column(
              children: [
                // Batch info header
                _buildBatchHeader(),
                // Tab bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF3B82F6),
                    unselectedLabelColor: const Color(0xFF6B7280),
                    indicatorColor: const Color(0xFF3B82F6),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Mentor'),
                      Tab(text: 'Students'),
                      Tab(text: 'Top Performers'),
                    ],
                  ),
                ),
                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMentorTab(),
                      _buildStudentsTab(),
                      _buildTopPerformersTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBatchHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _batchDetail?.courseName ?? 'Course',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_batchDetail?.totalStudents ?? 0} Students',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final batch = _batchDetail?.batch;
                    final dynamicProgress = batch == null
                        ? 0.0
                        : (batch.progress > 0
                              ? batch.progress
                              : (batch.capacity != null && batch.capacity! > 0)
                              ? (batch.enrolledCount / batch.capacity!)
                              : 0.0);
                    final progressPercent = (dynamicProgress * 100)
                        .clamp(0, 100)
                        .round();
                    return LinearProgressIndicator(
                      value: dynamicProgress.clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final batch = _batchDetail?.batch;
                    final dynamicProgress = batch == null
                        ? 0.0
                        : (batch.progress > 0
                              ? batch.progress
                              : (batch.capacity != null && batch.capacity! > 0)
                              ? (batch.enrolledCount / batch.capacity!)
                              : 0.0);
                    final progressPercent = (dynamicProgress * 100)
                        .clamp(0, 100)
                        .round();
                    return Text(
                      'Avg Progress: $progressPercent%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3B82F6),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentorTab() {
    final mentor = _batchDetail?.mentor;

    if (mentor == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'No mentor assigned',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  mentor.name.isNotEmpty ? mentor.name[0].toUpperCase() : 'M',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              mentor.name,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Mentor',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.email_outlined, 'Email', mentor.email),
            if (mentor.username != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.alternate_email,
                'Username',
                '@${mentor.username}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentsTab() {
    final students = _batchDetail?.students ?? [];

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'No students enrolled',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) {
        return StudentListCard(student: students[index]);
      },
    );
  }

  Widget _buildTopPerformersTab() {
    final topPerformers = _batchDetail?.topPerformers ?? [];

    if (topPerformers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              'No performance data yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: topPerformers.length,
      itemBuilder: (context, index) {
        return TopPerformerCard(performance: topPerformers[index]);
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              'Failed to load batch details',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBatchDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
