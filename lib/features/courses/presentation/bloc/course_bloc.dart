import 'dart:async';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/course_model.dart';
import '../../data/repositories/course_repository.dart';

// Events
abstract class CourseEvent extends Equatable {
  const CourseEvent();

  @override
  List<Object?> get props => [];
}

class LoadCourses extends CourseEvent {
  final String? category;
  final String? searchQuery;

  const LoadCourses({this.category, this.searchQuery});

  @override
  List<Object?> get props => [category, searchQuery];
}

class LoadMoreCourses extends CourseEvent {}

class LoadCourseDetail extends CourseEvent {
  final String courseId;

  const LoadCourseDetail(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

class CreateCourse extends CourseEvent {
  final String title;
  final String description;
  final String category;
  final String instructorId;
  final String instructorName;
  final String? thumbnailUrl;
  final Uint8List? thumbnailBytes;
  final String? thumbnailExtension;
  final String? thumbnailMimeType;

  const CreateCourse({
    required this.title,
    required this.description,
    required this.category,
    required this.instructorId,
    required this.instructorName,
    this.thumbnailUrl,
    this.thumbnailBytes,
    this.thumbnailExtension,
    this.thumbnailMimeType,
  });

  @override
  List<Object?> get props => [
    title,
    description,
    category,
    instructorId,
    thumbnailUrl,
    thumbnailBytes,
    thumbnailExtension,
    thumbnailMimeType,
  ];
}

class UpdateCourse extends CourseEvent {
  final String courseId;
  final Map<String, dynamic> updates;

  const UpdateCourse({required this.courseId, required this.updates});

  @override
  List<Object?> get props => [courseId, updates];
}

class DeleteCourse extends CourseEvent {
  final String courseId;

  const DeleteCourse(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

class ToggleCoursePublish extends CourseEvent {
  final String courseId;
  final bool publish;

  const ToggleCoursePublish({required this.courseId, required this.publish});

  @override
  List<Object?> get props => [courseId, publish];
}

class CheckEnrollment extends CourseEvent {
  final String courseId;
  final String userId;

  const CheckEnrollment({required this.courseId, required this.userId});

  @override
  List<Object?> get props => [courseId, userId];
}

class JoinCourseByCode extends CourseEvent {
  final String code;
  final String userId;
  final String? studentName;
  final String? studentEmail;

  const JoinCourseByCode({
    required this.code,
    required this.userId,
    this.studentName,
    this.studentEmail,
  });

  @override
  List<Object?> get props => [code, userId];
}

// States
abstract class CourseState extends Equatable {
  const CourseState();

  @override
  List<Object?> get props => [];
}

class CourseInitial extends CourseState {}

class CourseLoading extends CourseState {}

class CoursesLoaded extends CourseState {
  final List<CourseModel> courses;
  final bool hasMore;
  final String? category;
  final String? searchQuery;

  const CoursesLoaded({
    required this.courses,
    this.hasMore = true,
    this.category,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [courses, hasMore, category, searchQuery];
}

class CourseDetailLoaded extends CourseState {
  final CourseModel course;
  final EnrollmentModel? enrollment;

  const CourseDetailLoaded({required this.course, this.enrollment});

  @override
  List<Object?> get props => [course, enrollment];
}

class CourseCreated extends CourseState {
  final CourseModel course;

  const CourseCreated(this.course);

  @override
  List<Object?> get props => [course];
}

class CourseUpdated extends CourseState {
  final CourseModel course;

  const CourseUpdated(this.course);

  @override
  List<Object?> get props => [course];
}

class CourseDeleted extends CourseState {}

class CourseError extends CourseState {
  final String message;

  const CourseError(this.message);

  @override
  List<Object?> get props => [message];
}

class CourseJoinedByCode extends CourseState {
  final CourseModel course;
  final EnrollmentModel enrollment;

  const CourseJoinedByCode({required this.course, required this.enrollment});

  @override
  List<Object?> get props => [course, enrollment];
}

// Bloc
class CourseBloc extends Bloc<CourseEvent, CourseState> {
  final CourseRepository _courseRepository;

  CourseBloc({required CourseRepository courseRepository})
    : _courseRepository = courseRepository,
      super(CourseInitial()) {
    on<LoadCourses>(_onLoadCourses);
    on<LoadCourseDetail>(_onLoadCourseDetail);
    on<CreateCourse>(_onCreateCourse);
    on<UpdateCourse>(_onUpdateCourse);
    on<DeleteCourse>(_onDeleteCourse);
    on<ToggleCoursePublish>(_onToggleCoursePublish);
    on<CheckEnrollment>(_onCheckEnrollment);
    on<JoinCourseByCode>(_onJoinCourseByCode);
  }

  Future<void> _onLoadCourses(
    LoadCourses event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());

    try {
      final courses = await _courseRepository.getCourses(
        category: event.category,
        searchQuery: event.searchQuery,
      );

      emit(
        CoursesLoaded(
          courses: courses,
          hasMore: courses.length >= 20,
          category: event.category,
          searchQuery: event.searchQuery,
        ),
      );
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onLoadCourseDetail(
    LoadCourseDetail event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());

    try {
      final course = await _courseRepository.getCourse(event.courseId);
      if (course == null) {
        emit(const CourseError('Course not found'));
        return;
      }

      emit(CourseDetailLoaded(course: course));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onCreateCourse(
    CreateCourse event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());

    try {
      final course = await _courseRepository.createCourse(
        title: event.title,
        description: event.description,
        category: event.category,
        instructorId: event.instructorId,
        instructorName: event.instructorName,
        thumbnailUrl: event.thumbnailUrl,
        thumbnailBytes: event.thumbnailBytes,
        thumbnailExtension: event.thumbnailExtension,
        thumbnailMimeType: event.thumbnailMimeType,
      );

      emit(CourseCreated(course));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onUpdateCourse(
    UpdateCourse event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());

    try {
      final course = await _courseRepository.updateCourse(
        event.courseId,
        event.updates,
      );

      emit(CourseUpdated(course));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onDeleteCourse(
    DeleteCourse event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());

    try {
      await _courseRepository.deleteCourse(event.courseId);
      emit(CourseDeleted());
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onToggleCoursePublish(
    ToggleCoursePublish event,
    Emitter<CourseState> emit,
  ) async {
    try {
      final course = await _courseRepository.togglePublish(
        event.courseId,
        event.publish,
      );
      emit(CourseUpdated(course));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onCheckEnrollment(
    CheckEnrollment event,
    Emitter<CourseState> emit,
  ) async {
    try {
      final course = await _courseRepository.getCourse(event.courseId);
      if (course == null) {
        emit(const CourseError('Course not found'));
        return;
      }

      final enrollment = await _courseRepository.getEnrollment(
        event.courseId,
        event.userId,
      );

      emit(CourseDetailLoaded(course: course, enrollment: enrollment));
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }

  Future<void> _onJoinCourseByCode(
    JoinCourseByCode event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final joined = await _courseRepository.joinCourseByCode(
        code: event.code,
        userId: event.userId,
        studentName: event.studentName,
        studentEmail: event.studentEmail,
      );

      emit(
        CourseJoinedByCode(
          course: joined.course,
          enrollment: joined.enrollment,
        ),
      );
    } catch (e) {
      emit(CourseError(e.toString()));
    }
  }
}
