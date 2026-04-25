import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../providers/theme_provider.dart';
import '../providers/student_provider.dart';

class StudentHeaderRow extends StatelessWidget {
  const StudentHeaderRow({
    super.key,
    this.onNotificationsTap,
    this.onProfileTap,
    this.onLogoutTap,
    this.showProfile = true,
    this.showLogout = false,
    this.showNotifications = true,
    this.showThemeToggle = true,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;
  final bool showProfile;
  final bool showLogout;
  final bool showNotifications;
  final bool showThemeToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = context.watch<ThemeProvider>().isDark;

    final unreadCount = context
        .watch<StudentProvider>()
        .notifications
        .where((n) => !n.read)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              'assets/jenovate_logo.png',
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(
                'Jenovate',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2563EB),
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const Spacer(),

          if (showThemeToggle)
            _HeaderIconBtn(
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              onTap: () => context.read<ThemeProvider>().toggle(),
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              scheme: scheme,
            ),

          if (showNotifications) ...[
            const SizedBox(width: 8),
            _NotificationBtn(
              unreadCount: unreadCount,
              onTap: onNotificationsTap,
              scheme: scheme,
            ),
          ],

          if (showProfile) ...[
            const SizedBox(width: 8),
            _ProfileBtn(onTap: onProfileTap, scheme: scheme),
          ],

          if (showLogout) ...[
            const SizedBox(width: 8),
            _HeaderIconBtn(
              icon: Icons.logout_rounded,
              onTap: onLogoutTap,
              tooltip: 'Logout',
              scheme: scheme,
              color: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Small circular icon button ───────────────────────────────────────────────
class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.onTap,
    required this.scheme,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme scheme;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.onSurface.withAlpha(12)),
          ),
          child: Icon(icon, size: 20, color: color ?? scheme.onSurface),
        ),
      ),
    );
  }
}

// ── Notification button with badge ──────────────────────────────────────────
class _NotificationBtn extends StatelessWidget {
  const _NotificationBtn({
    required this.unreadCount,
    required this.onTap,
    required this.scheme,
  });

  final int unreadCount;
  final VoidCallback? onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.onSurface.withAlpha(12)),
              ),
              child: Icon(Icons.notifications_rounded, size: 20, color: scheme.onSurface),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Profile avatar button ────────────────────────────────────────────────────
class _ProfileBtn extends StatelessWidget {
  const _ProfileBtn({required this.onTap, required this.scheme});

  final VoidCallback? onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Profile',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary.withAlpha(40)),
          ),
          child: Icon(Icons.person_rounded, size: 20, color: scheme.primary),
        ),
      ),
    );
  }
}
