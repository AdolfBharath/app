import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../providers/batch_provider.dart';
import 'add_course_screen.dart';
import 'add_user_screen.dart';
import 'admin_profile_screen.dart';
import 'add_batch_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  static const routeName = '/admin';

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loaded = false;

  Future<void> _loadData(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final courses = Provider.of<CourseProvider>(context, listen: false);
    final batches = Provider.of<BatchProvider>(context, listen: false);
    await Future.wait([
      auth.loadUsers(),
      courses.loadCourses(),
      batches.loadBatches(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadData(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final courses = Provider.of<CourseProvider>(context).courses;
    final batches = Provider.of<BatchProvider>(context).batches;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF6F7FB),
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).pushNamed(AdminProfileScreen.routeName);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 24, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Overview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        auth.currentUser?.name ?? 'Admin',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatCard(
                    label: 'Active Students',
                    value: auth.students.length.toString(),
                    icon: Icons.school,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Mentors',
                    value: auth.mentors.length.toString(),
                    icon: Icons.group_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    label: 'Batches',
                    value: batches.length.toString(),
                    icon: Icons.auto_awesome_motion,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Courses',
                    value: courses.length.toString(),
                    icon: Icons.menu_book,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionChip(
                    icon: Icons.person_add_alt,
                    label: 'Add User',
                    onTap: () {
                      Navigator.of(context).pushNamed(AddUserScreen.routeName);
                    },
                  ),
                  _ActionChip(
                    icon: Icons.menu_book_outlined,
                    label: 'Add Course',
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(AddCourseScreen.routeName);
                    },
                  ),
                  _ActionChip(
                    icon: Icons.auto_awesome_motion,
                    label: 'Add Batch',
                    onTap: () {
                      Navigator.of(context).pushNamed(AddBatchScreen.routeName);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Active Library',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('Courses'),
                  subtitle: Text('${courses.length} total'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Active Batches',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...batches.map(
                (b) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_motion),
                    title: Text(b.name),
                    subtitle: Text('Status: ${b.status}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.primary.withOpacity(.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
