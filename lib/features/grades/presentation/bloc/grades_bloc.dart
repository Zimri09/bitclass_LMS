import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/grade_repository.dart';
import 'grades_event.dart';
import 'grades_state.dart';

/// Bloc for managing grade data
class GradesBloc extends Bloc<GradesEvent, GradesState> {
  final GradeRepository gradeRepository;

  GradesBloc({required this.gradeRepository}) : super(GradesInitial()) {
    on<LoadGrades>(_onLoadGrades);
    on<RefreshGrades>(_onRefreshGrades);
  }

  Future<void> _onLoadGrades(
    LoadGrades event,
    Emitter<GradesState> emit,
  ) async {
    emit(GradesLoading());
    try {
      final summary = await gradeRepository.getGradesSummary(event.userId);
      emit(GradesLoaded(summary: summary));
    } catch (e) {
      emit(GradesError(message: 'Failed to load grades: $e'));
    }
  }

  Future<void> _onRefreshGrades(
    RefreshGrades event,
    Emitter<GradesState> emit,
  ) async {
    try {
      final summary = await gradeRepository.getGradesSummary(event.userId);
      emit(GradesLoaded(summary: summary));
    } catch (e) {
      emit(GradesError(message: 'Failed to refresh grades: $e'));
    }
  }
}
