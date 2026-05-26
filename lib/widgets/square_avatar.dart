import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class SquareAvatar extends StatelessWidget {
  const SquareAvatar({super.key, this.child, this.size = 56});

  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
