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
