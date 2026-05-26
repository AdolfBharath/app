import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class AccentCard extends StatelessWidget {
  const AccentCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: child,
    );
  }
}
