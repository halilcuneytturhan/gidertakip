import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/navigation/main_shell.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../shared/expense_list.dart';

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

/// Tek satırlık giriş: "taksi 250" yaz, Ekle'ye bas.
class QuickEntryCard extends StatefulWidget {
  const QuickEntryCard({super.key});

  @override
  State<QuickEntryCard> createState() => _QuickEntryCardState();
}

class _QuickEntryCardState extends State<QuickEntryCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _error = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final text = _controller.text;
    if (text.trim().isEmpty) {
      _focus.requestFocus();
      return;
    }
    setState(() => _busy = true);
    final saved = await AppScope.read(context).state.addFromText(text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = saved == null;
    });
    if (saved != null) {
      _controller.clear();
      // Art arda yazmak için klavye açık kalır.
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppDimens.heroRadius,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('quickEntryField'),
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_error) setState(() => _error = false);
                  },
                  onSubmitted: (_) => _submit(),
                  style: AppText.subheading.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  decoration:
                      const InputDecoration(
                        hintText: 'Ne harcadın? örn. taksi 250',
                        semanticCounterText: '',
                      ).copyWith(
                        constraints: const BoxConstraints(
                          minHeight: AppDimens.fieldHeight,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('quickEntryAdd'),
                onPressed: _busy ? null : _submit,
                child: const Text('Ekle'),
              ),
            ],
          ),
          if (_error)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                'Tutarı da yaz, örneğin: kahve 85',
                style: AppText.small.copyWith(color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}
