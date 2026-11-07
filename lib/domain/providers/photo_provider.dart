import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/local_connection_service.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/remote_logger.dart';
import '../../core/utils/time_utils.dart';
import '../../data/datasources/dog_photos_api.dart';
import '../../data/services/photo_service.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';
import 'dog_profiles_provider.dart';
import '../../l10n/l10n.dart';
import 'l10n_provider.dart';

/// State for photo capture
class PhotoState {
  final List<CapturedPhoto> photos;
  final bool isCapturing;
  final CapturedPhoto? lastCaptured;
  final String? error;

  const PhotoState({
    this.photos = const [],
    this.isCapturing = false,
    this.lastCaptured,
    this.error,
  });

  PhotoState copyWith({
    List<CapturedPhoto>? photos,
    bool? isCapturing,
    CapturedPhoto? lastCaptured,
    String? error,
    bool clearLastCaptured = false,
    bool clearError = false,
  }) {
    return PhotoState(
      photos: photos ?? this.photos,
      isCapturing: isCapturing ?? this.isCapturing,
      lastCaptured: clearLastCaptured ? null : (lastCaptured ?? this.lastCaptured),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Provider for photo management
final photoProvider =
    StateNotifierProvider<PhotoNotifier, PhotoState>((ref) {
  return PhotoNotifier(ref);
});

/// Photo state notifier
class PhotoNotifier extends StateNotifier<PhotoState> {
  final Ref _ref;

  AppLocalizations get _l => _ref.read(l10nProvider);
  final PhotoService _photoService = PhotoService.instance;
  StreamSubscription? _photoSubscription;
  StreamSubscription? _commandResultSubscription;
  Timer? _photoTimeout;

  /// Single-flight guard for [syncRelayPhotos]; a second call while one runs
  /// is coalesced into a re-run after it finishes.
  Future<void>? _syncInFlight;
  bool _syncAgain = false;

  /// Ids currently being fetched (live save + catch-up can race on the same
  /// command_id; the relay guarantees one id per photo).
  final Set<String> _fetching = {};

  PhotoNotifier(this._ref) : super(const PhotoState()) {
    _init();
  }

  Future<void> _init() async {
    await _photoService.init();
    await loadPhotos();
    _subscribeToPhotos();
    // Catch up on relay photos taken while the app was closed. No-op without
    // a token (local mode / signed out) — auth hydrate calls it again on login.
    unawaited(syncRelayPhotos(reason: 'init'));
  }

  void _subscribeToPhotos() {
    final wsClient = _ref.read(websocketClientProvider);
    _photoSubscription?.cancel();
    _photoSubscription = wsClient.photoStream.listen(_handlePhotoMessage);
    // Relay brief 2026-11-07 §1: command_result for a relay take_photo
    // (voice agent / Claude connector / POST command) carries
    // gallery_photo_id — save it live. command_result is transient (no seq)
    // and is NOT target-filtered, so photos from any paired robot land here.
    _commandResultSubscription?.cancel();
    _commandResultSubscription = wsClient.eventStream
        .where((e) => e.type == 'command_result')
        .listen(_handleCommandResult);
  }

  // ---------------------------------------------------------------------
  // Relay-recorded photos (voice agent / Claude connectors)
  // ---------------------------------------------------------------------

  Future<void> _handleCommandResult(WsEvent event) async {
    final d = event.data;
    if (d['command']?.toString() != 'take_photo') return;
    final galleryId = d['gallery_photo_id'];
    if (galleryId is! String || galleryId.isEmpty) {
      // Failed / interim result, or an app-taken photo echoed back — ignore.
      return;
    }
    final dogId = d['dog_id']?.toString();
    final result = d['result'];
    final imageUrl =
        result is Map ? result['image_url']?.toString() : null;
    if (dogId == null || dogId.isEmpty || imageUrl == null || imageUrl.isEmpty) {
      connTrace('relay-photo-live-skip',
          'id=$galleryId dog=$dogId url=$imageUrl (missing fields)');
      return;
    }
    final filename = Uri.parse(imageUrl).pathSegments.lastWhere(
        (s) => s.isNotEmpty,
        orElse: () => '');
    if (filename.isEmpty) {
      connTrace('relay-photo-live-skip', 'id=$galleryId bad url=$imageUrl');
      return;
    }
    final capturedAt = tryParseServerTimestamp(
        (d['timestamp'] ?? event.tsServer)?.toString());
    connTrace('relay-photo-live', 'id=$galleryId dog=$dogId file=$filename');
    await _fetchAndSave(
      relayId: galleryId,
      dogId: dogId,
      url: ApiEndpoints.dogMedia(dogId, filename),
      capturedAt: capturedAt,
    );
  }

  /// Download one relay photo and add it to the gallery. Returns true when
  /// saved (or already present). Dedupe key is [relayId] (part 1 and part 2
  /// of the brief share it).
  Future<bool> _fetchAndSave({
    required String relayId,
    required String dogId,
    required String url,
    DateTime? capturedAt,
  }) async {
    if (await _photoService.hasRelayPhoto(relayId)) return true;
    if (!_fetching.add(relayId)) return true; // another path is on it
    try {
      final token = _ref.read(authProvider).token;
      if (token == null) {
        connTrace('relay-photo-skip', 'id=$relayId no token');
        return false;
      }
      final api = _ref.read(dogPhotosApiProvider);
      final dl = await api.download(token: token, url: url);
      switch (dl.status) {
        case RelayPhotoDownloadStatus.ok:
          break;
        case RelayPhotoDownloadStatus.gone:
          connTrace('relay-photo-expired', 'id=$relayId');
          return false;
        case RelayPhotoDownloadStatus.forbidden:
          connTrace('relay-photo-forbidden', 'id=$relayId');
          return false;
        case RelayPhotoDownloadStatus.failed:
          connTrace('relay-photo-dl-error', 'id=$relayId ${dl.error}');
          return false;
      }
      final photo = await _photoService.saveRelayPhoto(
        relayId: relayId,
        dogId: dogId,
        bytes: dl.bytes!,
        capturedAt: capturedAt,
      );
      final merged = [photo, ...state.photos.where((p) => p.id != photo.id)]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = state.copyWith(
        photos: merged,
        lastCaptured: photo,
        clearError: true,
      );
      connTrace('relay-photo-saved',
          'id=$relayId dog=$dogId gallery=${photo.savedToGallery}');
      return true;
    } catch (e) {
      connTrace('relay-photo-error', 'id=$relayId $e');
      return false;
    } finally {
      _fetching.remove(relayId);
    }
  }

  /// Relay brief 2026-11-07 §2: catch-up. For every dog the user can see,
  /// GET /api/dogs/{dog}/photos?since=<newest captured_at saved for that dog>
  /// and save anything not yet in the gallery. Called on init, login hydrate,
  /// app resume, and when the Photos screen is opened / refreshed.
  /// Skips profile photos and external URLs (optional per the brief).
  Future<void> syncRelayPhotos({String reason = ''}) {
    final running = _syncInFlight;
    if (running != null) {
      _syncAgain = true;
      return running;
    }
    final f = _syncRelayPhotosOnce(reason).whenComplete(() {
      _syncInFlight = null;
      if (_syncAgain) {
        _syncAgain = false;
        unawaited(syncRelayPhotos(reason: '$reason+again'));
      }
    });
    _syncInFlight = f;
    return f;
  }

  Future<void> _syncRelayPhotosOnce(String reason) async {
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (isLocal || token == null) {
      connTrace('relay-photos-sync-skip',
          '$reason local=$isLocal hasToken=${token != null}');
      return;
    }
    final dogs = _ref.read(dogProfilesProvider)
        .where((d) => d.id.isNotEmpty)
        .toList();
    if (dogs.isEmpty) {
      connTrace('relay-photos-sync-skip', '$reason no dogs');
      return;
    }
    final api = _ref.read(dogPhotosApiProvider);
    var saved = 0, skipped = 0;
    for (final dog in dogs) {
      final since = await _photoService.newestRelayCaptureFor(dog.id);
      final res = await api.list(token: token, dogId: dog.id, since: since);
      if (res.unsupported) {
        connTrace('relay-photos-sync', 'relay has no photos route; stop');
        return;
      }
      if (res.error != null) continue; // traced in the api; try next dog
      for (final p in res.photos) {
        if (p.isProfilePhoto || !p.photoUrl.startsWith('/')) {
          skipped++;
          continue;
        }
        final ok = await _fetchAndSave(
          relayId: p.id,
          dogId: p.dogId,
          url: p.photoUrl,
          capturedAt: p.capturedAt,
        );
        if (ok) saved++;
      }
    }
    connTrace('relay-photos-sync',
        '$reason dogs=${dogs.length} saved_or_present=$saved skipped=$skipped');
  }

  Future<void> _handlePhotoMessage(Map<String, dynamic> message) async {
    _photoTimeout?.cancel();
    _photoTimeout = null;
    rlog('PHOTO', 'Received photo message: ${message.keys} (timeout cancelled)');

    final base64Data = message['data'] as String?;
    final filename = message['filename'] as String? ?? 'wimz_photo';
    final timestamp = message['timestamp'] as String?;

    rlog('PHOTO', 'filename=$filename, timestamp=$timestamp');
    rlog('PHOTO', 'data length=${base64Data?.length ?? 0}');

    if (base64Data == null || base64Data.isEmpty) {
      rlog('PHOTO', 'ERROR - Empty photo data received');
      state = state.copyWith(
        isCapturing: false,
        error: _l.photoErrEmpty,
      );
      return;
    }

    try {
      final photo = await _photoService.savePhoto(
        base64Data: base64Data,
        filename: filename,
        timestamp: timestamp,
        saveToGallery: true,
      );

      state = state.copyWith(
        photos: [photo, ...state.photos],
        isCapturing: false,
        lastCaptured: photo,
        clearError: true,
      );

      rlog('PHOTO', 'Photo saved successfully: ${photo.filename}');
    } catch (e) {
      rlog('PHOTO', 'Failed to save photo: $e');
      state = state.copyWith(
        isCapturing: false,
        error: _l.editDogPhotoSaveFailed('$e'),
      );
    }
  }

  /// Take a photo (sends command to robot)
  void takePhoto({bool withHud = true}) {
    rlog('PHOTO', '===== takePhoto() CALLED =====');
    rlog('PHOTO', 'withHud=$withHud, isCapturing=${state.isCapturing}');

    if (state.isCapturing) {
      rlog('PHOTO', 'Already capturing, ignoring');
      return;
    }

    final connectionState = _ref.read(connectionProvider);
    rlog('PHOTO', 'status=${connectionState.status}, isConnected=${connectionState.isConnected}');

    if (!connectionState.isConnected) {
      rlog('PHOTO', 'ERROR - Not connected to robot');
      state = state.copyWith(error: _l.errNotConnectedToRobot);
      return;
    }

    state = state.copyWith(isCapturing: true, clearError: true);

    final wsClient = _ref.read(websocketClientProvider);
    rlog('PHOTO', 'WS state=${wsClient.state}, targetDevice=${wsClient.targetDeviceId}');
    rlog('PHOTO', 'Sending take_photo command...');
    wsClient.sendTakePhoto(withHud: withHud);
    rlog('PHOTO', 'take_photo command sent');

    // Cancellable timeout for photo response
    _photoTimeout?.cancel();
    _photoTimeout = Timer(const Duration(seconds: 10), () {
      if (state.isCapturing) {
        rlog('PHOTO', 'Photo capture timed out after 10s');
        state = state.copyWith(
          isCapturing: false,
          error: _l.photoErrTimeout,
        );
      }
      _photoTimeout = null;
    });
  }

  /// Load photos from local storage
  Future<void> loadPhotos() async {
    try {
      final photos = await _photoService.getPhotos();
      state = state.copyWith(photos: photos);
      rlog('PHOTO', 'Loaded ${photos.length} photos');
    } catch (e) {
      rlog('PHOTO', 'Failed to load photos: $e');
    }
  }

  /// Delete a photo
  Future<void> deletePhoto(String localPath) async {
    final success = await _photoService.deletePhoto(localPath);
    if (success) {
      state = state.copyWith(
        photos: state.photos.where((p) => p.localPath != localPath).toList(),
      );
    }
  }

  /// Clear the last captured notification
  void clearLastCaptured() {
    state = state.copyWith(clearLastCaptured: true);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _photoTimeout?.cancel();
    _photoSubscription?.cancel();
    _commandResultSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for photo count (for badges)
final photoCountProvider = Provider<int>((ref) {
  return ref.watch(photoProvider).photos.length;
});

/// Provider for last captured photo (for toast notifications)
final lastCapturedPhotoProvider = Provider<CapturedPhoto?>((ref) {
  return ref.watch(photoProvider).lastCaptured;
});
