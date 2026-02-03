class SavedSql {
  final String id;
  final String name;
  final String sql;
  final int updatedAtMs;

  const SavedSql({
    required this.id,
    required this.name,
    required this.sql,
    required this.updatedAtMs,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sql': sql,
    'updatedAtMs': updatedAtMs,
  };

  static SavedSql fromJson(Map<String, Object?> j) => SavedSql(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    sql: (j['sql'] ?? '').toString(),
    updatedAtMs: int.tryParse((j['updatedAtMs'] ?? '0').toString()) ?? 0,
  );
}
