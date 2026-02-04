import 'dart:collection';

import '../../data/abbr/abbr_loader.dart';

enum RelatedReason {
  seeAlso,        // v.
  compare,        // usp.
  opposite,       // opr.
  derivedFrom,    // izv.
  likelySynonym,  // after ';' tokens
  link,           // plain <a href="/r/..."> without marker
  markerText,     // marker found in plain text (no link)
}

class RelatedMention {
  final String termNorm;
  final RelatedReason reason;
  final double confidence;
  final String sourceField;

  const RelatedMention({
    required this.termNorm,
    required this.reason,
    required this.confidence,
    required this.sourceField,
  });
}

typedef NormalizeFn = String Function(String input);

class RelatedWordsParser {
  final AbbrRegistry abbr;
  final NormalizeFn normalizeFn;

  late final Set<String> _relationAbbrsLower;
  late final Set<String> _allAbbrLower;

  RelatedWordsParser({
    required this.abbr,
    required this.normalizeFn,
  }) {
    _relationAbbrsLower = abbr.map.entries
        .where((e) => e.value.kind == AbbrKind.relation)
        .map((e) => e.key.trim().toLowerCase())
        .toSet();

    _allAbbrLower = abbr.map.keys.map((k) => k.trim().toLowerCase()).toSet();
  }

  List<RelatedMention> parseAll({
    required String definicija,
    required String etimologija,
    required String frazeologija,
    required String sintagma,
    required String onomastika,
  }) {
    final out = <RelatedMention>[];
    out.addAll(parseField(definicija, sourceField: 'definicija'));
    out.addAll(parseField(etimologija, sourceField: 'etimologija'));
    out.addAll(parseField(frazeologija, sourceField: 'frazeologija'));
    out.addAll(parseField(sintagma, sourceField: 'sintagma'));
    out.addAll(parseField(onomastika, sourceField: 'onomastika'));
    return _dedupe(out);
  }

  List<RelatedMention> parseField(String raw, {required String sourceField}) {
    final s = raw.trim();
    if (s.isEmpty) return const [];

    final out = <RelatedMention>[];

    // A) Strong: HTML links (/r/... or keyword=...)
    out.addAll(_extractFromHtmlLinks(s, sourceField));

    final plain = _stripHtml(s);

    // B) Marker patterns in plain text: "usp. X", "v. X", "opr. X", "izv. X"
    out.addAll(_extractFromTextMarkers(plain, sourceField));

    // C) Semicolon tail: "...; a, b, c"
    out.addAll(_extractFromSemicolonTail(plain, sourceField));

    return _dedupe(out);
  }

  // ---------------- Extractors ----------------

  List<RelatedMention> _extractFromHtmlLinks(String raw, String sourceField) {
    final out = <RelatedMention>[];

    // href="..." or href='...'
    final hrefRe = RegExp(r'href\s*=\s*["' "'" r']([^"' "'" r']+)["' "'" r']', caseSensitive: false);

    for (final m in hrefRe.allMatches(raw)) {
      final url = m.group(1);
      final term = _extractDictionaryTerm(url);
      if (term == null || term.trim().isEmpty) continue;

      final norm = normalizeFn(term);
      if (!_isCandidate(norm)) continue;

      final start = m.start;
      final lookbackStart = (start - 90) < 0 ? 0 : (start - 90);
      final lookbackRaw = raw.substring(lookbackStart, start);
      final lookback = _stripHtml(lookbackRaw).toLowerCase();

      final lastMarker = _findLastRelationAbbr(lookback);

      final reason = _reasonFromMarker(lastMarker) ?? RelatedReason.link;
      final confidence = (reason == RelatedReason.link) ? 0.85 : 0.95;

      out.add(RelatedMention(
        termNorm: norm,
        reason: reason,
        confidence: confidence,
        sourceField: sourceField,
      ));
    }

    return out;
  }

