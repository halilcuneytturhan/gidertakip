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
import '../../core/models/expense.dart';
import '../../core/services/expense_export.dart';
import '../../core/utils/day.dart';
import '../../core/utils/money.dart';
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
    if (format == null || !context.mounted) return;
    if (format == ExportFormat.csv) {
      await _export(context, format);
      return;
    }
    final report = await _chooseReport(context);
    if (report != null && context.mounted) {
      await _export(context, format, report: report);
    }
  }

  /// "Bugüne kadar" ya da harcama olan aylardan biri; vazgeçilirse `null`.
  Future<_ReportChoice?> _chooseReport(BuildContext context) async {
    final state = AppScope.read(context).state;
    final months = await state.reportMonths();
    if (!context.mounted) return null;
    if (months.isEmpty) {
      showAppSnackBar(context, 'Dışa aktarılacak harcama yok.');
      return null;
    }
    final now = state.now;
    final grandTotal = months.fold(0, (sum, m) => sum + m.totalKurus);
    return showModalBottomSheet<_ReportChoice>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Hangi dönemin raporu?', style: AppText.heading),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    minTileHeight: 56,
                    title: const Text(
                      'Bugüne kadar',
                      style: AppText.subheading,
                    ),
                    subtitle: const Text(
                      'Tüm harcamalar',
                      style: AppText.small,
                    ),
                    trailing: Text(
                      Money.format(grandTotal),
                      style: AppText.bodyStrong,
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, const _ReportChoice()),
                  ),
                  for (final item in months)
                    ListTile(
                      minTileHeight: 56,
                      title: Text(
                        Day.monthYear(item.month),
                        style: AppText.subheading,
                      ),
                      subtitle:
                          item.month.year == now.year &&
                              item.month.month == now.month
                          ? const Text('Bu ay', style: AppText.small)
                          : null,
                      trailing: Text(
                        Money.format(item.totalKurus),
                        style: AppText.bodyStrong,
                      ),
                      onTap: () => Navigator.pop(
                        sheetContext,
                        _ReportChoice(month: item.month),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// PDF ve Word seçilen dönemin raporudur; CSV tüm kayıtları içerir, telefon
  /// değiştirirken yedek olarak işe yarar.
  Future<Uint8List> _build(
    AppState state,
    ExportFormat format,
    List<Expense> rows,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    switch (format) {
      case ExportFormat.csv:
        final csv = await state.exportCsv();
        // Excel Türkçe karakterleri doğru okusun diye UTF-8 BOM eklenir.
        return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      case ExportFormat.pdf:
        return ExpenseExport.pdf(
          rows,
          regular: await rootBundle.load('assets/fonts/Nunito-Regular.ttf'),
          bold: await rootBundle.load('assets/fonts/Nunito-Bold.ttf'),
          logo: (await rootBundle.load(
            'assets/images/brand/splash_mark.png',
          )).buffer.asUint8List(),
          periodStart: periodStart,
          periodEnd: periodEnd,
          generatedAt: state.now,
        );
      case ExportFormat.word:
        return ExpenseExport.docx(
          rows,
          periodStart: periodStart,
          periodEnd: periodEnd,
          generatedAt: state.now,
        );
    }
  }

  /// [report] PDF / Word içindir: geçmiş ayda ayın tamamı, içinde bulunulan
  /// ayda bugüne kadarı, "Bugüne kadar"da ilk kayıttan bugüne tüm harcamalar.
  Future<void> _export(
    BuildContext context,
    ExportFormat format, {
    _ReportChoice? report,
  }) async {
    final state = AppScope.read(context).state;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final now = state.now;
      final month = report?.month;
      var end = now;
      if (month != null) {
        final lastOfMonth = DateTime(
          month.year,
          month.month,
          Day.daysInMonth(month.year, month.month),
        );
        if (lastOfMonth.isBefore(now)) end = lastOfMonth;
      }
      final rows = month == null
          ? await state.allExpenses()
          : await state.expensesBetween(month, end);
      if (rows.isEmpty) {
        if (context.mounted) {
          showAppSnackBar(context, 'Dışa aktarılacak harcama yok.');
        }
        return;
      }
      final start = month ?? rows.first.spentAt;
      // Farklı dönemlerin raporları Drive vb. yerde birbirine karışmasın.
      final fileName = report == null
          ? format.fileName
          : 'emugider-rapor-'
                '${month == null ? 'tumu' : Day.key(month).substring(0, 7)}'
                '.${format.extension}';
      final file = XFile.fromData(
        await _build(state, format, rows, start, end),
        mimeType: format.mime,
        name: fileName,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [fileName],
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

/// Rapor dönemi: [month] ayın 1'idir, `null` ise "Bugüne kadar".
class _ReportChoice {
  const _ReportChoice({this.month});

  final DateTime? month;
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
