import '../../features/related/related_words_parser.dart';

class RelatedItem {
  final String id;
  final String rijec;
  final String vrsta;
  final double score;
  final Set<RelatedReason> reasons;

  RelatedItem({required this.id, required this.rijec, required this.vrsta, required this.score, required this.reasons});
}
