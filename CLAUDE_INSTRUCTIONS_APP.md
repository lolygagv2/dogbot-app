# Claude Code Instructions: WIM-Z Mobile App WebRTC Integration

## Context

You are working on the WIM-Z Flutter mobile app. The app needs WebRTC video streaming to display live video from the robot when connected through the cloud relay.

**Read API_CONTRACT.md first** - it contains the complete specification.

## Your Task

Implement WebRTC video streaming using flutter_webrtc that:
1. Requests video stream through relay server
2. Receives TURN credentials from relay
3. Handles SDP offer from robot and sends answer
4. Exchanges ICE candidates
5. Displays live video in the UI

## Dependencies to Add

Update `pubspec.yaml`:
```yaml
dependencies:
  flutter_webrtc: ^0.10.0
```

Run:
```bash
flutter pub get
```

### iOS Setup (ios/Podfile)
Add at the top:
```ruby
platform :ios, '13.0'
```

### Android Setup (android/app/build.gradle)
Ensure:
```gradle
minSdkVersion 21
```

### Permissions

**Android (android/app/src/main/AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

**iOS (ios/Runner/Info.plist):**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access for video calls</string>
```

## Files to Create/Modify

### 1. Create: `lib/data/services/webrtc_service.dart`

```dart
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum WebRTCState { disconnected, connecting, connected, error }

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  
  String? _sessionId;
  WebRTCState _state = WebRTCState.disconnected;
  
  // Callbacks
  final void Function(Map<String, dynamic>) onSendMessage;
  final void Function(WebRTCState) onStateChange;
  
  WebRTCService({
    required this.onSendMessage,
    required this.onStateChange,
  });
  
  WebRTCState get state => _state;
  bool get isConnected => _state == WebRTCState.connected;
  
  Future<void> initialize() async {
    await remoteRenderer.initialize();
  }
  
  void _setState(WebRTCState newState) {
    _state = newState;
    onStateChange(newState);
  }
  
  /// Start video stream request
  Future<void> requestVideoStream(String deviceId) async {
    _setState(WebRTCState.connecting);
    
    onSendMessage({
      'type': 'webrtc_request',
      'device_id': deviceId,
    });
  }
  
  /// Handle credentials received from relay
  Future<void> handleCredentials(String sessionId, Map<String, dynamic> iceServers) async {
    _sessionId = sessionId;
    
    try {
      final config = <String, dynamic>{
        'iceServers': iceServers['iceServers'],
        'sdpSemantics': 'unified-plan',
      };
      
      _peerConnection = await createPeerConnection(config);
      
      // Handle incoming video track
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
          _setState(WebRTCState.connected);
        }
      };
      
      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        onSendMessage({
          'type': 'webrtc_ice',
          'session_id': _sessionId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };
      
      // Handle connection state changes
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('WebRTC connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _setState(WebRTCState.error);
        }
      };
      
    } catch (e) {
      print('Error creating peer connection: $e');
      _setState(WebRTCState.error);
    }
  }
  
  /// Handle SDP offer from robot
  Future<void> handleOffer(Map<String, dynamic> sdp) async {
    if (_peerConnection == null) {
      print('No peer connection for offer');
      return;
    }
    
    try {
      final description = RTCSessionDescription(
        sdp['sdp'] as String,
        sdp['type'] as String,
      );
      
      await _peerConnection!.setRemoteDescription(description);
      
      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      // Send answer to robot via relay
      onSendMessage({
        'type': 'webrtc_answer',
        'session_id': _sessionId,
        'sdp': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });
      
    } catch (e) {
      print('Error handling offer: $e');
      _setState(WebRTCState.error);
    }
  }
  
  /// Handle ICE candidate from robot
  Future<void> handleIceCandidate(Map<String, dynamic> candidate) async {
    if (_peerConnection == null || candidate['candidate'] == null) {
      return;
    }
    
    try {
      final iceCandidate = RTCIceCandidate(
        candidate['candidate'] as String,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      );
      
      await _peerConnection!.addIceCandidate(iceCandidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }
  
  /// Close the WebRTC connection
  Future<void> close() async {
    if (_sessionId != null) {
      onSendMessage({
        'type': 'webrtc_close',
        'session_id': _sessionId,
      });
    }
    
    await _peerConnection?.close();
    _peerConnection = null;
    _sessionId = null;
    remoteRenderer.srcObject = null;
    
    _setState(WebRTCState.disconnected);
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await close();
    await remoteRenderer.dispose();
  }
}
```

### 2. Create: `lib/domain/providers/webrtc_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/webrtc_service.dart';
import '../../core/network/websocket_client.dart';
import 'connection_provider.dart';

final webrtcServiceProvider = Provider<WebRTCService?>((ref) {
  final wsClient = ref.watch(websocketClientProvider);
  final connection = ref.watch(connectionProvider);
  
  if (!connection.isConnected) return null;
  
  final service = WebRTCService(
    onSendMessage: (message) => wsClient.send(message),
    onStateChange: (state) {
      // State changes handled by the service itself
    },
  );
  
  ref.onDispose(() => service.dispose());
  
  return service;
});

final webrtcStateProvider = StateProvider<WebRTCState>((ref) {
  return WebRTCState.disconnected;
});
```

### 3. Create: `lib/presentation/widgets/video/webrtc_video_view.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../domain/providers/webrtc_provider.dart';
import '../../../data/services/webrtc_service.dart';
import '../../theme/app_theme.dart';

class WebRTCVideoView extends ConsumerStatefulWidget {
  final String deviceId;
  
  const WebRTCVideoView({super.key, required this.deviceId});
  
  @override
  ConsumerState<WebRTCVideoView> createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends ConsumerState<WebRTCVideoView> {
  WebRTCService? _service;
  bool _initialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }
  
  Future<void> _initializeWebRTC() async {
    _service = ref.read(webrtcServiceProvider);
    if (_service != null) {
      await _service!.initialize();
      setState(() => _initialized = true);
      
      // Request video stream
      _service!.requestVideoStream(widget.deviceId);
    }
  }
  
  @override
  void dispose() {
    _service?.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final webrtcState = ref.watch(webrtcStateProvider);
    
    if (!_initialized || _service == null) {
      return _buildLoading('Initializing...');
    }
    
    switch (webrtcState) {
      case WebRTCState.disconnected:
        return _buildLoading('Disconnected');
      case WebRTCState.connecting:
        return _buildLoading('Connecting...');
      case WebRTCState.error:
        return _buildError();
      case WebRTCState.connected:
        return _buildVideo();
    }
  }
  
  Widget _buildLoading(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Video connection failed',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _service?.requestVideoStream(widget.deviceId),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVideo() {
    return Container(
      color: Colors.black,
      child: RTCVideoView(
        _service!.remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      ),
    );
  }
}
```

### 4. Modify: `lib/core/network/websocket_client.dart`

Add WebRTC message handling in the `_onMessage` method:

```dart
void _onMessage(dynamic message) {
  try {
    final json = jsonDecode(message as String) as Map<String, dynamic>;
    final msgType = json['type'] as String?;
    
    // Handle WebRTC signaling messages
    if (msgType == 'webrtc_credentials') {
      _handleWebRTCCredentials(json);
    } else if (msgType == 'webrtc_offer') {
      _handleWebRTCOffer(json);
    } else if (msgType == 'webrtc_ice') {
      _handleWebRTCIce(json);
    } else if (msgType == 'webrtc_close') {
      _handleWebRTCClose(json);
    } else {
      // Existing event handling
      final event = WsEvent.fromJson(json);
      _eventController.add(event);
    }
  } catch (e) {
    print('WebSocket message parse error: $e');
  }
}

// Add these handlers and corresponding stream controllers:
final _webrtcCredentialsController = StreamController<Map<String, dynamic>>.broadcast();
final _webrtcOfferController = StreamController<Map<String, dynamic>>.broadcast();
final _webrtcIceController = StreamController<Map<String, dynamic>>.broadcast();

Stream<Map<String, dynamic>> get webrtcCredentialsStream => _webrtcCredentialsController.stream;
Stream<Map<String, dynamic>> get webrtcOfferStream => _webrtcOfferController.stream;
Stream<Map<String, dynamic>> get webrtcIceStream => _webrtcIceController.stream;

void _handleWebRTCCredentials(Map<String, dynamic> json) {
  _webrtcCredentialsController.add(json);
}

void _handleWebRTCOffer(Map<String, dynamic> json) {
  _webrtcOfferController.add(json);
}

void _handleWebRTCIce(Map<String, dynamic> json) {
  _webrtcIceController.add(json);
}

void _handleWebRTCClose(Map<String, dynamic> json) {
  // Notify WebRTC service to close
  print('WebRTC close received for session: ${json['session_id']}');
}
```

### 5. Modify: `lib/presentation/screens/home/home_screen.dart`

Replace MJPEG viewer with WebRTC when in cloud mode:

```dart
// In the video section of the build method:

// Determine if using local or cloud connection
final isCloudMode = connection.host?.contains('wimz.io') ?? false;

// Video stream
Expanded(
  flex: 3,
  child: Container(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Use WebRTC for cloud, MJPEG for local
        if (isCloudMode)
          WebRTCVideoView(deviceId: connection.deviceId ?? '')
        else
          MjpegViewer(streamUrl: connection.streamUrl),
        
        // HUD overlay (works for both)
        VideoHudOverlay(
          dogDetected: telemetry.dogDetected,
          behavior: telemetry.currentBehavior,
          // ... other props
        ),
      ],
    ),
  ),
),
```

### 6. Wire up WebRTC streams in provider

Create `lib/domain/providers/webrtc_handler.dart`:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../data/services/webrtc_service.dart';
import 'webrtc_provider.dart';

/// Handles WebRTC signaling messages from WebSocket
class WebRTCHandler {
  final Ref _ref;
  final List<StreamSubscription> _subscriptions = [];
  
  WebRTCHandler(this._ref) {
    _setupListeners();
  }
  
  void _setupListeners() {
    final wsClient = _ref.read(websocketClientProvider);
    
    // Listen for credentials
    _subscriptions.add(
      wsClient.webrtcCredentialsStream.listen((message) {
        final service = _ref.read(webrtcServiceProvider);
        service?.handleCredentials(
          message['session_id'] as String,
          message['ice_servers'] as Map<String, dynamic>,
        );
      }),
    );
    
    // Listen for offers
    _subscriptions.add(
      wsClient.webrtcOfferStream.listen((message) {
        final service = _ref.read(webrtcServiceProvider);
        service?.handleOffer(message['sdp'] as Map<String, dynamic>);
      }),
    );
    
    // Listen for ICE candidates
    _subscriptions.add(
      wsClient.webrtcIceStream.listen((message) {
        final service = _ref.read(webrtcServiceProvider);
        service?.handleIceCandidate(message['candidate'] as Map<String, dynamic>);
      }),
    );
  }
  
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
  }
}

final webrtcHandlerProvider = Provider((ref) {
  final handler = WebRTCHandler(ref);
  ref.onDispose(() => handler.dispose());
  return handler;
});
```

## Testing

1. Run relay server with Cloudflare credentials configured
2. Run robot with relay connection enabled
3. Run app and connect to relay (not direct to robot)
4. Verify video stream establishes
5. Test on both Android and iOS devices

### Debug WebRTC Issues

Add to your app for debugging:
```dart
// In main.dart or initialization
WebRTC.platformIsDesktop; // Check platform
navigator.mediaDevices.getUserMedia; // Test media access
```

Check console for:
- ICE candidate generation
- SDP offer/answer exchange
- Connection state changes

## Success Criteria

- [ ] App requests video stream from relay
- [ ] App receives and uses TURN credentials
- [ ] App handles SDP offer from robot
- [ ] App sends SDP answer back
- [ ] App exchanges ICE candidates
- [ ] Video displays in RTCVideoView
- [ ] Connection state shows correctly in UI
- [ ] Reconnection works after disconnect
- [ ] Works on both Android and iOS
