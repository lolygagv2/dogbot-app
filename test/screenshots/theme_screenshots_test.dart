// Renders the main screens in demo mode under both brand themes and writes
// PNGs to build/screenshots/<light|dark>/<route>.png for a visual audit.
//
// Opt-in only (it is slow and writes files):
//   flutter test test/screenshots --dart-define=WIMZ_SCREENSHOTS=1
//
// Real Roboto + Material Icons fonts are loaded from the Flutter SDK cache so
// the captures look like the device, not the test-only "Ahem" boxes.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wimz_app/app.dart';
import 'package:wimz_app/domain/providers/auth_provider.dart';

const bool _enabled = bool.fromEnvironment('WIMZ_SCREENSHOTS');

/// Route → file name. Demo mode bypasses the auth redirect for all of them.
const Map<String, String> _routes = {
  '/login': 'login',
  '/home': 'home',
  '/drive': 'drive',
  '/coach': 'coach',
  '/missions': 'missions',
  '/programs': 'programs',
  '/gallery': 'gallery',
  '/activity': 'activity',
  '/history': 'history',
  '/scheduler': 'scheduler',
  '/dogs': 'dogs',
  '/settings': 'settings',
  '/settings/notifications': 'settings_notifications',
  '/settings/connected-ai': 'settings_connected_ai',
  '/settings/sounds': 'settings_sounds',
  '/device-pairing': 'device_pairing',
  '/voice-setup': 'voice_setup',
};

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/home/morgan/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = await File('$dir/$f').readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  // The app's diagnostics / HUD text asks for 'monospace'; any mono TTF
  // under that family name keeps those labels legible in captures.
  const mono = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf';
  if (File(mono).existsSync()) {
    final loader = FontLoader('monospace');
    final bytes = await File(mono).readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

Future<void> _settle(WidgetTester tester) async {
  // Fixed-step pumping: pulse/shimmer animations never "settle".
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(
    WidgetTester tester, GlobalKey boundaryKey, String path) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in [Brightness.light, Brightness.dark]) {
    final themeName = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('screenshots: $themeName', (tester) async {
      await runZonedGuarded(() async {
        await tester.runAsync(_loadFonts);
        SharedPreferences.setMockInitialValues({});
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.binding.setSurfaceSize(const Size(390, 844));
        tester.view.devicePixelRatio = 1.0;

        final boundaryKey = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: const ProviderScope(child: WimzApp()),
        ));
        await _settle(tester);

        // The router pins every path to the splash while silent re-auth is
        // bootstrapping; wait for that to finish (there is no stored JWT in
        // the test, so it resolves to "show login").
        // The secure-storage read behind it completes on the real event loop,
        // so give real time inside runAsync between fake-clock pumps.
        for (var i = 0; i < 100; i++) {
          final container = ProviderScope.containerOf(
              tester.element(find.byType(Scaffold).first));
          if (!container.read(authProvider).bootstrapping) break;
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await _settle(tester);

        // Enter demo mode (sets connectionProvider.isDemoMode, then goes /home).
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/demo');
        await _settle(tester);

        final outDir = Directory('build/screenshots/$themeName');
        for (final entry in _routes.entries) {
          final router =
              GoRouter.of(tester.element(find.byType(Scaffold).first));
          router.go(entry.key);
          await _settle(tester);
          debugPrint('screenshot ${entry.key} -> '
              '${router.routerDelegate.currentConfiguration.uri}');
          // Plugins have no platform side under `flutter test` (WebRTC,
          // wakelock, secure storage...). Record what each screen threw so
          // a layout overflow would still be visible, but keep capturing.
          final thrown = tester.takeException();
          if (thrown != null) {
            debugPrint('  threw on ${entry.key}: '
                '${thrown.toString().split('\n').first}');
          }
          await _capture(
              tester, boundaryKey, '${outDir.path}/${entry.value}.png');
        }

        // Tear the app down so its timers cancel before the test ends. The
        // WebRTC notifier reads a provider from the already-disposed container
        // in its dispose() (harmless in the app, where the root container is
        // never disposed); consume that so it does not fail the capture run.
        await runZonedGuarded(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }, (error, stack) {
          debugPrint('teardown (ignored): $error');
        });
        tester.takeException();
        await tester.binding.setSurfaceSize(null);
      }, (error, stack) {
        debugPrint('zone (ignored): ${error.toString().split('\n').first}');
      });
    }, skip: !_enabled, timeout: const Timeout(Duration(minutes: 5)));
  }
}
