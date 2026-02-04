class EntryDetail {
  final String rijec;
  final String vrsta;
  final String detaljiHtml;
  final String definicijaHtml;
  final String onomastikaHtml;
  final String sintagmaHtml;
  final String etimologijaHtml;
  final String frazeText;
  final String izvedeniJson;

  const EntryDetail({
    required this.rijec,
    required this.vrsta,
    required this.detaljiHtml,
    required this.definicijaHtml,
    required this.onomastikaHtml,
    required this.sintagmaHtml,
    required this.etimologijaHtml,
    required this.frazeText,
    required this.izvedeniJson,
  });

  factory EntryDetail.fromMap(Map<String, Object?> m) {
    return EntryDetail(
      rijec: (m['rijec'] ?? '') as String,
      vrsta: (m['vrsta'] ?? '') as String,
      detaljiHtml: (m['detalji_html'] ?? '') as String,
      definicijaHtml: (m['definicija_text'] ?? '') as String,
      onomastikaHtml: (m['onomastika_html'] ?? '') as String,
      sintagmaHtml: (m['sintagma_html'] ?? '') as String,
      etimologijaHtml: (m['etimologija_html'] ?? '') as String,
      frazeText: (m['frazeologija_text'] ?? '') as String,
      izvedeniJson: (m['izvedeni_json'] ?? '') as String,
    );
  }
}
