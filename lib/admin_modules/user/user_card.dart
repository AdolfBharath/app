import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user.dart';
import '../shared/index.dart';

/// User card component for displaying a single user in the list
class UserCard extends StatelessWidget {
  const UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });

  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _getRoleColor(),
            child: Text(
              (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleBackgroundColor(),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.role.name,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getRoleColor(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CardActionButton(
            icon: Icons.visibility_outlined,
            label: 'View',
            color: const Color(0xFF6B7280),
            onTap: onView,
          ),
          const SizedBox(width: 6),
          CardActionButton(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: const Color(0xFF2563EB),
            onTap: onEdit,
          ),
          const SizedBox(width: 6),
          CardActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: const Color(0xFFEF4444),
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    switch (user.role) {
      case UserRole.admin:
        return const Color(0xFFEF4444);
      case UserRole.mentor:
        return const Color(0xFF3B82F6);
      case UserRole.student:
        return const Color(0xFF10B981);
    }
  }

  Color _getRoleBackgroundColor() {
    switch (user.role) {
      case UserRole.admin:
        return const Color(0xFFFEE2E2);
      case UserRole.mentor:
        return const Color(0xFFEFF6FF);
      case UserRole.student:
        return const Color(0xFFECFDF5);
    }
  }
}
