import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bitclass/features/auth/data/models/user_model.dart';
import 'package:bitclass/features/auth/data/repositories/auth_repository.dart';
import 'package:bitclass/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bitclass/features/files/data/models/upload_progress.dart';
import 'package:bitclass/features/files/data/repositories/file_repository.dart';
import 'package:bitclass/features/files/presentation/screens/upload_file_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../helpers/upload_picker_fake.dart';

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('batch preview, removal and retry at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final oldPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = UploadPickerFake([
        MemoryUploadFile('notes.txt', utf8.encode('Hello')),
        MemoryUploadFile('report.pdf', utf8.encode('%PDF-1.7')),
        MemoryUploadFile('remove.txt', utf8.encode('Remove me')),
      ]);
      addTearDown(() => FilePickerPlatform.instance = oldPicker);
      final authRepository = _AuthRepository();
      final authBloc = AuthBloc(authRepository: authRepository)
        ..add(
          AuthUserUpdated(
            UserModel(
              id: 'teacher',
              email: 'teacher@example.com',
              firstName: 'Test',
              lastName: 'Teacher',
              role: 'instructor',
              createdAt: DateTime(2026),
            ),
          ),
        );
      await authBloc.stream.firstWhere((state) => state is AuthAuthenticated);
      final files = _Files();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/upload'),
                child: const Text('Open upload'),
              ),
            ),
          ),
          GoRoute(
            path: '/upload',
            builder: (_, _) =>
                const UploadFileScreen(courseId: 'course', lessonId: 'lesson'),
          ),
        ],
      );
      addTearDown(() async {
        router.dispose();
        await authBloc.close();
        await authRepository.close();
      });
      await tester.pumpWidget(
        RepositoryProvider<FileRepository>.value(
          value: files,
          child: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.tap(find.text('Open upload'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select files'));
      await tester.pumpAndSettle();
      expect(find.text('TXT · 5 B'), findsOneWidget);
      expect(find.text('PDF · 8 B'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove remove.txt'));
      await tester.tap(find.byTooltip('Remove remove.txt'));
      await tester.pumpAndSettle();
      expect(find.text('remove.txt'), findsNothing);
      await tester.ensureVisible(find.text('Upload Files'));
      await tester.tap(find.text('Upload Files'));
      await tester.pumpAndSettle();
      expect(files.names, ['notes.txt', 'report.pdf']);
      expect(find.text('Uploaded'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Upload Files'));
      await tester.tap(find.text('Upload Files'));
      await tester.pumpAndSettle();
      expect(files.names, ['notes.txt', 'report.pdf', 'report.pdf']);
      expect(find.text('Open upload'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Files implements FileRepository {
  final names = <String>[];
  @override
  Stream<UploadProgress> uploadFileWithData({
    required String courseId,
    String? lessonId,
    required String fileName,
    required String mimeType,
    required Uint8List fileData,
    required String description,
    required String uploaderId,
    required String uploaderName,
  }) async* {
    expect(courseId, 'course');
    expect(lessonId, 'lesson');
    expect(uploaderId, 'teacher');
    names.add(fileName);
    expect(
      mimeType,
      fileName.endsWith('.pdf') ? 'application/pdf' : 'text/plain',
    );
    yield UploadProgress(
      fileId: fileName,
      fileName: fileName,
      status: names.length == 2 ? UploadStatus.failed : UploadStatus.completed,
      progress: 1,
      startedAt: DateTime.now(),
      errorMessage: names.length == 2 ? 'Temporary failure' : null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthRepository extends AuthRepository {
  final SupabaseClient client;
  final events = StreamController<User?>.broadcast();
  factory _AuthRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test');
    client.auth.stopAutoRefresh();
    return _AuthRepository._(client);
  }
  _AuthRepository._(this.client) : super(supabase: client);
  @override
  Stream<User?> get authStateChanges => events.stream;
  Future<void> close() async {
    client.auth.dispose();
    await events.close();
  }
}
