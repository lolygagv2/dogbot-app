import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/local_connection_service.dart';
import '../../core/utils/conn_trace.dart';
import 'device_provider.dart';
import 'settings_provider.dart';
import 'webrtc_provider.dart';

/// App-global arbiter for the local-mode video transport (robot brief
/// 2026-07-27 §5b). State is `true` when the MJPEG fallback should render.
///
/// Rules (robot journal proved local WebRTC is stable for a whole AP session,
/// so WebRTC is the default — the old Build 112 MJPEG-first behavior and its
/// per-screen "Try WebRTC" opt-in are gone):
///  - Local mode defaults to WebRTC; the first video surface to mount calls
///    [ensureLocalVideo], which fires the (idempotent) stream request.
///  - MJPEG is a fallback only: it renders when WebRTC hasn't connected
///    within [_fallbackAfter] or has declared an error.
///  - WebRTC connected always wins — SmartVideoView renders the track and
///    thereby unmounts the MJPEG player the moment WebRTC connects. Running
///    both saturates the robot's AP link (MJPEG ~4-7 Mbps vs WebRTC's
///    adaptive 0.4-1.5 Mbps) and doubles the Pi's encode load — that was the
///    drive-screen lag. Bounding boxes are burned into the WebRTC stream
///    robot-side, so boxes appear iff the WebRTC track renders.
///  - While the fallback is showing, WebRTC keeps being retried in the
///    background at a gentle pace so a recovered link flips the user back to
///    the good stream without any manual affordance.
///
/// This state is intentionally global (one per app, like the WebRTC session
/// itself): the fallback decision surviving navigation is the whole fix —
/// per-screen copies of it were why the drive screen re-ran MJPEG next to a
/// healthy WebRTC session.
final localVideoTransportProvider =
    StateNotifierProvider<LocalVideoTransportNotifier, bool>((ref) {
  return LocalVideoTransportNotifier(ref);
});

class LocalVideoTransportNotifier extends StateNotifier<bool> {
  final Ref _ref;
  Timer? _fallbackTimer;
  Timer? _retryTimer;

  /// Local ICE is host-pair only and completes in ~2s on the AP; 8s covers a
  /// slow first STUN binding without leaving the user staring at a spinner.
  static const Duration _fallbackAfter = Duration(seconds: 8);

  /// Background WebRTC retry cadence while the MJPEG fallback is showing.
  static const Duration _retryEvery = Duration(seconds: 30);

  LocalVideoTransportNotifier(this._ref) : super(false) {
    _ref.listen<WebRTCConnectionState>(webrtcProvider, (prev, next) {
      if (!_isLocalMode) return;
      if (next.isConnected) {
        // WebRTC wins — tear the fallback down immediately.
        _fallbackTimer?.cancel();
        _stopRetryLoop();
        if (state) {
          connTrace('video-transport', 'webrtc connected — leaving MJPEG');
          state = false;
        }
        return;
      }
      if (next.state == WebRTCState.error) {
        // Terminal for this attempt (15s connect timeout or max reconnects)
        // — don't make the user wait out the fallback timer too.
        _fallbackTimer?.cancel();
        _activateFallback('webrtc error: ${next.errorMessage}');
      } else if (prev?.isConnected == true) {
        // Dropped after being connected: the provider's own reconnect
        // machinery is already running — give it one window, then fall back
        // while it keeps trying.
        _armFallbackTimer('webrtc dropped');
      }
    });

    _ref.listen<bool>(
      settingsProvider.select((s) => s.localModeEnabled),
      (prev, isLocal) {
        if (isLocal == false) {
          _reset();
        } else if (prev == false) {
          // Entered local mode mid-session — video surfaces already mounted
          // won't re-run initState, so kick from here.
          ensureLocalVideo();
        }
      },
    );

    // The moment the local WS comes up, start video — this beats widget
    // mounting (home screen may already be up during an AP reconnect) and is
    // what makes the drive screen's acceptance ("WebRTC with boxes
    // immediately") hold no matter which screen is frontmost.
    _ref.listen<bool>(
      localConnectionProvider.select((c) => c.isConnected),
      (prev, connected) {
        if (connected && prev != true) ensureLocalVideo();
      },
    );
  }

  bool get _isLocalMode => _ref.read(settingsProvider).localModeEnabled;

  String get _localDeviceId => _ref.read(localConnectionProvider).isConnected
      ? 'local_robot'
      : _ref.read(deviceIdProvider);

  /// Idempotent kick — every video surface calls this at mount in local mode.
  /// If a WebRTC session is already connected or mid-handshake this is a
  /// no-op, so navigating between screens never restarts the session (the
  /// per-screen restart was the §5b bug).
  void ensureLocalVideo() {
    if (!_isLocalMode) return;
    final webrtc = _ref.read(webrtcProvider);
    final notifier = _ref.read(webrtcProvider.notifier);
    if (webrtc.isConnected || notifier.isPaused) return;
    if (webrtc.state == WebRTCState.connecting) {
      // Handshake in flight (possibly started by a previous screen) — just
      // make sure a fallback deadline exists.
      if (!(_fallbackTimer?.isActive ?? false)) {
        _armFallbackTimer('mount during handshake');
      }
      return;
    }
    connTrace('video-transport', 'auto-starting local WebRTC');
    _armFallbackTimer('local video start');
    // ignore: discarded_futures
    notifier.requestVideoStream(_localDeviceId);
  }

  void _armFallbackTimer(String reason) {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_fallbackAfter, () {
      if (_ref.read(webrtcProvider).isConnected) return;
      _activateFallback('timeout ($reason)');
    });
  }

  void _activateFallback(String reason) {
    if (!mounted || !_isLocalMode) return;
    if (!state) {
      connTrace('video-transport', 'MJPEG fallback on — $reason');
      state = true;
    }
    _startRetryLoop();
  }

  /// While MJPEG is showing, keep poking WebRTC so a recovered link brings
  /// the boxes back without user action. retryConnection resets the
  /// provider's attempt counter, so a stuck `error` state can't strand us.
  void _startRetryLoop() {
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer.periodic(_retryEvery, (_) {
      if (!_isLocalMode || !state) {
        _stopRetryLoop();
        return;
      }
      final notifier = _ref.read(webrtcProvider.notifier);
      final webrtc = _ref.read(webrtcProvider);
      if (notifier.isPaused ||
          webrtc.isConnected ||
          webrtc.state == WebRTCState.connecting) {
        return;
      }
      connTrace('video-transport', 'background WebRTC retry');
      // ignore: discarded_futures
      notifier.requestVideoStream(_localDeviceId);
    });
  }

  void _stopRetryLoop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _reset() {
    _fallbackTimer?.cancel();
    _stopRetryLoop();
    if (state) state = false;
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
