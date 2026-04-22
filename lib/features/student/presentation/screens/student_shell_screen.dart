import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../config/theme.dart';
import '../../../../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../providers/student_nav_provider.dart';
import '../widgets/student_bottom_nav.dart';
import 'student_home_screen.dart';
import 'student_courses_screen.dart';
import 'student_profile_screen.dart';
import 'student_batch_screen.dart';
import 'student_shop_screen.dart';

class StudentShellScreen extends StatefulWidget {
  const StudentShellScreen({super.key});

  static const routeName = '/student';

  @override
  State<StudentShellScreen> createState() => _StudentShellScreenState();
}

class _StudentShellScreenState extends State<StudentShellScreen> {
  late final _LifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _LifecycleObserver(onResume: () {
      if (!mounted) return;
      context.read<StudentProvider>().checkDailyReward();
    });
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    // Trigger daily reward check on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      () async {
        final auth = context.read<AuthProvider>();
        final studentProvider = context.read<StudentProvider>();
        await auth.refreshCurrentUser();
        if (!mounted) return;
        final assignedCourseIds = auth.currentUser?.courseIds ?? const <String>[];

        // Debug-only: seed Monday login so Tuesday shows 2 coins / 2 streak
        // and Monday is active in the weekly tracker.
        await studentProvider.debugSeedMondayLoginForTesting();
        await studentProvider.checkDailyReward();
        if (!mounted) return;
        await studentProvider.fetchCourses(
          assignedCourseIds: assignedCourseIds,
        );
        if (!mounted) return;
        await studentProvider.fetchNotifications();
      }();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final username = user?.username ?? user?.name ?? 'Student';

    final pages = [
      StudentHomeScreen(username: username),
      const StudentCoursesScreen(),
      const StudentBatchScreen(),
      const StudentShopScreen(),
      StudentProfileScreen(username: username, email: user?.email ?? ''),
    ];

    return ChangeNotifierProvider(
      create: (_) => StudentNavProvider(),
      child: Consumer2<StudentProvider, StudentNavProvider>(
        builder: (context, student, nav, _) {
          final brightness = Theme.of(context).brightness;
          final studentTheme = brightness == Brightness.dark
              ? LmsStudentTheme.darkTheme
              : LmsStudentTheme.lightTheme;

          return Theme(
            data: studentTheme,
            child: Builder(
              builder: (context) {
                if (student.earnedDailyReward) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showDailyRewardTopBanner(context);
                    student.clearDailyRewardFlag();
                  });
                }

                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: IndexedStack(index: nav.currentIndex, children: pages),
                  bottomNavigationBar: StudentBottomNav(
                    currentIndex: nav.currentIndex,
                    onTap: nav.setIndex,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver({required this.onResume});
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

void _showDailyRewardTopBanner(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final messenger = ScaffoldMessenger.of(context);

  messenger.hideCurrentSnackBar();
  messenger.hideCurrentMaterialBanner();

  messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: scheme.surface,
      elevation: 1,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      content: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                color: scheme.secondary,
              )
                  .animate()
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1))
                  .then()
                  .scale(begin: const Offset(1, 1), end: const Offset(0.95, 0.95))
                  .then()
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
              Positioned(
                right: -2,
                bottom: -2,
                child: Icon(
                  Icons.monetization_on_rounded,
                  size: 18,
                  color: LmsAdminTheme.coinGold,
                )
                    .animate()
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: 0.4, end: 0, duration: 250.ms),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Streak updated +1 coin',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
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
