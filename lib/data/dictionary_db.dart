import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../features/related/reverse_classify_worker.dart';

import '../features/related/related_words_parser.dart';
import 'abbr/abbr_loader.dart';
import 'models/related_word.dart';
import 'models/related_word_page.dart';
import 'models/search_result.dart';
import 'models/entry_detail.dart';
import 'normalize.dart';

class DictionaryDb {
  static const String assetPath = 'assets/dictionary.sqlite';
  static const String dbFileName = 'dictionary.sqlite';

  Database? _db;
  AbbrRegistry? _abbr;
  RelatedWordsParser? _parser;

  RelatedWordsParser get parser => _parser!;

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

    final lower = s.toLowerCase();
    if (lower.startsWith('select') || lower.startsWith('with')) {
      final rows = await db.rawQuery(s);
      return rows;
    }

    await db.execute(s);
    return const [];
  }

  /// Convenience: If user query returns id/rijec/vrsta, map to SearchResultRow.
  /// Works in both safe and danger mode.
  Future<List<SearchResultRow>> runQueryAsResults(String sql, {int limit = 200}) async {
    final s = sql.trim();
    if (s.isEmpty) return [];

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

    final withLimit = lower.contains(' limit ')
        ? s
        : '$s LIMIT $limit';

    final rows = await db.rawQuery(withLimit);

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

  Future<void> openReadWrite() async {
    if (_db != null) return;

    final dbPath = await _ensureDbCopied();
    _db = await openDatabase(dbPath, readOnly: false);

    _abbr ??= await AbbrRegistry.load();
    _parser ??= RelatedWordsParser(
      abbr: _abbr!,
      normalizeFn: normalize,
    );
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

  Future<List<RelatedWord>> relatedWords(String entryId, {int limit = 25}) async {
    final db = _requireDb;

    final curRows = await db.rawQuery('''
    SELECT id, rijec_norm, definicija_text, etimologija_html
    FROM entries
    WHERE id = ?
    LIMIT 1
  ''', [entryId]);

    if (curRows.isEmpty) return const [];

    final cur = curRows.first;
    final selfNorm = (cur['rijec_norm'] as String?)?.trim() ?? '';
    final definicijaText = (cur['definicija_text'] as String?) ?? '';
    final etimHtml = (cur['etimologija_html'] as String?) ?? '';

    if (selfNorm.isEmpty) return const [];

    String n(String s) => normalize(s);

    // 2) Extract candidate norms
    final candidates = <String>{};

    candidates.addAll(_extractNormTermsFromLinks(definicijaText, n));
    candidates.addAll(_extractNormTermsFromLinks(etimHtml, n));
    candidates.addAll(_extractNormTermsFromSemicolonTail(definicijaText, n));

    candidates.remove(selfNorm);

    // 3) Resolve extracted candidates via IN query
    final resultsById = <String, RelatedWord>{};

    if (candidates.isNotEmpty) {
      final args = candidates.toList();
      final placeholders = List.filled(args.length, '?').join(',');

      final rows = await db.rawQuery('''
      SELECT id, rijec, vrsta, rijec_norm
      FROM entries
      WHERE rijec_norm IN ($placeholders)
      LIMIT ?
    ''', [...args, limit]);

      for (final r in rows) {
        final id = (r['id'] ?? '').toString();
        if (id.isEmpty || id == entryId) continue;

        resultsById[id] = RelatedWord(
          id: id,
          rijec: (r['rijec'] ?? '').toString(),
          vrsta: (r['vrsta'] ?? '').toString(),
          score: 0.95,
        );
      }
    }

    // 4) Reverse-link candidates: who links to me?
    // NOTE: LIKE '%...%' is slower but OK for MVP with LIMIT
    final p1 = '%/r/$selfNorm%';
    final p2 = '%keyword=$selfNorm%';

    final backRows = await db.rawQuery('''
    SELECT id, rijec, vrsta
    FROM entries
    WHERE id != ?
      AND (
        definicija_text LIKE ? OR etimologija_html LIKE ?
        OR definicija_text LIKE ? OR etimologija_html LIKE ?
      )
    LIMIT ?
  ''', [entryId, p1, p1, p2, p2, limit]);

    for (final r in backRows) {
      final id = (r['id'] ?? '').toString();
      if (id.isEmpty || id == entryId) continue;

      resultsById.putIfAbsent(
        id,
            () => RelatedWord(
          id: id,
          rijec: (r['rijec'] ?? '').toString(),
          vrsta: (r['vrsta'] ?? '').toString(),
          score: 0.65, // reverse link = medium confidence
        ),
      );
    }

    // 5) Return sorted by score, then alphabetically
    final out = resultsById.values.toList()
      ..sort((a, b) {
        final s = b.score.compareTo(a.score);
        if (s != 0) return s;
        return a.rijec.compareTo(b.rijec);
      });

    if (out.length > limit) return out.take(limit).toList();
    return out;
  }

  Future<void> _ensureParserLoaded() async {
    _abbr ??= await AbbrRegistry.load();
    _parser ??= RelatedWordsParser(
      abbr: _abbr!,
      normalizeFn: normalize,
    );
  }

  Future<RelatedWordsPage> relatedWordsPage(
      String entryId, {
        required int reverseOffset,
        int pageSize = 20,
        bool includeStrong = false,
      }) async {
    final db = _requireDb;

    // Strong parsing needs parser + abbr registry
    if (includeStrong) {
      await _ensureParserLoaded();
    }

    final curRows = await db.rawQuery('''
    SELECT rijec_norm, definicija_text, etimologija_html,
           frazeologija_text, sintagma_html, onomastika_html
    FROM entries
    WHERE id = ?
    LIMIT 1
  ''', [entryId]);

    if (curRows.isEmpty) {
      return const RelatedWordsPage(items: [], nextReverseOffset: 0, hasMore: false);
    }

    final cur = curRows.first;
    final selfNorm = (cur['rijec_norm'] as String?)?.trim() ?? '';
    final definicijaText = (cur['definicija_text'] as String?) ?? '';
    final etimHtml = (cur['etimologija_html'] as String?) ?? '';
    final frazeText = (cur['frazeologija_text'] as String?) ?? '';
    final sintagmaHtml = (cur['sintagma_html'] as String?) ?? '';
    final onomastikaHtml = (cur['onomastika_html'] as String?) ?? '';

    if (selfNorm.isEmpty) {
      return const RelatedWordsPage(items: [], nextReverseOffset: 0, hasMore: false);
    }

    final out = <RelatedWord>[];
    final seenIds = <String>{};

    // Helper: turn parser reason into a short UI label
    String reasonLabel(RelatedReason r) {
      switch (r) {
        case RelatedReason.seeAlso:
          return 'v.';
        case RelatedReason.compare:
          return 'usp.';
        case RelatedReason.opposite:
          return 'opr.';
        case RelatedReason.derivedFrom:
          return 'izv.';
        case RelatedReason.likelySynonym:
          return 'syn?';
        case RelatedReason.link:
          return 'link';
        case RelatedReason.markerText:
          return 'marker';
      }
    }

    // 1) Strong candidates only on first page
    if (includeStrong) {
      final mentions = _parser!.parseAll(
        definicija: definicijaText,
        etimologija: etimHtml,
        frazeologija: frazeText,
        sintagma: sintagmaHtml,
        onomastika: onomastikaHtml,
      );

      // Group mentions by termNorm -> (max confidence, set of reasons)
      final byNorm = <String, _Agg>{};
      for (final m in mentions) {
        if (m.termNorm == selfNorm) continue;
        final a = byNorm.putIfAbsent(m.termNorm, () => _Agg());
        a.maxScore = (m.confidence > a.maxScore) ? m.confidence : a.maxScore;
        a.reasons.add(reasonLabel(m.reason));
      }

      final candidates = byNorm.keys.toList();
      if (candidates.isNotEmpty) {
        final placeholders = List.filled(candidates.length, '?').join(',');
        final rows = await db.rawQuery('''
        SELECT id, rijec, vrsta, rijec_norm
        FROM entries
        WHERE rijec_norm IN ($placeholders)
        LIMIT 500
      ''', candidates);

        for (final r in rows) {
          final id = (r['id'] ?? '').toString();
          if (id.isEmpty || id == entryId) continue;
          if (!seenIds.add(id)) continue;

          final norm = (r['rijec_norm'] ?? '').toString();
          final agg = byNorm[norm];

          final reasons = (agg == null || agg.reasons.isEmpty)
              ? ''
              : '(${agg.reasons.join('; ')})';

          out.add(RelatedWord(
            id: id,
            rijec: (r['rijec'] ?? '').toString(),
            vrsta: (r['vrsta'] ?? '').toString(),
            score: agg?.maxScore ?? 0.90,
            reason: reasons,
          ));
        }

        // Strong: score desc, then alphabetically
        out.sort((a, b) {
          final s = b.score.compareTo(a.score);
          if (s != 0) return s;
          return a.rijec.compareTo(b.rijec);
        });
      }
    }

    // 2) Reverse-mention page (robust + paged) — background classify
    final prefilterLike = '%$selfNorm%';
    const fetchFactor = 4;
    final fetchN = (pageSize * fetchFactor) + 1;

    final rawRows = await db.rawQuery('''
    SELECT id, rijec, vrsta,
           definicija_text, etimologija_html, frazeologija_text, sintagma_html, onomastika_html
    FROM entries
    WHERE id != ?
      AND (
        definicija_text LIKE ? OR etimologija_html LIKE ?
        OR frazeologija_text LIKE ? OR sintagma_html LIKE ? OR onomastika_html LIKE ?
      )
    LIMIT ? OFFSET ?
  ''', [
      entryId,
      prefilterLike, prefilterLike,
      prefilterLike, prefilterLike, prefilterLike,
      fetchN, reverseOffset,
    ]);

    final hasMore = rawRows.length >= fetchN;
    final pageRows = hasMore ? rawRows.take(fetchN - 1).toList() : rawRows;

    // Prepare rows for worker (text only + id + header fields)
    final rowsForWorker = <Map<String, String>>[];
    for (final r in pageRows) {
      final id = (r['id'] ?? '').toString();
      if (id.isEmpty || id == entryId) continue;

      final combined = [
        (r['definicija_text'] as String?) ?? '',
        (r['etimologija_html'] as String?) ?? '',
        (r['frazeologija_text'] as String?) ?? '',
        (r['sintagma_html'] as String?) ?? '',
        (r['onomastika_html'] as String?) ?? '',
      ].join(' ');

      rowsForWorker.add({
        'id': id,
        'rijec': (r['rijec'] ?? '').toString(),
        'vrsta': (r['vrsta'] ?? '').toString(),
        'text': combined,
      });
    }

    // Provide abbr keys (normalized-ish) to worker
    final abbrKeysNorm = _abbr!.map.keys.map((k) => normalize(k)).toList();


    final hitsJson = await compute(
      reverseClassifyWorker,
      ReverseClassifyInput(
        selfNorm: selfNorm,
        abbrKeysNorm: abbrKeysNorm,
        rows: rowsForWorker,
      ).toJson(),
    );

    final hitsById = <String, Map<String, dynamic>>{
      for (final h in hitsJson) (h['id'] as String): h,
    };

    int addedReverse = 0;
    for (final r in pageRows) {
      if (addedReverse >= pageSize) break;

      final id = (r['id'] ?? '').toString();
      if (id.isEmpty || id == entryId) continue;

      final hit = hitsById[id];
      if (hit == null) continue;

      if (!seenIds.add(id)) continue;

      out.add(RelatedWord(
        id: id,
        rijec: (r['rijec'] ?? '').toString(),
        vrsta: (r['vrsta'] ?? '').toString(),
        score: (hit['score'] as num).toDouble(),
        reason: (hit['reason'] as String),
      ));

      addedReverse++;
    }

    final nextOffset = reverseOffset + pageRows.length;

    out.sort((a, b) {
      // 1) score desc
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;

      // 2) reason priority desc
      final rp = _reasonPriority(b.reason).compareTo(_reasonPriority(a.reason));
      if (rp != 0) return rp;

      // 3) word asc
      return a.rijec.compareTo(b.rijec);
    });

    return RelatedWordsPage(
      items: out,
      nextReverseOffset: nextOffset,
      hasMore: hasMore,
    );
  }

  int _reasonPriority(String reason) {
    final r = reason.toLowerCase();

    // strongest
    if (r.contains('link')) return 100;

    // strong relation markers
    if (r.contains('usp.')) return 90;
    if (r.contains('v.')) return 85;
    if (r.contains('opr.')) return 80;
    if (r.contains('izv.')) return 75;

    // weaker / noisier
    if (r.contains('syn?')) return 60;
    if (r.contains('marker')) return 40;

    return 10;
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

  Set<String> _extractNormTermsFromLinks(String htmlOrText, String Function(String) normalize) {
    final out = <String>{};

    // /r/<term>  (term can be letters, numbers, dash, underscore)
    final reR = RegExp(r'href\s*=\s*"\/r\/([^"#?]+)"', caseSensitive: false);
    for (final m in reR.allMatches(htmlOrText)) {
      final term = m.group(1);
      if (term != null && term.isNotEmpty) out.add(normalize(term));
    }

    // keyword=<term> (inside url query)
    final reKw = RegExp(r'keyword=([^&#"]+)', caseSensitive: false);
    for (final m in reKw.allMatches(htmlOrText)) {
      final term = m.group(1);
      if (term != null && term.isNotEmpty) {
        out.add(normalize(Uri.decodeComponent(term)));
      }
    }

    return out..removeWhere((e) => e.isEmpty);
  }

  Set<String> _extractNormTermsFromSemicolonTail(String definicijaText, String Function(String) normalize) {
    final out = <String>{};

    final plain = _stripHtml(definicijaText);
    // Split into rough “sentences/lines”
    final parts = plain.split(RegExp(r'[\n\r]+'));

    for (final p in parts) {
      final semiParts = p.split(';');
      if (semiParts.length <= 1) continue;

      // Everything after the first semicolon can contain synonym-like tokens
      for (var i = 1; i < semiParts.length; i++) {
        final tail = semiParts[i];

        for (final raw in tail.split(',')) {
          var t = raw.trim();

          // Remove bracketed notes and common punctuation
          t = t.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
          t = t.replaceAll(RegExp(r'[(){}"“”„”]'), ' ');
          t = t.replaceAll(RegExp(r'[:.!?]'), ' ');
          t = t.trim();

          // Heuristic: keep short-ish tokens (avoid long phrases)
          if (t.isEmpty) continue;
          if (t.length > 40) continue;

          // Often tokens include extra words; keep first “word” if you want stricter behavior
          // final firstWord = t.split(RegExp(r'\s+')).first;
          // out.add(normalize(firstWord));

          out.add(normalize(t));
        }
      }
    }

    return out..removeWhere((e) => e.isEmpty);
  }

  String _stripHtml(String input) => input.replaceAll(RegExp(r'<[^>]+>'), ' ');
}

// small internal helper class
class _Agg {
  double maxScore = 0.0;
  final Set<String> reasons = {};
}

