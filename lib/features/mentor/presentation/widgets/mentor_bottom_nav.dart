import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class MentorBottomNav extends StatelessWidget {
  const MentorBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    return GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: states.contains(WidgetState.selected)
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    return IconThemeData(
                      color: states.contains(WidgetState.selected)
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                      size: 24,
                    );
                  }),
                ),
                child: NavigationBar(
                  height: 72,
                  selectedIndex: currentIndex,
                  onDestinationSelected: onTap,
                  backgroundColor: Colors.transparent,
                  indicatorColor: const Color(0xFF3B82F6),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book_rounded),
                      label: 'Courses',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_awesome_motion_outlined),
                      selectedIcon: Icon(Icons.auto_awesome_motion_rounded),
                      label: 'Batches',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
