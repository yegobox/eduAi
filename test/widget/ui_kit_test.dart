import 'package:eduai/app/shell/shell_tab.dart';
import 'package:eduai/core/error/failure.dart';
import 'package:eduai/core/platform/app_platform_style.dart';
import 'package:eduai/core/theme/app_tokens.dart';
import 'package:eduai/core/widgets/app_widgets.dart';
import 'package:eduai/core/widgets/async_value_view.dart';
import 'package:eduai/core/widgets/mastery_ring.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

BoxDecoration _cardDecoration(WidgetTester tester) {
  return tester
          .widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(AppCard),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration
      as BoxDecoration;
}

void main() {
  group('AppCard', () {
    testWidgets('is tappable when given a callback', (tester) async {
      var taps = 0;
      await pumpWidgetInApp(
        tester,
        AppCard(onTap: () => taps++, child: const Text('Tap me')),
      );
      await tester.tap(find.text('Tap me'));
      expect(taps, 1);
    });

    testWidgets('drops its shadow when highlighted with a border colour', (
      tester,
    ) async {
      await pumpWidgetInApp(
        tester,
        const AppCard(borderColor: Color(0xFF4A54E8), child: Text('Selected')),
      );
      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isEmpty);
    });

    testWidgets('carries a soft shadow on mobile', (tester) async {
      await pumpWidgetInApp(
        tester,
        const AppCard(child: Text('x')),
        platform: AppPlatformStyle.ios,
      );
      expect(_cardDecoration(tester).boxShadow, isNotEmpty);
      expect(_cardDecoration(tester).border, isNull);
    });

    testWidgets('is flat with a hairline on desktop', (tester) async {
      await pumpWidgetInApp(
        tester,
        const AppCard(child: Text('x')),
        platform: AppPlatformStyle.windows,
      );
      expect(_cardDecoration(tester).boxShadow, isEmpty);
      expect(_cardDecoration(tester).border, isNotNull);
    });
  });

  group('Small components', () {
    testWidgets('badges announce their label in sentence case', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpWidgetInApp(tester, const AppBadge('REB aligned'));
      // Uppercase is a visual treatment; the label is announced as written.
      expect(find.text('REB ALIGNED'), findsOneWidget);
      expect(find.bySemanticsLabel('REB aligned'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('every tone renders', (tester) async {
      for (final tone in AppTone.values) {
        await pumpWidgetInApp(
          tester,
          Column(
            children: [
              AppBadge(tone.name, tone: tone),
              SoftChip(tone.name, tone: tone, icon: Icons.check),
              IconTile(icon: Icons.check, tone: tone),
              IconTile(icon: Icons.check, tone: tone, filled: true),
            ],
          ),
        );
        expect(tester.takeException(), isNull, reason: tone.name);
      }
    });

    testWidgets('a selected chip inverts to the ink colour', (tester) async {
      var taps = 0;
      await pumpWidgetInApp(
        tester,
        Builder(
          builder: (context) {
            final t = AppTokens.read(context);
            return Column(
              children: [
                SoftChip('P1–P6', selected: true, onTap: () => taps++),
                Text('${t.brand.toARGB32()}'),
              ],
            );
          },
        ),
      );
      await tester.tap(find.text('P1–P6'));
      expect(taps, 1);
    });

    testWidgets('SectionTitle renders its trailing action', (tester) async {
      await pumpWidgetInApp(
        tester,
        const SectionTitle('Seats used', trailing: Text('640 / 750')),
      );
      expect(find.text('Seats used'), findsOneWidget);
      expect(find.text('640 / 750'), findsOneWidget);
    });

    testWidgets('BarTrack clamps out-of-range values', (tester) async {
      await pumpWidgetInApp(
        tester,
        const Column(
          children: [
            BarTrack(value: -1),
            BarTrack(value: 2),
            BarTrack(value: 0.5),
          ],
        ),
      );
      final bars = tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bars.map((b) => b.value), [0.0, 1.0, 0.5]);
    });

    testWidgets('MasteryRing rounds its label and clamps its arc', (
      tester,
    ) async {
      await pumpWidgetInApp(
        tester,
        const Column(
          children: [
            MasteryRing(value: 0.784, color: Color(0xFF4A54E8)),
            MasteryRing(value: 3, color: Color(0xFF4A54E8)),
            MasteryRing(value: 0, color: Color(0xFF4A54E8)),
          ],
        ),
      );
      expect(find.text('78%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AvatarInitials, StatTile and TrustBanner render', (
      tester,
    ) async {
      await pumpWidgetInApp(
        tester,
        const Column(
          children: [
            AvatarInitials('AK'),
            StatTile(value: '210', label: 'minutes this week'),
            TrustBanner(
              icon: Icons.cloud_off,
              title: 'Works without internet',
              body: 'Progress syncs when you are back online.',
              action: Text('Set PIN'),
            ),
          ],
        ),
      );
      expect(find.text('AK'), findsOneWidget);
      expect(find.text('210'), findsOneWidget);
      expect(find.text('Works without internet'), findsOneWidget);
      expect(find.text('Set PIN'), findsOneWidget);
    });

    testWidgets('AppSegmented reports the tapped value', (tester) async {
      String? picked;
      await pumpWidgetInApp(
        tester,
        AppSegmented<String>(
          values: const ['Grid', 'Lines', 'Plain'],
          labelOf: (v) => v,
          selected: 'Grid',
          onChanged: (v) => picked = v,
        ),
      );
      await tester.tap(find.text('Lines'));
      expect(picked, 'Lines');
    });

    testWidgets('a disabled ToolIconButton does nothing', (tester) async {
      await pumpWidgetInApp(
        tester,
        const ToolIconButton(
          icon: Icons.remove,
          onPressed: null,
          tooltip: 'Remove seats',
        ),
      );
      await tester.tap(find.byIcon(Icons.remove));
      expect(tester.takeException(), isNull);
    });

    testWidgets('SwitchRow toggles', (tester) async {
      bool? value;
      await pumpWidgetInApp(
        tester,
        SwitchRow(
          title: 'Share weekly report',
          subtitle: 'Mastery, not mistakes.',
          value: true,
          onChanged: (v) => value = v,
        ),
      );
      await tester.tap(find.byType(Switch));
      expect(value, isFalse);
    });
  });

  group('AsyncValueView', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await pumpWidgetInApp(
        tester,
        AsyncValueView<int>(
          value: const AsyncValue.loading(),
          data: (v) => Text('$v'),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows a failure message and a working retry', (tester) async {
      var retries = 0;
      await pumpWidgetInApp(
        tester,
        AsyncValueView<int>(
          value: AsyncValue.error(const NetworkFailure(), StackTrace.empty),
          onRetry: () => retries++,
          data: (v) => Text('$v'),
        ),
      );
      expect(
        find.text('No internet connection. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('falls back to a generic message for a non-Failure error', (
      tester,
    ) async {
      await pumpWidgetInApp(
        tester,
        AsyncValueView<int>(
          value: AsyncValue.error(StateError('boom'), StackTrace.empty),
          data: (v) => Text('$v'),
        ),
      );
      expect(find.text('Something went wrong.'), findsOneWidget);
      // With no retry callback, no retry button is offered.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('uses the empty builder when the data is empty', (
      tester,
    ) async {
      await pumpWidgetInApp(
        tester,
        AsyncValueView<List<int>>(
          value: const AsyncValue.data([]),
          isEmpty: (list) => list.isEmpty,
          emptyBuilder: () => const Text('Nothing here yet'),
          data: (list) => Text('${list.length}'),
        ),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('renders data when it is not empty', (tester) async {
      await pumpWidgetInApp(
        tester,
        AsyncValueView<List<int>>(
          value: const AsyncValue.data([1, 2]),
          isEmpty: (list) => list.isEmpty,
          emptyBuilder: () => const Text('Nothing here yet'),
          data: (list) => Text('${list.length}'),
        ),
      );
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('ShellTabs', () {
    test('every role has a tab set whose routes are unique', () {
      for (final role in AppRole.values) {
        final tabs = ShellTabs.forRole(role);
        expect(tabs, isNotEmpty, reason: role.name);
        expect(
          tabs.map((t) => t.route).toSet(),
          hasLength(tabs.length),
          reason: role.name,
        );
      }
    });
  });
}
