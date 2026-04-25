import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart' as admin_api;
import '../../models/batch.dart';
import '../shared/index.dart';

/// Edit dialog for updating batch details
class BatchEditDialog extends StatefulWidget {
  const BatchEditDialog({super.key, required this.batch, required this.onSave});

  final Batch batch;
  final VoidCallback onSave;

  @override
  State<BatchEditDialog> createState() => _BatchEditDialogState();
}

class _BatchEditDialogState extends State<BatchEditDialog> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _studentsCountController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _nameController = TextEditingController(text: widget.batch.name);
    _descriptionController = TextEditingController(
      text: widget.batch.capacity?.toString() ?? '',
    );
    _studentsCountController = TextEditingController(
      text: '${widget.batch.enrolledCount}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _studentsCountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await admin_api.ApiService.instance.updateBatch(
        batchId: widget.batch.id,
        name: _nameController.text.trim(),
        capacity: int.tryParse(_descriptionController.text.trim()),
      );
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch updated', style: GoogleFonts.poppins())),
        );
        Navigator.of(context).pop();
      }
      widget.onSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Update failed: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Batch',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminFormField(
                  controller: _nameController,
                  label: 'Batch Name',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Batch name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                AdminFormField(
                  controller: _descriptionController,
                  label: 'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                AdminFormField(
                  controller: _studentsCountController,
                  label: 'Number of Students',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Student count is required';
                    }
                    if (int.tryParse(v.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Save', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}
