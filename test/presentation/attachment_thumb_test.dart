import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/presentation/widgets/notifications/attachment_thumb.dart';
import 'package:wimz_app/theme/wimz_theme.dart';

Widget _host(Widget child) => MaterialApp(
      theme: WimzTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('clip gets a play badge; still alone does not', (tester) async {
    await tester.pumpWidget(_host(const AttachmentThumb(
        imageUrl: 'https://x/a.jpg', clipUrl: 'https://x/a.mp4')));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester
        .pumpWidget(_host(const AttachmentThumb(imageUrl: 'https://x/a.jpg')));
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('no media draws nothing', (tester) async {
    await tester.pumpWidget(_host(const AttachmentThumb()));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });
}
