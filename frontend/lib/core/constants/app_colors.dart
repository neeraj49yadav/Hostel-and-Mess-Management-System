import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF6366F1); // Indigo 500
  static const Color primaryDark = Color(0xFF3730A3); // Indigo 800
  static const Color secondary = Color(0xFF0D9488); // Teal 600
  static const Color secondaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color accent = Color(0xFF8B5CF6); // Violet 500

  // Status Indicators
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFF34D399); // Emerald 400
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFBBF24); // Amber 400
  static const Color danger = Color(0xFFEF4444); // Red 500
  static const Color dangerLight = Color(0xFFF87171); // Red 400
  static const Color info = Color(0xFF0EA5E9); // Sky 500

  // Light Mode Surfaces & Neutrals
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF); // White
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate 100
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate 400

  // Dark Mode Surfaces & Neutrals (Obsidian Pro)
  static const Color backgroundDark = Color(0xFF0B0F19); // Midnight Black
  static const Color surfaceDark = Color(0xFF161F30); // Deep Obsidian Slate
  static const Color surfaceDarkSecondary = Color(0xFF1E293B); // Slate 800
  static const Color surfaceVariantDark = Color(0xFF26334D); // Raised Slate Card
  static const Color borderDark = Color(0xFF334155); // Slate 700 Border
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Pure Crisp Slate 50
  static const Color textSecondaryDark = Color(0xFFCBD5E1); // Slate 300
  static const Color textMutedDark = Color(0xFF64748B); // Slate 500

  // Fallbacks for legacy references
  static const Color background = backgroundLight;
  static const Color surface = surfaceLight;
  static const Color surfaceVariant = surfaceVariantLight;
  static const Color border = borderLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textMuted = textMutedLight;

  // Category Colors for Mess
  static const Color catMilk = Color(0xFF38BDF8); // Sky Blue
  static const Color catVeggies = Color(0xFF34D399); // Mint Emerald
  static const Color catRation = Color(0xFFFBBF24); // Warm Gold
  static const Color catGas = Color(0xFFF87171); // Coral Rose
  static const Color catSpices = Color(0xFFA78BFA); // Soft Lavender
  static const Color catOther = Color(0xFF94A3B8); // Slate
}