  List<RelatedMention> _extractFromTextMarkers(String plain, String sourceField) {
    final out = <RelatedMention>[];
    final textLower = plain.toLowerCase();

    for (final abbrLower in _relationAbbrsLower) {
      final re = RegExp(
        r'(?<!\w)' + RegExp.escape(abbrLower) + r'\s+([^.;\n]+)',
        caseSensitive: false,
      );

      for (final m in re.allMatches(textLower)) {
        final chunk = (m.group(1) ?? '').trim();
        if (chunk.isEmpty) continue;

        for (final token in _splitTargets(chunk)) {
          final norm = normalizeFn(token);
          if (!_isCandidate(norm)) continue;

          out.add(RelatedMention(
            termNorm: norm,
            reason: _reasonFromMarker(abbrLower) ?? RelatedReason.markerText,
            confidence: 0.75,
            sourceField: sourceField,
          ));
        }
      }
    }

    return out;
  }

  List<RelatedMention> _extractFromSemicolonTail(String plain, String sourceField) {
    final out = <RelatedMention>[];
    final parts = plain.split(';');
    if (parts.length <= 1) return out;

    for (var i = 1; i < parts.length; i++) {
      final tail = parts[i];
      for (final token in _splitTargets(tail)) {
        final norm = normalizeFn(token);
        if (!_isCandidate(norm)) continue;

        out.add(RelatedMention(
          termNorm: norm,
          reason: RelatedReason.likelySynonym,
          confidence: 0.80,
          sourceField: sourceField,
        ));
      }
    }

    return out;
  }

  // ---------------- Helpers ----------------

  String _stripHtml(String input) => input.replaceAll(RegExp(r'<[^>]+>'), ' ');

  String? _extractDictionaryTerm(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;

    final idx = u.indexOf('/r/');
    if (idx != -1) {
      var part = u.substring(idx + 3);
      part = part.split('?').first.split('#').first;
      return Uri.decodeComponent(part).trim();
    }

    try {
      final uri = Uri.parse(u);
      final keyword = uri.queryParameters['keyword'];
      if (keyword != null && keyword.trim().isNotEmpty) {
        return Uri.decodeComponent(keyword).trim();
      }
    } catch (_) {}

    return null;
  }

  String? _findLastRelationAbbr(String textLower) {
    String? best;
    int bestPos = -1;
    for (final abbrLower in _relationAbbrsLower) {
      final pos = textLower.lastIndexOf(abbrLower);
      if (pos > bestPos) {
        bestPos = pos;
        best = abbrLower;
      }
    }
    return best;
  }

  RelatedReason? _reasonFromMarker(String? markerLower) {
    switch (markerLower) {
      case 'v.':
        return RelatedReason.seeAlso;
      case 'usp.':
        return RelatedReason.compare;
      case 'opr.':
        return RelatedReason.opposite;
      case 'izv.':
        return RelatedReason.derivedFrom;
      default:
        return null;
    }
  }

  bool _isCandidate(String norm) {
    final n = norm.trim().toLowerCase();
    if (n.isEmpty) return false;
    if (n.length < 2) return false;

    // filter abbreviations (mat., npr., lat., itd.)
    if (_allAbbrLower.contains(n)) return false;
    if (n.endsWith('.') && _allAbbrLower.contains(n)) return false;

    // obvious non-words
    if (RegExp(r'^\d+$').hasMatch(n)) return false;

    return true;
  }

  List<String> _splitTargets(String s) {
    var t = s.trim();
    if (t.isEmpty) return const [];

    t = t.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    t = t.replaceAll(RegExp(r'[(){}"“”„”]'), ' ');
    t = t.replaceAll(RegExp(r'[:.!?]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return const [];

    final pieces = t.split(RegExp(
      r'\s*(?:,|/|\bi\b|\bodnosno\b)\s*',
      caseSensitive: false,
    ));

    final out = <String>[];
    for (var x in pieces) {
      x = x.trim();
      if (x.isEmpty) continue;

      // skip “short abbreviation-looking” tokens
      if (x.endsWith('.') && x.length <= 6) continue;

      // cap length to avoid pulling full phrases
      if (x.length > 60) continue;

      out.add(x);
    }
    return out;
  }

  List<RelatedMention> _dedupe(List<RelatedMention> items) {
    final map = LinkedHashMap<String, RelatedMention>();
    for (final m in items) {
      final key = '${m.termNorm}|${m.reason}|${m.sourceField}';
      final prev = map[key];
      if (prev == null || m.confidence > prev.confidence) {
        map[key] = m;
      }
    }
    return map.values.toList();
  }
}
