import 'package:flutter/material.dart';
import '../../../../widgets/animated_lms_nav_bar.dart';

class MentorBottomNav extends StatelessWidget {
  const MentorBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _navItems = [
    LmsNavItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'Courses',
    ),
    LmsNavItem(
      icon: Icons.auto_awesome_motion_outlined,
      activeIcon: Icons.auto_awesome_motion_rounded,
      label: 'Batches',
    ),
    LmsNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LmsNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedLmsNavBar(
        currentIndex: currentIndex,
        items: _navItems,
        onTap: onTap,
        activeColor: const Color(0xFF3B82F6),
      ),
    );
  }
}
