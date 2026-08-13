import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Max width for tutor content on wide windows. Full-bleed chat lines are
/// hard to read on a desktop display, so both the transcript and the composer
/// stay inside this.
const tutorMaxContentWidth = 760.0;

/// The tutor's question box.
///
/// Enter sends, Shift+Enter starts a new line. The Enter handler lives on the
/// field's own [FocusNode] rather than an ancestor `Shortcuts`, because
/// `WidgetsApp` installs `DefaultTextEditingShortcuts` at the app root and
/// that binds bare Enter to `DoNothingAndStopPropagationTextIntent` — an
/// ancestor would never see the key. Key events travel from the focused node
/// outward, so a handler on this node runs first.
class TutorComposer extends StatefulWidget {
  const TutorComposer({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;

  /// An answer is in flight. The field stays editable — only sending is
  /// blocked — so the next question can be typed while waiting.
  final bool busy;

  final ValueChanged<String> onSend;

  @override
  State<TutorComposer> createState() => _TutorComposerState();
}

class _TutorComposerState extends State<TutorComposer> {
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'tutor-composer',
    onKeyEvent: _onKeyEvent,
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy) return;
    final text = widget.controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    // Sending otherwise drops the caret, forcing a click before the next
    // question.
    _focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;

    // Shift+Enter falls through to the field and inserts a newline.
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;

    _submit();
    // Swallow it either way: a bare Enter should never leave a stray newline
    // behind, even when the field is empty or an answer is still in flight.
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: tutorMaxContentWidth),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  final canSend = !widget.busy && value.text.trim().isNotEmpty;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _buildField(context)),
                      const SizedBox(width: 8),
                      _SendButton(
                        enabled: canSend,
                        busy: widget.busy,
                        onPressed: _submit,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(22);

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: true,
      minLines: 1,
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      // Soft keyboards surface a "send" key and route it here; the hardware
      // Enter path goes through [_onKeyEvent] instead.
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: 'Ask a question…',
        helperText: 'Enter to send · Shift+Enter for a new line',
        helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: border(Colors.transparent, 0),
        enabledBorder: border(Colors.transparent, 0),
        focusedBorder: border(scheme.primary, 1.5),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Sits above the helper text so the button lines up with the field.
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: busy
          ? const SizedBox.square(
              dimension: 40,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : IconButton.filled(
              tooltip: 'Send (Enter)',
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
    );
  }
}
