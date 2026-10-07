import '../../../photos/data/models/selected_photo.dart';

enum AnalysisMethod { photo, text }

class AnalysisInput {
  const AnalysisInput({
    this.method = AnalysisMethod.photo,
    this.front,
    this.side,
    this.goal,
    this.text = '',
    this.goalDescription = '',
  });

  final AnalysisMethod method;
  final SelectedPhoto? front;
  final SelectedPhoto? side;
  final SelectedPhoto? goal;
  final String text;
  final String goalDescription;

  AnalysisInput copyWith({
    AnalysisMethod? method,
    String? text,
    String? goalDescription,
    PhotoSlot? slot,
    SelectedPhoto? photo,
  }) => AnalysisInput(
    method: method ?? this.method,
    front: slot == PhotoSlot.front ? photo : front,
    side: slot == PhotoSlot.side ? photo : side,
    goal: slot == PhotoSlot.goal ? photo : goal,
    text: text ?? this.text,
    goalDescription: goalDescription ?? this.goalDescription,
  );

  Map<String, dynamic> toJson() => {
    'method': method.name,
    'front': front?.toJson(),
    'side': side?.toJson(),
    'goal': goal?.toJson(),
    'text': text,
    'goal_description': goalDescription,
  };

  factory AnalysisInput.fromJson(Map<String, dynamic> json) => AnalysisInput(
    method: AnalysisMethod.values.byName(json['method'] as String),
    front: json['front'] == null
        ? null
        : SelectedPhoto.fromJson(
            Map<String, dynamic>.from(json['front'] as Map),
          ),
    side: json['side'] == null
        ? null
        : SelectedPhoto.fromJson(
            Map<String, dynamic>.from(json['side'] as Map),
          ),
    goal: json['goal'] == null
        ? null
        : SelectedPhoto.fromJson(
            Map<String, dynamic>.from(json['goal'] as Map),
          ),
    text: json['text'] as String? ?? '',
    goalDescription: json['goal_description'] as String? ?? '',
  );
}
