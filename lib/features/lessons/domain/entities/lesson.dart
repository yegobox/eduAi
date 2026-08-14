import 'package:equatable/equatable.dart';

/// The REB grade bands the catalog is filtered by.
enum GradeBand {
  prePrimary('Pre-primary'),
  primary('P1–P6'),
  oLevel('O-Level'),
  aLevel('A-Level'),
  examPrep('Exam prep');

  const GradeBand(this.label);

  final String label;

  static GradeBand fromLabel(String? label) => GradeBand.values.firstWhere(
    (b) => b.label == label,
    orElse: () => GradeBand.primary,
  );
}

/// One curriculum lesson in the offline-first library.
class Lesson extends Equatable {
  const Lesson({
    required this.id,
    required this.title,
    required this.subject,
    required this.band,
    required this.body,
    this.rebAligned = true,
    this.downloaded = false,
    this.completed = false,
  });

  final String id;
  final String title;

  /// Display subject ("Mathematics", "Biology"…). Free text so a school can
  /// add its own without a schema migration.
  final String subject;

  final GradeBand band;

  /// Reading-width paragraphs. Bundled with the app so a downloaded lesson
  /// opens with no network at all.
  final List<String> body;

  final bool rebAligned;

  /// Kept in the on-device cache for offline reading.
  final bool downloaded;

  /// Marked complete by the student; feeds the Progress screen.
  final bool completed;

  Lesson copyWith({bool? downloaded, bool? completed}) => Lesson(
    id: id,
    title: title,
    subject: subject,
    band: band,
    body: body,
    rebAligned: rebAligned,
    downloaded: downloaded ?? this.downloaded,
    completed: completed ?? this.completed,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    subject,
    band,
    body,
    rebAligned,
    downloaded,
    completed,
  ];
}
