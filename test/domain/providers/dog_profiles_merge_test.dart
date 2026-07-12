import 'package:flutter_test/flutter_test.dart';
import 'package:wimz_app/data/models/dog_profile.dart';
import 'package:wimz_app/domain/providers/dog_profiles_provider.dart';

DogProfile dog(
  String id,
  String name, {
  DateTime? createdAt,
  DateTime? updatedAt,
  String? localPhotoPath,
  int photoVersion = 0,
  String? breed,
}) =>
    DogProfile(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      localPhotoPath: localPhotoPath,
      photoVersion: photoVersion,
      breed: breed,
    );

void main() {
  group('mergeRelayDogs', () {
    test('relay copy with a minted id is absorbed by name, not duplicated',
        () {
      // The logout/login replication bug: app created dog A, relay stored it
      // under its own id X1. Merge must NOT produce two dogs.
      final local = [dog('A', 'Rex', createdAt: DateTime(2026, 1, 1))];
      final remote = [dog('X1', 'Rex')];

      final result = DogProfilesNotifier.mergeRelayDogs(local, remote);

      expect(result.merged, hasLength(1));
      expect(result.merged.single.id, 'A'); // local id is canonical
      // Relay already has this dog — must not be backfilled again.
      expect(result.relayKnownIds, contains('A'));
    });

    test('repeated login cycles stay stable (no growth)', () {
      var local = [dog('A', 'Rex', createdAt: DateTime(2026, 1, 1))];
      // Relay accumulated replicas from earlier buggy cycles.
      final remote = [dog('X1', 'Rex'), dog('X2', 'Rex'), dog('X3', 'Rex')];

      for (var cycle = 0; cycle < 3; cycle++) {
        final result = DogProfilesNotifier.mergeRelayDogs(local, remote);
        local = result.merged;
      }
      expect(local, hasLength(1));
      expect(local.single.id, 'A');
    });

    test('fresh install adopts relay dogs but collapses relay replicas', () {
      final remote = [dog('X1', 'Rex'), dog('X2', 'Rex'), dog('Y1', 'Fido')];

      final result = DogProfilesNotifier.mergeRelayDogs([], remote);

      expect(result.merged, hasLength(2));
      expect(result.merged.map((d) => d.name).toSet(), {'Rex', 'Fido'});
    });

    test('same id merges by newer updatedAt and keeps photo cache fields', () {
      final local = [
        dog('A', 'Rex',
            updatedAt: DateTime(2026, 1, 1),
            localPhotoPath: '/photos/rex.jpg',
            photoVersion: 3),
      ];
      final remote = [
        dog('A', 'Rex', updatedAt: DateTime(2026, 2, 1), breed: 'Lab'),
      ];

      final result = DogProfilesNotifier.mergeRelayDogs(local, remote);

      final merged = result.merged.single;
      expect(merged.breed, 'Lab'); // remote newer → remote fields win
      expect(merged.localPhotoPath, '/photos/rex.jpg'); // local-only preserved
      expect(merged.photoVersion, 3);
    });

    test('older remote record does not clobber newer local edits', () {
      final local = [
        dog('A', 'Rex', updatedAt: DateTime(2026, 3, 1), breed: 'Husky'),
      ];
      final remote = [dog('X1', 'Rex', updatedAt: DateTime(2026, 1, 1))];

      final result = DogProfilesNotifier.mergeRelayDogs(local, remote);

      expect(result.merged.single.breed, 'Husky');
      expect(result.merged.single.id, 'A');
    });

    test('genuinely new dog from another device is adopted and not backfilled',
        () {
      final local = [dog('A', 'Rex')];
      final remote = [dog('B', 'Fido')];

      final result = DogProfilesNotifier.mergeRelayDogs(local, remote);

      expect(result.merged, hasLength(2));
      expect(result.relayKnownIds, contains('B'));
      // Local-only Rex is NOT known to relay → eligible for backfill.
      expect(result.relayKnownIds, isNot(contains('A')));
    });

    test('name matching is case-insensitive', () {
      final local = [dog('A', 'Rex')];
      final remote = [dog('X1', 'REX')];

      final result = DogProfilesNotifier.mergeRelayDogs(local, remote);

      expect(result.merged, hasLength(1));
    });
  });

  group('dedupeByName', () {
    test('collapses persisted replicas keeping earliest-created id', () {
      final profiles = [
        dog('A', 'Rex',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
            localPhotoPath: '/photos/rex.jpg'),
        dog('X1', 'Rex',
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
            breed: 'Lab'),
      ];

      final healed = DogProfilesNotifier.dedupeByName(profiles);

      expect(healed, hasLength(1));
      expect(healed.single.id, 'A'); // earliest created wins the id
      expect(healed.single.breed, 'Lab'); // newest edits win the fields
      expect(healed.single.localPhotoPath, '/photos/rex.jpg');
    });

    test('null createdAt counts as oldest (legacy record keeps its id)', () {
      final profiles = [
        dog('X1', 'Rex', createdAt: DateTime(2026, 6, 1)),
        dog('dog_123', 'Rex'), // legacy, no createdAt
      ];

      final healed = DogProfilesNotifier.dedupeByName(profiles);

      expect(healed.single.id, 'dog_123');
    });

    test('distinct dogs are untouched', () {
      final profiles = [dog('A', 'Rex'), dog('B', 'Fido')];
      expect(DogProfilesNotifier.dedupeByName(profiles), hasLength(2));
    });
  });
}
