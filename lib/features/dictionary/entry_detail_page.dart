import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/dictionary_db.dart';
import '../../data/models/entry_detail.dart';
import '../../common/widgets/error_view.dart';
import '../../common/widgets/loading_view.dart';
import '../../data/models/related_word.dart';
import 'widgets/entry_view.dart';

class EntryDetailPage extends StatefulWidget {
  final DictionaryDb db;
  final String entryId;

  final bool Function(String entryId) isFavorite;
  final Future<void> Function(String entryId) onToggleFavorite;

  final Future<void> Function(String word) onOpenWord;
  final Future<void> Function(String entryId) onAddToHistory;

  const EntryDetailPage({
    super.key,
    required this.db,
    required this.entryId,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenWord,
    required this.onAddToHistory,
  });

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  EntryDetail? _entry;
  String? _error;
  bool _loading = true;

  List<RelatedWord> _relatedWords = const [];
  int _relatedReverseOffset = 0;
  bool _relatedHasMore = false;
  bool _relatedLoadingMore = false;

  static const int _relatedPageSize = 50;

  // AppBar animation state
  bool _barVisible = true;
  double _lastPixels = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadRelatedOnDemand() async {
    if (_relatedLoadingMore) return;

    // If we have nothing yet, this is the first expand → load first page with strong signals.
    if (_relatedWords.isEmpty && _relatedReverseOffset == 0) {
      setState(() => _relatedLoadingMore = true);

      try {
        final page = await widget.db.relatedWordsPage(
          widget.entryId,
          reverseOffset: 0,
          pageSize: _relatedPageSize,
          includeStrong: true,
        );

        if (!mounted) return;
        setState(() {
          _relatedWords = page.items;
          _relatedReverseOffset = page.nextReverseOffset;
          _relatedHasMore = page.hasMore;
          _relatedLoadingMore = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _relatedLoadingMore = false;
          _relatedHasMore = false;
        });
      }
      return;
    }

    // Otherwise normal pagination
    await _loadMoreRelated();
  }

  Future<void> _load() async {
    try {
      final e = await widget.db.getEntryById(widget.entryId);

      if (!mounted) return;
      setState(() {
        _entry = e;
        _loading = false;
        _error = null;
        _relatedWords = const [];
        _relatedLoadingMore = false;
        _relatedHasMore = false;
        _relatedReverseOffset = 0;
      });

      await widget.onAddToHistory(widget.entryId);

    } catch (ex) {
      if (!mounted) return;
      setState(() {
        _error = ex.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadRelatedInitial() async {
    _relatedReverseOffset = 0;
    _relatedHasMore = false;

    try {
      final page = await widget.db.relatedWordsPage(
        widget.entryId,
        reverseOffset: 0,
        pageSize: _relatedPageSize,
        includeStrong: true,
      );

      if (!mounted) return;
      setState(() {
        _relatedWords = page.items;
        _relatedReverseOffset = page.nextReverseOffset;
        _relatedHasMore = page.hasMore;
        _relatedLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _relatedWords = const [];
        _relatedHasMore = false;
        _relatedLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreRelated() async {
    if (_relatedLoadingMore || !_relatedHasMore) return;

    setState(() => _relatedLoadingMore = true);

    try {
      final page = await widget.db.relatedWordsPage(
        widget.entryId,
        reverseOffset: _relatedReverseOffset,
        pageSize: _relatedPageSize,
        includeStrong: false,
      );

      if (!mounted) return;

      // Deduplicate by id while appending
      final existingIds = _relatedWords.map((e) => e.id).toSet();
      final appended = <RelatedWord>[
        ..._relatedWords,
        ...page.items.where((w) => existingIds.add(w.id)),
      ];

      setState(() {
        _relatedWords = appended;
        _relatedReverseOffset = page.nextReverseOffset;
        _relatedHasMore = page.hasMore;
        _relatedLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _relatedLoadingMore = false);
    }
  }

  Future<void> _toggleFavorite() async {
    await widget.onToggleFavorite(widget.entryId);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _copy(String text, {String msg = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView(message: 'Loading…'));
    if (_error != null) return Scaffold(body: ErrorView(message: '$_error'));
    if (_entry == null) return const Scaffold(body: ErrorView(message: 'Entry not found.'));

    final fav = widget.isFavorite(widget.entryId);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FrostedAnimatedAppBar(
        visible: _barVisible,
        title: Text(_entry!.rijec),
        actions: [
          IconButton(
            tooltip: fav ? 'Remove from saved' : 'Save word',
            icon: Icon(fav ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'copy_word') _copy(_entry!.rijec, msg: 'Word copied');
              if (v == 'copy_def') _copy(_entry!.definicijaHtml, msg: 'Definition copied');
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'copy_word', child: Text('Copy word')),
              PopupMenuItem(value: 'copy_def', child: Text('Copy definition')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: EntryView(
          entry: _entry,
          onOpenWord: widget.onOpenWord,
          relatedWords: _relatedWords,
          relatedHasMore: _relatedHasMore,
          relatedLoadingMore: _relatedLoadingMore,
          onLoadMoreRelated: _loadRelatedOnDemand,
        ),
      ),
    );
  }
}

class FrostedAnimatedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool visible;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;

  const FrostedAnimatedAppBar({
    super.key,
    required this.visible,
    this.title,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      leading: leading,
      title: title,
      actions: actions,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,

      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: theme.colorScheme.surface.withOpacity(0.72),
          ),
        ),
      ),
    );
  }
}
