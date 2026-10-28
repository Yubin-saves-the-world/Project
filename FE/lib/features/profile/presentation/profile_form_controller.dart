import 'package:flutter/foundation.dart';
import '../data/models/body_profile.dart';

abstract interface class ProfileFormController implements Listenable {
  String get height;
  set height(String value);
  String get weight;
  set weight(String value);
  String get age;
  set age(String value);
  Gender? get gender;
  GoalType? get goalType;
  int? get frequency;
  ExperienceLevel? get experienceLevel;
  bool get busy;
  String? get error;
  Map<String, String> get fieldErrors;
  void clearFieldError(String field);
  void updateProfile({
    Gender? gender,
    GoalType? goal,
    int? frequency,
    ExperienceLevel? experience,
  });
  Future<bool> submitProfile();
  void back();
}
