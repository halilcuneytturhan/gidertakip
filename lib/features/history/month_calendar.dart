import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/utils/day.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';

/// Pazartesi ile başlayan ay takvimi; her günün altında o gün harcanan
/// tutar (TL) yazar.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.totals,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  /// Ayın 1'i.
  final DateTime month;
  final DateTime today;
  final int selectedDay;

  /// Gün → kuruş.
  final Map<int, int> totals;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final days = Day.daysInMonth(month.year, month.month);
    final lead = month.weekday - 1; // Pazartesi = 0
    final slots = ((lead + days) / 7).ceil() * 7;

    return AppCard(
      radius: AppDimens.heroRadius,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                _RoundButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Önceki ay',
                  onPressed: onPrevious,
                ),
                Expanded(
                  child: Text(
                    Day.monthYear(month),
                    textAlign: TextAlign.center,
                    style: AppText.heading,
                  ),
                ),
                _RoundButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Sonraki ay',
                  onPressed: onNext,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final name in Day.weekdaysShort)
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AppText.label,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < slots ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(child: _cell(row * 7 + col - lead + 1, days)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(int day, int days) {
    if (day < 1 || day > days) return const SizedBox(height: 54);
    final date = DateTime(month.year, month.month, day);
    final total = totals[day] ?? 0;
    final selected = day == selectedDay;
    final isToday = Day.same(date, today);
    final numberColor = selected ? AppColors.onGreen : AppColors.textPrimary;
    final amountColor = selected
        ? AppColors.greenSoft
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '$day ${Day.months[month.month - 1]}, '
            '${total > 0 ? Money.format(total) : 'harcama yok'}',
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.green : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusDay),
            side: isToday && !selected
                ? const BorderSide(color: AppColors.green, width: 1.4)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelect(day),
            child: SizedBox(
              height: 54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: AppText.subheading.copyWith(
                      color: numberColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 15,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        total > 0 ? Money.compact(total) : '',
                        style: AppText.label.copyWith(
                          color: amountColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 24),
    );
  }
}
