import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/utils/expense_parser.dart';

/// "Sık kullanılanlara ekle" sayfası: yazılan satır harcama olarak
/// kaydedilmez, çiplere eklenir. Eklenen öğeyi döner, vazgeçilirse `null`.
Future<ParsedExpense?> showFavoriteSheet(BuildContext context) =>
    showModalBottomSheet<ParsedExpense>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => const _FavoriteSheet(),
    );

class _FavoriteSheet extends StatefulWidget {
  const _FavoriteSheet();

  @override
  State<_FavoriteSheet> createState() => _FavoriteSheetState();
}

class _FavoriteSheetState extends State<_FavoriteSheet> {
  final _controller = TextEditingController();
  bool _error = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _controller.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final saved = await AppScope.read(
      context,
    ).state.addFavoriteFromText(_controller.text);
    if (!mounted) return;
    if (saved != null) {
      Navigator.pop(context, saved);
      return;
    }
    setState(() {
      _busy = false;
      _error = true;
    });
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
            const Text('Sık kullanılanlara ekle', style: AppText.heading),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('favoriteField'),
                    controller: _controller,
                    autofocus: true,
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
                      hintText: 'örn. Sigara 125',
                      constraints: BoxConstraints(
                        minHeight: AppDimens.fieldHeight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('favoriteAdd'),
                  onPressed: _busy ? null : _submit,
                  child: const Text('Ekle'),
                ),
              ],
            ),
            if (_error)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  'Tutarı da yaz, örneğin: Sigara 125',
                  style: AppText.small.copyWith(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
