import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/domain/providers/foreground_push_provider.dart';
import 'package:wimz_app/presentation/widgets/notifications/push_banner_host.dart';
import 'package:wimz_app/theme/wimz_theme.dart';

void main() {
  testWidgets('foreground push banners over the current route, then clears',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: WimzTheme.light,
        builder: (context, child) => PushBannerHost(child: child!),
        home: const Scaffold(body: Text('demo view')),
      ),
    ));
    expect(find.text('Bezik is barking'), findsNothing);

    container.read(foregroundPushProvider.notifier).state =
        ForegroundPush(title: 'Bezik is barking', body: '3 barks');
    await tester.pumpAndSettle();
    expect(find.text('demo view'), findsOneWidget);
    expect(find.text('Bezik is barking'), findsOneWidget);
    expect(find.text('3 barks'), findsOneWidget);

    await tester.pump(PushBannerHost.showFor);
    await tester.pumpAndSettle();
    expect(find.text('Bezik is barking'), findsNothing);
    expect(container.read(foregroundPushProvider), isNull);
  });

  testWidgets('tap dismisses', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: WimzTheme.dark,
        builder: (context, child) => PushBannerHost(child: child!),
        home: const Scaffold(),
      ),
    ));
    container.read(foregroundPushProvider.notifier).state =
        ForegroundPush(title: 'Treat given', body: '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Treat given'));
    await tester.pumpAndSettle();
    expect(find.text('Treat given'), findsNothing);
  });
}
