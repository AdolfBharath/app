import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'providers/course_provider.dart';
import 'providers/batch_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/shop_provider.dart';
import 'features/mentor/presentation/providers/mentor_provider.dart';
import 'providers/config_provider.dart';
import 'features/student/presentation/providers/student_provider.dart';
import 'providers/question_provider.dart';
import 'screens/add_course_screen.dart';
import 'screens/add_user_screen.dart';
import 'screens/manage_user_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/admin_profile_screen.dart';
import 'screens/add_batch_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/active_courses_screen.dart';
import 'screens/batch_list_screen.dart';
import 'screens/batch_details_screen.dart';
import 'screens/review_projects_screen.dart';
import 'screens/project_details_screen.dart';
import 'features/mentor/presentation/screens/mentor_home_screen.dart';
import 'features/student/presentation/screens/student_shell_screen.dart';
import 'config/theme.dart';
import 'providers/theme_provider.dart';

void main() {
  // On Web, allow runtime fetching so GoogleFonts can load (unless fonts are bundled).
  // On mobile/desktop, prefer bundled fonts (no network dependency).
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => BatchProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProxyProvider<AuthProvider, MentorProvider>(
          create: (context) => MentorProvider(
            currentUser: context.read<AuthProvider>().currentUser,
          ),
          update: (context, auth, previous) {
            final provider =
                previous ?? MentorProvider(currentUser: auth.currentUser);
            provider.updateCurrentUser(auth.currentUser);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => QuestionProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Jenovate LMS',
            theme: LmsAdminTheme.lightTheme,
            darkTheme: LmsAdminTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: MarketplaceScreen.routeName,
            routes: {
              MarketplaceScreen.routeName: (_) => const MarketplaceScreen(),
              LoginScreen.routeName: (_) => const LoginScreen(),
              AdminHomeScreen.routeName: (_) => const AdminHomeScreen(),
              AdminDashboardScreen.routeName: (_) => const AdminDashboardScreen(),
              AddCourseScreen.routeName: (_) => const AddCourseScreen(),
              AddUserScreen.routeName: (_) => const AddUserScreen(),
              ManageUserScreen.routeName: (_) => const ManageUserScreen(),
              AdminProfileScreen.routeName: (_) => const AdminProfileScreen(),
              AddBatchScreen.routeName: (_) => const AddBatchScreen(),
              CourseDetailScreen.routeName: (_) => const CourseDetailScreen(),
              ActiveCoursesScreen.routeName: (_) => const ActiveCoursesScreen(),
              BatchListScreen.routeName: (_) => const BatchListScreen(),
              BatchDetailsScreen.routeName: (_) => const BatchDetailsScreen(),
              ReviewProjectsScreen.routeName: (_) => const ReviewProjectsScreen(),
              ProjectDetailsScreen.routeName: (_) => const ProjectDetailsScreen(),
              MentorHomeScreen.routeName: (_) => const MentorHomeScreen(),
              StudentShellScreen.routeName: (_) => const StudentShellScreen(),
            },
          );
        },
      ),
    );
  }
}
