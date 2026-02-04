import 'package:flutter/material.dart';
import '../features/dictionary/dictionary_page.dart';

class HjpApp extends StatelessWidget {
  const HjpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Croatian dictionary',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const DictionaryPage(),
    );
  }
}
