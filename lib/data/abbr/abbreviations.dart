enum AbbrKind { relation, label }

class AbbrInfo {
  final AbbrKind kind;
  final String meaning;
  const AbbrInfo(this.kind, this.meaning);
}
