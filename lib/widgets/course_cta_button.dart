import 'package:flutter/material.dart';

class CourseCtaButton extends StatelessWidget {
  const CourseCtaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isCompact = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isCompact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: isCompact ? 12 : null,
    );

    final padding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 12);

    final content = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label, style: textStyle);

    final style = FilledButton.styleFrom(
      padding: padding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    if (icon != null && !isLoading) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: isCompact ? 16 : 18),
        label: Text(label, style: textStyle),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: content,
    );
  }
}
