import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class StudentBottomNav extends StatelessWidget {
  const StudentBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  // Pairs of (inactive icon, active icon)
  static const _items = [
    (Icons.home_outlined,          Icons.home_rounded,            'Home'),
    (Icons.menu_book_outlined,     Icons.menu_book_rounded,       'My Course'),
    (Icons.groups_2_outlined,      Icons.groups_2_rounded,        'Batch'),
    (Icons.shopping_bag_outlined,  Icons.shopping_bag_rounded,    'Shop'),
    (Icons.person_outline_rounded, Icons.person_rounded,          'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black).withValues(alpha: isDark ? 40 : 12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: scheme.onSurface.withValues(alpha: isDark ? 14 : 10),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final selected = i == currentIndex;
              final item = _items[i];
              return _NavItem(
                icon: item.$1,
                activeIcon: item.$2,
                label: item.$3,
                selected: selected,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeColor = scheme.primary;
    final inactiveColor = scheme.onSurface.withValues(alpha: 140);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 4,
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 24,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? activeColor : inactiveColor,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

