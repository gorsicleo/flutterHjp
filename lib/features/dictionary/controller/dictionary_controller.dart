import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/dictionary_db.dart';
import '../../../data/models/search_result.dart';

class DictionaryController extends ChangeNotifier {
  final DictionaryDb _db;
  DictionaryController(this._db);

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String _query = '';
  String get query => _query;

  List<SearchResultRow> _results = [];
  List<SearchResultRow> get results => _results;

  List<SearchResultRow> _suggestions = [];
  List<SearchResultRow> get suggestions => _suggestions;

  Timer? _debounce;

  // Favorites
  final Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  List<Map<String, String>> _favoriteHeaders = [];
  List<Map<String, String>> get favoriteHeaders => _favoriteHeaders;

  // History (most recent first)
  final List<String> _historyIds = [];
  List<String> get historyIds => List.unmodifiable(_historyIds);

  List<Map<String, String>> _historyHeaders = [];
  List<Map<String, String>> get historyHeaders => _historyHeaders;

  static const _prefsFavKey = 'favorites_entry_ids_v1';
  static const _prefsHistoryKey = 'history_entry_ids_v1';
  static const _historyMax = 60;

  DictionaryDb get db => _db;

  Future<void> init() async {
    try {
      _loading = true;
      notifyListeners();

      await _db.openReadOnly();
      await _loadFavorites();
      await _loadHistory();

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  void disposeController() {
    _debounce?.cancel();
    _db.close();
  }

  void clearSearch() {
    _query = '';
    _results = [];
    _suggestions = [];
    notifyListeners();
  }

  void onQueryChanged(String query) {
    _query = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _results = [];
      _suggestions = [];
      notifyListeners();
      return;
    }

    // 1) Prefix
    final prefix = await _db.searchPrefix(q, limit: 60);
    if (prefix.isNotEmpty) {
      _results = prefix;
      _suggestions = [];
      notifyListeners();
      return;
    }

    // 2) Contains fallback
    final contains = await _db.searchContains(q, limit: 60);
    if (contains.isNotEmpty) {
      _results = contains;
      _suggestions = [];
      notifyListeners();
      return;
    }

    // 3) Suggestions
    _results = [];
    _suggestions = await _db.suggest(q, limit: 8);
    notifyListeners();
  }

  // Favorites
  bool isFavorite(String entryId) => _favorites.contains(entryId);

  Future<void> toggleFavorite(String entryId) async {
    if (_favorites.contains(entryId)) {
      _favorites.remove(entryId);
    } else {
      _favorites.add(entryId);
    }
    await _saveFavorites();
    await _refreshFavoriteHeaders();
    notifyListeners();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsFavKey) ?? const <String>[];
    _favorites
      ..clear()
      ..addAll(ids.where((e) => e.trim().isNotEmpty));
    await _refreshFavoriteHeaders();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsFavKey, _favorites.toList());
  }

  Future<void> _refreshFavoriteHeaders() async {
    final items = <Map<String, String>>[];
    for (final id in _favorites) {
      final h = await _db.entryHeaderById(id);
      if (h != null) items.add(h);
    }
    items.sort((a, b) => (a['rijec'] ?? '').compareTo(b['rijec'] ?? ''));
    _favoriteHeaders = items;
  }

  // History
  Future<void> addToHistory(String entryId) async {
    _historyIds.remove(entryId);
    _historyIds.insert(0, entryId);
    if (_historyIds.length > _historyMax) {
      _historyIds.removeRange(_historyMax, _historyIds.length);
    }
    await _saveHistory();
    await _refreshHistoryHeaders();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _historyIds.clear();
    await _saveHistory();
    await _refreshHistoryHeaders();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsHistoryKey) ?? const <String>[];
    _historyIds
      ..clear()
      ..addAll(ids.where((e) => e.trim().isNotEmpty));
    await _refreshHistoryHeaders();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsHistoryKey, List<String>.from(_historyIds));
  }

  Future<void> _refreshHistoryHeaders() async {
    final items = <Map<String, String>>[];
    for (final id in _historyIds.take(20)) {
      final h = await _db.entryHeaderById(id);
      if (h != null) items.add(h);
    }
    _historyHeaders = items; // keep history order (most recent first)
  }

  /// Called from Android "Process text" intent.
  /// Sets the query immediately and performs the search right away (no debounce).
  Future<void> setQueryFromExternal(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;

    // Stop pending debounce search (if user was typing)
    _debounce?.cancel();

    // Update query so SearchBar gets prefilled
    _query = q;

    // Optionally clear old results first so UI feels responsive
    _results = [];
    _suggestions = [];
    notifyListeners();

    // Run search immediately
    await _search(q);
  }



  // Word of the day
  Future<String?> wordOfTheDayId() async => _db.entryIdForDay(DateTime.now());

}
