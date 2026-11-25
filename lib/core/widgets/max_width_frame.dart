import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Geniş ekranlarda (iPad) arayüzü ortada, telefon genişliğine yakın bir
/// sütunda tutar. Yazılar ve kartlar tüm genişliğe yayılıp küçük kalmaz.
///
/// Sütunun içindeki ekranlar [MediaQuery] boyutunu sütun genişliği olarak
/// görür. Telefonlarda hiçbir şey değişmez.
class MaxWidthFrame extends StatelessWidget {
  const MaxWidthFrame({super.key, required this.child});

  /// Sütunun en fazla genişliği (mantıksal nokta).
  static const double maxWidth = 600;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;

    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: const BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: AppColors.divider),
            ),
          ),
          child: SizedBox(
            width: maxWidth,
            height: double.infinity,
            child: MediaQuery(
              data: media.copyWith(
                size: Size(maxWidth, media.size.height),
                padding: media.padding.copyWith(left: 0, right: 0),
                viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
