import 'package:flutter/material.dart';

import '../../common/widgets/error_view.dart';
import '../../common/widgets/loading_view.dart';
import '../../data/dictionary_db.dart';
import 'package:receive_intent/receive_intent.dart' as android_intent;
import '../games/games_page.dart';
import 'controller/dictionary_controller.dart';
import 'entry_detail_page.dart';
import '../sql_console/sql_console_page.dart';
import 'widgets/search_panel.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  late final DictionaryController controller;
  bool _searchEmpty = true;

  @override
  void initState() {
    super.initState();

    controller = DictionaryController(DictionaryDb());
    controller.init();

    _initProcessTextListener();
  }

  Future<void> _initProcessTextListener() async {
    final intent = await android_intent.ReceiveIntent.getInitialIntent();
    _handleProcessTextIntent(intent);

    android_intent.ReceiveIntent.receivedIntentStream.listen((intent) {
      _handleProcessTextIntent(intent);
    });
  }

  void _handleProcessTextIntent(android_intent.Intent? intent) {
    if (intent == null) return;

    final q = intent.extra?['process_text_query']?.toString();
    if (q == null || q.trim().isEmpty) return;

    final query = q.trim();
    controller.setQueryFromExternal(query);
  }


  @override
  void dispose() {
    controller.disposeController();
    super.dispose();
  }

  Future<void> _openEntry(String entryId) async {
    await controller.addToHistory(entryId);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryDetailPage(
          db: controller.db,
          entryId: entryId,
          isFavorite: controller.isFavorite,
          onToggleFavorite: controller.toggleFavorite,
          onOpenWord: _openWord,
          onAddToHistory: controller.addToHistory,
        ),
      ),
    );
  }

  Future<void> _openWord(String word) async {
    final id = await controller.db.findEntryIdByWord(word);
    if (!mounted) return;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not found: $word')),
      );
      return;
    }
    await _openEntry(id);
  }

  Future<void> _openWordOfTheDay() async {
    final id = await controller.wordOfTheDayId();
    if (!mounted) return;

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick a word today.')),
      );
      return;
    }
    await _openEntry(id);
  }

  Future<void> _openGames() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GamesPage(
        db: controller.db,
        onOpenWord: _openWord,
      ))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Croatian Dictionary'),
        actions: [
          IconButton(
            tooltip: 'SQL console',
            icon: const Icon(Icons.terminal),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SqlConsolePage(
                    db: controller.db,
                    onOpen: (id) => _openEntry(id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) return const LoadingView(message: 'Loading dictionary…');
          if (controller.error != null) return ErrorView(message: controller.error!);

          return SearchPanel(
            results: controller.results,
            suggestions: controller.suggestions,
            query: controller.query,
            onQueryChanged: (q) {
              setState(() => _searchEmpty = q.trim().isEmpty);
              controller.onQueryChanged(q);
            },
            onClear: () {
              setState(() => _searchEmpty = true);
              controller.clearSearch();
            },
            onOpen: (id) => _openEntry(id),

            showHomeOptions: _searchEmpty,
            onOpenWordOfTheDay: _openWordOfTheDay,

            favoriteHeaders: controller.favoriteHeaders,
            historyHeaders: controller.historyHeaders,
            onClearHistory: controller.clearHistory,

            isFavorite: controller.isFavorite,
            onToggleFavorite: controller.toggleFavorite,
            onOpenGames: _openGames,
          );
        },
      ),
    );
  }
}
