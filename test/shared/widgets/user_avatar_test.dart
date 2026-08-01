import 'package:bitclass/shared/widgets/user_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a default avatar when no profile image exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: UserAvatar(radius: 18))),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('crops a profile image without stretching it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            imageUrl: 'https://example.com/avatar.jpg',
            radius: 24,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final box = tester.widget<SizedBox>(find.byType(SizedBox).first);

    expect(image.fit, BoxFit.cover);
    expect(box.width, 48);
    expect(box.height, 48);
    expect(find.byType(ClipOval), findsOneWidget);
  });
}
