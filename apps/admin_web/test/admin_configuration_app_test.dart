import 'package:bitclass_admin/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains how to configure the shared Supabase project', (
    tester,
  ) async {
    await tester.pumpWidget(const AdminConfigurationApp());

    expect(find.text('Admin configuration required'), findsOneWidget);
    expect(find.textContaining('Supabase URL'), findsOneWidget);
    expect(
      find.textContaining('frontend-safe publishable key'),
      findsOneWidget,
    );
  });
}
