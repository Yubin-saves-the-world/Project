enum Gender {
  male('남성'),
  female('여성'),
  none('선택 안 함');

  const Gender(this.label);
  final String label;
}

enum GoalType {
  muscle('근육 키우기'),
  diet('체중 줄이기'),
  posture('자세 교정');

  const GoalType(this.label);
  final String label;
}

enum ExperienceLevel {
  under3m('3개월 미만'),
  under1y('1년 미만'),
  over1y('1년 이상');

  const ExperienceLevel(this.label);
  final String label;
}

class BodyProfile {
  const BodyProfile({
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.gender,
    required this.goalType,
    required this.weeklyFrequency,
    required this.experienceLevel,
  });

  final double heightCm;
  final double weightKg;
  final int age;
  final Gender gender;
  final GoalType goalType;
  final int weeklyFrequency;
  final ExperienceLevel experienceLevel;

  Map<String, dynamic> toJson() => {
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'age': age,
    'gender': gender.name,
    'goal_type': goalType.name,
    'weekly_frequency': weeklyFrequency,
    'experience_level': experienceLevel.name,
  };

  factory BodyProfile.fromJson(Map<String, dynamic> json) => BodyProfile(
    heightCm: (json['height_cm'] as num).toDouble(),
    weightKg: (json['weight_kg'] as num).toDouble(),
    age: json['age'] as int,
    gender: Gender.values.byName(json['gender'] as String),
    goalType: GoalType.values.byName(json['goal_type'] as String),
    weeklyFrequency: json['weekly_frequency'] as int,
    experienceLevel: ExperienceLevel.values.byName(
      json['experience_level'] as String,
    ),
  );
}
