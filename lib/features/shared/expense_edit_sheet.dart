import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/expense.dart';
import '../../core/utils/expense_parser.dart';
import '../../core/utils/money.dart';

/// Bir harcamanın adını ve tutarını düzenler. Değişiklik ya da silme
/// olduysa `true` döner.
Future<bool> showExpenseEditSheet(BuildContext context, Expense expense) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ExpenseEditSheet(expense: expense),
  );
  return result ?? false;
}

class _ExpenseEditSheet extends StatefulWidget {
  const _ExpenseEditSheet({required this.expense});

  final Expense expense;

  @override
  State<_ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<_ExpenseEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.expense.name,
  );
  late final TextEditingController _amount = TextEditingController(
    text: Money.number(widget.expense.amountKurus),
  );
  String? _amountError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = ExpenseParser.parseAmount(_amount.text.replaceAll(' ', ''));
    if (amount == null || amount <= 0 || amount > ExpenseParser.maxKurus) {
      setState(() => _amountError = 'Geçerli bir tutar yaz, örneğin 85,50');
      return;
    }
    var name = _name.text.trim();
    if (name.isEmpty) name = ExpenseParser.fallbackName;
    setState(() => _busy = true);
    await AppScope.read(context).state.update(
      widget.expense.copyWith(
        name: ExpenseParser.capitalize(name),
        amountKurus: amount,
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    await AppScope.read(context).state.delete(widget.expense);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Harcamayı düzenle', style: AppText.heading),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: ExpenseParser.maxNameLength,
              decoration: const InputDecoration(
                labelText: 'Ne harcadın?',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Tutar',
                suffixText: 'TL',
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Kaydet'),
            ),
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: _busy ? null : _delete,
              child: const Text('Sil'),
            ),
          ],
        ),
      ),
    );
  }
}
