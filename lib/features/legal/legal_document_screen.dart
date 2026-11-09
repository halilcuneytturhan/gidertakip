import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/common.dart';
import 'legal_config.dart';

/// Yasal belgeyi açar (alt menü görünmez).
Future<void> openLegalDocument(BuildContext context, LegalDocument document) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );

/// `assets/legal/*.md` belgesini uygulama içinde gösterir.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.document, this.bundle});

  final LegalDocument document;

  /// Testler için (varsayılan: [rootBundle]).
  final AssetBundle? bundle;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final Future<List<LegalBlock>> _blocks = (widget.bundle ?? rootBundle)
      .loadString(widget.document.asset)
      .then((text) => parseLegalMarkdown(fillLegalPlaceholders(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: widget.document.title),
            Expanded(
              child: FutureBuilder<List<LegalBlock>>(
                future: _blocks,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimens.gutter),
                        child: Text('Belge yüklenemedi.', style: AppText.body),
                      ),
                    );
                  }
                  final blocks = snapshot.data;
                  if (blocks == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SelectionArea(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        AppDimens.gutter,
                        8,
                        AppDimens.gutter,
                        MediaQuery.paddingOf(context).bottom + 24,
                      ),
                      children: [
                        AppCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final block in blocks)
                                if (block.kind != LegalBlockKind.title)
                                  _BlockView(block),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView(this.block);

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final text = Text.rich(
      TextSpan(children: _inline(block.text)),
      style: switch (block.kind) {
        LegalBlockKind.heading => AppText.subheading,
        LegalBlockKind.subheading => AppText.bodyStrong,
        _ => AppText.body,
      },
    );
    return switch (block.kind) {
      LegalBlockKind.heading => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: text,
      ),
      LegalBlockKind.subheading => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: text,
      ),
      LegalBlockKind.bullet => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, right: 10),
              child: Icon(Icons.circle, size: 6, color: AppColors.green),
            ),
            Expanded(child: text),
          ],
        ),
      ),
      _ => Padding(padding: const EdgeInsets.only(bottom: 10), child: text),
    };
  }

  /// `**kalın**` vurgusu.
  static List<TextSpan> _inline(String text) {
    final parts = text.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(
            text: parts[i],
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
    ];
  }
}

enum LegalBlockKind { title, heading, subheading, bullet, paragraph }

class LegalBlock {
  const LegalBlock(this.kind, this.text);

  final LegalBlockKind kind;
  final String text;

  @override
  String toString() => '${kind.name}: $text';
}

/// Yasal metinlerde kullanılan sade Markdown alt kümesi: `#`, `##`, `###`
/// başlıklar, `- ` madde, boş satırla ayrılan paragraflar ve `**kalın**`.
/// Aynı kurallar `tool/legal/build_legal_pages.py` içinde de uygulanır.
List<LegalBlock> parseLegalMarkdown(String source) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalBlock(LegalBlockKind.paragraph, paragraph.join(' ')));
    paragraph.clear();
  }

  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final (kind, prefix) = switch (line) {
      _ when line.startsWith('### ') => (LegalBlockKind.subheading, 4),
      _ when line.startsWith('## ') => (LegalBlockKind.heading, 3),
      _ when line.startsWith('# ') => (LegalBlockKind.title, 2),
      _ when line.startsWith('- ') => (LegalBlockKind.bullet, 2),
      _ => (LegalBlockKind.paragraph, 0),
    };
    if (kind == LegalBlockKind.paragraph) {
      paragraph.add(line);
    } else {
      flush();
      blocks.add(LegalBlock(kind, line.substring(prefix).trim()));
    }
  }
  flush();
  return blocks;
}
