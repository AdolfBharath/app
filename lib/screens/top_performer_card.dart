import 'package:flutter/material.dart';
import '../models/batch_detail.dart';

class TopPerformerCard extends StatelessWidget {
  final StudentPerformance performance;
  final VoidCallback? onTap;

  const TopPerformerCard({super.key, required this.performance, this.onTap});

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFBBF24); // Gold
      case 2:
        return const Color(0xFF9CA3AF); // Silver
      case 3:
        return const Color(0xFFD97706); // Bronze
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events; // Trophy
      case 2:
        return Icons.stars; // Stars
      case 3:
        return Icons.military_tech; // Medal
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = _getRankColor(performance.rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: performance.rank <= 3
            ? Border.all(color: rankColor.withOpacity(0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [rankColor, rankColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getRankIcon(performance.rank),
                        color: Colors.white,
                        size: 18,
                      ),
                      Text(
                        '#${performance.rank}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Student info and stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        performance.student.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Progress indicator
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.trending_up,
                                  size: 14,
                                  color: Color(0xFF3B82F6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${performance.progress.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Score
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Color(0xFFFBBF24),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  performance.score.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Assignments completed
                      Text(
                        '${performance.completedAssignments}/${performance.totalAssignments} assignments completed',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
