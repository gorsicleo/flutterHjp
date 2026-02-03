class RelatedWord {
  final String id;
  final String rijec;
  final String vrsta;
  final double score;
  final String reason;

  const RelatedWord({
    required this.id,
    required this.rijec,
    required this.vrsta,
    required this.score,
    this.reason = '',
  });

}
