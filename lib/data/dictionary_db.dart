import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';

import 'models/search_result.dart';
import 'models/entry_detail.dart';
import 'normalize.dart';

class DictionaryDb {
  static const String assetPath = 'assets/dictionary.sqlite';
  static const String dbFileName = 'dictionary.sqlite';

  Database? _db;

  Database get _requireDb {
    final db = _db;
    if (db == null) throw StateError('Database is not open');
    return db;
  }

  /// Runs ANY SQL (dangerous). Use only for local debugging.
  ///
  /// Returns:
  /// - for SELECT: rows (List<Map<String,Object?>>)
  /// - for non-SELECT: empty list, but executes the statement
  Future<List<Map<String, Object?>>> runAnySql(String sql) async {
    final db = _requireDb;
    final s = sql.trim();
    if (s.isEmpty) return [];

    // If it's a SELECT, return rows
    final lower = s.toLowerCase();
    if (lower.startsWith('select') || lower.startsWith('with')) {
      final rows = await db.rawQuery(s);
      return rows;
    }

    // Otherwise execute (CREATE/UPDATE/DELETE/etc.)
    // NOTE: sqflite execute() does not return affected rows.
    await db.execute(s);
    return const [];
  }

  /// Convenience: If user query returns id/rijec/vrsta, map to SearchResultRow.
  /// Works in both safe and danger mode.
  Future<List<SearchResultRow>> runQueryAsResults(String sql, {int limit = 200}) async {
    final s = sql.trim();
    if (s.isEmpty) return [];

    // Soft limit for SELECT if user didn't specify limit.
    final lower = s.toLowerCase();
    final withLimit =
    (lower.startsWith('select') || lower.startsWith('with')) && !lower.contains(' limit ')
        ? '$s LIMIT $limit'
        : s;

    final rows = await runAnySql(withLimit);

    return rows.map((r) {
      return SearchResultRow(
        id: (r['id'] ?? '').toString(),
        rijec: (r['rijec'] ?? '').toString(),
        vrsta: (r['vrsta'] ?? '').toString(),
      );
    }).where((e) => e.id.trim().isNotEmpty).toList();
  }


  Future<List<SearchResultRow>> runSelectQuery(String sql, {int limit = 200}) async {
    final db = _requireDb;
    final s = sql.trim();
    if (s.isEmpty) return [];

    // Safety: only allow SELECT queries (no inserts/updates/drops)
    final lower = s.toLowerCase();
    if (!lower.startsWith('select')) {
      throw ArgumentError('Only SELECT queries are allowed.');
    }
    if (lower.contains('insert') ||
        lower.contains('update') ||
        lower.contains('delete') ||
        lower.contains('drop') ||
        lower.contains('alter') ||
        lower.contains('create') ||
        lower.contains('pragma') ||
        lower.contains('attach') ||
        lower.contains('detach')) {
      throw ArgumentError('Only plain SELECT queries are allowed.');
    }

    // Make it convenient: if user didn’t limit results, apply a limit.
    final withLimit = lower.contains(' limit ')
        ? s
        : '$s LIMIT $limit';

    final rows = await db.rawQuery(withLimit);

    // Expect: id, rijec, vrsta (but be forgiving)
    return rows.map((r) {
      return SearchResultRow(
        id: (r['id'] ?? '').toString(),
        rijec: (r['rijec'] ?? '').toString(),
        vrsta: (r['vrsta'] ?? '').toString(),
      );
    }).where((e) => e.id.trim().isNotEmpty).toList();
  }

  Future<List<SearchResultRow>> searchPrefix(String query, {int limit = 50}) async {
    final db = _requireDb;
    final q = normalize(query);
    if (q.isEmpty) return [];

    final rows = await db.rawQuery('''
      SELECT id, rijec, vrsta
      FROM entries
      WHERE rijec_norm LIKE ?
      ORDER BY LENGTH(rijec_norm) ASC
      LIMIT ?
    ''', ['$q%', limit]);

    return rows
        .map((r) => SearchResultRow(
      id: r['id'] as String,
      rijec: r['rijec'] as String,
      vrsta: (r['vrsta'] as String?) ?? '',
    ))
        .toList();
  }

