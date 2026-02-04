import 'package:diacritic/diacritic.dart';

String normalize(String input) {
  var s = input.trim().toLowerCase();
  if (s.isEmpty) return s;

  // Remove all diacritics (á, è, ȁ, č, ć, đ, š, ž, etc.)
  s = removeDiacritics(s);

  // Croatian-specific mapping (removeDiacritics already covers most)
  s = s
      .replaceAll('đ', 'd')
      .replaceAll('Đ', 'd')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return s;
}

final _numSuffixRe = RegExp(r'[\d\u00B9\u00B2\u00B3\u2070-\u2079]+$');

String stripNumSuffix(String s) => s.trim().replaceAll(_numSuffixRe, '');

