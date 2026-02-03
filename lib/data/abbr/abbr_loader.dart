import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

enum AbbrKind { relation, label, language }

class AbbrInfo {
  final AbbrKind kind;
  final Object meaning;
  const AbbrInfo(this.kind, this.meaning);
}

class AbbrRegistry {
  final Map<String, AbbrInfo> map;
  const AbbrRegistry(this.map);

  static AbbrKind _kindFromString(String s) {
    switch (s) {
      case 'relation':
        return AbbrKind.relation;
      case 'language':
        return AbbrKind.language;
      default:
        return AbbrKind.label;
    }
  }

  static Future<AbbrRegistry> load() async {
    final raw = await rootBundle.loadString('assets/abbr/abbr.json');
    final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    final abbr = (jsonMap['abbr'] as Map).cast<String, dynamic>();

    final out = <String, AbbrInfo>{};
    for (final e in abbr.entries) {
      final v = (e.value as Map).cast<String, dynamic>();
      final kind = _kindFromString((v['kind'] ?? 'label').toString());
      final meaning = v['meaning'];
      out[e.key] = AbbrInfo(kind, meaning);
    }
    return AbbrRegistry(out);
  }
}
