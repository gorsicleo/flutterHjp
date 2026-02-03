import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../data/models/entry_detail.dart';
import 'forms_table.dart';

class EntryView extends StatelessWidget {
  final EntryDetail? entry;

  /// When user taps a dictionary link, we call this with the extracted word.
  final void Function(String word)? onOpenWord;

  const EntryView({
    super.key,
    required this.entry,
    this.onOpenWord,
  });

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return const Center(child: Text('Type to search…'));
    }

    final theme = Theme.of(context);

    String fixRelativeLinks(String s) => s;

    void handleLinkTap(String? url) {
      final term = _extractDictionaryTerm(url);
      if (term != null && term.trim().isNotEmpty) {
        onOpenWord?.call(term.trim());
      }
    }

    final detalji = fixRelativeLinks(entry!.detaljiHtml);
    final definicija = fixRelativeLinks(entry!.definicijaHtml.replaceAll('\n', '<br>'));
    final etim = fixRelativeLinks(entry!.etimologijaHtml);

    final frazeHtml = fixRelativeLinks(entry!.frazeText.replaceAll('\n', '<br>'));
    final sintagmaRaw = fixRelativeLinks(entry!.sintagmaHtml);
    final onomastikaHtml = fixRelativeLinks(entry!.onomastikaHtml.replaceAll('\n', '<br>'));

    Widget htmlCard(String html) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Html(
            data: html,
            style: {
              "body": Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                lineHeight: const LineHeight(1.4),
              ),
            },
            onLinkTap: (url, _, __) => handleLinkTap(url),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: _AnimatedIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AnimatedBlock(
              delay: const Duration(milliseconds: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry!.rijec, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(entry!.vrsta, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _AnimatedBlock(
              delay: const Duration(milliseconds: 30),
              child: htmlCard(detalji),
            ),

            const SizedBox(height: 16),
            _AnimatedBlock(
              delay: const Duration(milliseconds: 60),
              child: Text('Definicija', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            _AnimatedBlock(
              delay: const Duration(milliseconds: 80),
              child: htmlCard(definicija),
            ),

            if (entry!.frazeText.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 110),
                child: Text('Frazeologija', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 130),
                child: htmlCard(frazeHtml),
              ),
            ],

            if (sintagmaRaw.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 150),
                child: Text('Sintagma', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 170),
                child: _SintagmaCard(
                  raw: sintagmaRaw,
                  onLinkTap: handleLinkTap,
                ),
              ),
            ],

            if (entry!.izvedeniJson.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 190),
                child: Text('Izvedeni oblici', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 210),
                child: FormsTable(izvedeniJson: entry!.izvedeniJson),
              ),
            ],

            if (entry!.onomastikaHtml.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 270),
                child: Text('Onomastika', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 290),
                child: htmlCard(onomastikaHtml),
              ),
            ],

            if (entry!.etimologijaHtml.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 230),
                child: Text('Etimologija', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 250),
                child: htmlCard(etim),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _extractDictionaryTerm(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;

    final idx = u.indexOf('/r/');
    if (idx != -1) {
      var part = u.substring(idx + 3);
      part = part.split('?').first.split('#').first;
      part = Uri.decodeComponent(part);
      return part.trim();
    }

    try {
      final uri = Uri.parse(u);
      final keyword = uri.queryParameters['keyword'];
      if (keyword != null && keyword.trim().isNotEmpty) {
        return keyword.trim();
      }
    } catch (_) {}

    return null;
  }
}

/// Same helper you already had.
class _SintagmaCard extends StatelessWidget {
  final String raw;
  final void Function(String? url) onLinkTap;

  const _SintagmaCard({
    required this.raw,
    required this.onLinkTap,
  });

  List<Map<String, String>>? _tryParseSintagmaList(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;

    dynamic parsed;

    if ((t.startsWith('[') && t.endsWith(']')) || (t.startsWith('{') && t.endsWith('}'))) {
      try {
        parsed = jsonDecode(t);
      } catch (_) {}
    }

    if (parsed == null && (t.startsWith('"sintagma"') || t.startsWith('sintagma'))) {
      try {
        parsed = jsonDecode('{$t}');
      } catch (_) {}
    }

    if (parsed is Map && parsed['sintagma'] is List) {
      parsed = parsed['sintagma'];
    }

    if (parsed is List) {
      final out = <Map<String, String>>[];
      for (final item in parsed) {
        if (item is Map) {
          final term = (item['sintagma'] ?? '').toString().trim();
          final zn = (item['znacenje'] ?? '').toString().trim();
          if (term.isEmpty && zn.isEmpty) continue;
          out.add({'sintagma': term, 'znacenje': zn});
        } else if (item is String) {
          final v = item.trim();
          if (v.isNotEmpty) out.add({'sintagma': v, 'znacenje': ''});
        }
      }
      return out.isEmpty ? null : out;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = _tryParseSintagmaList(raw);

    if (items == null) {
      final t = raw.trim();
      final looksJson = t.startsWith('{') || t.startsWith('[') || t.startsWith('"sintagma"');
      final html = looksJson ? '<pre>$t</pre>' : t.replaceAll('\n', '<br>');

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Html(
            data: html,
            style: {
              "body": Style(margin: Margins.zero, padding: HtmlPaddings.zero),
              "pre": Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            },
            onLinkTap: (url, _, __) => onLinkTap(url),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            ListTile(
              title: Text(
                items[i]['sintagma'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: (items[i]['znacenje'] ?? '').trim().isEmpty
                  ? null
                  : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Html(
                  data: items[i]['znacenje']!.replaceAll('\n', '<br>'),
                  style: {
                    "body": Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      lineHeight: const LineHeight(1.35),
                    ),
                  },
                  onLinkTap: (url, _, __) => onLinkTap(url),
                ),
              ),
            ),
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _AnimatedIn extends StatelessWidget {
  final Widget child;
  const _AnimatedIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

class _AnimatedBlock extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedBlock({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_AnimatedBlock> createState() => _AnimatedBlockState();
}

class _AnimatedBlockState extends State<_AnimatedBlock> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _show = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _show = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.02),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
