import '../../../../core/error/result.dart';
import '../entities/tutor_block.dart';
import '../entities/tutor_turn.dart';

/// One tutor answer: the blocks to render plus which model produced them
/// (shown small, for transparency — never an API key).
class TutorAnswer {
  const TutorAnswer({required this.blocks, required this.modelUsed});
  final List<TutorBlock> blocks;
  final String modelUsed;
}

/// Contract for asking the AI tutor a question. The implementation talks to
/// data-connector's `/api/edu/tutor/chat` — a stateless completion proxy, so
/// [history] must be passed on every call.
abstract interface class TutorRepository {
  Future<Result<TutorAnswer>> ask({
    required String message,
    required List<TutorTurn> history,
    String? subject,
    String? level,
  });
}
