import 'package:flutter/material.dart';

/// Calendar heatmap of daily study activity — one cell per day, weeks running
/// left to right, weekdays top to bottom.
///
/// Magnitude gets a **sequential** encoding: a single hue stepped light→dark
/// (alpha over the chart surface), never a rainbow. Empty days are a recessive
/// surface tone rather than step 0 of the ramp, so "did nothing" never reads as
/// "did a little". Each cell carries a tooltip and a semantic label, so the
/// count is never conveyed by colour alone.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.dailyCounts,
    this.today,
  });

  /// Date (local midnight) → events that day.
  final Map<DateTime, int> dailyCounts;

  /// Injectable for tests; defaults to now.
  final DateTime? today;

  static const _cell = 14.0;
  static const _gap = 2.0;
  static const _rowLabelWidth = 28.0;
  // A floor low enough that the grid still fits on any real phone width; the
  // week count is otherwise driven purely by available space.
  static const _minWeeks = 4;
  static const _maxWeeks = 26;

  @override
  Widget build(BuildContext context) {
    final now = _dateOnly(today ?? DateTime.now());
    // Anchor the last column to the week containing today, so "today" is
    // always in the rightmost column.
    final lastWeekStart = now.subtract(Duration(days: now.weekday - 1));

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _rowLabelWidth;
        final weeks = ((available + _gap) / (_cell + _gap))
            .floor()
            .clamp(_minWeeks, _maxWeeks);
        final firstWeekStart =
            lastWeekStart.subtract(Duration(days: (weeks - 1) * 7));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthLabels(firstWeekStart: firstWeekStart, weeks: weeks),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WeekdayLabels(),
                for (var w = 0; w < weeks; w++)
                  Padding(
                    padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : _gap),
                    child: _WeekColumn(
                      weekStart: firstWeekStart.add(Duration(days: w * 7)),
                      today: now,
                      dailyCounts: dailyCounts,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const _ScaleLegend(),
          ],
        );
      },
    );
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.weekStart,
    required this.today,
    required this.dailyCounts,
  });

  final DateTime weekStart;
  final DateTime today;
  final Map<DateTime, int> dailyCounts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var d = 0; d < 7; d++)
          Padding(
            padding: EdgeInsets.only(bottom: d == 6 ? 0 : ActivityHeatmap._gap),
            child: _DayCell(
              date: weekStart.add(Duration(days: d)),
              today: today,
              dailyCounts: dailyCounts,
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.dailyCounts,
  });

  final DateTime date;
  final DateTime today;
  final Map<DateTime, int> dailyCounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFuture = date.isAfter(today);
    final count = dailyCounts[date] ?? 0;

    // Future days in the current week are placeholders, not empty days.
    if (isFuture) {
      return const SizedBox.square(dimension: ActivityHeatmap._cell);
    }

    final label = count == 0
        ? 'No activity on ${_formatDate(date)}'
        : '$count ${count == 1 ? 'activity' : 'activities'} on ${_formatDate(date)}';

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 300),
      child: Semantics(
        label: label,
        child: Container(
          width: ActivityHeatmap._cell,
          height: ActivityHeatmap._cell,
          decoration: BoxDecoration(
            color: heatColor(scheme, count),
            borderRadius: BorderRadius.circular(3),
            // Ring today so the "now" edge of the range is findable.
            border: date == today
                ? Border.all(color: scheme.onSurfaceVariant, width: 1)
                : null,
          ),
        ),
      ),
    );
  }
}

/// The sequential ramp: one hue, stepped by intensity. Exposed so the legend
/// and the cells can never drift apart.
Color heatColor(ColorScheme scheme, int count) {
  if (count <= 0) return scheme.surfaceContainerHighest;
  final alpha = switch (count) {
    <= 2 => 0.30,
    <= 5 => 0.55,
    <= 9 => 0.78,
    _ => 1.0,
  };
  return scheme.primary.withValues(alpha: alpha);
}

class _ScaleLegend extends StatelessWidget {
  const _ScaleLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Label text wears ink tokens, never the ramp colour.
    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: style),
        const SizedBox(width: 6),
        for (final count in const [0, 1, 3, 6, 12])
          Padding(
            padding: const EdgeInsets.only(right: ActivityHeatmap._gap),
            child: Container(
              width: ActivityHeatmap._cell,
              height: ActivityHeatmap._cell,
              decoration: BoxDecoration(
                color: heatColor(scheme, count),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text('More', style: style),
      ],
    );
  }
}

class _WeekdayLabels extends StatelessWidget {
  const _WeekdayLabels();

  // Sparse labels: a name on every row is noise at this cell size.
  static const _labels = ['Mon', '', 'Wed', '', 'Fri', '', ''];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 9,
    );

    return SizedBox(
      width: ActivityHeatmap._rowLabelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var d = 0; d < 7; d++)
            Padding(
              padding:
                  EdgeInsets.only(bottom: d == 6 ? 0 : ActivityHeatmap._gap),
              child: SizedBox(
                height: ActivityHeatmap._cell,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_labels[d], style: style),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({required this.firstWeekStart, required this.weeks});

  final DateTime firstWeekStart;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 9,
    );

    var previousMonth = -1;
    final cells = <Widget>[];
    for (var w = 0; w < weeks; w++) {
      final start = firstWeekStart.add(Duration(days: w * 7));
      // Label a column only where the month changes.
      final show = start.month != previousMonth;
      previousMonth = start.month;
      cells.add(
        Padding(
          padding: EdgeInsets.only(
            right: w == weeks - 1 ? 0 : ActivityHeatmap._gap,
          ),
          child: SizedBox(
            width: ActivityHeatmap._cell,
            child: show
                ? Text(
                    _monthNames[start.month - 1],
                    style: style,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  )
                : null,
          ),
        ),
      );
    }

    return Row(
      children: [
        const SizedBox(width: ActivityHeatmap._rowLabelWidth),
        ...cells,
      ],
    );
  }
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdayNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _formatDate(DateTime d) =>
    '${_weekdayNames[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1]}';
