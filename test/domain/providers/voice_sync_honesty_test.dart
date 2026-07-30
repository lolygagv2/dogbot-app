import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wimz_app/data/models/voice_command.dart';
import 'package:wimz_app/domain/providers/voice_commands_provider.dart';

/// Voice sync honesty (2026-07-30 contract): a cloud sync that cannot reach
/// the relay must LEAVE the command unsynced — no fire-and-forget WS fallback
/// silently marking isSynced=true. The unsynced flag is what the tile's
/// "tap to sync" state and the reconnect auto-sync retry key off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  VoiceCommand seeded(String dogId, String commandId) => VoiceCommand(
        dogId: dogId,
        commandId: commandId,
        // Path is deliberately nonexistent for the delete test and irrelevant
        // for the no-token test (auth gate fires before file IO).
        localPath: '/nonexistent/${dogId}_$commandId.wav',
        recordedAt: DateTime.now(),
        isSynced: false,
        durationMs: 800,
      );

  test('cloud sync without auth token stays unsynced and returns false',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const dogId = 'dog-test-1';
    final notifier = container.read(voiceCommandsProvider(dogId).notifier);
    notifier.debugSetCommand(seeded(dogId, 'come'));

    // Not in local mode, no JWT (fresh container) → the old code fell through
    // to the WS fallback and lied isSynced=true; the new code must refuse.
    final ok = await notifier.syncCommand('come');

    expect(ok, isFalse);
    final state = container.read(voiceCommandsProvider(dogId));
    expect(state.commands['come']!.isSynced, isFalse,
        reason: 'a sync that never reached the relay must not claim success');
  });

  test('syncCommand returns false for a missing local file', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const dogId = 'dog-test-2';
    final notifier = container.read(voiceCommandsProvider(dogId).notifier);
    notifier.debugSetCommand(seeded(dogId, 'sit'));

    expect(await notifier.syncCommand('nonexistent-command'), isFalse);
  });

  test('resetAllToDefault removes every command for the dog', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const dogId = 'dog-test-3';
    final notifier = container.read(voiceCommandsProvider(dogId).notifier);
    notifier.debugSetCommand(seeded(dogId, 'come'));
    notifier.debugSetCommand(seeded(dogId, 'no'));
    notifier.debugSetCommand(seeded(dogId, 'quiet'));

    final removed = await notifier.resetAllToDefault();

    expect(removed, 3);
    final state = container.read(voiceCommandsProvider(dogId));
    expect(state.commands, isEmpty);
    expect(notifier.recordedCount, 0);
  });
}
