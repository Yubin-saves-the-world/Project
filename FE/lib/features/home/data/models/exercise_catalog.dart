class PreviewExercise {
  const PreviewExercise(
    this.name,
    this.sets,
    this.reps, {
    this.category = '',
    this.selectable = true,
  });
  final String name, category;
  final int sets, reps;
  final bool selectable;
}

// Indices 0–11 are persisted by existing installations. Never reorder or remove.
// Entries outside the backend seed remain readable for old schedules and records.
const workoutCatalog = [
  PreviewExercise('바벨 스쿼트', 4, 12, category: '하체'),
  PreviewExercise('루마니안 데드리프트', 4, 10, selectable: false),
  PreviewExercise('레그 프레스', 3, 15, category: '하체'),
  PreviewExercise('레그 컬', 3, 12, selectable: false),
  PreviewExercise('벤치 프레스', 3, 10, selectable: false),
  PreviewExercise('랫 풀다운', 3, 12, category: '등'),
  PreviewExercise('시티드 로우', 3, 12, category: '등'),
  PreviewExercise('숄더 프레스', 3, 10, selectable: false),
  PreviewExercise('푸시업', 3, 10, category: '가슴'),
  PreviewExercise('런지', 3, 12, selectable: false),
  PreviewExercise('덤벨 컬', 3, 12, category: '팔'),
  PreviewExercise('트라이셉스 푸시다운', 3, 12, category: '팔'),
  PreviewExercise('덤벨 벤치프레스', 3, 10, category: '가슴'),
  PreviewExercise('바벨 벤치프레스', 3, 10, category: '가슴'),
  PreviewExercise('체스트 프레스 머신', 3, 10, category: '가슴'),
  PreviewExercise('덤벨 로우', 3, 10, category: '등'),
  PreviewExercise('바벨 로우', 3, 10, category: '등'),
  PreviewExercise('바디웨이트 스쿼트', 3, 10, category: '하체'),
  PreviewExercise('고블릿 스쿼트', 3, 10, category: '하체'),
  PreviewExercise('숄더 프레스 머신', 3, 10, category: '어깨'),
  PreviewExercise('덤벨 숄더 프레스', 3, 10, category: '어깨'),
  PreviewExercise('사이드 레터럴 레이즈', 3, 10, category: '어깨'),
  PreviewExercise('바벨 오버헤드 프레스', 3, 10, category: '어깨'),
  PreviewExercise('해머 컬', 3, 10, category: '팔'),
  PreviewExercise('벤치 딥스', 3, 10, category: '팔'),
  PreviewExercise('플랭크', 3, 10, category: '코어'),
  PreviewExercise('크런치', 3, 10, category: '코어'),
  PreviewExercise('레그 레이즈', 3, 10, category: '코어'),
  PreviewExercise('케이블 크런치', 3, 10, category: '코어'),
];
