import 'package:flutter/material.dart';
import 'saved_sql.dart';

class SavedSqlSheet extends StatelessWidget {
  final List<SavedSql> items;
  final void Function(SavedSql item) onSelect;
  final void Function(SavedSql item) onDelete;
  final void Function(SavedSql item) onRename;

  const SavedSqlSheet({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          const Text('Saved SQL', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Divider(height: 1),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No saved queries yet.'),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(it.name),
                    subtitle: Text(
                      it.sql.replaceAll('\n', ' '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => onSelect(it),
                    onLongPress: () async {
                      final v = await showModalBottomSheet<String>(
                        context: context,
                        showDragHandle: true,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Saved query'),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.edit),
                                title: const Text('Rename'),
                                onTap: () => Navigator.pop(ctx, 'rename'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete),
                                title: const Text('Delete'),
                                onTap: () => Navigator.pop(ctx, 'delete'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );

                      if (v == 'rename') onRename(it);
                      if (v == 'delete') onDelete(it);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
