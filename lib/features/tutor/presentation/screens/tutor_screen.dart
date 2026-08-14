import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/config_providers.dart';
import '../../../../core/ink/ink_canvas.dart';
import '../../../../core/ink/ink_controller.dart';
import '../../../../core/ink/ink_stroke.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../access/presentation/widgets/access_gate.dart';
import '../../../progress/application/progress_providers.dart';
import '../../application/tutor_controller.dart';
import '../../application/tutor_state.dart';
import '../../domain/entities/tutor_block.dart';
import '../../domain/entities/tutor_turn.dart';
import '../widgets/tutor_block_view.dart';
import '../widgets/tutor_composer.dart';

const _samplePrompts = [
  'Explain photosynthesis simply',
  'Help me solve 2x + 5 = 11',
  'What caused World War I?',
  'Why is the sky blue?',
];

/// The prompt the scratchpad sends when working is attached. Fixed wording so
/// the backend can recognise a handwriting turn.
const kAttachedWorkingPrompt = 'Can you check my handwritten working?';

/// Conversational tutor: user turns as brand bubbles, assistant turns as
/// ordered blocks, plus a pen scratchpad for showing handwritten working.
class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key});

  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _scratchpad = InkController();

  bool _padOpen = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _scratchpad.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(tutorControllerProvider.notifier).send(text);
  }

  /// Records a graded concept check. Best-effort: the card has already shown
  /// the result, so a recording failure stays silent.
  void _recordCheck(TutorCheckBlock block, bool correct) {
    final state = ref.read(tutorControllerProvider);
    unawaited(
      ref
          .read(progressRecorderProvider)
          .check(
            correct: correct,
            question: block.question,
            subject: state.subject,
            level: state.level,
          ),
    );
  }

  /// Subject / level sharpen the tutor's pitch and label progress events, so
  /// the control stays reachable even though the redesigned shell has no
  /// per-screen app-bar actions.
  Future<void> _showContextSheet() async {
    final state = ref.read(tutorControllerProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TunerSheet(
        subject: state.subject,
        level: state.level,
        onSave: (subject, level) => ref
            .read(tutorControllerProvider.notifier)
            .setContext(subject: subject, level: level),
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasBackend = ref.watch(appConfigProvider).hasDataConnector;
    final state = ref.watch(tutorControllerProvider);
    ref.listen(tutorControllerProvider, (_, _) => _scrollToBottom());

    // The tutor is the expensive surface, so it is the one that stops when
    // nobody is paying. Lessons, the workbook canvas and a student's own
    // progress stay open — see AccessGate.
    return AccessGate(
      featureName: 'The AI Tutor',
      child: Column(
        children: [
          if (!hasBackend) const _BackendUnconfiguredBanner(),
          if (state.subject != null || state.level != null)
            _ContextBar(state: state, onEdit: _showContextSheet),
          Expanded(
            child: state.turns.isEmpty
                ? _EmptyState(onPromptTap: _send, onTune: _showContextSheet)
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: tutorMaxContentWidth,
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.turns.length,
                        itemBuilder: (context, i) => _TurnTile(
                          turn: state.turns[i],
                          onFollowupTap: _send,
                          onCheckAnswered: _recordCheck,
                        ),
                      ),
                    ),
                  ),
          ),
          if (state.busy) const _ThinkingIndicator(),
          if (state.failure != null)
            _ErrorBanner(
              message: state.failure!.message,
              onDismiss: () =>
                  ref.read(tutorControllerProvider.notifier).dismissError(),
            ),
          if (_padOpen)
            _Scratchpad(
              controller: _scratchpad,
              onClose: () => setState(() => _padOpen = false),
              onAttach: () {
                _send(kAttachedWorkingPrompt);
                _scratchpad.clear();
                setState(() => _padOpen = false);
              },
            ),
          TutorComposer(
            controller: _inputController,
            busy: state.busy,
            onSend: _send,
            leading: ToolIconButton(
              key: const Key('tutor-pen-button'),
              icon: Icons.edit_outlined,
              tooltip: 'Show your work with a pen',
              active: _padOpen,
              onPressed: () => setState(() => _padOpen = !_padOpen),
            ),
          ),
        ],
      ),
    );
  }
}

