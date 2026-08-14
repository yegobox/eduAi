import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Semantic colour roles shared by badges, chips and icon tiles.
enum AppTone { brand, success, warning, danger, neutral }

extension AppToneColors on AppTone {
  Color foreground(AppTokens t) => switch (this) {
    AppTone.brand => t.brand,
    AppTone.success => t.success,
    AppTone.warning => t.warning,
    AppTone.danger => t.danger,
    AppTone.neutral => t.ink3,
  };

  Color background(AppTokens t) => switch (this) {
    AppTone.brand => t.brandSoft,
    AppTone.success => t.successSoft,
    AppTone.warning => t.warningSoft,
    AppTone.danger => t.dangerSoft,
    AppTone.neutral => t.surfaceSunken,
  };
}

/// The redesign's surface card: platform radius, flat + hairline on desktop,
/// soft double shadow on mobile.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  /// Overrides the hairline colour (used to highlight a selected plan card).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final showBorder = borderColor != null || t.flatCards;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: t.cardBorderRadius,
        border: showBorder
            ? Border.all(color: borderColor ?? t.border, width: 1)
            : null,
        boxShadow: borderColor != null ? const [] : t.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.cardBorderRadius,
        child: content,
      ),
    );
  }
}

/// A recessed panel — the `card-flat` style (sunken fill, no shadow).
class SunkenCard extends StatelessWidget {
  const SunkenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.surfaceSunken,
        borderRadius: t.cardBorderRadius,
      ),
      child: child,
    );
  }
}

/// The rounded-square icon container used in list rows, banners and headers.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tone = AppTone.brand,
    this.size = 38,
    this.iconSize = 18,
    this.filled = false,
  });

  final IconData icon;
  final AppTone tone;
  final double size;
  final double iconSize;

  /// Inverts the tile: solid tone background with on-brand glyph.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? tone.foreground(t) : tone.background(t),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: filled ? t.onBrand : tone.foreground(t),
      ),
    );
  }
}

/// Section heading — H2 scale, bold, tight tracking.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final label = Text(
      text,
      style: TextStyle(
        fontSize: t.h2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: t.ink,
      ),
    );
    if (trailing == null) return label;
    return Row(
      children: [
        Expanded(child: label),
        trailing!,
      ],
    );
  }
}

/// Small uppercase status badge (`REB aligned`, `Paid`, `Current`).
class AppBadge extends StatelessWidget {
  const AppBadge(this.text, {super.key, this.tone = AppTone.brand});

  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.background(t),
        borderRadius: BorderRadius.circular(6),
      ),
      // The uppercase is a visual treatment only — screen readers announce the
      // label as written, so "REB aligned" isn't spelled out letter by letter.
      child: Semantics(
        label: text,
        excludeSemantics: true,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: tone.foreground(t),
          ),
        ),
      ),
    );
  }
}

/// Pill chip. Tappable when [onTap] is given.
class SoftChip extends StatelessWidget {
  const SoftChip(
    this.label, {
    super.key,
    this.icon,
    this.tone = AppTone.neutral,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final AppTone tone;
  final VoidCallback? onTap;

  /// Selected chips invert to the ink colour (the Lessons grade filter).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final fg = selected ? t.surface : tone.foreground(t);
    final bg = selected ? t.ink : tone.background(t);
    final body = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: body,
    );
  }
}

/// A bordered, tappable suggestion chip (tutor sample prompts / follow-ups).
class PromptChip extends StatelessWidget {
  const PromptChip(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: t.ink,
          ),
        ),
      ),
    );
  }
}

/// Circular tool / action button. `active` fills it with the brand tint.
class ToolIconButton extends StatelessWidget {
  const ToolIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.tooltip,
    this.tone = AppTone.brand,
    this.size = 36,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final String? tooltip;
  final AppTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? tone.background(t) : t.surfaceSunken,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            icon,
            size: size * 0.47,
            color: active ? tone.foreground(t) : t.ink2,
          ),
        ),
      ),
    );
  }
}

/// One of the sunken number tiles on Parent Overview / Admin Usage.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return SunkenCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: t.ink3)),
        ],
      ),
    );
  }
}

/// Brand-soft reassurance banner (offline PIN nudge, "works without
/// internet", "included in your school's plan").
class TrustBanner extends StatelessWidget {
  const TrustBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.brandSoft,
        borderRadius: t.cardBorderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, filled: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 13, color: t.ink2)),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// Rounded horizontal progress bar (`bar-track` / `bar-fill`).
class BarTrack extends StatelessWidget {
  const BarTrack({super.key, required this.value, this.color, this.height = 8});

  /// 0..1; values outside are clamped rather than overflowing the track.
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: t.surfaceSunken,
          valueColor: AlwaysStoppedAnimation(color ?? t.brand),
        ),
      ),
    );
  }
}

/// Initials avatar used by the parent child-switcher and message threads.
class AvatarInitials extends StatelessWidget {
  const AvatarInitials(this.initials, {super.key, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.375,
          color: t.brand,
        ),
      ),
    );
  }
}

/// Compact segmented control (workbook guide switch, desktop section tabs).
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: t.controlBorderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in values)
            InkWell(
              onTap: () => onChanged(v),
              borderRadius: BorderRadius.circular(t.controlRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: v == selected ? t.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    (t.controlRadius - 3).clamp(0, 999),
                  ),
                ),
                child: Text(
                  labelOf(v),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: v == selected ? t.ink : t.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A labelled row with a trailing switch — the Progress share toggle shape.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: t.ink3)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
