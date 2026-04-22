import 'package:flutter/material.dart';

class AnimatedTeacherWidget extends StatelessWidget {
  const AnimatedTeacherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder for Lottie/animated asset. This keeps the widget lightweight
    // and avoids adding new dependencies while providing a clear slot for
    // future animation.
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.school_outlined, color: Colors.white, size: 40),
    );
  }
}
