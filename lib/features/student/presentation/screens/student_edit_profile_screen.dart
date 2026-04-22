import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../widgets/student_animated_avatar.dart';

class StudentEditProfileScreen extends StatefulWidget {
  const StudentEditProfileScreen({super.key});

  @override
  State<StudentEditProfileScreen> createState() => _StudentEditProfileScreenState();
}

class _StudentEditProfileScreenState extends State<StudentEditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _saving = false;
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;

    _nameController.text = user?.name ?? '';
    _usernameController.text = user?.username ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phone ?? '';
    _profileImageBytes = context.read<StudentProvider>().profileImageBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _showTopBanner(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    final changingPassword =
        currentPassword.trim().isNotEmpty || newPassword.trim().isNotEmpty;
    if (changingPassword) {
      if (currentPassword.trim().isEmpty || newPassword.trim().isEmpty) {
        _showTopBanner('Enter both current and new password.', isError: true);
        return;
      }
      if (newPassword.trim().length < 6) {
        _showTopBanner('New password must be at least 6 characters.', isError: true);
        return;
      }
    }

    final namePayload = name == user.name ? null : name;
    final usernamePayload = username == (user.username ?? '') ? null : username;
    final emailPayload = email == user.email ? null : email;
    final phonePayload = phone == (user.phone ?? '') ? null : phone;

    final hasProfileUpdates =
        namePayload != null ||
        usernamePayload != null ||
        emailPayload != null ||
        phonePayload != null ||
        changingPassword;

    if (!hasProfileUpdates) {
      _showTopBanner('No changes to save.');
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await auth.updateUserProfile(
        name: namePayload,
        username: usernamePayload,
        email: emailPayload,
        phone: phonePayload,
        currentPassword: changingPassword ? currentPassword : null,
        password: changingPassword ? newPassword : null,
      );

      if (!mounted) return;

      if (ok) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        Navigator.of(context).pop(true);
      } else {
        _showTopBanner('Update failed. Please try again.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      var message = 'Update failed. Please try again.';
      try {
        final decoded = jsonDecode(e.toString());
        if (decoded is Map && decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      } catch (_) {
        // ignore
      }
      _showTopBanner(message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showTopBanner('Could not load selected image.', isError: true);
        return;
      }

      if (!mounted) return;
      setState(() => _profileImageBytes = bytes);
      await context.read<StudentProvider>().setProfileImageBytes(bytes);
      _showTopBanner('Profile picture updated.');
    } catch (_) {
      if (!mounted) return;
      _showTopBanner('Image selection failed. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final student = context.watch<StudentProvider>();
    final gender = student.gender;
    final displayName = auth.currentUser?.username ?? auth.currentUser?.name ?? 'Student';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Column(
                children: [
                  StudentAnimatedAvatar(
                    gender: gender,
                    size: 120,
                    onPrimaryContext: false,
                    imageBytes: _profileImageBytes,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickProfileImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Change Photo'),
                      ),
                      if (_profileImageBytes != null)
                        OutlinedButton.icon(
                          onPressed: () async {
                            setState(() => _profileImageBytes = null);
                            await context.read<StudentProvider>().setProfileImageBytes(null);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Gender',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Male'),
                        selected: gender == 'male',
                        onSelected: (_) => context.read<StudentProvider>().setGender('male'),
                      ),
                      ChoiceChip(
                        label: const Text('Female'),
                        selected: gender == 'female',
                        onSelected: (_) => context.read<StudentProvider>().setGender('female'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This controls your avatar illustration.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 150),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'Name',
              controller: _nameController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Username',
              controller: _usernameController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Phone',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            Text(
              'Change password (optional)',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _Field(
              label: 'Current password',
              controller: _currentPasswordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'New password',
              controller: _newPasswordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _saving ? 'Saving...' : 'Save',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface.withValues(alpha: 235),
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
        hintStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: scheme.onSurface.withValues(alpha: 235),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 60)),
        ),
      ),
    );
  }
}
