import 'package:flutter/material.dart';

import '../../domain/entities/tutor_block.dart';

/// Reports a graded concept check so progress can be recorded.
typedef CheckAnsweredCallback = void Function(
  TutorCheckBlock block,
  bool correct,
);

/// Renders one [TutorBlock]. `onFollowupTap` lets the followups block send a
/// suggested question with a single tap instead of retyping it.
class TutorBlockView extends StatelessWidget {
  const TutorBlockView({
    super.key,
    required this.block,
    this.onFollowupTap,
    this.onCheckAnswered,
  });

  final TutorBlock block;
  final ValueChanged<String>? onFollowupTap;
  final CheckAnsweredCallback? onCheckAnswered;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      TutorTextBlock(text: final text) => _RichBlockText(text: text),
      TutorExampleBlock(title: final title, body: final body) =>
        _ExampleCard(title: title, body: body),
      final TutorCheckBlock check =>
        _CheckCard(block: check, onAnswered: onCheckAnswered),
      TutorFollowupsBlock(items: final items) =>
        _FollowupsRow(items: items, onTap: onFollowupTap),
      TutorUnknownBlock() => const SizedBox.shrink(),
    };
  }
}

/// Plain paragraphs (split on blank lines) with `**bold**` support — the
/// tutor prompt is instructed to use only this much markup, so a full
/// markdown renderer/dependency isn't needed.
class _RichBlockText extends StatelessWidget {
  const _RichBlockText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty);
    final style = Theme.of(context).textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText.rich(_parseBold(p, style)),
          ),
      ],
    );
  }

  TextSpan _parseBold(String text, TextStyle? base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start), style: base));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: base?.copyWith(fontWeight: FontWeight.w700),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return TextSpan(children: spans, style: base);
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RichBlockText(text: body),
          ],
        ),
      ),
    );
  }
}

/// A low-stakes concept check: pick an option, see it graded in place with an
/// explanation. Still retrieval practice rather than an exam — nothing is
/// shown as a score here — but the first answer is reported through
/// [onAnswered] so the Progress screen can track accuracy over time.
class _CheckCard extends StatefulWidget {
  const _CheckCard({required this.block, this.onAnswered});

  final TutorCheckBlock block;
  final CheckAnsweredCallback? onAnswered;

  @override
  State<_CheckCard> createState() => _CheckCardState();
}

class _CheckCardState extends State<_CheckCard> {
  int? _selected;

  /// Only the first answer counts — the choices lock afterwards, so this can
  /// never double-record.
  void _choose(int index) {
    setState(() => _selected = index);
    widget.onAnswered?.call(widget.block, widget.block.isCorrect(index));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = widget.block;
    return Card(
      color: scheme.secondaryContainer.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.quiz_outlined, size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Quick check',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(block.question, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            for (var i = 0; i < block.choices.length; i++)
              _ChoiceTile(
                label: block.choices[i],
                selected: _selected == i,
                correct: _selected != null && i == block.correctIndex,
                wrong: _selected == i && i != block.correctIndex,
                onTap: _selected == null ? () => _choose(i) : null,
              ),
            if (_selected != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    block.isCorrect(_selected!) ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: block.isCorrect(_selected!) ? Colors.green : scheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(block.explanation)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? tileColor;
    if (correct) tileColor = Colors.green.withValues(alpha: 0.15);
    if (wrong) tileColor = scheme.error.withValues(alpha: 0.12);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: tileColor,
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(
          correct
              ? Icons.check_circle
              : wrong
                  ? Icons.cancel
                  : Icons.circle_outlined,
          color: correct
              ? Colors.green
              : wrong
                  ? scheme.error
                  : scheme.outline,
        ),
        title: Text(label),
      ),
    );
  }
}

class _FollowupsRow extends StatelessWidget {
  const _FollowupsRow({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            ActionChip(
              label: Text(item),
              onPressed: onTap == null ? null : () => onTap!(item),
            ),
        ],
      ),
    );
  }
}
