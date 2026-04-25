import 'package:flutter/material.dart';
import '../../../../widgets/animated_lms_nav_bar.dart';

class StudentBottomNav extends StatelessWidget {
  const StudentBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _navItems = [
    LmsNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LmsNavItem(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'My Course',
    ),
    LmsNavItem(
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      label: 'Batch',
    ),
    LmsNavItem(
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag_rounded,
      label: 'Shop',
    ),
    LmsNavItem(
      icon: Icons.person_outline_rounded,
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
      ),
    );
  }
}
