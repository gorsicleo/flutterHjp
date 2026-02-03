class SearchResultRow {
  final String id;
  final String rijec;
  final String vrsta;

  const SearchResultRow({
    required this.id,
    required this.rijec,
    required this.vrsta,
  });

  factory SearchResultRow.fromMap(Map<String, Object?> m) {
    return SearchResultRow(
      id: (m['id'] ?? '') as String,
      rijec: (m['rijec'] ?? '') as String,
      vrsta: (m['vrsta'] ?? '') as String,
    );
  }
}
