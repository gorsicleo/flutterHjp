import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'saved_sql.dart';

class SavedSqlStore {
  static const _prefsKey = 'saved_sql_queries_v1';

  Future<List<SavedSql>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => SavedSql.fromJson(m.cast<String, Object?>()))
          .where((s) => s.id.isNotEmpty && s.name.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<SavedSql> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = items.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  Future<void> upsert(SavedSql item) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      all[idx] = item;
    } else {
      all.add(item);
    }
    await saveAll(all);
  }

  Future<void> deleteById(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }
}
