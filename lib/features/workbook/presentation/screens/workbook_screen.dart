import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/ink/ink_canvas.dart';
import '../../../../core/ink/ink_stroke.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../access/application/access_providers.dart';
import '../../application/workbook_controller.dart';
import '../../domain/entities/workbook_feedback.dart';

/// A full stylus notebook: three pages, pen / highlighter / eraser, guide
/// ruling, undo-redo, and an AI check of the working on the current page.
class WorkbookScreen extends ConsumerStatefulWidget {
  const WorkbookScreen({super.key});

  @override
  ConsumerState<WorkbookScreen> createState() => _WorkbookScreenState();
}

class _WorkbookScreenState extends ConsumerState<WorkbookScreen> {
  final _canvasKey = GlobalKey();

  /// The check needs the canvas' real size to rasterise at the same scale the
  /// student drew at.
  Size get _canvasSize {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size ?? const Size(600, 400);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final state = ref.watch(workbookControllerProvider);
    final controller = ref.read(workbookControllerProvider.notifier);

    return ShellContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SectionTitle('Workbook')),
              for (var p = 0; p < kWorkbookPageCount; p++)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _PageTab(
                    index: p,
                    selected: p == state.page,
                    onTap: () => controller.selectPage(p),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _Toolbar(),
          const SizedBox(height: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: t.cardBorderRadius,
                boxShadow: t.cardShadow,
                border: t.flatCards ? Border.all(color: t.border) : null,
              ),
              child: InkCanvas(
                key: _canvasKey,
                controller: controller.pageAt(state.page),
                tool: state.tool,
                color: state.color,
                guide: state.guide,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _CheckSection(canvasSize: () => _canvasSize),
        ],
      ),
    );
  }
}

class _PageTab extends StatelessWidget {
  const _PageTab({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: selected ? t.brand : t.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? t.brand : t.ink2,
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final state = ref.watch(workbookControllerProvider);
    final controller = ref.read(workbookControllerProvider.notifier);

    Widget divider() => Container(width: 1, height: 24, color: t.border);

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tool in InkTool.values)
          _ToolButton(
            icon: switch (tool) {
              InkTool.pen => Icons.edit_outlined,
              InkTool.highlighter => Icons.brush_outlined,
              InkTool.eraser => Icons.auto_fix_normal_outlined,
            },
            label: tool.name,
            selected: state.tool == tool,
            onTap: () => controller.selectTool(tool),
          ),
        divider(),
        for (final color in kWorkbookColors)
          _Swatch(
            color: color,
            // Colour only applies to the pen, so the swatches read as
            // disabled while another tool is active.
            enabled: state.tool == InkTool.pen,
            selected: state.color == color && state.tool == InkTool.pen,
            onTap: () => controller.selectColor(color),
          ),
        divider(),
        AppSegmented<InkGuide>(
          values: InkGuide.values,
          labelOf: (g) => g.label,
          selected: state.guide,
          onChanged: controller.selectGuide,
        ),
        divider(),
        ToolIconButton(
          icon: Icons.undo,
          tooltip: 'Undo',
          onPressed: controller.undo,
        ),
        ToolIconButton(
          icon: Icons.redo,
          tooltip: 'Redo',
          onPressed: controller.redo,
        ),
        ToolIconButton(
          icon: Icons.delete_outline,
          tooltip: 'Clear page',
          onPressed: controller.clear,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? t.brand : t.surfaceSunken,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: selected ? t.onBrand : t.ink2),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final InkColor color;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final brightness = t.isDark ? Brightness.dark : Brightness.light;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        selected: selected,
        label: color.label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          // The ring sits outside the fill rather than on its edge: graphite
          // is near-white in dark mode, so an ink-coloured ring drawn on the
          // swatch itself would disappear into it.
          child: Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.brand : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.resolve(brightness),
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckSection extends ConsumerWidget {
  const _CheckSection({required this.canvasSize});

  final Size Function() canvasSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final state = ref.watch(workbookControllerProvider);
    final controller = ref.read(workbookControllerProvider.notifier);
    final hasAiAccess = ref.watch(hasPaidAccessProvider);

    if (state.feedback != null) {
      final feedback = state.feedback!;
      // A found mistake in a green success card reads as "well done" at a
      // glance, which is the opposite of what the student was told.
      final (tone, wash, icon) = switch (feedback.status) {
        WorkbookVerdictStatus.correct => (
          t.success,
          t.successSoft,
          Icons.check_circle_outline,
        ),
        WorkbookVerdictStatus.mistake => (
          t.warning,
          t.warningSoft,
          Icons.flag_outlined,
        ),
        WorkbookVerdictStatus.unclear => (
          t.ink2,
          t.surfaceSunken,
          Icons.help_outline,
        ),
      };
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feedback.verdict,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: t.ink,
                    ),
                  ),
                  if (feedback.tip.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      feedback.tip,
                      style: TextStyle(fontSize: 13, color: t.ink2),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: controller.dismissFeedback,
              tooltip: 'Dismiss',
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.failure!.message,
              style: TextStyle(fontSize: 13, color: t.danger),
            ),
          ),
        // The canvas itself is never gated — a student keeps writing, keeps
        // their pages, and keeps undo. Only the AI call costs money, so only
        // the AI call waits for a licence.
        if (!hasAiAccess)
          Text(
            'AI checking is paused until the licence is paid. Your pages are '
            'saved and nothing is lost.',
            style: TextStyle(fontSize: 12.5, color: t.ink3),
          )
        else
          FilledButton.icon(
            onPressed: state.checking
                ? null
                : () => controller.checkWork(canvasSize()),
            icon: state.checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              state.checking ? 'Checking…' : 'Ask AI to check my work',
            ),
          ),
      ],
    );
  }
}
