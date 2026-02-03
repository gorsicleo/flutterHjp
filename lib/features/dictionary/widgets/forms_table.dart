import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormsTable extends StatelessWidget {
  final String izvedeniJson;
  const FormsTable({super.key, required this.izvedeniJson});

  @override
  Widget build(BuildContext context) {
    final parsed = _tryJsonDecode(izvedeniJson);

    // If not JSON (or null), still show something + allow copy
    if (parsed == null || parsed is String) {
      return Card(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRow(
                  title: 'Izvedeni oblici',
                  onCopy: () => _copy(context, izvedeniJson),
                ),
                const SizedBox(height: 8),
                SelectableText(parsed?.toString() ?? izvedeniJson),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(
                title: 'Izvedeni oblici',
                onCopy: () => _copy(context, _toPlainText(parsed)),
              ),
              const SizedBox(height: 8),
              _NodeView(
                title: null,
                node: parsed,
                depth: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Izvedeni oblici copied')),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String title;
  final VoidCallback onCopy;

  const _HeaderRow({required this.title, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy),
          onPressed: onCopy,
        ),
      ],
    );
  }
}

/// Tries to decode JSON. If input is already a decoded object, returns it.
/// If it's a string that contains JSON, tries to decode that too.
dynamic _tryJsonDecode(dynamic input) {
  if (input == null) return null;

  if (input is Map || input is List) return input;

  if (input is String) {
    final s = input.trim();
    if (s.isEmpty) return null;

    final looksJson =
        (s.startsWith('{') && s.endsWith('}')) || (s.startsWith('[') && s.endsWith(']'));
    if (!looksJson) return input;

    try {
      return jsonDecode(s);
    } catch (_) {
      return input; // keep as string
    }
  }

  return input;
}

/// Pretty labels for common Croatian morphology keys.
String _labelKey(String k) {
  const map = {
    // number
    "jednina": "Jednina",
    "mnozina": "Množina",

    // gender
    "muskiRod": "Muški rod",
    "zenskiRod": "Ženski rod",
    "srednjiRod": "Srednji rod",

    // degrees
    "pozitivNeodredeni": "Pozitiv (neodređeni)",
    "pozitivOdredeni": "Pozitiv (određeni)",
    "komparativ": "Komparativ",
    "superlativ": "Superlativ",

    // cases
    "nominativ": "Nominativ",
    "genitiv": "Genitiv",
    "dativ": "Dativ",
    "akuzativ": "Akuzativ",
    "vokativ": "Vokativ",
    "lokativ": "Lokativ",
    "instrumental": "Instrumental",

    // verb persons
    "prvoLice": "1. lice",
    "drugoLice": "2. lice",
    "treceLice": "3. lice",

    // verb-ish headings (examples – add more if you like)
    "infinitiv": "Infinitiv",
    "prezent": "Prezent",
    "Prezent": "Prezent",
    "futur": "Futur",
    "Futur": "Futur",
    "imperfekt": "Imperfekt",
    "Imperfekt": "Imperfekt",
    "perfekt": "Perfekt",
    "Perfekt": "Perfekt",
    "pluskvamperfekt": "Pluskvamperfekt",
    "Pluskvamperfekt": "Pluskvamperfekt",
    "imperativ": "Imperativ",
    "Imperativ": "Imperativ",
    "glagolskiPrilogSadasnji": "Glagolski prilog sadašnji",
    "glagolskiPridjevAktivni": "Glagolski pridjev aktivni",
    "glagolskiPridjevPasivni": "Glagolski pridjev pasivni",
  };
  return map[k] ?? k;
}

class _NodeView extends StatelessWidget {
  final String? title;
  final dynamic node;
  final int depth;

  const _NodeView({
    required this.title,
    required this.node,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoded = _tryJsonDecode(node);

    final children = <Widget>[];

    if (title != null) {
      final style = depth == 0
          ? theme.textTheme.titleMedium
          : depth == 1
          ? theme.textTheme.titleSmall
          : theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);

      children.add(Padding(
        padding: EdgeInsets.only(top: depth == 0 ? 0 : 10, bottom: 6),
        child: Text(title!, style: style),
      ));
    }

    if (decoded is Map) {
      // ✅ Case tables
      if (_looksLikeCaseTable(decoded)) {
        children.add(_CaseTable(map: decoded.cast<String, dynamic>()));
      }
      // ✅ Verb-person tables (prvo/drugo/trece lice)
      else if (_looksLikePersonTable(decoded)) {
        children.add(_PersonTable(map: decoded.cast<String, dynamic>()));
      }
      // ✅ Verb tenses: if it contains both jednina & mnozina, render as tabs
      else if (_looksLikeNumberTabs(decoded)) {
        final m = decoded.cast<String, dynamic>();
        children.add(_NumberTabs(
          jednina: m["jednina"],
          mnozina: m["mnozina"],
        ));
      } else {
        // Normal nested sections
        final entries = decoded.entries.toList();
        entries.sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        final initiallyExpandedKey = entries.isNotEmpty ? entries.first.key.toString() : null;

        for (final e in entries) {
          final key = e.key.toString();
          final label = _labelKey(key);
          final childDecoded = _tryJsonDecode(e.value);
          final canExpand = childDecoded is Map || childDecoded is List;

          final isTopSection = depth == 0 && canExpand;

          if (isTopSection) {
            children.add(
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 8, bottom: 10),
                title: Text(label, style: theme.textTheme.titleSmall),
                initiallyExpanded: key == initiallyExpandedKey,
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  _NodeView(
                    title: null,
                    node: e.value,
                    depth: depth + 1,
                  ),
                ],
              ),
            );
          } else {
            children.add(_NodeView(
              title: label,
              node: e.value,
              depth: depth + 1,
            ));
          }
        }
      }
    } else if (decoded is List) {
      for (var i = 0; i < decoded.length; i++) {
        children.add(_NodeView(
          title: "${title ?? 'Item'} #${i + 1}",
          node: decoded[i],
          depth: depth + 1,
        ));
      }
    } else {
      children.add(SelectableText((decoded ?? "").toString()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  bool _looksLikeCaseTable(Map m) {
    const keys = {
      "nominativ",
      "genitiv",
      "dativ",
      "akuzativ",
      "vokativ",
      "lokativ",
      "instrumental",
    };
    final present = m.keys.map((k) => k.toString()).toSet();
    return present.intersection(keys).length >= 3;
  }

  bool _looksLikePersonTable(Map m) {
    const keys = {"prvoLice", "drugoLice", "treceLice"};
    final present = m.keys.map((k) => k.toString()).toSet();
    return present.intersection(keys).length >= 2;
  }

  bool _looksLikeNumberTabs(Map m) {
    final keys = m.keys.map((k) => k.toString()).toSet();
    if (!(keys.contains("jednina") && keys.contains("mnozina"))) return false;

    // Avoid tabbing for nouns where jednina/mnozina are directly the case table.
    // We only want tabs when they contain a nested map/list (like person tables / complex forms).
    final j = _tryJsonDecode(m["jednina"]);
    final mn = _tryJsonDecode(m["mnozina"]);
    final complex = (j is Map || j is List) && (mn is Map || mn is List);

    // If jednina itself is a pure case-table map, prefer the case-table rendering.
    if (j is Map && _looksLikeCaseTable(j)) return false;
    if (mn is Map && _looksLikeCaseTable(mn)) return false;

    return complex;
  }
}

/// Tabs widget for Jednina/Množina (verb tenses)
class _NumberTabs extends StatelessWidget {
  final dynamic jednina;
  final dynamic mnozina;

  const _NumberTabs({
    required this.jednina,
    required this.mnozina,
  });

  @override
  Widget build(BuildContext context) {
    final j = _tryJsonDecode(jednina);
    final m = _tryJsonDecode(mnozina);

    Widget buildBody(dynamic node) {
      final decoded = _tryJsonDecode(node);

      if (decoded is Map && _looksLikePersonTable(decoded)) {
        return _PersonTable(map: decoded.cast<String, dynamic>());
      }
      if (decoded is Map && _looksLikeCaseTable(decoded)) {
        return _CaseTable(map: decoded.cast<String, dynamic>());
      }
      return _NodeView(title: null, node: decoded, depth: 99);
    }

    return DefaultTabController(
      length: 2,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              tabs: const [
                Tab(text: 'Jednina'),
                Tab(text: 'Množina'),
              ],
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              dividerColor: Colors.transparent,
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                height: _estimateTabHeight(context, j, m),
                child: TabBarView(
                  children: [
                    SingleChildScrollView(child: buildBody(j)),
                    SingleChildScrollView(child: buildBody(m)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep TabBarView from being "unbounded height" inside Column.
  // We choose a reasonable height that usually fits persons/cases.
  double _estimateTabHeight(BuildContext context, dynamic j, dynamic m) {
    final base = 190.0;
    final hasPerson = (j is Map && _looksLikePersonTable(j)) || (m is Map && _looksLikePersonTable(m));
    final hasCase = (j is Map && _looksLikeCaseTable(j)) || (m is Map && _looksLikeCaseTable(m));
    if (hasCase) return base + 140;
    if (hasPerson) return base + 70;
    return base + 120;
  }

  bool _looksLikePersonTable(Map m) {
    const keys = {"prvoLice", "drugoLice", "treceLice"};
    final present = m.keys.map((k) => k.toString()).toSet();
    return present.intersection(keys).length >= 2;
  }

  bool _looksLikeCaseTable(Map m) {
    const keys = {
      "nominativ",
      "genitiv",
      "dativ",
      "akuzativ",
      "vokativ",
      "lokativ",
      "instrumental",
    };
    final present = m.keys.map((k) => k.toString()).toSet();
    return present.intersection(keys).length >= 3;
  }
}

class _CaseTable extends StatelessWidget {
  final Map<String, dynamic> map;
  const _CaseTable({required this.map});

  @override
  Widget build(BuildContext context) {
    const order = [
      "nominativ",
      "genitiv",
      "dativ",
      "akuzativ",
      "vokativ",
      "lokativ",
      "instrumental",
    ];

    final entries = <MapEntry<String, dynamic>>[];

    for (final k in order) {
      if (map.containsKey(k)) entries.add(MapEntry(k, map[k]));
    }
    for (final e in map.entries) {
      if (!order.contains(e.key)) entries.add(e);
    }

    return _KeyValueTable(entries: entries, labelWidth: 130);
  }
}

class _PersonTable extends StatelessWidget {
  final Map<String, dynamic> map;
  const _PersonTable({required this.map});

  @override
  Widget build(BuildContext context) {
    const order = ["prvoLice", "drugoLice", "treceLice"];

    final entries = <MapEntry<String, dynamic>>[];
    for (final k in order) {
      if (map.containsKey(k)) entries.add(MapEntry(k, map[k]));
    }
    for (final e in map.entries) {
      if (!order.contains(e.key)) entries.add(e);
    }

    return _KeyValueTable(entries: entries, labelWidth: 110);
  }
}

class _KeyValueTable extends StatelessWidget {
  final List<MapEntry<String, dynamic>> entries;
  final double labelWidth;

  const _KeyValueTable({
    required this.entries,
    required this.labelWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: entries.map((e) {
          final label = _labelKey(e.key);
          final valDecoded = _tryJsonDecode(e.value);

          final valueWidget = (valDecoded is Map || valDecoded is List)
              ? _NodeView(title: null, node: valDecoded, depth: 99)
              : SelectableText((valDecoded ?? "").toString());

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: valueWidget),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Convert the decoded forms structure into a readable plain-text outline.
/// Used for "Copy izvedeni oblici".
String _toPlainText(dynamic node, {int indent = 0}) {
  final decoded = _tryJsonDecode(node);
  final pad = '  ' * indent;

  if (decoded is Map) {
    final entries = decoded.entries.toList();
    entries.sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    final buf = StringBuffer();
    for (final e in entries) {
      final k = _labelKey(e.key.toString());
      final v = _tryJsonDecode(e.value);
      if (v is Map || v is List) {
        buf.writeln('$pad$k:');
        buf.write(_toPlainText(v, indent: indent + 1));
      } else {
        buf.writeln('$pad$k: ${v ?? ""}');
      }
    }
    return buf.toString();
  }

  if (decoded is List) {
    final buf = StringBuffer();
    for (var i = 0; i < decoded.length; i++) {
      final v = _tryJsonDecode(decoded[i]);
      if (v is Map || v is List) {
        buf.writeln('${pad}-');
        buf.write(_toPlainText(v, indent: indent + 1));
      } else {
        buf.writeln('$pad- ${v ?? ""}');
      }
    }
    return buf.toString();
  }

  return '$pad${decoded ?? ""}\n';
}
