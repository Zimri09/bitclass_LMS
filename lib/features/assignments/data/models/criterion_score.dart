import 'package:equatable/equatable.dart';

/// A grading result for one Activity criterion.
///
/// The criterion name and maximum points are stored as a snapshot so a
/// student's returned grade remains understandable if the Activity rubric is
/// edited later.
class CriterionScore extends Equatable {
  final String criterionId;
  final String criterionName;
  final double maxPoints;
  final double score;

  const CriterionScore({
    required this.criterionId,
    required this.criterionName,
    required this.maxPoints,
    required this.score,
  });

  factory CriterionScore.fromMap(Map<String, dynamic> map) {
    return CriterionScore(
      criterionId: map['criterionId'] as String? ?? '',
      criterionName: map['criterionName'] as String? ?? '',
      maxPoints: (map['maxPoints'] as num?)?.toDouble() ?? 0,
      score: (map['score'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'criterionId': criterionId,
    'criterionName': criterionName,
    'maxPoints': maxPoints,
    'score': score,
  };

  @override
  List<Object?> get props => [criterionId, criterionName, maxPoints, score];
}

extension CriterionScoreTotals on Iterable<CriterionScore> {
  double get totalScore => fold(0, (total, item) => total + item.score);

  double get totalMaxPoints => fold(0, (total, item) => total + item.maxPoints);
}
