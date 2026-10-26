const exerciseParts = {
  'chest': '가슴',
  'back': '등',
  'leg': '하체',
  'shoulder': '어깨',
  'arm': '팔',
  'core': '코어',
};
const exerciseEquipment = {
  'barbell': '바벨',
  'dumbbell': '덤벨',
  'machine': '머신',
  'bodyweight': '맨몸',
};

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.targetPart,
    required this.equipment,
    required this.difficulty,
    this.minSets,
    this.maxSets,
    this.mediaUrl,
    this.description,
  });
  final int id, difficulty;
  final String name, targetPart, equipment;
  final int? minSets, maxSets;
  final String? mediaUrl, description;
  String get partLabel => exerciseParts[targetPart] ?? '기타 부위';
  String get equipmentLabel => exerciseEquipment[equipment] ?? '기타 기구';
  String get difficultyLabel =>
      difficulty >= 1 && difficulty <= 5 ? '난이도 $difficulty' : '난이도 정보 없음';
  String get setsLabel =>
      minSets == null || maxSets == null || minSets! < 1 || maxSets! < minSets!
      ? '권장 세트 정보 없음'
      : minSets == maxSets
      ? '권장 $minSets세트'
      : '권장 $minSets~$maxSets세트';
  Uri? get mediaUri {
    final value = mediaUrl;
    if (value == null) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['exercise_id'] as int,
    name: json['name'] as String,
    targetPart: json['target_part'] as String,
    equipment: json['equipment'] as String,
    difficulty: json['difficulty'] as int,
    minSets: json['min_sets'] as int?,
    maxSets: json['max_sets'] as int?,
    mediaUrl: json['media_url'] as String?,
    description: json['description'] as String?,
  );
}

class ExercisePageData {
  ExercisePageData(List<Exercise> items, this.page, this.total)
    : items = List.unmodifiable(items);
  final List<Exercise> items;
  final int page, total;
  factory ExercisePageData.fromJson(Map<String, dynamic> json) =>
      ExercisePageData(
        (json['items'] as List)
            .map((v) => Exercise.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList(),
        json['page'] as int,
        json['total'] as int,
      );
}

class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.part,
    this.equipment,
    this.difficulty,
  });
  final String query;
  final String? part, equipment;
  final int? difficulty;
  bool get active =>
      query.trim().isNotEmpty ||
      part != null ||
      equipment != null ||
      difficulty != null;
  ExerciseFilter withQuery(String value) => ExerciseFilter(
    query: value,
    part: part,
    equipment: equipment,
    difficulty: difficulty,
  );
  ExerciseFilter withPart(String? value) => ExerciseFilter(
    query: query,
    part: value,
    equipment: equipment,
    difficulty: difficulty,
  );
  ExerciseFilter withEquipment(String? value) => ExerciseFilter(
    query: query,
    part: part,
    equipment: value,
    difficulty: difficulty,
  );
  ExerciseFilter withDifficulty(int? value) => ExerciseFilter(
    query: query,
    part: part,
    equipment: equipment,
    difficulty: value,
  );
}
