import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/app_platform_style.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import 'more_menu.dart';
import 'shell_tab.dart';
import 'status_chip.dart';

/// Maximum reading width for screen content on wide windows.
const double kShellContentMaxWidth = 900;

/// The adaptive chrome around every tabbed screen.
///
/// One shared widget tree per feature; only the *navigation chrome* changes
/// per platform — iOS large title + bottom tab bar, Android app bar + M3
/// navigation bar, macOS toolbar with a centred segmented control, Windows
/// title strip + underline pivot tabs.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.tabs,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  void _goBranch(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(appPlatformStyleProvider);
    final title = tabs[navigationShell.currentIndex].label;

    // A phone-width window gets the mobile chrome even under a desktop design
    // language: a title, a tab strip and the status actions do not fit on one
    // toolbar row, and tabs at the bottom are what a narrow window expects.
    if (isCompactChrome(context)) {
      return platform.isApple
          ? _IosShell(
              title: title,
              tabs: tabs,
              index: navigationShell.currentIndex,
              onTab: _goBranch,
              child: navigationShell,
            )
          : _AndroidShell(
              title: title,
              tabs: tabs,
              index: navigationShell.currentIndex,
              onTab: _goBranch,
              child: navigationShell,
            );
    }

    return switch (platform) {
      AppPlatformStyle.ios => _IosShell(
        title: title,
        tabs: tabs,
        index: navigationShell.currentIndex,
        onTab: _goBranch,
        child: navigationShell,
      ),
      AppPlatformStyle.android => _AndroidShell(
        title: title,
        tabs: tabs,
        index: navigationShell.currentIndex,
        onTab: _goBranch,
        child: navigationShell,
      ),
      AppPlatformStyle.macos => _MacShell(
        title: title,
        tabs: tabs,
        index: navigationShell.currentIndex,
        onTab: _goBranch,
        child: navigationShell,
      ),
      AppPlatformStyle.windows => _WindowsShell(
        title: title,
        tabs: tabs,
        index: navigationShell.currentIndex,
        onTab: _goBranch,
        child: navigationShell,
      ),
    };
  }
}

/// Constrains screen content to a comfortable reading width and applies the
/// platform's page padding. Every screen body is wrapped in this by the shell.
class ShellContent extends ConsumerWidget {
  const ShellContent({super.key, required this.child, this.padded = true});

  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(appPlatformStyleProvider);
    final roomy = platform.isDesktop && !isCompactChrome(context);
    final pad = padded
        ? (roomy
              ? const EdgeInsets.fromLTRB(26, 8, 26, 24)
              : const EdgeInsets.fromLTRB(16, 4, 16, 20))
        : EdgeInsets.zero;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kShellContentMaxWidth),
        child: Padding(padding: pad, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------- iOS ------

class _IosShell extends ConsumerWidget {
  const _IosShell({
    required this.title,
    required this.tabs,
    required this.index,
    required this.onTab,
    required this.child,
  });

  final String title;
  final List<ShellTab> tabs;
  final int index;
  final ValueChanged<int> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    return Scaffold(
      backgroundColor: t.surfaceAlt,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.h1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: t.ink,
                      ),
                    ),
                  ),
                  const _TrailingActions(),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _IosTabBar(tabs: tabs, index: index, onTab: onTab),
    );
  }
}

class _IosTabBar extends StatelessWidget {
  const _IosTabBar({
    required this.tabs,
    required this.index,
    required this.onTab,
  });

  final List<ShellTab> tabs;
  final int index;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTab(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tabs[i].icon,
                          size: 22,
                          color: i == index ? t.brand : t.ink3,
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            tabs[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: i == index ? t.brand : t.ink3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Android ------

class _AndroidShell extends StatelessWidget {
  const _AndroidShell({
    required this.title,
    required this.tabs,
    required this.index,
    required this.onTab,
    required this.child,
  });

  final String title;
  final List<ShellTab> tabs;
  final int index;
  final ValueChanged<int> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Scaffold(
      backgroundColor: t.surfaceAlt,
      appBar: AppBar(
        title: Text(title, style: TextStyle(fontSize: 22, color: t.ink)),
        centerTitle: false,
        actions: const [_TrailingActions(), SizedBox(width: 8)],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTab,
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- macOS ------

class _MacShell extends StatelessWidget {
  const _MacShell({
    required this.title,
    required this.tabs,
    required this.index,
    required this.onTab,
    required this.child,
  });

  final String title;
  final List<ShellTab> tabs;
  final int index;
  final ValueChanged<int> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Scaffold(
      backgroundColor: t.surfaceAlt,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  // Bounded, not Expanded: the title takes what it needs and
                  // gives the rest of the row to the tabs.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.h2,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Centred while the segments fit, scrollable once a role has
                  // more tabs than the window is wide — never an overflow.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Center(
                            child: AppSegmented<int>(
                              values: [for (var i = 0; i < tabs.length; i++) i],
                              labelOf: (i) => tabs[i].label,
                              selected: index,
                              onChanged: onTab,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _TrailingActions(compact: true),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Windows ------

class _WindowsShell extends StatelessWidget {
  const _WindowsShell({
    required this.title,
    required this.tabs,
    required this.index,
    required this.onTab,
    required this.child,
  });

  final String title;
  final List<ShellTab> tabs;
  final int index;
  final ValueChanged<int> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Scaffold(
      backgroundColor: t.surfaceAlt,
      body: Column(
        children: [
          // App identity strip. The window's minimise / maximise / close
          // buttons are drawn by Windows itself — painting fake ones here
          // would give the user controls that do nothing.
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.brand,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.auto_awesome, size: 11, color: t.onBrand),
                ),
                const SizedBox(width: 8),
                Text(
                  'EduAI',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
          // Fluent "Pivot" tab strip.
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Row(
              children: [
                // The pivot strip scrolls rather than overflowing when the
                // window is narrower than the role's tab set.
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: _PivotTab(
                              tab: tabs[i],
                              selected: i == index,
                              onTap: () => onTab(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const _TrailingActions(compact: true),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PivotTab extends StatelessWidget {
  const _PivotTab({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final color = selected ? t.ink : t.ink2;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? t.brand : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- shared ------

class _TrailingActions extends ConsumerWidget {
  const _TrailingActions({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        compact ? const StatusDot() : const StatusChip(),
        const SizedBox(width: 8),
        ToolIconButton(
          icon: Icons.more_vert,
          tooltip: 'More',
          size: compact ? 28 : 36,
          onPressed: () => showMoreMenu(context, ref),
        ),
      ],
    );
  }
}