/// The embedded handwriting pad above the composer — the bridge between
/// free-hand maths and the chat.
class _Scratchpad extends StatelessWidget {
  const _Scratchpad({
    required this.controller,
    required this.onClose,
    required this.onAttach,
  });

  final InkController controller;
  final VoidCallback onClose;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: tutorMaxContentWidth),
          child: SunkenCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Show your work',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: t.ink,
                        ),
                      ),
                    ),
                    ToolIconButton(
                      icon: Icons.close,
                      size: 28,
                      tooltip: 'Close scratchpad',
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: InkCanvas(
                    key: const Key('tutor-scratchpad-canvas'),
                    controller: controller,
                    guide: InkGuide.grid,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: controller.clear,
                      child: const Text('Clear'),
                    ),
                    FilledButton(
                      key: const Key('tutor-attach-button'),
                      onPressed: onAttach,
                      child: const Text('Attach & ask'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackendUnconfiguredBanner extends StatelessWidget {
  const _BackendUnconfiguredBanner();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      width: double.infinity,
      color: t.warningSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        "The AI tutor backend isn't configured for this build "
        '(DATA_CONNECTOR_URL missing).',
        style: TextStyle(color: t.warning, fontSize: 13),
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.state, required this.onEdit});

  final TutorChatState state;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        children: [
          if (state.subject != null)
            SoftChip(state.subject!, tone: AppTone.brand, onTap: onEdit),
          if (state.level != null)
            SoftChip(state.level!, tone: AppTone.brand, onTap: onEdit),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptTap, required this.onTune});

  final ValueChanged<String> onPromptTap;
  final VoidCallback onTune;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconTile(icon: Icons.auto_awesome, size: 64, iconSize: 26),
              const SizedBox(height: 14),
              Text(
                "Ask me anything you're studying",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "I'll explain step by step and check your understanding along "
                'the way.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.ink2),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in _samplePrompts)
                    PromptChip(prompt, onTap: () => onPromptTap(prompt)),
                ],
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onTune,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Set subject & level'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnTile extends StatelessWidget {
  const _TurnTile({
    required this.turn,
    required this.onFollowupTap,
    required this.onCheckAnswered,
  });

  final TutorTurn turn;
  final ValueChanged<String> onFollowupTap;
  final CheckAnsweredCallback onCheckAnswered;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return switch (turn) {
      TutorUserTurn(text: final text) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: t.brand,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(text, style: TextStyle(color: t.onBrand, fontSize: 15)),
          ),
        ),
      ),
      TutorAssistantTurn(blocks: final blocks) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final block in blocks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TutorBlockView(
                  block: block,
                  onFollowupTap: onFollowupTap,
                  onCheckAnswered: onCheckAnswered,
                ),
              ),
          ],
        ),
      ),
    };
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Thinking it through…',
            style: TextStyle(fontSize: 13, color: t.ink2),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      width: double.infinity,
      color: t.dangerSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: t.danger, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: t.danger, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Subject / level entry. A StatefulWidget so the sheet owns its text
/// controllers: disposing them from the caller kills them while the sheet is
/// still animating out, and the fields then throw mid-dismiss.
class _TunerSheet extends StatefulWidget {
  const _TunerSheet({
    required this.subject,
    required this.level,
    required this.onSave,
  });

  final String? subject;
  final String? level;
  final void Function(String? subject, String? level) onSave;

  @override
  State<_TunerSheet> createState() => _TunerSheetState();
}

class _TunerSheetState extends State<_TunerSheet> {
  late final _subject = TextEditingController(text: widget.subject ?? '');
  late final _level = TextEditingController(text: widget.level ?? '');

  @override
  void dispose() {
    _subject.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      // Scrollable: on a short phone with the keyboard up there is not enough
      // room for two fields plus the save button.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Tune your tutor'),
            const SizedBox(height: 4),
            Text(
              'Helps the tutor pitch explanations at the right level.',
              style: TextStyle(color: t.ink2),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('tutor-subject-field'),
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject (optional)',
                hintText: 'e.g. algebra, biology',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tutor-level-field'),
              controller: _level,
              decoration: const InputDecoration(
                labelText: 'Level (optional)',
                hintText: 'e.g. P6, O-Level',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final subject = _subject.text.trim();
                final level = _level.text.trim();
                widget.onSave(
                  subject.isEmpty ? null : subject,
                  level.isEmpty ? null : level,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
