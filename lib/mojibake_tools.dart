import 'dart:convert';

import 'package:flutter/material.dart';

const List<String> mojibakeEmojiGlyphs = <String>[
  '\u{1F600}',
  '\u{1F601}',
  '\u{1F602}',
  '\u{1F923}',
  '\u{1F60A}',
  '\u{1F60D}',
  '\u{1F618}',
  '\u{1F44D}',
  '\u{1F44F}',
  '\u{1F64C}',
  '\u{1F525}',
  '\u{1F389}',
  '\u{2764}\u{FE0F}',
  '\u{1F499}',
  '\u{1F60E}',
  '\u{1F91D}',
];

String repairMojibakeText(String value) {
  var current = value;
  for (var i = 0; i < 2; i++) {
    try {
      final candidate = utf8.decode(latin1.encode(current), allowMalformed: true);
      final currentScore = _mojibakeScore(current);
      final candidateScore = _mojibakeScore(candidate);
      if (candidateScore < currentScore && candidate.trim().isNotEmpty) {
        current = candidate;
      }
    } catch (_) {
      break;
    }
  }
  return current;
}

String cleanMojibakeText(Object? value) => repairMojibakeText('${value ?? ''}').trim();

int _mojibakeScore(String value) {
  const suspiciousTokens = <String>['Ã', 'Â', 'â', 'ð', '�'];
  var score = 0;
  for (final token in suspiciousTokens) {
    score += token.allMatches(value).length;
  }
  return score;
}

class MojibakeEmojiPicker extends StatelessWidget {
  const MojibakeEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.height = 190,
  });

  final ValueChanged<String> onEmojiSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 8,
        children: mojibakeEmojiGlyphs
            .map(
              (emoji) => InkWell(
                onTap: () => onEmojiSelected(emoji),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 25),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class MojibakeLabPage extends StatefulWidget {
  const MojibakeLabPage({super.key});

  @override
  State<MojibakeLabPage> createState() => _MojibakeLabPageState();
}

class _MojibakeLabPageState extends State<MojibakeLabPage> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repaired = repairMojibakeText(_inputController.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Mojibake Lab')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _inputController,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Broken text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Repaired preview',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(repaired),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Emoji preview',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const MojibakeEmojiPicker(onEmojiSelected: _noop),
          ],
        ),
      ),
    );
  }

  static void _noop(String _) {}
}