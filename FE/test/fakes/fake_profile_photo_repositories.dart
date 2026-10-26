import 'package:fe/features/routines/data/routine_refresh_repository.dart';
import 'dart:typed_data';
import 'package:fe/features/profile/data/models/body_profile.dart';
import 'package:fe/features/profile/data/profile_repository.dart';
import 'package:fe/features/photos/data/models/body_photo.dart';
import 'package:fe/features/photos/data/photo_repository.dart';
import 'package:fe/features/photos/data/photo_preparer.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';

const editableProfile = BodyProfile(
  heightCm: 174.5,
  weightKg: 68.5,
  age: 18,
  gender: Gender.male,
  goalType: GoalType.muscle,
  weeklyFrequency: 4,
  experienceLevel: ExperienceLevel.under1y,
);

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile = editableProfile});
  BodyProfile? profile;
  Object? loadError, saveError;
  bool refresh = false;
  int writes = 0;
  @override
  Future<BodyProfile?> load() async {
    if (loadError != null) throw loadError!;
    return profile;
  }

  @override
  Future<ProfileSaveResult> save(
    BodyProfile profile, {
    required bool create,
  }) async {
    writes++;
    if (saveError != null) throw saveError!;
    this.profile = profile;
    return ProfileSaveResult(profile, routineRefreshRecommended: refresh);
  }
}

class FakePhotoRepository implements PhotoRepository {
  List<BodyPhoto> items = [];
  Object? listError, writeError;
  int uploads = 0, deletes = 0, lists = 0;
  Uint8List? lastUpload;
  PhotoDeleteResult? deleteResult;
  @override
  Future<PhotoPage> list({BodyPhotoType type = BodyPhotoType.current}) async {
    lists++;
    if (listError != null) throw listError!;
    return PhotoPage(items, items.length);
  }

  @override
  Future<BodyPhoto> upload(
    Uint8List jpeg, {
    required BodyPhotoType type,
    required BodyPhotoSide side,
  }) async {
    uploads++;
    lastUpload = jpeg;
    if (writeError != null) throw writeError!;
    final photo = testPhoto(items.length + 1, side: side);
    items = [photo, ...items];
    return photo;
  }

  @override
  Future<void> delete(int id) async {
    if (writeError != null) throw writeError!;
    deletes++;
    items = items.where((p) => p.id != id).toList();
  }

  @override
  Future<PhotoDeleteResult> deleteAll({
    BodyPhotoType type = BodyPhotoType.current,
  }) async {
    if (writeError != null) throw writeError!;
    deletes++;
    final result =
        deleteResult ?? PhotoDeleteResult(deleted: items.length, skipped: 0);
    items = items.skip(result.deleted).toList();
    return result;
  }
}

BodyPhoto testPhoto(int id, {BodyPhotoSide side = BodyPhotoSide.front}) =>
    BodyPhoto(
      id: id,
      type: BodyPhotoType.current,
      side: side,
      url: 'http://photo.test/$id',
      urlExpiresAt: DateTime.now().add(const Duration(hours: 1)),
      createdAt: DateTime(2026, 10, 26),
    );

class FakePhotoPreparer implements PhotoPreparer {
  int calls = 0;
  Object? failure;
  @override
  Future<Uint8List> prepare(SelectedPhoto photo) async {
    calls++;
    if (failure != null) throw failure!;
    return Uint8List.fromList([255, 216, 255, 217]);
  }
}

class FakeRoutineRefreshRepository implements RoutineRefreshRepository {
  int calls = 0;
  Object? error;
  @override
  Future<void> regenerate() async {
    calls++;
    if (error != null) throw error!;
  }
}
