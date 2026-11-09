import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Ortak boşluk, köşe ve gölge değerleri.
abstract final class AppDimens {
  static const double gutter = 16;
  static const double gap = 12;
  static const double gapLarge = 24;

  static const double radiusHero = 20;
  static const double radiusCard = 16;
  static const double radiusPill = 26;
  static const double radiusDay = 12;

  static const double minTouch = 48;
  static const double fieldHeight = 52;

  static const BorderRadius heroRadius = BorderRadius.all(
    Radius.circular(radiusHero),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(radiusCard),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(radiusPill),
  );

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
  ];
}
