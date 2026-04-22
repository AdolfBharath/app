import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/mentor_provider.dart';
import '../../../../services/api_service.dart';

class MentorCreateAnnouncementScreen extends StatefulWidget {
  const MentorCreateAnnouncementScreen({super.key});

  @override
  State<MentorCreateAnnouncementScreen> createState() => _MentorCreateAnnouncementScreenState();
}

class _MentorCreateAnnouncementScreenState extends State<MentorCreateAnnouncementScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String? _batchId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final provider = context.read<MentorProvider>();
    final batches = provider.batches;
    if (_batchId == null || _batchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a batch')),
      );
      return;
    }

    final msg = _message.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is required')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ApiService.instance.sendBatchAnnouncement(
        batchId: _batchId!,
        title: _title.text.trim().isEmpty ? 'Batch Announcement' : _title.text.trim(),
        message: msg,
      );
      if (!mounted) return;
      await provider.loadAll();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement sent to students.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = context.watch<MentorProvider>().batches;
    final selectedExists = batches.any((b) => b.id == _batchId);
    if (!selectedExists && batches.isNotEmpty) {
      _batchId = batches.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Announcement'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _batchId,
              decoration: const InputDecoration(labelText: 'Target Batch'),
              items: batches
                  .map(
                    (b) => DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (v) {
                      setState(() => _batchId = v);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 16),
            Text(
              'Students in selected batch will receive this as announcement and notification.',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Announcement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
