import 'package:flutter/foundation.dart';

class ReverseClassifyInput {
  final String selfNorm;
  final List<String> abbrKeysNorm;
  final List<Map<String, String>> rows;
  const ReverseClassifyInput({
    required this.selfNorm,
    required this.abbrKeysNorm,
    required this.rows,
  });

  Map<String, dynamic> toJson() => {
    'selfNorm': selfNorm,
    'abbrKeysNorm': abbrKeysNorm,
    'rows': rows,
  };

  static ReverseClassifyInput fromJson(Map<String, dynamic> j) {
    return ReverseClassifyInput(
      selfNorm: j['selfNorm'] as String,
      abbrKeysNorm: (j['abbrKeysNorm'] as List).cast<String>(),
      rows: (j['rows'] as List)
          .map((e) => (e as Map).cast<String, String>())
          .toList(),
    );
  }
}

class ReverseClassifyHit {
  final String id;
  final double score;
  final String reason;
  const ReverseClassifyHit({required this.id, required this.score, required this.reason});

  Map<String, dynamic> toJson() => {'id': id, 'score': score, 'reason': reason};

  static ReverseClassifyHit fromJson(Map<String, dynamic> j) => ReverseClassifyHit(
    id: j['id'] as String,
    score: (j['score'] as num).toDouble(),
    reason: j['reason'] as String,
  );
}

List<Map<String, dynamic>> reverseClassifyWorker(Map<String, dynamic> json) {
  final input = ReverseClassifyInput.fromJson(json);
  final selfNorm = input.selfNorm;

  String stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll('&nbsp;', ' ');
  String collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  String prep(String s) => collapse(stripHtml(s).toLowerCase());

  final selfWordRe = RegExp(
    r'(?<!\p{L})' + RegExp.escape(selfNorm) + r'(?!\p{L})',
    caseSensitive: false,
    unicode: true,
  );

  RegExp? abbrBeforeRe;
  final abbrKeys = input.abbrKeysNorm.toList()
    ..removeWhere((e) => e.trim().isEmpty)
    ..sort((a, b) => b.length.compareTo(a.length));
  if (abbrKeys.isNotEmpty) {
    final alt = abbrKeys.map(RegExp.escape).join('|');
    abbrBeforeRe = RegExp(
      r'(?<!\p{L})(' +
          alt +
          r')\s*[:.]?\s{0,3}.{0,20}?(?<!\p{L})' +
          RegExp.escape(selfNorm) +
          r'(?!\p{L})',
      caseSensitive: false,
      unicode: true,
      dotAll: true,
    );
  }

  const linkScore = 0.88;
  const abbrScore = 0.78;
  const mentionScore = 0.55;

  final out = <Map<String, dynamic>>[];

  for (final r in input.rows) {
    final id = r['id'] ?? '';
    if (id.isEmpty) continue;

    final text = prep(r['text'] ?? '');
    if (text.isEmpty) continue;

    final reasons = <String>[];
    double score = 0.0;

    final isLink = text.contains('/r/$selfNorm') || text.contains('keyword=$selfNorm');
    if (isLink) {
      reasons.add('(link → this)');
      score = score < linkScore ? linkScore : score;
    }

    if (abbrBeforeRe != null) {
      final m = abbrBeforeRe.firstMatch(text);
      if (m != null) {
        final abbr = (m.group(1) ?? '').trim();
        if (abbr.isNotEmpty) {
          reasons.add('($abbr → this)');
          score = score < abbrScore ? abbrScore : score;
        }
      }
    }

    if (selfWordRe.hasMatch(text)) {
      reasons.add('(mentions)');
      score = score < mentionScore ? mentionScore : score;
    }

    if (reasons.isEmpty) continue;

    out.add({
      'id': id,
      'score': score,
      'reason': reasons.join(' '),
    });
  }

  return out;
}
