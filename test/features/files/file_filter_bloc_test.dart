import 'package:bitclass/features/files/data/models/file_model.dart';
import 'package:bitclass/features/files/data/repositories/file_repository.dart';
import 'package:bitclass/features/files/presentation/bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _FakeFileRepository repository;
  late FileBloc bloc;

  setUp(() {
    repository = _FakeFileRepository([
      _file('document', FileType.document),
      _file('image', FileType.image),
      _file('video', FileType.video),
    ]);
    bloc = FileBloc(fileRepository: repository);
  });

  tearDown(() async {
    await bloc.close();
    repository.dispose();
  });

  test('type filters are exclusive and All restores every material', () async {
    final documentsLoaded = _nextLoadedState(bloc);
    bloc.add(
      const FilterFilesByType(courseId: 'course-1', type: FileType.document),
    );

    final documents = await documentsLoaded;
    expect(documents.filterType, FileType.document);
    expect(documents.files, hasLength(1));
    expect(documents.files.single.type, FileType.document);

    final allLoaded = _nextLoadedState(bloc);
    bloc.add(const FilterFilesByType(courseId: 'course-1'));

    final all = await allLoaded;
    expect(all.filterType, isNull);
    expect(all.files, hasLength(3));
  });
}

Future<FilesLoaded> _nextLoadedState(FileBloc bloc) async {
  final state = await bloc.stream.firstWhere((state) => state is FilesLoaded);
  return state as FilesLoaded;
}

CourseFile _file(String id, FileType type) {
  return CourseFile(
    id: id,
    courseId: 'course-1',
    uploaderId: 'instructor-1',
    uploaderName: 'Instructor',
    name: '$id.material',
    url: 'https://example.com/$id',
    type: type,
    mimeType: 'application/octet-stream',
    sizeBytes: 1,
    createdAt: DateTime(2026),
  );
}

class _FakeFileRepository extends FileRepository {
  _FakeFileRepository(this.files)
    : super(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
        ),
      );

  final List<CourseFile> files;

  @override
  Future<List<CourseFile>> getCourseFiles(String courseId) async {
    return files.where((file) => file.courseId == courseId).toList();
  }

  @override
  Future<List<CourseFile>> getFilesByType(
    String courseId,
    FileType type,
  ) async {
    return files
        .where((file) => file.courseId == courseId && file.type == type)
        .toList();
  }
}
