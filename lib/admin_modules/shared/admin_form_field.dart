import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable form field for admin dialogs
class AdminFormField extends StatelessWidget {
  const AdminFormField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<dynamic>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator ?? (v) => null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      style: GoogleFonts.poppins(fontSize: 13),
    );
  }
}
