import 'package:bitclass/features/settings/data/models/support_request.dart';
import 'package:bitclass/features/settings/data/repositories/support_repository.dart';
import 'package:bitclass/features/settings/presentation/screens/admin_support_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('admin can review a request and change its status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeSupportRepository();
    addTearDown(repository.disposeFake);
    await tester.pumpWidget(
      RepositoryProvider<SupportRepository>.value(
        value: repository,
        child: const MaterialApp(home: AdminSupportInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Support Inbox'), findsOneWidget);
    expect(find.text('Quiz timer stopped'), findsWidgets);
    expect(
      find.text('The timer stopped after resuming the app.'),
      findsWidgets,
    );
    expect(find.text('Test Student'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('request-1-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolved').last);
    await tester.pumpAndSettle();

    expect(repository.updatedRequestId, 'request-1');
    expect(repository.updatedStatus, SupportRequestStatus.resolved);
    expect(find.textContaining('marked resolved'), findsOneWidget);
  });
}

class _FakeSupportRepository extends SupportRepository {
  final SupabaseClient _client;
  String? updatedRequestId;
  SupportRequestStatus? updatedStatus;

  factory _FakeSupportRepository() {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    client.auth.stopAutoRefresh();
    return _FakeSupportRepository._(client);
  }

  _FakeSupportRepository._(this._client) : super(supabase: _client);

  @override
  Future<List<SupportRequestRecord>> getRequests({
    SupportRequestType? type,
    SupportRequestStatus? status,
  }) async => [_request];

  @override
  Future<void> updateStatus(
    String requestId,
    SupportRequestStatus status,
  ) async {
    updatedRequestId = requestId;
    updatedStatus = status;
  }

  void disposeFake() {
    _client.auth.dispose();
  }
}

final _request = SupportRequestRecord(
  id: 'request-1',
  userId: 'student-1',
  type: SupportRequestType.bug,
  category: 'High',
  subject: 'Quiz timer stopped',
  description: 'The timer stopped after resuming the app.',
  metadata: const {
    'platform': 'android',
    'app_version': '1.0.0+1',
    'steps_to_reproduce': 'Start a quiz, leave the app, and return.',
    'expected_result': 'The timer should continue counting down.',
  },
  status: SupportRequestStatus.open,
  createdAt: DateTime.utc(2026, 8, 26, 1),
  updatedAt: DateTime.utc(2026, 8, 26, 1),
  userEmail: 'student@bisu.edu.ph',
  userFirstName: 'Test',
  userLastName: 'Student',
  userRole: 'student',
);
