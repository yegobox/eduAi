import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/failure.dart';

/// Renders an [AsyncValue] with consistent loading, error (with retry) and
/// data states. Keeps every screen from re-implementing the same three cases.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.emptyBuilder,
    this.isEmpty,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;

  /// Optional empty-state override; used when [isEmpty] returns true.
  final Widget Function()? emptyBuilder;
  final bool Function(T value)? isEmpty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorState(
        message: err is Failure ? err.message : 'Something went wrong.',
        onRetry: onRetry,
      ),
      data: (value) {
        if (emptyBuilder != null && (isEmpty?.call(value) ?? false)) {
          return emptyBuilder!();
        }
        return data(value);
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
