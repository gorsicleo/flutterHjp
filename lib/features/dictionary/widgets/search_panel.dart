import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/search_result.dart';

class SearchPanel extends StatefulWidget {
  final List<SearchResultRow> results;
  final List<SearchResultRow> suggestions;
  final String query;

  final void Function(String) onQueryChanged;
  final VoidCallback onClear;

  final void Function(String entryId) onOpen;

  // Home options
  final bool showHomeOptions;
  final Future<void> Function() onOpenWordOfTheDay;

  // Saved + History
  final List<Map<String, String>> favoriteHeaders;
  final List<Map<String, String>> historyHeaders;
  final VoidCallback onClearHistory;

  // Favorites actions from list (long press)
  final bool Function(String entryId) isFavorite;
  final Future<void> Function(String entryId) onToggleFavorite;

  const SearchPanel({
    super.key,
    required this.results,
    required this.suggestions,
    required this.query,
    required this.onQueryChanged,
    required this.onClear,
    required this.onOpen,
    required this.showHomeOptions,
    required this.onOpenWordOfTheDay,

    required this.favoriteHeaders,
    required this.historyHeaders,
    required this.onClearHistory,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant SearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _controller.text != widget.query) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onClear();
    widget.onQueryChanged('');
    _focusNode.requestFocus();
  }

  Future<void> _showResultActions(SearchResultRow r) async {
    final fav = widget.isFavorite(r.id);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(r.rijec, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(r.vrsta),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpen(r.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy word'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: r.rijec));
                  if (mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(fav ? Icons.star : Icons.star_border),
                title: Text(fav ? 'Remove from saved' : 'Save word'),
                onTap: () async {
                  await widget.onToggleFavorite(r.id);
                  if (mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showClear = _controller.text.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SearchBar(
            controller: _controller,
            focusNode: _focusNode,
            hintText: 'Search any word',
            leading: const Icon(Icons.search),
            trailing: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: showClear
                    ? IconButton(
                  key: const ValueKey('clear'),
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: _clear,
                )
                    : const SizedBox.shrink(key: ValueKey('noclear')),
              ),
            ],
            onChanged: widget.onQueryChanged,
          ),
        ),

        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: widget.showHomeOptions
                ? _AnimatedIn(
              key: const ValueKey('home'),
              child: _HomeOptions(
                onWordOfTheDay: widget.onOpenWordOfTheDay,

                favorites: widget.favoriteHeaders,
                history: widget.historyHeaders,
                onOpen: widget.onOpen,
                onClearHistory: widget.onClearHistory,
              ),
            )
                : _AnimatedIn(
              key: const ValueKey('results'),
              child: _ResultsOrSuggestions(
                query: widget.query,
                results: widget.results,
                suggestions: widget.suggestions,
                onOpen: widget.onOpen,
                onLongPress: _showResultActions,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Subtle enter animation: fade + tiny slide.
class _AnimatedIn extends StatelessWidget {
  final Widget child;
  const _AnimatedIn({super.key, required this.child});

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
            offset: Offset(0, (1 - t) * 8),
            child: child,
          ),
        );
      },
    );
  }
}

class _ResultsOrSuggestions extends StatelessWidget {
  final String query;
  final List<SearchResultRow> results;
  final List<SearchResultRow> suggestions;
  final void Function(String entryId) onOpen;
  final Future<void> Function(SearchResultRow r) onLongPress;

  const _ResultsOrSuggestions({
    required this.query,
    required this.results,
    required this.suggestions,
    required this.onOpen,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isNotEmpty) {
      return ListView.separated(
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final r = results[index];

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 6),
                  child: child,
                ),
              );
            },
            child: ListTile(
              title: Text(r.rijec),
              subtitle: Text(r.vrsta),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(r.id),
              onLongPress: () => onLongPress(r),
            ),
          );
        },
      );
    }

    // No results => show "Did you mean" suggestions (if any)
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No results for “$query”.'),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Did you mean:', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final s in suggestions) ...[
                  ListTile(
                    title: Text(s.rijec),
                    subtitle: Text(s.vrsta),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpen(s.id),
                    onLongPress: () => onLongPress(s),
                  ),
                  if (s != suggestions.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeOptions extends StatelessWidget {
  final Future<void> Function() onWordOfTheDay;

  final List<Map<String, String>> favorites;
  final List<Map<String, String>> history;
  final void Function(String entryId) onOpen;
  final VoidCallback onClearHistory;

  const _HomeOptions({
    required this.onWordOfTheDay,

    required this.favorites,
    required this.history,
    required this.onOpen,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget headerRow(String title, {Widget? trailing}) {
      return Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          if (trailing != null) trailing,
        ],
      );
    }

    Widget cardList(List<Map<String, String>> items, {IconData leading = Icons.star}) {
      return Card(
        child: Column(
          children: [
            for (final f in items) ...[
              ListTile(
                leading: Icon(leading),
                title: Text(f['rijec'] ?? ''),
                subtitle: Text(f['vrsta'] ?? ''),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(f['id'] ?? ''),
              ),
              if (f != items.last) const Divider(height: 1),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        // Word of the day
        _AnimatedIn(
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Word of the day'),
              subtitle: const Text('Tap to discover something new'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onWordOfTheDay(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Saved
        headerRow('Saved words'),
        const SizedBox(height: 8),
        if (favorites.isEmpty)
          _AnimatedIn(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No saved words yet.\nOpen a word and tap the star.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          _AnimatedIn(child: cardList(favorites, leading: Icons.star)),

        const SizedBox(height: 14),

        // History
        headerRow(
          'History',
          trailing: TextButton(
            onPressed: history.isEmpty ? null : onClearHistory,
            child: const Text('Clear'),
          ),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          _AnimatedIn(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No history yet.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          _AnimatedIn(child: cardList(history, leading: Icons.history)),
      ],
    );
  }
}

class _RandomChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  const _RandomChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () async {
        await onTap();
      },
    );
  }
}
