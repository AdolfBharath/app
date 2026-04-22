import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user.dart';
import '../shared/index.dart';

/// View dialog for displaying user details
class UserViewDialog extends StatelessWidget {
  const UserViewDialog({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        user.name,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailItem(label: 'Email', value: user.email),
            DetailItem(label: 'Role', value: user.role.name),
            if (user.username != null && user.username!.isNotEmpty)
              DetailItem(label: 'Username', value: user.username!),
            if (user.batchId != null && user.batchId!.isNotEmpty)
              DetailItem(label: 'Batch ID', value: user.batchId!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}
