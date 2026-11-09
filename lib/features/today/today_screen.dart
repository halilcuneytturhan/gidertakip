import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/navigation/main_shell.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../add_past/add_past_screen.dart';
import '../shared/expense_list.dart';
import '../shared/quick_entry_card.dart';

/// Ana ekran: bugünün toplamı, "Ne harcadın?" satırı ve bugün eklenenler.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context).state;
    final count = state.todayExpenses.length;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          bottom: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppDimens.gutter,
              24,
              AppDimens.gutter,
              MainShell.bottomInset(context),
            ),
            children: [
              TotalCard(
                label: 'Bugün toplam',
                amount: Money.format(state.todayTotal),
                caption: count == 0
                    ? 'Henüz harcama yazmadın.'
                    : 'Bugün $count harcama yazdın.',
              ),
              const SizedBox(height: 14),
              const QuickEntryCard(),
              const SizedBox(height: 10),
              _PastDayButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddPastScreen()),
                ),
              ),
              const SectionTitle('Eklenenler'),
              ExpenseList(
                expenses: state.todayExpenses,
                emptyText: 'İlk harcamanı yaz, örneğin: kahve 85',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Geçmiş günlere harcama ekle" satırı.
class _PastDayButton extends StatelessWidget {
  const _PastDayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppDimens.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('addPastDay'),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_calendar_rounded,
                  color: AppColors.green,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Geçmiş günlere harcama ekle',
                    style: AppText.subheading.copyWith(
                      color: AppColors.greenDeep,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
