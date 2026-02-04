import 'package:flutter/material.dart';
import '../../data/dictionary_db.dart';
import 'kalodont/kalodont_page.dart';

class GamesPage extends StatelessWidget {
  final DictionaryDb db;
  final Future<void> Function(String word) onOpenWord;

  const GamesPage({super.key, required this.db, required this.onOpenWord});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Kalodont'),
              subtitle: const Text('Next word must start with last 2 letters'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => KalodontPage(db: db, onOpenWord: onOpenWord)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
