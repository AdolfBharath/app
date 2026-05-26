import 'package:flutter/material.dart';
import '../services/api_service.dart';

Future<void> showMentorInboxSheet(BuildContext context) async {
  List<Map<String, dynamic>> notifications = const [];
  try {
    notifications = await ApiService.instance.getMentorNotifications();
  } catch (_) {
    notifications = const [];
  }

  if (!context.mounted) return;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a1, a2) {
      final size = MediaQuery.of(context).size;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 18,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: size.width > 520 ? 420 : size.width - 40,
              height: size.height * 0.78,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_none_rounded),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Mentor Inbox',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: notifications.isEmpty
                          ? const Center(child: Text('No notifications'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: notifications.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, i) {
                                final n = notifications[i];
                                return ListTile(
                                  title: Text(n['title'] ?? 'Notification'),
                                  subtitle: Text(n['message'] ?? ''),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
