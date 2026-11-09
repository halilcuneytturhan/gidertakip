import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/expense.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart' show AppCard;
import 'expense_edit_sheet.dart';

/// Harcama listesi kartı. Satıra dokununca düzenleme açılır, sola
/// kaydırınca silinir (geri alınabilir).
class ExpenseList extends StatefulWidget {
  const ExpenseList({
    super.key,
    required this.expenses,
    required this.emptyText,
    this.onChanged,
  });

  final List<Expense> expenses;
  final String emptyText;

  /// Silme / düzenleme / geri alma sonrası (geçmiş ekranı yeniden sorgular).
  final VoidCallback? onChanged;

  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  // Kaydırılarak silinen satır aynı karede ağaçtan çıkmalı (Dismissible
  // kuralı); veritabanı yanıtı beklenmeden yerel kopyadan düşülür.
  late List<Expense> _items = List.of(widget.expenses);

  @override
  void didUpdateWidget(ExpenseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.expenses, widget.expenses)) {
      _items = List.of(widget.expenses);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Text(widget.emptyText, style: AppText.body),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++)
            _ExpenseRow(
              key: ValueKey(_items[i].id),
              expense: _items[i],
              showDivider: i < _items.length - 1,
              onDismissed: () => setState(() => _items.removeAt(i)),
              onChanged: widget.onChanged,
            ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    super.key,
    required this.expense,
    required this.showDivider,
    required this.onDismissed,
    this.onChanged,
  });

  final Expense expense;
  final bool showDivider;
  final VoidCallback onDismissed;
  final VoidCallback? onChanged;

  Future<void> _delete(BuildContext context) async {
    // Satır birazdan ağaçtan çıkacağı için bağlamdan okunacaklar önce alınır.
    final state = AppScope.read(context).state;
    final messenger = ScaffoldMessenger.of(context);
    final onChanged = this.onChanged;
    await state.delete(expense);
    onChanged?.call();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${expense.name} silindi.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () async {
              await state.restore(expense);
              onChanged?.call();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.dangerSoft,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
          semanticLabel: 'Sil',
        ),
      ),
      onDismissed: (_) {
        onDismissed();
        _delete(context);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final changed = await showExpenseEditSheet(context, expense);
            if (changed) onChanged?.call();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: showDivider
                  ? const Border(bottom: BorderSide(color: AppColors.divider))
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    expense.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.subheading.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Money.format(expense.amountKurus),
                  style: AppText.bodyStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
