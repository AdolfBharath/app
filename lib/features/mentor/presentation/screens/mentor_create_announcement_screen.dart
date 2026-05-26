import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../services/api_service.dart';
import '../providers/mentor_provider.dart';

class MentorCreateAnnouncementScreen extends StatefulWidget {
  const MentorCreateAnnouncementScreen({super.key});

  @override
  State<MentorCreateAnnouncementScreen> createState() =>
      _MentorCreateAnnouncementScreenState();
}

class _MentorCreateAnnouncementScreenState
    extends State<MentorCreateAnnouncementScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  DateTime? _expiresOn;
  String? _batchId;
  String _priority = 'normal';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MentorProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _message.text.trim();
    if (_batchId == null || _batchId!.isEmpty) {
      _showMessage('Select a target batch');
      return;
    }
    if (msg.isEmpty) {
      _showMessage('Announcement message is required');
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.instance.sendBatchAnnouncement(
        batchId: _batchId!,
        title: _title.text.trim().isEmpty
            ? 'Batch Announcement'
            : _title.text.trim(),
        message: [
          msg,
          if (_priority != 'normal') '\nPriority: ${_priorityLabel(_priority)}',
          if (_expiresOn != null) 'Expires on: ${_formatDate(_expiresOn!)}',
        ].join('\n'),
      );
      if (!mounted) return;
      await context.read<MentorProvider>().loadAll();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _showMessage('Announcement sent to students.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to send announcement: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mentor = context.watch<MentorProvider>();
    final batches = mentor.batches;
    final courses = mentor.courses;

    final selectedExists = batches.any((b) => b.id == _batchId);
    if (!selectedExists && batches.isNotEmpty) {
      _batchId = batches.first.id;
    }

    final selectedBatch = batches.where((b) => b.id == _batchId).isEmpty
        ? null
        : batches.firstWhere((b) => b.id == _batchId);
    final selectedCourse = selectedBatch == null
        ? null
        : courses.where((c) => c.id == selectedBatch.courseId).isEmpty
            ? null
            : courses.firstWhere((c) => c.id == selectedBatch.courseId);

    return Scaffold(
      backgroundColor: const Color(0xFF6B7280),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'New Announcement',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _sending ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AnnouncementLabel('Title'),
                        const SizedBox(height: 16),
                        _AnnouncementTextField(
                          controller: _title,
                          hintText: 'Class update',
                          enabled: !_sending,
                        ),
                        const SizedBox(height: 28),
                        _AnnouncementLabel('Message'),
                        const SizedBox(height: 16),
                        _AnnouncementTextField(
                          controller: _message,
                          hintText: 'Write the announcement for students...',
                          enabled: !_sending,
                          minLines: 5,
                          maxLines: 7,
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: _StaticField(
                                label: 'Send to',
                                value: 'Selected batch students',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AnnouncementDropdown<String>(
                                label: 'Priority',
                                value: _priority,
                                items: const [
                                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                  DropdownMenuItem(value: 'important', child: Text('Important')),
                                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                                ],
                                onChanged: _sending
                                    ? null
                                    : (value) => setState(() {
                                          _priority = value ?? 'normal';
                                        }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: _AnnouncementDropdown<String?>(
                                label: 'Batch',
                                value: _batchId,
                                items: batches
                                    .map(
                                      (batch) => DropdownMenuItem<String?>(
                                        value: batch.id,
                                        child: Text(batch.name, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _sending
                                    ? null
                                    : (value) => setState(() => _batchId = value),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StaticField(
                                label: 'Course',
                                value: selectedCourse?.title ?? selectedBatch?.courseId ?? 'Course',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _AnnouncementLabel('Expires on'),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _sending ? null : _pickExpiry,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: _announcementInputDecoration().copyWith(
                              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                            ),
                            child: Text(
                              _expiresOn == null ? 'dd-mm-yyyy' : _formatDate(_expiresOn!),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: _expiresOn == null
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: _sending ? null : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 14),
                            FilledButton(
                              onPressed: _sending ? null : _send,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _sending
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(
                                      'Send Announcement',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _expiresOn ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _expiresOn = picked);
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'important':
        return 'Important';
      case 'urgent':
        return 'Urgent';
      default:
        return 'Normal';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }
}

class _AnnouncementLabel extends StatelessWidget {
  const _AnnouncementLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF111827),
      ),
    );
  }
}

InputDecoration _announcementInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
    ),
  );
}

class _AnnouncementTextField extends StatelessWidget {
  const _AnnouncementTextField({
    required this.controller,
    required this.hintText,
    required this.enabled,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: _announcementInputDecoration().copyWith(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: const Color(0xFF7A7F88)),
      ),
    );
  }
}

class _AnnouncementDropdown<T> extends StatelessWidget {
  const _AnnouncementDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnnouncementLabel(label),
        const SizedBox(height: 16),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          decoration: _announcementInputDecoration(),
          style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF111827)),
          dropdownColor: Colors.white,
        ),
      ],
    );
  }
}

class _StaticField extends StatelessWidget {
  const _StaticField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnnouncementLabel(label),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: _announcementInputDecoration(),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF111827)),
          ),
        ),
      ],
    );
  }
}
