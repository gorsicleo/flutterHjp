import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/dictionary_db.dart';
import '../../data/models/entry_detail.dart';
import '../../common/widgets/error_view.dart';
import '../../common/widgets/loading_view.dart';
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

  // AppBar animation state
  bool _barVisible = true;
  double _lastPixels = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await widget.db.getEntryById(widget.entryId);
      setState(() {
        _entry = e;
        _loading = false;
      });
      await widget.onAddToHistory(widget.entryId);
    } catch (ex) {
      setState(() {
        _error = ex.toString();
        _loading = false;
      });
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
      extendBodyBehindAppBar: true, // ✅ lets blur overlay the content behind
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
        // ✅ keep top padding so content doesn't go under the frosted appbar too much
        top: true,
        child: EntryView(
          entry: _entry,
          onOpenWord: widget.onOpenWord,
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
      // ✅ frosted blur background
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
