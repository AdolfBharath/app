import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/batch.dart';
import '../shared/index.dart';
import '../../features/student/presentation/screens/batch_chat_screen.dart';

/// View dialog for displaying batch details
class BatchViewDialog extends StatelessWidget {
  const BatchViewDialog({super.key, required this.batch});

  final Batch batch;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        batch.name,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailItem(label: 'Status', value: batch.status),
            DetailItem(
              label: 'Enrolled Students',
              value: '${batch.enrolledCount}',
            ),
            DetailItem(label: 'Capacity', value: '${batch.capacity ?? 0}'),
            if (batch.startDate != null)
              DetailItem(
                label: 'Start Date',
                value: batch.startDate.toString().split(' ')[0],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BatchChatScreen(
                  batchId: batch.id,
                  batchName: batch.name,
                ),
              ),
            );
          },
          child: Text('View Chat', style: GoogleFonts.poppins(color: const Color(0xFF8B5CF6))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}
