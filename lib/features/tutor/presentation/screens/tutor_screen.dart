import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/config_providers.dart';
import '../../application/tutor_controller.dart';
import '../../application/tutor_state.dart';
import '../../domain/entities/tutor_turn.dart';
import '../widgets/tutor_block_view.dart';

const _samplePrompts = [
  'Explain photosynthesis simply',
  'Help me solve 2x + 5 = 11',
  'What caused World War I?',
  'Why is the sky blue?',
];

class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key});

  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(tutorControllerProvider.notifier).send(text);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tutor'),
        actions: [
          IconButton(
            tooltip: 'Subject & level',
            icon: const Icon(Icons.tune),
            onPressed: () => _showContextSheet(context),
          ),
          IconButton(
            tooltip: 'New conversation',
            icon: const Icon(Icons.refresh),
            onPressed: state.turns.isEmpty
                ? null
                : () => ref.read(tutorControllerProvider.notifier).reset(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!hasBackend) const _BackendUnconfiguredBanner(),
            if (state.subject != null || state.level != null) _ContextBar(state: state),
            Expanded(
              child: state.turns.isEmpty
                  ? _EmptyState(onPromptTap: _send)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.turns.length,
                      itemBuilder: (context, i) => _TurnTile(
                        turn: state.turns[i],
                        onFollowupTap: _send,
                      ),
                    ),
            ),
            if (state.busy) const _ThinkingIndicator(),
            if (state.failure != null)
              _ErrorBanner(
                message: state.failure!.message,
                onDismiss: () => ref.read(tutorControllerProvider.notifier).dismissError(),
              ),
            _Composer(controller: _inputController, busy: state.busy, onSend: _send),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextSheet(BuildContext context) async {
    final state = ref.read(tutorControllerProvider);
    final subjectController = TextEditingController(text: state.subject ?? '');
    final levelController = TextEditingController(text: state.level ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tune your tutor',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Helps the tutor pitch explanations at the right level.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject (optional)',
                hintText: 'e.g. algebra, biology',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: levelController,
              decoration: const InputDecoration(
                labelText: 'Level (optional)',
                hintText: 'e.g. grade 6, beginner',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                ref.read(tutorControllerProvider.notifier).setContext(
                      subject: subjectController.text.trim().isEmpty
                          ? null
                          : subjectController.text.trim(),
                      level: levelController.text.trim().isEmpty
                          ? null
                          : levelController.text.trim(),
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

class _BackendUnconfiguredBanner extends StatelessWidget {
  const _BackendUnconfiguredBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'The AI tutor backend isn\'t configured for this build (DATA_CONNECTOR_URL missing).',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.state});

  final TutorChatState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        children: [
          if (state.subject != null) Chip(label: Text(state.subject!)),
          if (state.level != null) Chip(label: Text(state.level!)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_outlined, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Ask me anything you\'re studying',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'I\'ll explain step by step and check your understanding along the way.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in _samplePrompts)
                    ActionChip(label: Text(prompt), onPressed: () => onPromptTap(prompt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnTile extends StatelessWidget {
  const _TurnTile({required this.turn, required this.onFollowupTap});

  final TutorTurn turn;
  final ValueChanged<String> onFollowupTap;

  @override
  Widget build(BuildContext context) {
    return switch (turn) {
      TutorUserTurn(text: final text) => Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  text,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
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
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TutorBlockView(block: block, onFollowupTap: onFollowupTap),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Thinking it through…'),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
          IconButton(
            icon: Icon(Icons.close, color: scheme.onErrorContainer, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.busy, required this.onSend});

  final TextEditingController controller;
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !busy,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: busy ? null : onSend,
              decoration: const InputDecoration(
                hintText: 'Ask a question…',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: busy ? null : () => onSend(controller.text),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
