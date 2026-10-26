import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/validation/input_validators.dart';
import '../data/models/body_profile.dart';
import '../data/profile_repository.dart';
import 'profile_form_controller.dart';

class ProfileEditViewModel extends ChangeNotifier
    implements ProfileFormController {
  ProfileEditViewModel(this.repository);
  final ProfileRepository repository;
  bool loading = true, saving = false, _disposed = false;
  bool _create = false;
  bool loaded = false;
  BodyProfile? original;
  ProfileSaveResult? saved;
  @override
  String height = '', weight = '', age = '';
  @override
  Gender? gender;
  @override
  GoalType? goalType;
  @override
  int? frequency;
  @override
  ExperienceLevel? experienceLevel;
  @override
  String? error;
  @override
  Map<String, String> fieldErrors = {};
  @override
  bool get busy => loading || saving;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (saving) return;
    loading = true;
    error = null;
    _notify();
    try {
      original = await repository.load();
      _create = original == null;
      loaded = true;
      final p = original;
      if (p != null) {
        height = _number(p.heightCm);
        weight = _number(p.weightKg);
        age = '${p.age}';
        gender = [Gender.male, Gender.female].contains(p.gender)
            ? p.gender
            : null;
        goalType = p.goalType == GoalType.unknown ? null : p.goalType;
        frequency = p.weeklyFrequency;
        experienceLevel = p.experienceLevel == ExperienceLevel.unknown
            ? null
            : p.experienceLevel;
      }
    } catch (e) {
      error = _message(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  static String _number(double n) =>
      n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  static String _message(Object e) =>
      e is StateError ? e.message : '정보를 처리하지 못했어요. 다시 시도해 주세요.';
  @override
  void clearFieldError(String field) {
    final previous = fieldErrors.remove(field);
    if (error == previous) error = null;
    _notify();
  }

  @override
  void updateProfile({
    Gender? gender,
    GoalType? goal,
    int? frequency,
    ExperienceLevel? experience,
  }) {
    if (busy) return;
    this.gender = gender ?? this.gender;
    goalType = goal ?? goalType;
    this.frequency = frequency ?? this.frequency;
    experienceLevel = experience ?? experienceLevel;
    for (final f in [
      if (gender != null) 'gender',
      if (goal != null) 'goal_type',
      if (frequency != null) 'weekly_frequency',
      if (experience != null) 'experience_level',
    ]) {
      fieldErrors.remove(f);
    }
    error = null;
    _notify();
  }

  @override
  Future<bool> submitProfile() async {
    if (busy) return false;
    error =
        InputValidators.metric(
          height,
          label: '키',
          min: 100,
          max: 250,
          decimalPlaces: 1,
        ) ??
        InputValidators.metric(
          weight,
          label: '몸무게',
          min: 30,
          max: 250,
          decimalPlaces: 1,
        ) ??
        InputValidators.metric(
          age,
          label: '나이',
          min: 10,
          max: 100,
          integer: true,
        );
    error ??= gender == null || ![Gender.male, Gender.female].contains(gender)
        ? '성별을 선택해 주세요.'
        : null;
    error ??= goalType == null || goalType == GoalType.unknown
        ? '운동 목적을 선택해 주세요.'
        : null;
    error ??= frequency == null || frequency! < 1 || frequency! > 7
        ? '주 운동 횟수를 선택해 주세요.'
        : null;
    error ??=
        experienceLevel == null || experienceLevel == ExperienceLevel.unknown
        ? '운동 기간을 선택해 주세요.'
        : null;
    if (error != null) {
      _notify();
      return false;
    }
    saving = true;
    fieldErrors = {};
    _notify();
    try {
      saved = await repository.save(
        BodyProfile(
          heightCm: double.parse(height),
          weightKg: double.parse(weight),
          age: int.parse(age),
          gender: gender!,
          goalType: goalType!,
          weeklyFrequency: frequency!,
          experienceLevel: experienceLevel!,
        ),
        create: _create,
      );
      return true;
    } catch (e) {
      error = _message(e);
      if (e is ApiRequestError) {
        fieldErrors = {
          for (final f in e.failure.fields ?? []) f.field: f.reason,
        };
      }
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  @override
  void back() {}
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
