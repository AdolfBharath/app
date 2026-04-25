import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LmsNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const LmsNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class AnimatedLmsNavBar extends StatelessWidget {
  const AnimatedLmsNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.activeColor,
  });

  final int currentIndex;
  final List<LmsNavItem> items;
  final ValueChanged<int> onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = activeColor ?? scheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 16) / items.length;

          return Stack(
            children: [
              // Sliding active indicator (bubble)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                left: 8 + (currentIndex * itemWidth) + (itemWidth * 0.1),
                top: 12,
                child: Container(
                  width: itemWidth * 0.8,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              
              // Bottom active line
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutBack,
                left: 8 + (currentIndex * itemWidth) + (itemWidth * 0.35),
                bottom: 8,
                child: Container(
                  width: itemWidth * 0.3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Nav Items
              Row(
                children: List.generate(items.length, (index) {
                  final isSelected = index == currentIndex;
                  final item = items[index];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: _NavBarItemWidget(
                        item: item,
                        isSelected: isSelected,
                        activeColor: primary,
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavBarItemWidget extends StatelessWidget {
  const _NavBarItemWidget({
    required this.item,
    required this.isSelected,
    required this.activeColor,
  });

  final LmsNavItem item;
  final bool isSelected;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: isSelected ? 1.2 : 1.0,
          curve: Curves.easeOutBack,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? item.activeIcon : item.icon,
              key: ValueKey('icon_${isSelected}_${item.label}'),
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : inactiveColor,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}
