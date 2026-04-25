import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:typed_data';

class StudentAnimatedAvatar extends StatelessWidget {
  const StudentAnimatedAvatar({
    super.key,
    required this.gender,
    this.size = 108,
    this.onPrimaryContext = true,
    this.imageBytes,
  });

  final String gender;
  final double size;
  final bool onPrimaryContext;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = gender.trim().toLowerCase();
    final asset = normalized == 'female'
        ? 'assets/avatars/female.png'
        : 'assets/avatars/male.png';

    final bg = onPrimaryContext
        ? Colors.white.withAlpha(36)
        : scheme.primary.withAlpha(12);
    final borderColor = onPrimaryContext
        ? Colors.white.withAlpha(60)
        : scheme.primary.withAlpha(30);

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: onPrimaryContext ? 20 : 8),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.06),
      child: ClipOval(
        child: imageBytes != null && imageBytes!.isNotEmpty
            ? Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
              )
            : Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      normalized == 'female'
                          ? Icons.face_3_outlined
                          : Icons.face_outlined,
                      size: size * 0.5,
                      color: onPrimaryContext
                          ? Colors.white.withAlpha(220)
                          : scheme.primary,
                    ),
                  );
                },
              ),
      ),
    );

    // Idle floating animation
    return avatar
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .slideY(
          begin: 0.0,
          end: -0.045,
          duration: 1600.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .slideY(
          begin: -0.045,
          end: 0.0,
          duration: 1600.ms,
          curve: Curves.easeInOut,
        );
  }
}
