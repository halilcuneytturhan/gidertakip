import 'package:flutter/material.dart';

/// EmuGider renk paleti. Tüm renkler buradan okunur.
abstract final class AppColors {
  // Zeminler
  static const Color background = Color(0xFFF6F5F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceGlass = Color(0xE6FFFFFF); // %90 beyaz
  static const Color fieldFill = Color(0xFFF6F5F2);
  static const Color divider = Color(0xFFECEAE4);
  static const Color border = Color(0xFFD9D6CE);
  static const Color shadow = Color(0x1F1B3A33);

  // Ana vurgu: koyu yeşil
  static const Color green = Color(0xFF0F6B5C);
  static const Color greenDeep = Color(0xFF0A5246);
  static const Color greenSoft = Color(0xFFE3F0EC);
  static const Color onGreen = Color(0xFFFFFFFF);

  // Uyarı
  static const Color danger = Color(0xFFB4461F);
  static const Color dangerSoft = Color(0xFFFBE9E1);

  // Metin
  static const Color textPrimary = Color(0xFF1B1B1A);
  static const Color textSecondary = Color(0xFF5E5C57);
  static const Color textTertiary = Color(0xFF8C8981);
}
