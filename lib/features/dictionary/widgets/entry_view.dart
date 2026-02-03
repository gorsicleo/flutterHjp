import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../data/models/entry_detail.dart';
import '../../../data/models/related_word.dart';
import 'forms_table.dart';

class EntryView extends StatelessWidget {
  final EntryDetail? entry;
  final List<RelatedWord> relatedWords;
  final bool relatedHasMore;
  final bool relatedLoadingMore;
  final Future<void> Function()? onLoadMoreRelated;

  /// When user taps a dictionary link, we call this with the extracted word.
  final void Function(String word)? onOpenWord;

  const EntryView({
    super.key,
    required this.entry,
    this.onOpenWord,
    this.relatedWords = const [],
    this.relatedHasMore = false,
    this.relatedLoadingMore = false,
    this.onLoadMoreRelated,
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
              const SizedBox(height: 16),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 220),
                child: Text('Povezane riječi', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              _AnimatedBlock(
                delay: const Duration(milliseconds: 240),
                child: _RelatedWordsSection(
                  items: relatedWords,
                  hasMore: relatedHasMore,
                  isLoadingMore: relatedLoadingMore,
                  onLoadMore: onLoadMoreRelated,
                  onTap: (w) => onOpenWord?.call(w.rijec),
                ),
              ),
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
class _RelatedWordsSection extends StatefulWidget {
  final List<RelatedWord> items;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function()? onLoadMore;
  final void Function(RelatedWord w) onTap;

  const _RelatedWordsSection({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onTap,
    this.onLoadMore,
  });

  @override
  State<_RelatedWordsSection> createState() => _RelatedWordsSectionState();
}

class _RelatedWordsSectionState extends State<_RelatedWordsSection> {
  late final ScrollController _controller;

  bool _expanded = false;
  bool _autoFillScheduled = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_expanded) return;
    if (!widget.hasMore || widget.isLoadingMore) return;
    if (!_controller.hasClients) return;

    // Standard infinite-scroll trigger when user gets close to bottom.
    if (_controller.position.extentAfter < 200) {
      widget.onLoadMore?.call();
    }
  }

  void _maybeAutoFill() {
    if (!_expanded) return;
    if (!widget.hasMore || widget.isLoadingMore) return;
    if (widget.onLoadMore == null) return;

    // Schedule once per frame to avoid loops.
    if (_autoFillScheduled) return;
    _autoFillScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFillScheduled = false;
      if (!mounted) return;
      if (!_expanded) return;
      if (!widget.hasMore || widget.isLoadingMore) return;
      if (!_controller.hasClients) return;

      // If list is NOT scrollable yet, load more automatically.
      if (_controller.position.maxScrollExtent <= 0) {
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _RelatedWordsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When items change (new page appended), see if we still can't scroll and need more.
    if (_expanded &&
        (oldWidget.items.length != widget.items.length ||
            oldWidget.hasMore != widget.hasMore ||
            oldWidget.isLoadingMore != widget.isLoadingMore)) {
      _maybeAutoFill();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.45;

    final showFooter = widget.isLoadingMore || widget.hasMore || widget.items.isEmpty;
    final itemCount = widget.items.length + (showFooter ? 1 : 0);

    return Card(
      child: ExpansionTile(
        title: Text(
          widget.items.isNotEmpty
              ? 'Povezane riječi (${widget.items.length})'
              : 'Povezane riječi — započni pretragu',
        ),
        initiallyExpanded: false,
        onExpansionChanged: (v) {
          setState(() => _expanded = v);

          if (v) {
            if (!_started) {
              _started = true;
              widget.onLoadMore?.call();
            }
            _maybeAutoFill();
          }
        },
        children: [
          SizedBox(
            height: maxHeight.clamp(220, 420),
            child: ListView.separated(
              controller: _controller,
              itemCount: itemCount,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                // Footer row
                if (i >= widget.items.length) {
                  if (widget.isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (widget.items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('Expand to load related words…')),
                    );
                  }

                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text('Scroll to load more…')),
                  );
                }

                final w = widget.items[i];

                final pct = (w.score * 100).round();
                final rightLabel = [
                  if (w.reason.trim().isNotEmpty) w.reason.trim(),
                  '$pct%',
                ].join(' ');

                return ListTile(
                  dense: true,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          w.rijec,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (rightLabel.trim().isNotEmpty)
                        Text(
                          rightLabel,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                    ],
                  ),
                  subtitle: w.vrsta.trim().isEmpty
                      ? null
                      : Text(
                    w.vrsta,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onTap(w),
                );
              },
            ),
          ),
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
