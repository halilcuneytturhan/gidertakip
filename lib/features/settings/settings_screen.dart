import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/navigation/main_shell.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/services/expense_export.dart';
import '../../core/widgets/common.dart';
import '../legal/legal_config.dart';
import '../legal/legal_document_screen.dart';

/// Ayarlar: dışa aktarma, tüm verileri silme ve uygulama bilgisi.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String version = '1.0.0';

  Future<void> _chooseExport(BuildContext context) async {
    final format = await showModalBottomSheet<ExportFormat>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Hangi biçimde olsun?', style: AppText.heading),
            ),
            for (final format in ExportFormat.values)
              ListTile(
                minTileHeight: 60,
                title: Text(format.label, style: AppText.subheading),
                subtitle: Text(format.description, style: AppText.small),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
                onTap: () => Navigator.pop(sheetContext, format),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format != null && context.mounted) await _export(context, format);
  }

  Future<Uint8List> _build(AppState state, ExportFormat format) async {
    switch (format) {
      case ExportFormat.csv:
        final csv = await state.exportCsv();
        // Excel Türkçe karakterleri doğru okusun diye UTF-8 BOM eklenir.
        return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      case ExportFormat.pdf:
        return ExpenseExport.pdf(
          await state.allExpenses(),
          regular: await rootBundle.load('assets/fonts/Nunito-Regular.ttf'),
          bold: await rootBundle.load('assets/fonts/Nunito-Bold.ttf'),
        );
      case ExportFormat.word:
        return ExpenseExport.docx(await state.allExpenses());
    }
  }

  Future<void> _export(BuildContext context, ExportFormat format) async {
    final state = AppScope.read(context).state;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      if ((await state.allExpenses()).isEmpty) {
        if (context.mounted) {
          showAppSnackBar(context, 'Dışa aktarılacak harcama yok.');
        }
        return;
      }
      final file = XFile.fromData(
        await _build(state, format),
        mimeType: format.mime,
        name: format.fileName,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [format.fileName],
          subject: 'EmuGider harcamaları',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, 'Dışa aktarılamadı.');
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tüm harcamalar silinsin mi?'),
        content: const Text(
          'Yazdığın tüm harcamalar bu cihazdan kalıcı olarak silinir. '
          'İstersen önce dışa aktarabilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await AppScope.read(context).state.deleteAllData();
      if (context.mounted) showAppSnackBar(context, 'Tüm harcamalar silindi.');
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, 'Veriler silinemedi.');
    }
  }

  void _about(BuildContext context) {
    showAboutDialog(
      context: context,
      useRootNavigator: true,
      applicationName: 'EmuGider',
      applicationVersion: version,
      children: const [
        Text(
          'Yazdığın harcamaları gün gün toplar. Hesap açman gerekmez; '
          'veriler yalnızca bu cihazda saklanır ve hiçbir sunucuya '
          'gönderilmez.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppDimens.gutter,
            12,
            AppDimens.gutter,
            MainShell.bottomInset(context),
          ),
          children: [
            const SizedBox(
              height: 56,
              child: Center(child: Text('Ayarlar', style: AppText.screenTitle)),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Builder(
                    builder: (tileContext) => _SettingsTile(
                      icon: Icons.ios_share_rounded,
                      title: 'Harcamaları dışa aktar',
                      onTap: () => _chooseExport(tileContext),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: LegalDocument.privacy.title,
                    onTap: () =>
                        openLegalDocument(context, LegalDocument.privacy),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    title: LegalDocument.terms.title,
                    onTap: () =>
                        openLegalDocument(context, LegalDocument.terms),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'Hakkında',
                    onTap: () => _about(context),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Tüm verileri sil',
                    destructive: true,
                    onTap: () => _deleteAll(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Veriler yalnızca bu cihazda saklanır. Telefonunu '
                'değiştirmeden önce dışa aktarmayı unutma.',
                textAlign: TextAlign.center,
                style: AppText.small.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: color),
      title: Text(title, style: AppText.subheading.copyWith(color: color)),
      trailing: destructive
          ? null
          : const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
      onTap: onTap,
    );
  }
}
