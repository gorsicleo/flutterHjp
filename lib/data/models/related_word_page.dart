import 'package:hjp/data/models/related_word.dart';

class RelatedWordsPage {
  final List<RelatedWord> items;
  final int nextReverseOffset;
  final bool hasMore;

  const RelatedWordsPage({
    required this.items,
    required this.nextReverseOffset,
    required this.hasMore,
  });
}