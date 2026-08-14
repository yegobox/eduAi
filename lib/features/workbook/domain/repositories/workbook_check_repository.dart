import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/workbook_feedback.dart';

/// Sends a page of handwritten working to the AI for a check.
abstract interface class WorkbookCheckRepository {
  /// [pageImage] is a PNG of the page's strokes on a white ground.
  Future<Result<WorkbookFeedback>> check(Uint8List pageImage);
}
