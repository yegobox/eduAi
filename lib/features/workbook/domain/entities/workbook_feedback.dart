import 'package:equatable/equatable.dart';

/// How the checker judged the page. Drives the feedback card's tone, so a
/// value the backend doesn't recognise — or an older build that sends none —
/// lands on [unclear] rather than claiming the work is right.
enum WorkbookVerdictStatus {
  correct,
  mistake,
  unclear;

  static WorkbookVerdictStatus fromJson(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'correct' => WorkbookVerdictStatus.correct,
      'mistake' => WorkbookVerdictStatus.mistake,
      _ => WorkbookVerdictStatus.unclear,
    };
  }
}

/// Short structured feedback on a page of handwritten working.
///
/// Deliberately two fields plus a status: a one-line verdict and exactly one
/// actionable tip. The same tone as the tutor's `check` block — encouraging,
/// specific, and never a list of everything that went wrong.
class WorkbookFeedback extends Equatable {
  const WorkbookFeedback({
    required this.verdict,
    required this.tip,
    this.status = WorkbookVerdictStatus.unclear,
  });

  final String verdict;
  final String tip;
  final WorkbookVerdictStatus status;

  factory WorkbookFeedback.fromJson(Map<String, dynamic> json) {
    return WorkbookFeedback(
      verdict: json['verdict'] as String? ?? 'I had a look at your working.',
      tip: json['tip'] as String? ?? '',
      status: WorkbookVerdictStatus.fromJson(json['status']),
    );
  }

  @override
  List<Object?> get props => [verdict, tip, status];
}
