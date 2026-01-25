import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/services/photo_service.dart';
import 'connection_provider.dart';

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
  final PhotoService _photoService = PhotoService.instance;
  StreamSubscription? _photoSubscription;

  PhotoNotifier(this._ref) : super(const PhotoState()) {
    _init();
  }

  Future<void> _init() async {
    await _photoService.init();
    await loadPhotos();
    _subscribeToPhotos();
  }

  void _subscribeToPhotos() {
    final wsClient = _ref.read(websocketClientProvider);
    _photoSubscription?.cancel();
    _photoSubscription = wsClient.photoStream.listen(_handlePhotoMessage);
  }

  Future<void> _handlePhotoMessage(Map<String, dynamic> message) async {
    print('PhotoNotifier: Received photo message: ${message.keys}');

    final base64Data = message['data'] as String?;
    final filename = message['filename'] as String? ?? 'wimz_photo';
    final timestamp = message['timestamp'] as String?;

    print('PhotoNotifier: filename=$filename, timestamp=$timestamp');
    print('PhotoNotifier: data length=${base64Data?.length ?? 0}');

    if (base64Data == null || base64Data.isEmpty) {
      print('PhotoNotifier: ERROR - Empty photo data received');
      state = state.copyWith(
        isCapturing: false,
        error: 'Received empty photo data',
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

      print('PhotoNotifier: Photo saved successfully: ${photo.filename}');
    } catch (e) {
      print('PhotoNotifier: Failed to save photo: $e');
      state = state.copyWith(
        isCapturing: false,
        error: 'Failed to save photo: $e',
      );
    }
  }

  /// Take a photo (sends command to robot)
  void takePhoto({bool withHud = true}) {
    print('PhotoNotifier: takePhoto() called, withHud=$withHud');

    final isConnected = _ref.read(connectionProvider).isConnected;
    print('PhotoNotifier: isConnected=$isConnected');

    if (!isConnected) {
      print('PhotoNotifier: ERROR - Not connected to robot');
      state = state.copyWith(error: 'Not connected to robot');
      return;
    }

    state = state.copyWith(isCapturing: true, clearError: true);
    print('PhotoNotifier: State updated to isCapturing=true');

    final wsClient = _ref.read(websocketClientProvider);
    print('PhotoNotifier: Got websocket client, sending take_photo command...');
    wsClient.sendTakePhoto(withHud: withHud);
    print('PhotoNotifier: Take photo command sent successfully');

    // Add timeout for photo response
    Future.delayed(const Duration(seconds: 10), () {
      if (state.isCapturing) {
        print('PhotoNotifier: Photo capture timed out after 10s');
        state = state.copyWith(
          isCapturing: false,
          error: 'Photo capture timed out - no response from robot',
        );
      }
    });
  }

  /// Load photos from local storage
  Future<void> loadPhotos() async {
    try {
      final photos = await _photoService.getPhotos();
      state = state.copyWith(photos: photos);
      print('PhotoNotifier: Loaded ${photos.length} photos');
    } catch (e) {
      print('PhotoNotifier: Failed to load photos: $e');
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
    _photoSubscription?.cancel();
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
