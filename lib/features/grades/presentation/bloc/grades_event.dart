import 'package:equatable/equatable.dart';

/// Grades Bloc Events
abstract class GradesEvent extends Equatable {
  const GradesEvent();

  @override
  List<Object?> get props => [];
}

/// Load all grades for the current user
class LoadGrades extends GradesEvent {
  final String userId;

  const LoadGrades({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Refresh grades (pull-to-refresh)
class RefreshGrades extends GradesEvent {
  final String userId;

  const RefreshGrades({required this.userId});

  @override
  List<Object?> get props => [userId];
}
