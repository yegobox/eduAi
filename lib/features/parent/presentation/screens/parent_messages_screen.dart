import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../application/parent_providers.dart';
import '../../domain/entities/parent_entities.dart';

/// A plain two-way thread with the class teacher.
class ParentMessagesScreen extends ConsumerStatefulWidget {
  const ParentMessagesScreen({super.key});

  @override
  ConsumerState<ParentMessagesScreen> createState() =>
      _ParentMessagesScreenState();
}

class _ParentMessagesScreenState extends ConsumerState<ParentMessagesScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(parentActionControllerProvider).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final messages = ref.watch(parentMessagesProvider);

    return Column(
      children: [
        Expanded(
          child: AsyncValueView<List<ParentMessage>>(
            value: messages,
            onRetry: () => ref.invalidate(parentMessagesProvider),
            isEmpty: (list) => list.isEmpty,
            emptyBuilder: () => Center(
              child: Text(
                'No messages yet. Say hello to the class teacher.',
                style: TextStyle(color: t.ink3),
              ),
            ),
            data: (list) => ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: list.length,
              itemBuilder: (_, i) => _Bubble(message: list[i]),
            ),
          ),
        ),
        _Composer(controller: _input, onSend: _send),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ParentMessage message;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final mine = message.fromParent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? t.brand : t.surfaceSunken,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mine ? 14 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 14),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: mine ? t.onBrand : t.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${message.from} · ${Formatters.relative(message.at)}',
            style: TextStyle(fontSize: 11, color: t.ink3),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('parent-message-field'),
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Message the class teacher…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('parent-message-send'),
                  onPressed: value.text.trim().isEmpty ? null : onSend,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
