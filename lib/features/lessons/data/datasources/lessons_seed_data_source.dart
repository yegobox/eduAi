import '../../domain/entities/lesson.dart';

/// The bundled REB-aligned catalog.
///
/// Shipping the catalog with the binary is deliberate: a student on a school
/// Wi-Fi that drops at 10am must still be able to open Lessons. A remote
/// source can later be layered in front of this without changing the
/// repository contract — the seed then becomes the fallback.
class LessonsSeedDataSource {
  const LessonsSeedDataSource();

  List<Lesson> catalog() => const [
    Lesson(
      id: 'l1',
      title: 'Fractions: adding like denominators',
      subject: 'Mathematics',
      band: GradeBand.primary,
      body: [
        'Fractions with the same denominator share equal-sized parts of a '
            'whole — so adding them only means adding the numerators.',
        'For example, 2/5 + 1/5 = 3/5. The denominator (5) stays the same '
            'because the pieces are the same size; only count how many '
            'pieces you have.',
        'Try it: 3/8 + 2/8 = ? Write your working in the margin and check '
            'it against the worked example.',
      ],
    ),
    Lesson(
      id: 'l2',
      title: 'Building compound sentences',
      subject: 'English',
      band: GradeBand.primary,
      body: [
        'A compound sentence joins two complete ideas with a conjunction '
            'such as and, but, or so.',
        '"I finished my homework" and "I went outside" become "I finished '
            'my homework, so I went outside." Each half could still stand '
            'on its own.',
        'Watch the comma: it goes before the joining word, not after it.',
      ],
    ),
    Lesson(
      id: 'l3',
      title: 'The water cycle',
      subject: 'Science',
      band: GradeBand.primary,
      body: [
        'Water moves in a loop: evaporation lifts it into the air, '
            'condensation forms clouds, precipitation returns it as rain, '
            'and collection gathers it in rivers and lakes.',
        'The sun powers the whole cycle. Without that energy, water would '
            'never leave the lake surface.',
      ],
    ),
    Lesson(
      id: 'l4',
      title: 'Cell structure & function',
      subject: 'Biology',
      band: GradeBand.oLevel,
      body: [
        'Every living thing is built from cells. Plant and animal cells '
            'share a membrane, cytoplasm and a nucleus; only plant cells '
            'add a cell wall, chloroplasts and a large vacuole.',
        'Structure follows function: a root hair cell is long and thin to '
            'maximise the surface area it can absorb water through.',
      ],
    ),
    Lesson(
      id: 'l5',
      title: "Newton's laws of motion",
      subject: 'Physics',
      band: GradeBand.oLevel,
      body: [
        'First law: an object keeps doing what it is doing unless a '
            'resultant force acts on it.',
        'Second law: F = ma. Double the force on the same mass and you '
            'double the acceleration.',
        'Third law: forces come in pairs — equal in size, opposite in '
            'direction, acting on different bodies.',
      ],
    ),
    Lesson(
      id: 'l6',
      title: 'Organic reaction mechanisms',
      subject: 'Chemistry',
      band: GradeBand.aLevel,
      body: [
        'A mechanism traces where the electrons go. Curly arrows always '
            'start at a lone pair or a bond, and always end where the new '
            'bond forms.',
        'Nucleophiles are electron-rich and attack electron-poor centres; '
            'electrophiles are the reverse.',
      ],
    ),
    Lesson(
      id: 'l7',
      title: 'REB National Exam: past paper drills',
      subject: 'Mathematics',
      band: GradeBand.examPrep,
      body: [
        'Past papers are the highest-value revision you can do — they '
            'teach the phrasing examiners use, not just the content.',
        'Work one full paper under timed conditions, then mark it '
            'honestly. The questions you got wrong are your revision list.',
      ],
    ),
    Lesson(
      id: 'l8',
      title: 'Counting 1 to 20 with objects',
      subject: 'Numeracy',
      band: GradeBand.prePrimary,
      rebAligned: false,
      body: [
        'Count real things first — stones, bottle tops, fingers. The '
            'number word only means something once it is attached to a '
            'thing you can touch.',
        'Say one number for each object, and the last number you say is '
            'how many there are.',
      ],
    ),
  ];
}
