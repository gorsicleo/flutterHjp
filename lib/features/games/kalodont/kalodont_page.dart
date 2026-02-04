import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../common/widgets/loading_view.dart';
import '../../../data/dictionary_db.dart';
import 'kalodont_controller.dart';

class KalodontPage extends StatefulWidget {
  final DictionaryDb db;
  final Future<void> Function(String word) onOpenWord;
  const KalodontPage({super.key, required this.db, required this.onOpenWord });

  @override
  State<KalodontPage> createState() => _KalodontPageState();
}

class _KalodontPageState extends State<KalodontPage> {
  late final KalodontController controller;
  final TextEditingController input = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = KalodontController(widget.db);
    controller.start();
  }

  @override
  void dispose() {
    input.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalodont'),
        actions: [
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              input.clear();
              controller.start();
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.status == KalodontStatus.loading) {
            return const LoadingView(message: 'Starting game…');
          }

          final last = controller.history.isEmpty ? '—' : controller.history.last.word;

          final userCanPlay = controller.status == KalodontStatus.userTurn;

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Column(
              children: [
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    title: Text(
                      'Current word: $last (next: ${controller.requiredNorm}-)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: controller.message == null ? null : Text(controller.message!),
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: controller.definitionLoading
                            ? const Center(child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ))
                            : SingleChildScrollView(
                          child: Html(
                            data: controller.currentDefinition,
                            style: {
                              "body": Style(
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                              ),
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (userCanPlay) ...[
                  TextField(
                    controller: input,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Your word',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) async {
                      final t = input.text;
                      input.clear();
                      await controller.submitUser(t);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final t = input.text;
                            input.clear();
                            await controller.submitUser(t);
                          },
                          child: const Text('Play'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('Hint'),
                        onPressed: userCanPlay
                            ? () async {
                          final hint = await controller.getHintWord();
                          if (!mounted) return;

                          if (hint == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Nemam prijedlog na "${controller.requiredNorm}-"')),
                            );
                            return;
                          }

                          input.text = hint;
                          input.selection = TextSelection(baseOffset: 0, extentOffset: hint.length);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hint: $hint')),
                          );
                        }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: controller.giveUp,
                        child: const Text('Give up'),
                      ),
                    ],
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () {
                      input.clear();
                      controller.start();
                    },
                    child: const Text('Start new game'),
                  ),
                ],

                const SizedBox(height: 12),

                Expanded(
                  child: Card(
                    child: ListView.separated(
                      itemCount: controller.history.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = controller.history[i];
                        return ListTile(
                          leading: Icon(t.bot ? Icons.smart_toy : Icons.person),
                          title: Text(t.word),
                          subtitle: Text(t.bot ? 'Phone' : 'You'),
                          onTap: () => widget.onOpenWord(t.word),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
