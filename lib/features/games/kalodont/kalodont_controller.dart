import 'package:flutter/foundation.dart';
import '../../../../data/dictionary_db.dart';
import '../../../../data/normalize.dart';

enum KalodontStatus { loading, userTurn, botTurn, userWon, botWon }

class KalodontTurn {
  final bool bot;
  final String word;
  final String norm;
  const KalodontTurn({required this.bot, required this.word, required this.norm});
}

class KalodontController extends ChangeNotifier {
  KalodontController(this.db);

  final DictionaryDb db;

  KalodontStatus status = KalodontStatus.loading;

  final List<KalodontTurn> history = [];
  final Set<String> usedNorms = {};

  String requiredOriginal = '';
  String requiredNorm = '';
  String? message;

  String currentDefinition = '';
  bool definitionLoading = false;
  int _defReq = 0;

  bool _busy = false;

  Future<void> start() async {
    if (_busy) return;
    _busy = true;

    status = KalodontStatus.loading;
    history.clear();
    usedNorms.clear();
    requiredOriginal = '';
    requiredNorm = '';
    message = null;
    notifyListeners();

    final start = await db.kalodontRandomStartWord(avoidEndingKa: true);
    if (start == null) {
      status = KalodontStatus.botWon; // doesn't matter; show message
      message = 'No start word found in database.';
      _busy = false;
      notifyListeners();
      return;
    }

    _acceptTurn(bot: true, word: start.word, norm: start.norm);

    status = KalodontStatus.userTurn;
    message = 'Tvoj potez: riječ na "$requiredOriginal"';
    _busy = false;
    notifyListeners();
  }

  Future<void> _refreshDefinition() async {
    final req = ++_defReq;
    definitionLoading = true;
    currentDefinition = '';
    notifyListeners();

    if (history.isEmpty) {
      definitionLoading = false;
      notifyListeners();
      return;
    }

    final norm = history.last.norm;
    final def = await db.kalodontDefinitionTextByBaseNorm(norm);

    if (req != _defReq) return;
    currentDefinition = (def ?? '').trim();
    definitionLoading = false;
    notifyListeners();
  }


  Future<void> submitUser(String rawInput) async {
    if (_busy) return;
    if (status != KalodontStatus.userTurn) return;

    _busy = true;

    final norm = stripNumSuffix(normalize(rawInput.trim()));

    if (norm.length < 2) {
      message = 'Riječ mora imati barem 2 slova.';
      _busy = false;
      notifyListeners();
      return;
    }
    if (!RegExp(r'^[a-z]+$').hasMatch(norm)) {
      message = 'Koristi jednu riječ (samo slova).';
      _busy = false;
      notifyListeners();
      return;
    }
    if (!norm.startsWith(requiredNorm)) {
      message = 'Mora početi s "$requiredOriginal".';
      _busy = false;
      notifyListeners();
      return;
    }
    if (usedNorms.contains(norm)) {
      message = 'Ta riječ je već iskorištena.';
      _busy = false;
      notifyListeners();
      return;
    }

    if (requiredNorm == 'ka' && norm == 'kalodont') {
      _acceptTurn(bot: false, word: 'kalodont', norm: 'kalodont');
      status = KalodontStatus.userWon;
      message = 'Kalodont! Pobijedio si.';
      _busy = false;
      notifyListeners();
      return;
    }

    final display = await db.kalodontCanonicalWordForBaseNorm(norm);
    if (display == null) {
      message = 'Ne nalazim tu riječ u rječniku.';
      _busy = false;
      notifyListeners();
      return;
    }
    _acceptTurn(bot: false, word: display, norm: norm);

    status = KalodontStatus.botTurn;
    message = 'Moj potez…';
    notifyListeners();

    if (requiredNorm == 'ka' && !usedNorms.contains('kalodont')) {
      _acceptTurn(bot: true, word: 'kalodont', norm: 'kalodont');
      status = KalodontStatus.botWon;
      message = 'Kalodont! Pobijedio sam.';
      _busy = false;
      notifyListeners();
      return;
    }

    final botPick = await db.kalodontRandomWordByPrefix(requiredNorm, usedNorms);
    if (botPick == null) {
      status = KalodontStatus.userWon;
      message = 'Nemam riječ na "$requiredOriginal". Ti pobjeđuješ!';
      _busy = false;
      notifyListeners();
      return;
    }

    _acceptTurn(bot: true, word: botPick.word, norm: botPick.norm);
    status = KalodontStatus.userTurn;
    message = 'Tvoj potez: riječ na "$requiredOriginal"';
    _busy = false;
    notifyListeners();
  }

  void giveUp() {
    if (status == KalodontStatus.userTurn) {
      status = KalodontStatus.botWon;
      message = 'Predao si. Pobijedio sam.';
      notifyListeners();
    }
  }

  Future<String?> getHintWord() async {
    final pick = await db.kalodontRandomWordByPrefix(requiredNorm, usedNorms);
    return pick?.word;
  }

  void _acceptTurn({required bool bot, required String word, required String norm}) {
    final cleanWord = stripNumSuffix(word);
    final cleanNorm = stripNumSuffix(norm);

    history.add(KalodontTurn(bot: bot, word: cleanWord, norm: cleanNorm));
    usedNorms.add(cleanNorm);

    requiredNorm = cleanNorm.substring(cleanNorm.length - 2);
    requiredOriginal = cleanWord.substring(cleanWord.length - 2);

    _refreshDefinition();
  }

}
