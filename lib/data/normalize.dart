String normalize(String input) {
  var s = input.trim().toLowerCase();
  if (s.isEmpty) return s;

  const map = <String, String>{
    'č': 'c',
    'ć': 'c',
    'đ': 'd',
    'š': 's',
    'ž': 'z',
  };

  final sb = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(map[ch] ?? ch);
  }

  return sb.toString().replaceAll(RegExp(r'\s+'), ' ');
}
