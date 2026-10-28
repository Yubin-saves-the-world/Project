import 'package:flutter/foundation.dart';
import '../data/models/analysis_input.dart';
import '../../photos/data/models/selected_photo.dart';

abstract interface class AnalysisFormController implements Listenable {
  AnalysisInput get analysis;
  bool get busy;
  bool get bodyPhotoAgreed;
  String? get error;
  void setMethod(AnalysisMethod method);
  void setText(String value);
  SelectedPhoto? photoFor(PhotoSlot slot);
  Future<void> pickPhoto(PhotoSlot slot, PhotoSource source);
  void removePhoto(PhotoSlot slot);
  Future<bool> finish({required bool prepareAnalysis});
  void back();
}
