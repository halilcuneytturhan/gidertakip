import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/models/expense.dart';
import '../../core/utils/expense_parser.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import 'favorite_sheet.dart';

/// Tek satırlık giriş: "taksi 250" yaz, Ekle'ye bas. Altında sık yazılan
/// harcamalar tek dokunuşla eklenecek çipler olarak durur.
///
/// [day] verilmezse bugüne, verilirse o güne ekler.
class QuickEntryCard extends StatefulWidget {
  const QuickEntryCard({super.key, this.day});

  final DateTime? day;

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
    final saved = await AppScope.read(
      context,
    ).state.addFromText(text, day: widget.day);
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

  Future<void> _addFrequent(ParsedExpense item) async {
    final state = AppScope.read(context).state;
    final messenger = ScaffoldMessenger.of(context);
    final Expense saved = await state.add(
      name: item.name,
      amountKurus: item.amountKurus,
      at: widget.day == null ? null : state.timeFor(widget.day!),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} eklendi.'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => state.delete(saved),
          ),
        ),
      );
  }

  Future<void> _openFavoriteSheet() async {
    final saved = await showFavoriteSheet(context);
    if (saved == null || !mounted) return;
    showAppSnackBar(
      context,
      '${saved.name} sık kullanılanlarda. Çıkarmak için çipe basılı tut.',
    );
  }

  Future<void> _removeFavorite(ParsedExpense item) async {
    final state = AppScope.read(context).state;
    final messenger = ScaffoldMessenger.of(context);
    await state.removeFavorite(item);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} sık kullanılanlardan çıkarıldı.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => state.addFavorite(item),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context).state;
    final items = state.quickItems;
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
                  decoration: const InputDecoration(
                    hintText: 'Ne harcadın? örn. taksi 250',
                    constraints: BoxConstraints(
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
          // "+" yalnızca ana sayfada; geçmiş güne eklemede başlık boşsa gizli.
          if (items.isNotEmpty || widget.day == null) ...[
            SizedBox(height: widget.day == null ? 8 : 12),
            Padding(
              padding: EdgeInsets.only(
                left: 6,
                bottom: widget.day == null ? 4 : 8,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Sık kullanılanlar', style: AppText.label),
                  ),
                  if (widget.day == null)
                    IconButton(
                      key: const Key('favoriteOpen'),
                      tooltip: 'Sık kullanılanlara ekle',
                      onPressed: _openFavoriteSheet,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.greenSoft,
                        foregroundColor: AppColors.green,
                        minimumSize: const Size(40, 40),
                        maximumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 22),
                    ),
                ],
              ),
            ),
            if (items.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    _FrequentChip(
                      item: item,
                      onTap: () => _addFrequent(item),
                      onLongPress: state.isFavorite(item)
                          ? () => _removeFavorite(item)
                          : null,
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _FrequentChip extends StatelessWidget {
  const _FrequentChip({
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  final ParsedExpense item;
  final VoidCallback onTap;

  /// Yalnızca kullanıcının eklediği çiplerde: sık kullanılanlardan çıkarır.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final amount = Money.format(item.amountKurus);
    return Semantics(
      button: true,
      label: '${item.name} $amount ekle',
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null
          ? null
          : 'Sık kullanılanlardan çıkar',
      excludeSemantics: true,
      child: Material(
        color: AppColors.greenSoft,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${item.name} · $amount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small.copyWith(
                        color: AppColors.greenDeep,
                        fontWeight: FontWeight.w700,
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
