import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/student_provider.dart';

class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<StudentProvider>().fetchNotifications(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Consumer<StudentProvider>(
            builder: (context, student, _) {
              final notifications = student.notifications;

              if (student.isLoading && notifications.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (notifications.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        'No notifications yet',
                        style: GoogleFonts.poppins(
                          color: scheme.onSurface.withAlpha(235),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final n = notifications[index];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.onSurface.withAlpha(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withAlpha(10),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: n.read
                                ? scheme.onSurface.withAlpha(8)
                                : scheme.primary.withAlpha(14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications,
                            size: 18,
                            color: n.read
                                ? scheme.onSurface.withAlpha(150)
                                : scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: n.read
                                          ? scheme.onSurface.withValues(
                                              alpha: 110,
                                            )
                                          : scheme.tertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color:
                                      scheme.onSurface.withAlpha(150),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatTimestamp(n.timestamp),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color:
                                      scheme.onSurface.withAlpha(130),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} h ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    return '${time.day}/${time.month}/${time.year}';
  }
}
