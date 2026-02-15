import 'package:flutter/material.dart';

/// SafePath York color system
class AppColors {
  AppColors._();

  // === Dark Theme (Default) ===
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color card = Color(0xFF334155);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color border = Color(0xFF475569);

  // === Brand ===
  static const Color brand = Color(0xFF6366F1);
  static const Color brandLight = Color(0xFF818CF8);

  // === Safety Score Colors ===
  static const Color safeHigh = Color(0xFF10B981); // 80-100
  static const Color safeModerate = Color(0xFFF59E0B); // 60-79
  static const Color safeCaution = Color(0xFFEF8B3F); // 40-59
  static const Color safeRisk = Color(0xFFEF4444); // 0-39

  // === Route Type Colors ===
  static const Color routeFastest = Color(0xFF0EA5E9);
  static const Color routeBalanced = Color(0xFF14B8A6);
  static const Color routeSafest = Color(0xFF10B981);

  // === Accents ===
  static const Color safeAccent = Color(0xFF34D399);
  static const Color alertAccent = Color(0xFFFCD34D);
  static const Color dangerAccent = Color(0xFFFB7185);
  
  // === Semantic Colors ===
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // === Light Theme ===
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  /// Returns color for a given safety score (0-100)
  static Color forScore(double score) {
    if (score >= 80) return safeHigh;
    if (score >= 60) return safeModerate;
    if (score >= 40) return safeCaution;
    return safeRisk;
  }

  /// Returns label for a given safety score
  static String labelForScore(double score) {
    if (score >= 80) return 'Very Safe';
    if (score >= 60) return 'Moderate';
    if (score >= 40) return 'Caution';
    return 'Higher Risk';
  }

  /// Returns icon for a given safety score
  static IconData iconForScore(double score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.warning_amber;
    if (score >= 40) return Icons.warning_amber;
    return Icons.cancel;
  }
}
