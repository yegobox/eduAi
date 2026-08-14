import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../application/parent_providers.dart';
import '../../domain/entities/parent_entities.dart';

/// Horizontal pill tabs for parents with more than one enrolled child.
///
/// Hidden entirely for a single child — a switcher with one option is noise.
class ChildSwitcher extends ConsumerWidget {
  const ChildSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentChildrenProvider).valueOrNull ?? const [];
    if (children.length < 2) return const SizedBox.shrink();

    final selected = ref.watch(selectedChildProvider);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(
          child: _ChildTab(
            child: children[i],
            selected: children[i].id == selected?.id,
            onTap: () => ref.read(selectedChildIdProvider.notifier).state =
                children[i].id,
          ),
        ),
      ),
    );
  }
}

class _ChildTab extends StatelessWidget {
  const _ChildTab({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Child child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: selected ? t.brandSoft : t.surface,
          border: Border.all(color: selected ? t.brand : t.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarInitials(child.initials, size: 28),
            const SizedBox(width: 8),
            Text(
              child.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? t.brand : t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
