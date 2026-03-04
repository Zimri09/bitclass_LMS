import 'package:equatable/equatable.dart';

import '../../data/models/models.dart';

/// Grades Bloc States
abstract class GradesState extends Equatable {
  const GradesState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class GradesInitial extends GradesState {}

/// Grades are currently being loaded
class GradesLoading extends GradesState {}

/// Grades loaded successfully
class GradesLoaded extends GradesState {
  final GradesSummaryModel summary;

  const GradesLoaded({required this.summary});

  @override
  List<Object?> get props => [summary];
}

/// Error loading grades
class GradesError extends GradesState {
  final String message;

  const GradesError({required this.message});

  @override
  List<Object?> get props => [message];
}
