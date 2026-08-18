import 'package:bitclass_admin/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains how to configure the shared Supabase project', (
    tester,
  ) async {
    await tester.pumpWidget(const AdminConfigurationApp());

    expect(find.text('Admin configuration required'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('same project values'), findsOneWidget);
  });
}