  Future<List<SearchResultRow>> searchContains(String query, {int limit = 50}) async {
    final db = _requireDb;
    final q = normalize(query);
    if (q.isEmpty) return [];

    final rows = await db.rawQuery('''
      SELECT id, rijec, vrsta
      FROM entries
      WHERE rijec_norm LIKE ?
      ORDER BY LENGTH(rijec_norm) ASC
      LIMIT ?
    ''', ['%$q%', limit]);

    return rows
        .map((r) => SearchResultRow(
      id: r['id'] as String,
      rijec: r['rijec'] as String,
      vrsta: (r['vrsta'] as String?) ?? '',
    ))
        .toList();
  }

  Future<List<SearchResultRow>> suggest(String query, {int limit = 6}) async {
    final db = _requireDb;
    final q = normalize(query);
    if (q.isEmpty) return [];

    final n = q.length;
    final prefixLen = n >= 4 ? 4 : (n >= 3 ? 3 : (n >= 2 ? 2 : 1));
    final pfx = q.substring(0, prefixLen);

    final rows = await db.rawQuery('''
      SELECT id, rijec, vrsta
      FROM entries
      WHERE rijec_norm LIKE ?
      ORDER BY LENGTH(rijec_norm) ASC
      LIMIT ?
    ''', ['$pfx%', limit]);

    return rows
        .map((r) => SearchResultRow(
      id: r['id'] as String,
      rijec: r['rijec'] as String,
      vrsta: (r['vrsta'] as String?) ?? '',
    ))
        .toList();
  }

  Future<String?> findEntryIdByWord(String rawWord) async {
    final db = _requireDb;

    final q = normalize(rawWord);
    if (q.isEmpty) return null;

    final rows = await db.rawQuery('''
      SELECT id
      FROM entries
      WHERE rijec_norm = ?
      LIMIT 1
    ''', [q]);

    if (rows.isNotEmpty) return (rows.first['id'] as String?)?.trim();

    final fallback = await searchPrefix(rawWord, limit: 1);
    if (fallback.isNotEmpty) return fallback.first.id;

    return null;
  }

  Future<int> countEntries() async {
    final db = _requireDb;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM entries');
    return (r.first['c'] as int?) ?? 0;
  }

  Future<String?> entryIdForDay(DateTime dayLocal) async {
    final db = _requireDb;

    final total = await countEntries();
    if (total <= 0) return null;

    final seed = dayLocal.year * 10000 + dayLocal.month * 100 + dayLocal.day;
    final rnd = Random(seed);
    final offset = rnd.nextInt(total);

    final rows = await db.rawQuery('''
      SELECT id
      FROM entries
      ORDER BY rowid
      LIMIT 1 OFFSET ?
    ''', [offset]);

    if (rows.isEmpty) return null;
    return (rows.first['id'] as String?)?.trim();
  }

  Future<Map<String, String>?> entryHeaderById(String id) async {
    final db = _requireDb;
    final rows = await db.rawQuery('''
      SELECT id, rijec, vrsta
      FROM entries
      WHERE id = ?
      LIMIT 1
    ''', [id]);

    if (rows.isEmpty) return null;
    return {
      'id': (rows.first['id'] ?? '') as String,
      'rijec': (rows.first['rijec'] ?? '') as String,
      'vrsta': ((rows.first['vrsta'] ?? '') as String),
    };
  }

  Future<void> openReadOnly() async {
    if (_db != null) return;

    final dbPath = await _ensureDbCopied();
    _db = await openDatabase(dbPath, readOnly: false);
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) {
      await db.close();
    }
  }

  Future<EntryDetail?> getEntryById(String id) async {
    final db = _requireDb;

    final rows = await db.rawQuery('''
      SELECT rijec, vrsta, detalji_html, definicija_text,
             frazeologija_text, izvedeni_json, etimologija_html,
             sintagma_html, onomastika_html
      FROM entries
      WHERE id = ?
      LIMIT 1
    ''', [id]);

    if (rows.isEmpty) return null;
    return EntryDetail.fromMap(rows.first);
  }

  // --- Internals ---

  static Future<String> _dbFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dbFileName);
  }

  static Future<String> _ensureDbCopied() async {
    final path = await _dbFilePath();

    final exists = await File(path).exists();
    if (!exists) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return path;
  }
}
