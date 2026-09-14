import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';

class AppFormatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String formatCurrency(num? amount) {
    if (amount == null) return '₹0';
    return _currencyFormat.format(amount);
  }

  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  static String formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  // Returns color and background for plan badges with alpha glow for dark/light themes
  static StatusBadgeStyle getStatusBadge(String? status, {bool isDark = false}) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
        return StatusBadgeStyle(
          label: 'Active',
          textColor: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
          bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFD1FAE5),
          icon: Icons.check_circle_outline,
        );
      case 'EXPIRING_SOON':
        return StatusBadgeStyle(
          label: 'Expiring Soon',
          textColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
          bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7),
          icon: Icons.warning_amber_rounded,
        );
      case 'EXPIRED':
        return StatusBadgeStyle(
          label: 'Overdue',
          textColor: isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
          bgColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2),
          icon: Icons.error_outline,
        );
      case 'OUT':
        return StatusBadgeStyle(
          label: 'Outside Hostel',
          textColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF854D0E),
          bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF9C3),
          icon: Icons.directions_walk,
        );
      case 'RETURNED':
        return StatusBadgeStyle(
          label: 'Returned',
          textColor: isDark ? const Color(0xFF34D399) : const Color(0xFF166534),
          bgColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7),
          icon: Icons.home,
        );
      default:
        return StatusBadgeStyle(
          label: status ?? 'Unknown',
          textColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          bgColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
          icon: Icons.info_outline,
        );
    }
  }

  // Color mapping for mess category chips
  static Color getCategoryColor(String? category) {
    switch (category?.toUpperCase()) {
      case 'MILK':
        return AppColors.catMilk;
      case 'VEGETABLES':
        return AppColors.catVeggies;
      case 'RATION':
        return AppColors.catRation;
      case 'GAS':
        return AppColors.catGas;
      case 'SPICES':
        return AppColors.catSpices;
      default:
        return AppColors.catOther;
    }
  }
}

class StatusBadgeStyle {
  final String label;
  final Color textColor;
  final Color bgColor;
  final IconData icon;

  StatusBadgeStyle({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.icon,
  });
}
