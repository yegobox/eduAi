import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/app_platform_style.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import 'app_shell.dart';

/// Chrome for a pushed detail page (classroom, lesson reader, schools list).
///
/// Detail pages cover the tab bar on every platform — the back chevron is the
/// only way out, which is what the redesign specifies and what each native
/// platform does for a pushed view.
class DetailScaffold extends ConsumerWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.bottomBar,
    this.padded = true,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  /// Pinned footer (e.g. the lesson reader's "Mark as complete").
  final Widget? bottomBar;

  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final platform = ref.watch(appPlatformStyleProvider);
    return Scaffold(
      backgroundColor: t.surfaceAlt,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            platform.isApple ? Icons.arrow_back_ios_new : Icons.arrow_back,
            size: 18,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          tooltip: 'Back',
        ),
        title: Text(title, overflow: TextOverflow.ellipsis),
        centerTitle: platform == AppPlatformStyle.ios,
        actions: [...actions, const SizedBox(width: 8)],
      ),
      body: ShellContent(padded: padded, child: child),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                // heightFactor: 1 makes this bar hug its child. Without it the
                // Align expands to the whole window inside Scaffold's
                // bottomNavigationBar slot and the body is laid out at zero
                // height — the screen renders blank.
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kShellContentMaxWidth,
                    ),
                    child: bottomBar,
                  ),
                ),
              ),
            ),
    );
  }
}
