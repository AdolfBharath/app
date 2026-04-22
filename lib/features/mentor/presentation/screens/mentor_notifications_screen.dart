import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/mentor_provider.dart';

class MentorNotificationsScreen extends StatefulWidget {
  const MentorNotificationsScreen({super.key});

  @override
  State<MentorNotificationsScreen> createState() => _MentorNotificationsScreenState();
}

class _MentorNotificationsScreenState extends State<MentorNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MentorProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MentorProvider>();
    final items = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MentorProvider>().loadAll(),
        child: provider.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? Center(
                    child: Text(
                      'No notifications yet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.sender,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.message,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.timestamp.toLocal().toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
