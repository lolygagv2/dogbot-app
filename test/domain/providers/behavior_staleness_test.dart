import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wimz_app/core/network/websocket_client.dart';
import 'package:wimz_app/data/models/telemetry.dart';
import 'package:wimz_app/domain/providers/telemetry_provider.dart';

/// Behavior labels are point-in-time readings, not persistent state — the
/// robot classifies at ~2-3 Hz while it can see the dog. Regression: the
/// home/drive detection chips showed "Sit"/"Lay Down" forever after the dog
/// left the frame because telemetry currentBehavior/confidence/dogDetected
/// (and lastDetectionProvider) were never cleared.
void main() {
  test('behavior + confidence clear after the 2s staleness window', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(telemetryProvider.notifier);

    notifier.debugHandleEvent(WsEvent(
      type: 'detection',
      data: {
        'detected': true,
        'behavior': 'sit',
        'confidence': 0.91,
        'dog_id': 'dog-a',
      },
    ));

    var t = container.read(telemetryProvider);
    expect(t.dogDetected, isTrue);
    expect(t.currentBehavior, 'sit');
    expect(t.confidence, 0.91);
    expect(container.read(lastDetectionProvider).detected, isTrue);

    // Within the window nothing clears.
    notifier.debugExpireStaleBehavior();
    t = container.read(telemetryProvider);
    expect(t.currentBehavior, 'sit');

    // Backdate the last reading past the window → everything clears.
    notifier.debugSetBehaviorFreshAt(
        DateTime.now().subtract(const Duration(seconds: 3)));
    notifier.debugExpireStaleBehavior();

    t = container.read(telemetryProvider);
    expect(t.dogDetected, isFalse);
    expect(t.currentBehavior, isNull);
    expect(t.confidence, isNull);
    expect(container.read(lastDetectionProvider).detected, isFalse);
  });

  test('a fresh reading after expiry restarts the window', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(telemetryProvider.notifier);

    notifier.debugSetBehaviorFreshAt(
        DateTime.now().subtract(const Duration(seconds: 3)));
    notifier.debugExpireStaleBehavior();

    notifier.debugHandleEvent(WsEvent(
      type: 'detection',
      data: {'detected': true, 'behavior': 'laydown', 'confidence': 0.8},
    ));

    final t = container.read(telemetryProvider);
    expect(t.currentBehavior, 'laydown');
    expect(t.dogDetected, isTrue);
  });

  test('expiry with no reading ever received is a no-op', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(telemetryProvider.notifier);

    notifier.debugExpireStaleBehavior();
    expect(container.read(telemetryProvider), const Telemetry());
  });
}
