import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/schools_action_controller.dart';

/// Prompt for a join code and enrol the user. Returns true on success.
Future<bool> showJoinByCodeDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const _JoinByCodeDialog(),
  );
  return ok ?? false;
}

/// Create a new school. Returns true on success.
Future<bool> showCreateSchoolDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const _CreateSchoolDialog(),
  );
  return ok ?? false;
}

/// Create a new class within [schoolId]. Returns true on success.
Future<bool> showCreateClassDialog(
  BuildContext context,
  String schoolId,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _CreateClassDialog(schoolId: schoolId),
  );
  return ok ?? false;
}

// ─────────────────────────────────────────────────────────────────────────

class _JoinByCodeDialog extends ConsumerStatefulWidget {
  const _JoinByCodeDialog();
  @override
  ConsumerState<_JoinByCodeDialog> createState() => _JoinByCodeDialogState();
}

class _JoinByCodeDialogState extends ConsumerState<_JoinByCodeDialog> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await ref
        .read(schoolsActionControllerProvider.notifier)
        .joinByCode(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join with a code'),
      content: TextField(
        controller: _code,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Join code',
          hintText: 'e.g. MATH5',
        ),
        onSubmitted: (_) => _busy ? null : _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const _MiniSpinner() : const Text('Join'),
        ),
      ],
    );
  }
}

class _CreateSchoolDialog extends ConsumerStatefulWidget {
  const _CreateSchoolDialog();
  @override
  ConsumerState<_CreateSchoolDialog> createState() =>
      _CreateSchoolDialogState();
}

class _CreateSchoolDialogState extends ConsumerState<_CreateSchoolDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result =
        await ref.read(schoolsActionControllerProvider.notifier).createSchool(
              name: _name.text,
              description: _desc.text,
              joinCode: _code.text,
            );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a school'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'School name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            decoration:
                const InputDecoration(labelText: 'Description (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration:
                const InputDecoration(labelText: 'Join code (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const _MiniSpinner() : const Text('Create'),
        ),
      ],
    );
  }
}

class _CreateClassDialog extends ConsumerStatefulWidget {
  const _CreateClassDialog({required this.schoolId});
  final String schoolId;
  @override
  ConsumerState<_CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends ConsumerState<_CreateClassDialog> {
  final _name = TextEditingController();
  final _grade = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _grade.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result =
        await ref.read(schoolsActionControllerProvider.notifier).createClass(
              schoolId: widget.schoolId,
              name: _name.text,
              grade: _grade.text,
              joinCode: _code.text,
            );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a class'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Class name',
              hintText: 'e.g. Primary 5 — Mathematics',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _grade,
            decoration:
                const InputDecoration(labelText: 'Grade / level (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration:
                const InputDecoration(labelText: 'Join code (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const _MiniSpinner() : const Text('Add'),
        ),
      ],
    );
  }
}

class _MiniSpinner extends StatelessWidget {
  const _MiniSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
