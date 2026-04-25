import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../services/api_service.dart';
import '../widgets/student_header_row.dart';

class StudentSupportScreen extends StatefulWidget {
  const StudentSupportScreen({super.key});

  static const routeName = '/student/support';

  @override
  State<StudentSupportScreen> createState() => _StudentSupportScreenState();
}

class _StudentSupportScreenState extends State<StudentSupportScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final auth = context.read<AuthProvider>();
    final username = auth.currentUser?.username ?? auth.currentUser?.name ?? 'Student';
    final message = _controller.text.trim();

    if (message.length < 2) {
      _showTopBanner(context, 'Please type a message.', isError: true);
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.instance.sendSupportMessage(message: message);
      if (!mounted) return;
      _controller.clear();
      _showTopBanner(context, 'Message sent. We\'ll get back to you soon, $username.');
    } catch (_) {
      if (!mounted) return;
      _showTopBanner(context, 'Failed to send message. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StudentHeaderRow(
                showProfile: false,
                showLogout: false,
                showNotifications: false,
                showThemeToggle: false,
              ),
              const SizedBox(height: 12),
              Text(
                'Support',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Need help? Send us a message.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface.withAlpha(160),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.onSurface.withAlpha(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withAlpha(10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface.withAlpha(235),
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: scheme.onSurface.withAlpha(12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: scheme.onSurface.withAlpha(12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: scheme.primary.withAlpha(60),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _send,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _sending ? 'Sending...' : 'Send Message',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.onSurface.withAlpha(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, color: scheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin Email: support@jenovate.com',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: scheme.onSurface.withAlpha(160),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, color: scheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Phone: +91 00000 00000',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: scheme.onSurface.withAlpha(160),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

void _showTopBanner(BuildContext context, String message, {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentMaterialBanner();
  messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: isError ? scheme.errorContainer : scheme.surface,
      content: Text(
        message,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: isError ? scheme.onErrorContainer : scheme.onSurface,
        ),
      ),
      actions: [
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('OK'),
        ),
      ],
    ),
  );
  Future<void>.delayed(const Duration(seconds: 3), () {
    if (!context.mounted) return;
    messenger.hideCurrentMaterialBanner();
  });
}
