import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

/// Alt menüdeki tek öğe.
class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Ekranın altına oturan sade menü: beyaz zemin, üstte ince çizgi. Seçili
/// sekmenin simgesi açık yeşil zeminde durur.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double barHeight = 66;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItemView(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () {
                      if (i != selectedIndex) HapticFeedback.selectionClick();
                      onSelected(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemView extends StatelessWidget {
  const _NavItemView({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOut,
              width: 58,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.greenSoft : Colors.transparent,
                borderRadius: AppDimens.pillRadius,
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppText.label.copyWith(
                color: color,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
