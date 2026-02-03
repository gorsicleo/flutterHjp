import 'package:flutter/material.dart';
import '../../data/dictionary_db.dart';
import '../../data/models/search_result.dart';
import 'package:flutter/services.dart';
import 'saved_sql.dart';
import 'saved_sql_store.dart';
import 'saved_sql_sheet.dart';


class SqlConsolePage extends StatefulWidget {
  final DictionaryDb db;
  final void Function(String entryId) onOpen;

  const SqlConsolePage({
    super.key,
    required this.db,
    required this.onOpen,
  });

  @override
  State<SqlConsolePage> createState() => _SqlConsolePageState();
}

class _SqlConsolePageState extends State<SqlConsolePage> {
  final _controller = TextEditingController(
    text: '''
SELECT id, rijec, vrsta
FROM entries
WHERE rijec_norm LIKE 'majka%'
ORDER BY rijec_norm
'''.trim(),
  );

  final _store = SavedSqlStore();
  List<SavedSql> _saved = [];

  bool _running = false;
  bool _danger = false;

  String? _error;

  // For "result list" use-case
  List<SearchResultRow> _rows = [];

  // For raw output (danger mode / non-standard selects)
  List<Map<String, Object?>> _rawRows = [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final items = await _store.loadAll();
    if (!mounted) return;
    setState(() => _saved = items);
  }

  Future<void> _openSavedSheet() async {
    await _loadSaved();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: SavedSqlSheet(
          items: _saved,
          onSelect: (it) {
            Navigator.pop(ctx);
            setState(() => _controller.text = it.sql);
          },
          onDelete: (it) async {
            await _store.deleteById(it.id);
            await _loadSaved();
            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            // Re-open to reflect updated list (simple approach)
            if (mounted) _openSavedSheet();
          },
          onRename: (it) async {
            final c = TextEditingController(text: it.name);
            final newName = await showDialog<String>(
              context: context,
              builder: (dctx) => AlertDialog(
                title: const Text('Rename'),
                content: TextField(
                  controller: c,
                  decoration: const InputDecoration(labelText: 'Name'),
                  autofocus: true,
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(dctx, c.text.trim()), child: const Text('Save')),
                ],
              ),
            );

            if (newName == null || newName.trim().isEmpty) return;

            final now = DateTime.now().millisecondsSinceEpoch;
            final updated = SavedSql(
              id: newName.trim().toLowerCase(),
              name: newName.trim(),
              sql: it.sql,
              updatedAtMs: now,
            );

            // delete old key, upsert new
            await _store.deleteById(it.id);
            await _store.upsert(updated);
            await _loadSaved();

            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
            if (mounted) _openSavedSheet();
          },
        ),
      ),
    );
  }


  Future<void> _saveCurrentQuery() async {
    final sql = _controller.text.trim();
    if (sql.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SQL is empty')),
      );
      return;
    }

    final nameController = TextEditingController();

    final pickedName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save query'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Words starting with majka',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (pickedName == null || pickedName.trim().isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = pickedName.trim().toLowerCase(); // simple stable id by name

    // If same name exists, overwrite
    final item = SavedSql(id: id, name: pickedName.trim(), sql: sql, updatedAtMs: now);
    await _store.upsert(item);
    await _loadSaved();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
      _rows = [];
      _rawRows = [];
    });

    final sql = _controller.text.trim();

    try {
      if (!_danger) {
        // SAFE MODE: SELECT only, formatted as SearchResultRow
        final res = await widget.db.runSelectQuery(sql, limit: 300);
        setState(() => _rows = res);
      } else {
        // DANGER MODE:
        // - If the query is SELECT/WITH and returns id/rijec/vrsta -> show normal list
        // - Otherwise show raw rows (or show success message if no rows)
        final lower = sql.toLowerCase();
        if (lower.startsWith('select') || lower.startsWith('with')) {
          final asRows = await widget.db.runQueryAsResults(sql, limit: 300);
          if (asRows.isNotEmpty) {
            setState(() => _rows = asRows);
          } else {
            final raw = await widget.db.runAnySql(sql);
            setState(() => _rawRows = raw);
          }
        } else {
          await widget.db.runAnySql(sql);
          // For non-select statements, show a simple message via snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Executed successfully')),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SQL Console')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: 'SQL',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: () => _controller.clear(),
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Danger mode (allow ALL commands)'),
                    subtitle: Text(
                      _danger
                          ? 'You can run UPDATE/DELETE/DROP. Be careful.'
                          : 'Only SELECT is allowed.',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: _danger,
                    onChanged: _running
                        ? null
                        : (v) async {
                      if (v) {
                        // Confirm once when enabling danger mode
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Enable Danger mode?'),
                            content: const Text(
                              'This allows UPDATE/DELETE/DROP and can break your app database.\n\n'
                                  'Use only for debugging on your own device.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Enable'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          setState(() => _danger = true);
                        }
                      } else {
                        setState(() => _danger = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label: const Text('Run'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Save query',
                  onPressed: _running ? null : _saveCurrentQuery,
                  icon: const Icon(Icons.bookmark_add),
                ),
                IconButton(
                  tooltip: 'Saved queries',
                  onPressed: _running ? null : _openSavedSheet,
                  icon: const Icon(Icons.library_books),
                ),
                const SizedBox(width: 12),
                Text('Rows: ${_rows.isNotEmpty ? _rows.length : _rawRows.length}'),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),

          const Divider(height: 1),

          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_rows.isNotEmpty) {
      return ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = _rows[i];
          return ListTile(
            title: Text(r.rijec),
            subtitle: Text(r.vrsta),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onOpen(r.id),
          );
        },
      );
    }

    if (_rawRows.isNotEmpty) {
      // Show raw output (first ~100 rows for sanity)
      final shown = _rawRows.take(100).toList();
      return ListView.separated(
        itemCount: shown.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final row = shown[i];
          return ListTile(
            title: Text(row.keys.join(', ')),
            subtitle: Text(row.values.map((v) => v?.toString() ?? 'null').join(' | ')),
          );
        },
      );
    }

    return const Center(child: Text('No results'));
  }
}
