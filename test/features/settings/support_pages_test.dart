import 'package:bitclass/features/settings/data/models/support_request.dart';
import 'package:bitclass/features/settings/presentation/screens/help_center_screen.dart';
import 'package:bitclass/features/settings/presentation/screens/legal_document_screen.dart';
import 'package:bitclass/features/settings/presentation/screens/support_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('help center filters its frequently asked questions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HelpCenterScreen()));

    expect(find.text('How do I sign in?'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search help articles'),
      'offline',
    );
    await tester.pump();

    expect(find.text('How do offline files work?'), findsOneWidget);
    expect(find.text('How do I sign in?'), findsNothing);
  });

  testWidgets('bug report includes reproduction and expected result fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SupportRequestScreen(type: SupportRequestType.bug),
      ),
    );

    expect(find.text('Report a Bug'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Steps to reproduce'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Steps to reproduce'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Expected result'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Expected result'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Submit'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.widgetWithText(FilledButton, 'Submit'), findsOneWidget);
  });

  testWidgets('privacy page exposes the main disclosure sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(document: LegalDocument.privacy),
      ),
    );

    expect(find.text('BitClass Privacy Policy'), findsOneWidget);
    expect(find.textContaining('Information collected'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Your choices and rights'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Your choices and rights'), findsOneWidget);
  });
}
