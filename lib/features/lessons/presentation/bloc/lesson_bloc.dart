import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/repositories/lesson_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Events
// ═══════════════════════════════════════════════════════════════════════════

abstract class LessonEvent extends Equatable {
  const LessonEvent();

  @override
  List<Object?> get props => [];
}

/// Load all modules and lessons for a course
class LoadModulesAndLessons extends LessonEvent {
  final String courseId;

  const LoadModulesAndLessons(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

/// Load a specific lesson's details
class LoadLessonDetail extends LessonEvent {
  final String courseId;
  final String lessonId;
  final String? userId;
  final String? enrollmentId;

  const LoadLessonDetail({
    required this.courseId,
    required this.lessonId,
    this.userId,
    this.enrollmentId,
  });

  @override
  List<Object?> get props => [courseId, lessonId, userId, enrollmentId];
}

/// Create a new module
class CreateModule extends LessonEvent {
  final String courseId;
  final String title;
  final String? description;
  final int order;

  const CreateModule({
    required this.courseId,
    required this.title,
    this.description,
    required this.order,
  });

  @override
  List<Object?> get props => [courseId, title, description, order];
}

/// Update a module
class UpdateModule extends LessonEvent {
  final String courseId;
  final String moduleId;
  final Map<String, dynamic> updates;

  const UpdateModule({
    required this.courseId,
    required this.moduleId,
    required this.updates,
  });

  @override
  List<Object?> get props => [courseId, moduleId, updates];
}

/// Delete a module
class DeleteModule extends LessonEvent {
  final String courseId;
  final String moduleId;

  const DeleteModule({required this.courseId, required this.moduleId});

  @override
  List<Object?> get props => [courseId, moduleId];
}

/// Create a new lesson
class CreateLesson extends LessonEvent {
  final String courseId;
  final String moduleId;
  final String title;
  final String? description;
  final int order;
  final LessonType type;
  final String? content;
  final String? videoUrl;
  final int durationMinutes;

  const CreateLesson({
    required this.courseId,
    required this.moduleId,
    required this.title,
    this.description,
    required this.order,
    required this.type,
    this.content,
    this.videoUrl,
    required this.durationMinutes,
  });

  @override
  List<Object?> get props => [
    courseId,
    moduleId,
    title,
    description,
    order,
    type,
    content,
    videoUrl,
    durationMinutes,
  ];
}

/// Update a lesson
class UpdateLesson extends LessonEvent {
  final String courseId;
  final String lessonId;
  final Map<String, dynamic> updates;

  const UpdateLesson({
    required this.courseId,
    required this.lessonId,
    required this.updates,
  });

  @override
  List<Object?> get props => [courseId, lessonId, updates];
}

/// Delete a lesson
class DeleteLesson extends LessonEvent {
  final String courseId;
  final String lessonId;

  const DeleteLesson({required this.courseId, required this.lessonId});

  @override
  List<Object?> get props => [courseId, lessonId];
}

/// Toggle lesson publish status
class ToggleLessonPublish extends LessonEvent {
  final String courseId;
  final String lessonId;
  final bool publish;

  const ToggleLessonPublish({
    required this.courseId,
    required this.lessonId,
    required this.publish,
  });

  @override
  List<Object?> get props => [courseId, lessonId, publish];
}

/// Mark a lesson as complete
class MarkLessonComplete extends LessonEvent {
  final String courseId;
  final String lessonId;
  final String enrollmentId;
  final String userId;

  const MarkLessonComplete({
    required this.courseId,
    required this.lessonId,
    required this.enrollmentId,
    required this.userId,
  });

  @override
  List<Object?> get props => [courseId, lessonId, enrollmentId, userId];
}

/// Navigate to next lesson
class LoadNextLesson extends LessonEvent {
  final String courseId;
  final String currentLessonId;
  final String? userId;
  final String? enrollmentId;

  const LoadNextLesson({
    required this.courseId,
    required this.currentLessonId,
    this.userId,
    this.enrollmentId,
  });

  @override
  List<Object?> get props => [courseId, currentLessonId, userId, enrollmentId];
}

/// Navigate to previous lesson
class LoadPreviousLesson extends LessonEvent {
  final String courseId;
  final String currentLessonId;
  final String? userId;
  final String? enrollmentId;

  const LoadPreviousLesson({
    required this.courseId,
    required this.currentLessonId,
    this.userId,
    this.enrollmentId,
  });

  @override
  List<Object?> get props => [courseId, currentLessonId, userId, enrollmentId];
}

// ═══════════════════════════════════════════════════════════════════════════
// States
// ═══════════════════════════════════════════════════════════════════════════

abstract class LessonState extends Equatable {
  const LessonState();

  @override
  List<Object?> get props => [];
}

class LessonInitial extends LessonState {}

class LessonLoading extends LessonState {}

/// Modules and lessons loaded for a course
class ModulesAndLessonsLoaded extends LessonState {
  final String courseId;
  final List<ModuleModel> modules;
  final Map<String, List<LessonModel>> lessonsByModule;
  final Map<String, LessonProgressModel> progressByLesson;
  final int totalLessons;
  final int completedLessons;
  final double completionPercentage;

  const ModulesAndLessonsLoaded({
    required this.courseId,
    required this.modules,
    required this.lessonsByModule,
    this.progressByLesson = const {},
    required this.totalLessons,
    required this.completedLessons,
    required this.completionPercentage,
  });

  @override
  List<Object?> get props => [
    courseId,
    modules,
    lessonsByModule,
    progressByLesson,
    totalLessons,
    completedLessons,
    completionPercentage,
  ];
}

/// Single lesson detail loaded
class LessonDetailLoaded extends LessonState {
  final LessonModel lesson;
  final ModuleModel? module;
  final LessonProgressModel? progress;
  final String? previousLessonId;
  final String? nextLessonId;

  const LessonDetailLoaded({
    required this.lesson,
    this.module,
    this.progress,
    this.previousLessonId,
    this.nextLessonId,
  });

  @override
  List<Object?> get props => [
    lesson,
    module,
    progress,
    previousLessonId,
    nextLessonId,
  ];
}

/// Module created successfully
class ModuleCreated extends LessonState {
  final ModuleModel module;

  const ModuleCreated(this.module);

  @override
  List<Object?> get props => [module];
}

/// Module updated successfully
class ModuleUpdated extends LessonState {
  final ModuleModel module;

  const ModuleUpdated(this.module);

  @override
  List<Object?> get props => [module];
}

/// Module deleted successfully
class ModuleDeleted extends LessonState {
  final String moduleId;

  const ModuleDeleted(this.moduleId);

  @override
  List<Object?> get props => [moduleId];
}

/// Lesson created successfully
class LessonCreated extends LessonState {
  final LessonModel lesson;

  const LessonCreated(this.lesson);

  @override
  List<Object?> get props => [lesson];
}

/// Lesson updated successfully
class LessonUpdated extends LessonState {
  final LessonModel lesson;

  const LessonUpdated(this.lesson);

  @override
  List<Object?> get props => [lesson];
}

/// Lesson deleted successfully
class LessonDeleted extends LessonState {
  final String lessonId;

  const LessonDeleted(this.lessonId);

  @override
  List<Object?> get props => [lessonId];
}

/// Lesson marked as complete
class LessonCompleted extends LessonState {
  final LessonProgressModel progress;
  final String? nextLessonId;

  const LessonCompleted({required this.progress, this.nextLessonId});

  @override
  List<Object?> get props => [progress, nextLessonId];
}

/// Error state
class LessonError extends LessonState {
  final String message;

  const LessonError(this.message);

  @override
  List<Object?> get props => [message];
}

// ═══════════════════════════════════════════════════════════════════════════
// Bloc
// ═══════════════════════════════════════════════════════════════════════════

class LessonBloc extends Bloc<LessonEvent, LessonState> {
  final LessonRepository _lessonRepository;

  LessonBloc({required LessonRepository lessonRepository})
    : _lessonRepository = lessonRepository,
      super(LessonInitial()) {
    on<LoadModulesAndLessons>(_onLoadModulesAndLessons);
    on<LoadLessonDetail>(_onLoadLessonDetail);
    on<CreateModule>(_onCreateModule);
    on<UpdateModule>(_onUpdateModule);
    on<DeleteModule>(_onDeleteModule);
    on<CreateLesson>(_onCreateLesson);
    on<UpdateLesson>(_onUpdateLesson);
    on<DeleteLesson>(_onDeleteLesson);
    on<ToggleLessonPublish>(_onToggleLessonPublish);
    on<MarkLessonComplete>(_onMarkLessonComplete);
    on<LoadNextLesson>(_onLoadNextLesson);
    on<LoadPreviousLesson>(_onLoadPreviousLesson);
  }

  Future<void> _onLoadModulesAndLessons(
    LoadModulesAndLessons event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      final modules = await _lessonRepository.getModules(event.courseId);
      final allLessons = await _lessonRepository.getLessons(event.courseId);

      // Group lessons by module
      final lessonsByModule = <String, List<LessonModel>>{};
      for (final module in modules) {
        lessonsByModule[module.id] =
            allLessons.where((l) => l.moduleId == module.id).toList()
              ..sort((a, b) => a.order.compareTo(b.order));
      }

      emit(
        ModulesAndLessonsLoaded(
          courseId: event.courseId,
          modules: modules,
          lessonsByModule: lessonsByModule,
          totalLessons: allLessons.length,
          completedLessons: 0, // Will be updated with enrollment context
          completionPercentage: 0.0,
        ),
      );
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadLessonDetail(
    LoadLessonDetail event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      final lesson = await _lessonRepository.getLesson(
        event.courseId,
        event.lessonId,
      );
      if (lesson == null) {
        emit(const LessonError('Lesson not found'));
        return;
      }

      final module = await _lessonRepository.getModule(
        event.courseId,
        lesson.moduleId,
      );

      final adjacent = await _lessonRepository.getAdjacentLessons(
        event.courseId,
        event.lessonId,
      );

      LessonProgressModel? progress;
      if (event.userId != null) {
        progress = await _lessonRepository.getLessonProgress(
          event.lessonId,
          event.userId!,
        );
      }

      emit(
        LessonDetailLoaded(
          lesson: lesson,
          module: module,
          progress: progress,
          previousLessonId: adjacent['previous'],
          nextLessonId: adjacent['next'],
        ),
      );
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onCreateModule(
    CreateModule event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      final module = await _lessonRepository.createModule(
        courseId: event.courseId,
        title: event.title,
        description: event.description,
        order: event.order,
      );

      emit(ModuleCreated(module));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onUpdateModule(
    UpdateModule event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      final module = await _lessonRepository.updateModule(
        event.courseId,
        event.moduleId,
        event.updates,
      );

      emit(ModuleUpdated(module));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onDeleteModule(
    DeleteModule event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      await _lessonRepository.deleteModule(event.courseId, event.moduleId);
      emit(ModuleDeleted(event.moduleId));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onCreateLesson(
    CreateLesson event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      final lesson = await _lessonRepository.createLesson(
        courseId: event.courseId,
        moduleId: event.moduleId,
        title: event.title,
        description: event.description,
        order: event.order,
        type: event.type,
        content: event.content,
        videoUrl: event.videoUrl,
        durationMinutes: event.durationMinutes,
      );

      emit(LessonCreated(lesson));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onUpdateLesson(
    UpdateLesson event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      final lesson = await _lessonRepository.updateLesson(
        event.courseId,
        event.lessonId,
        event.updates,
      );

      emit(LessonUpdated(lesson));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onDeleteLesson(
    DeleteLesson event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      await _lessonRepository.deleteLesson(event.courseId, event.lessonId);
      emit(LessonDeleted(event.lessonId));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onToggleLessonPublish(
    ToggleLessonPublish event,
    Emitter<LessonState> emit,
  ) async {
    emit(LessonLoading());

    try {
      final lesson = await _lessonRepository.toggleLessonPublish(
        event.courseId,
        event.lessonId,
        event.publish,
      );

      emit(LessonUpdated(lesson));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onMarkLessonComplete(
    MarkLessonComplete event,
    Emitter<LessonState> emit,
  ) async {
    try {
      final progress = await _lessonRepository.markLessonComplete(
        courseId: event.courseId,
        lessonId: event.lessonId,
        enrollmentId: event.enrollmentId,
        userId: event.userId,
      );

      final adjacent = await _lessonRepository.getAdjacentLessons(
        event.courseId,
        event.lessonId,
      );

      emit(LessonCompleted(progress: progress, nextLessonId: adjacent['next']));
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadNextLesson(
    LoadNextLesson event,
    Emitter<LessonState> emit,
  ) async {
    try {
      final adjacent = await _lessonRepository.getAdjacentLessons(
        event.courseId,
        event.currentLessonId,
      );

      if (adjacent['next'] != null) {
        add(
          LoadLessonDetail(
            courseId: event.courseId,
            lessonId: adjacent['next']!,
            userId: event.userId,
            enrollmentId: event.enrollmentId,
          ),
        );
      }
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLoadPreviousLesson(
    LoadPreviousLesson event,
    Emitter<LessonState> emit,
  ) async {
    try {
      final adjacent = await _lessonRepository.getAdjacentLessons(
        event.courseId,
        event.currentLessonId,
      );

      if (adjacent['previous'] != null) {
        add(
          LoadLessonDetail(
            courseId: event.courseId,
            lessonId: adjacent['previous']!,
            userId: event.userId,
            enrollmentId: event.enrollmentId,
          ),
        );
      }
    } catch (e) {
      emit(LessonError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
