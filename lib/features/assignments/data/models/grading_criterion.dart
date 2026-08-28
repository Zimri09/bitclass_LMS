import 'package:equatable/equatable.dart';

/// A percentage-based grading criterion for an activity.
///
/// Equivalent points are deliberately derived from the activity total so they
/// cannot become stale when an instructor changes the total points.
class GradingCriterion extends Equatable {
  final String id;
  final String name;
  final double percentage;

  const GradingCriterion({
    required this.id,
    required this.name,
    required this.percentage,
  });

  double equivalentPoints(num totalPoints) => totalPoints * percentage / 100;

  factory GradingCriterion.fromMap(Map<String, dynamic> map) {
    return GradingCriterion(
      id: map['id'] as String? ?? map['criterionId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'percentage': percentage,
  };

  @override
  List<Object?> get props => [id, name, percentage];
}

extension GradingCriteriaValidation on Iterable<GradingCriterion> {
  double get totalPercentage =>
      fold<double>(0, (total, criterion) => total + criterion.percentage);

  bool get hasValidPercentageTotal => (totalPercentage - 100).abs() < 0.001;
}
