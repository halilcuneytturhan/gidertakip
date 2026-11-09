import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';

/// Beyaz, yuvarlatılmış ve yumuşak gölgeli kart.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppDimens.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    // Gölge dışta, beyaz zemin Material'da: içteki dokunma efektleri görünür.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppDimens.softShadow,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Yeşil toplam kartı: etiket, büyük tutar ve alt satır.
class TotalCard extends StatelessWidget {
  const TotalCard({
    super.key,
    required this.label,
    required this.amount,
    required this.caption,
  });

  final String label;
  final String amount;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $amount. $caption',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: const BoxDecoration(
          color: AppColors.green,
          borderRadius: AppDimens.heroRadius,
          boxShadow: AppDimens.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.small.copyWith(color: AppColors.greenSoft),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(amount, style: AppText.amount),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: AppText.body.copyWith(
                color: AppColors.greenSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ortalanmış başlık + geri düğmesi (alt sayfalarda).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: canPop
                ? IconButton(
                    tooltip: 'Geri',
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                    ),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.screenTitle,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10, left: 4, right: 4),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppText.heading)),
          ?trailing,
        ],
      ),
    );
  }
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
}
