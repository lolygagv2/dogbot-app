# Build 28 - App Claude Tasks

**Date:** 2026-01-28
**Priority:** Mode state management, upload fix, breed field, login consolidation

---

## Context

Build 27 testing revealed several critical issues:

1. **Mission mode gets killed:** When user navigates to Drive screen, it auto-sets mode to "manual", killing the active mission's AI detection
2. **Upload crashes:** Opens Apple Music library instead of file picker, then crashes
3. **Breed field:** Missing from Add Dog screen, doesn't save in Settings
4. **Two login screens:** User gets kicked to login screen when phone locks, and there appear to be two such screens
5. **Video drops on navigation:** Video disconnects when navigating between screens

---

## P0 TASK 1: Single Source of Truth for Mode (ModeService)

### Problem
Each screen has local mode state. Drive screen auto-sets to "manual" on load, which kills active missions.

### Solution
Create a global ModeService that all screens read from. Screens should NOT set mode independently.

### File: `lib/services/mode_service.dart` (NEW FILE)

```dart
import 'package:flutter/foundation.dart';

/// Global singleton for mode state.
/// All screens should READ from this, never maintain local mode state.
class ModeService extends ChangeNotifier {
  static final ModeService _instance = ModeService._internal();
  factory ModeService() => _instance;
  ModeService._internal();
  
  String _currentMode = 'idle';
  String? _activeMissionId;
  String? _activeMissionName;
  bool _modeLocked = false;
  String? _lockReason;
  
  // Getters
  String get currentMode => _currentMode;
  bool get isMissionActive => _activeMissionId != null;
  bool get isModeLocked => _modeLocked;
  String? get activeMissionId => _activeMissionId;
  String? get activeMissionName => _activeMissionName;
  String? get lockReason => _lockReason;
  
  /// Called when robot sends mode_changed event
  void updateFromRobot(Map<String, dynamic> data) {
    final newMode = data['new'] as String? ?? data['mode'] as String?;
    final locked = data['locked'] as bool? ?? _modeLocked;
    
    if (newMode != null) {
      _currentMode = newMode;
      _modeLocked = locked;
      print('[MODE] Updated from robot: $_currentMode (locked: $_modeLocked)');
      notifyListeners();
    }
  }
  
  /// Called when robot sends mode_change_rejected event
  void handleModeRejected(Map<String, dynamic> data) {
    final reason = data['reason'] as String?;
    final requested = data['requested'] as String?;
    print('[MODE] Change to "$requested" rejected: $reason');
    // UI can listen and show snackbar
    notifyListeners();
  }
  
  /// Called when mission starts (from mission_progress event)
  void missionStarted(String missionId, String missionName) {
    _activeMissionId = missionId;
    _activeMissionName = missionName;
    _modeLocked = true;
    _lockReason = 'Mission active: $missionName';
    _currentMode = 'mission';
    print('[MODE] Mission started: $missionName, mode locked');
    notifyListeners();
  }
  
  /// Called when mission ends (from mission_progress event)
  void missionEnded() {
    final wasActive = _activeMissionName;
    _activeMissionId = null;
    _activeMissionName = null;
    _modeLocked = false;
    _lockReason = null;
    _currentMode = 'idle';
    print('[MODE] Mission ended: $wasActive, mode unlocked');
    notifyListeners();
  }
  
  /// Check if mode change is allowed (for UI to show appropriate feedback)
  bool canChangeMode() {
    return !_modeLocked;
  }
}
```

### File: `lib/main.dart`

Register the provider:

```dart
import 'package:provider/provider.dart';
import 'services/mode_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ModeService()),
        // ... other existing providers ...
      ],
      child: MyApp(),
    ),
  );
}
```

### File: `lib/services/websocket_service.dart` (or wherever messages are handled)

Handle mode events from robot:

```dart
void _handleMessage(Map<String, dynamic> message) {
  final type = message['type'];
  final data = message['data'] as Map<String, dynamic>? ?? message;
  
  switch (type) {
    case 'mode_changed':
    case 'status_update':
      ModeService().updateFromRobot(data);
      break;
      
    case 'mode_change_rejected':
      ModeService().handleModeRejected(data);
      // Optionally show a snackbar/toast
      break;
      
    case 'mission_progress':
      _handleMissionProgress(data);
      break;
    
    // ... other handlers ...
  }
}

void _handleMissionProgress(Map<String, dynamic> data) {
  final action = data['action'] as String?;
  
  switch (action) {
    case 'started':
      ModeService().missionStarted(
        data['mission_id']?.toString() ?? '',
        data['mission'] as String? ?? '',
      );
      break;
    case 'completed':
    case 'stopped':
      ModeService().missionEnded();
      break;
  }
}
```

### File: `lib/screens/drive_screen.dart`

**CRITICAL:** Do NOT auto-set mode to manual. Respect the current mode.

```dart
import 'package:provider/provider.dart';
import '../services/mode_service.dart';

class _DriveScreenState extends State<DriveScreen> {
  @override
  void initState() {
    super.initState();
    
    // DON'T DO THIS:
    // _sendCommand('set_mode', {'mode': 'manual'});  // ❌ REMOVE THIS
    
    // Instead, check if we CAN change mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modeService = context.read<ModeService>();
      
      if (modeService.isMissionActive) {
        print('[DRIVE] Mission active: ${modeService.activeMissionName} - keeping mission mode');
        // Optionally show indicator
      } else if (!modeService.isModeLocked) {
        // Only set manual if no mission and mode not locked
        _requestManualMode();
      }
    });
  }
  
  void _requestManualMode() {
    final modeService = context.read<ModeService>();
    if (modeService.canChangeMode()) {
      _sendCommand('set_mode', {'mode': 'manual'});
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ModeService>(
      builder: (context, modeService, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Drive'),
            actions: [
              // Mode indicator chip
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(modeService.currentMode.toUpperCase()),
                  backgroundColor: _getModeColor(modeService.currentMode),
                  labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Normal drive controls
              _buildDriveControls(),
              
              // Mission active banner
              if (modeService.isMissionActive)
                _buildMissionBanner(modeService),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMissionBanner(ModeService modeService) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.orange.shade700,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(Icons.pets, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🎯 Mission Active: ${modeService.activeMissionName}',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: _stopMission,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text('STOP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _stopMission() {
    _sendCommand('stop_mission', {});
  }
  
  Color _getModeColor(String mode) {
    switch (mode) {
      case 'mission': return Colors.orange;
      case 'manual': return Colors.blue;
      case 'coach': return Colors.green;
      case 'silent_guardian': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
```

---

## P1 TASK 2: Fix Upload Crash

### Problem
Upload button opens Apple Music library instead of file picker, then crashes the app.

### Solution
Use `FilePicker` with `FileType.custom` and explicit `.mp3` extension filter.

**DO NOT use `FileType.audio`** - this triggers Apple Music on iOS.

### File: Find the music/song upload screen

```dart
import 'package:file_picker/file_picker.dart';
import 'dart:io';

Future<void> pickAndUploadMusic() async {
  try {
    print('[UPLOAD] Opening file picker...');
    
    // CORRECT: Use FileType.custom with explicit extensions
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],  // Only MP3 files
      allowMultiple: false,
    );
    
    // WRONG - DO NOT USE:
    // type: FileType.audio,  // ❌ This opens Apple Music on iOS!
    
    if (result == null || result.files.isEmpty) {
      print('[UPLOAD] User cancelled');
      return;
    }
    
    final file = result.files.first;
    print('[UPLOAD] Selected: ${file.name}, size: ${file.size} bytes');
    
    // Validate extension
    if (!file.name.toLowerCase().endsWith('.mp3')) {
      _showError('Please select an MP3 file');
      return;
    }
    
    // Check we have a valid path
    if (file.path == null) {
      _showError('Could not access file');
      return;
    }
    
    // Read file bytes
    final bytes = await File(file.path!).readAsBytes();
    print('[UPLOAD] Read ${bytes.length} bytes');
    
    // Upload to robot
    await _uploadToRobot(file.name, bytes);
    _showSuccess('Upload complete!');
    
  } on PlatformException catch (e) {
    print('[UPLOAD] Platform error: ${e.code} - ${e.message}');
    _showError('Could not open file picker: ${e.message}');
  } catch (e, stack) {
    print('[UPLOAD] Error: $e');
    print('[UPLOAD] Stack: $stack');
    _showError('Upload failed: $e');
  }
}

void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}

void _showSuccess(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.green),
  );
}
```

**Search and remove** any usage of:
- `FileType.audio`
- `MediaPicker`
- Apple Music integration code

---

## P1 TASK 3: Fix Breed Field

### Problem
1. Breed field is MISSING from Add Dog screen
2. Breed field doesn't save in Dog Settings (API call not firing)

### Part A: Add breed to Add Dog screen

Find the Add Dog screen and add a breed TextField:

```dart
class _AddDogScreenState extends State<AddDogScreen> {
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();  // ADD THIS
  // ... other controllers ...
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... 
      body: Form(
        child: ListView(
          children: [
            // Name field (existing)
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Dog Name'),
            ),
            
            // ADD BREED FIELD
            SizedBox(height: 16),
            TextFormField(
              controller: _breedController,
              decoration: InputDecoration(
                labelText: 'Breed',
                hintText: 'e.g. Golden Retriever, Mixed, Unknown',
              ),
            ),
            
            // ... other fields (color, photo, aruco) ...
          ],
        ),
      ),
    );
  }
  
  Future<void> _saveDog() async {
    final response = await _apiService.createDog({
      'name': _nameController.text,
      'breed': _breedController.text,  // INCLUDE BREED
      'color': _selectedColor,
      'aruco_id': _arucoId,
      // ... other fields ...
    });
    
    print('[DOG] Create response: ${response.statusCode}');
    // ...
  }
}
```

### Part B: Fix breed save in Dog Settings

```dart
class _DogSettingsScreenState extends State<DogSettingsScreen> {
  final _breedController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Load existing breed
    _breedController.text = widget.dog.breed ?? '';
  }
  
  Future<void> _saveBreed() async {
    final breed = _breedController.text.trim();
    print('[DOG] Saving breed: "$breed" for dog ${widget.dogId}');
    
    try {
      final response = await _apiService.updateDog(
        dogId: widget.dogId,
        data: {'breed': breed},
      );
      
      print('[DOG] Update response: ${response.statusCode}');
      print('[DOG] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        _showSuccess('Breed saved');
      } else {
        _showError('Failed to save: ${response.statusCode}');
      }
    } catch (e) {
      print('[DOG] Error: $e');
      _showError('Error saving breed');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          // Breed field
          TextFormField(
            controller: _breedController,
            decoration: InputDecoration(
              labelText: 'Breed',
              suffixIcon: IconButton(
                icon: Icon(Icons.save),
                onPressed: _saveBreed,  // MAKE SURE THIS IS CONNECTED
              ),
            ),
            onFieldSubmitted: (_) => _saveBreed(),  // Save on enter
          ),
          // ... other settings ...
        ],
      ),
    );
  }
}
```

**Debug checklist:**
- [ ] Is `_breedController` initialized?
- [ ] Is `_saveBreed()` actually called when save button is tapped?
- [ ] Is the API endpoint correct?
- [ ] Check console for the print statements

---

## P2 TASK 4: Consolidate Login Screens

### Problem
There appear to be two login/connect screens. User gets kicked to one when phone is locked.

### Investigation

First, find all login-related screens:

```bash
# In terminal, from app root:
grep -r "class.*Login\|class.*Connect" lib/screens/
grep -r "LoginScreen\|ConnectScreen" lib/
```

### Solution

1. Identify which screen is the "real" one
2. Remove the duplicate
3. Update all navigation routes to use the single screen

```dart
// There should be ONE entry point for login/connection
class LoginScreen extends StatefulWidget {
  // This handles BOTH login and connection to robot
}

// In routes:
routes: {
  '/': (context) => LoginScreen(),  // Single entry point
  '/home': (context) => HomeScreen(),
  '/drive': (context) => DriveScreen(),
  // ... other routes - NO second login screen
}
```

---

## P2 TASK 5: iOS Background Disconnect

### Problem
When phone locks, user gets kicked to login screen within ~1 minute, even though timeout should be 5 minutes.

### Solution

Handle app lifecycle properly:

```dart
class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[LIFECYCLE] State changed to: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background
        print('[LIFECYCLE] App paused - connection should stay alive');
        // DON'T disconnect here
        break;
        
      case AppLifecycleState.resumed:
        // App coming back to foreground
        print('[LIFECYCLE] App resumed - checking connection');
        _checkAndReconnect();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }
  
  Future<void> _checkAndReconnect() async {
    final isConnected = await _connectionService.checkConnection();
    
    if (!isConnected) {
      print('[LIFECYCLE] Connection lost, attempting reconnect...');
      final reconnected = await _connectionService.reconnect();
      
      if (!reconnected) {
        print('[LIFECYCLE] Reconnect failed, showing login');
        // Only NOW show login screen
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        print('[LIFECYCLE] Reconnected successfully!');
      }
    }
  }
}
```

---

## P2 TASK 6: Video Persistence Across Screens

### Problem
Video disconnects when navigating between screens (Drive → Mission → back).

### Solution

WebRTC service should be a true singleton that persists across screen navigation.

```dart
class WebRTCService {
  // Singleton pattern
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  
  // Video should NOT be closed when screens change
  // Only close when:
  // 1. Explicitly disconnecting from robot
  // 2. App is terminating
  // 3. Switching to different robot
  
  // DON'T put close() in screen dispose()!
}

// In screens, DON'T do this:
class _DriveScreenState extends State<DriveScreen> {
  @override
  void dispose() {
    // ❌ DON'T: WebRTCService().close();
    super.dispose();
  }
}

// Instead, video lifecycle is managed at app level
class _AppState extends State<App> {
  @override
  void dispose() {
    // ✅ Close video only when app closes
    WebRTCService().close();
    super.dispose();
  }
}
```

---

## Testing Checklist

### Mode Service
- [ ] Start mission from mission menu
- [ ] Navigate to Drive screen
- [ ] Mode should show "MISSION" (not "MANUAL")
- [ ] Mission banner should appear
- [ ] Stop mission - mode should change to "IDLE"
- [ ] Now navigating to Drive should set "MANUAL"

### Upload
- [ ] Tap upload button
- [ ] FILE picker opens (not Apple Music)
- [ ] Select MP3 - uploads successfully
- [ ] Select non-MP3 - shows error
- [ ] No crash!

### Breed
- [ ] Add new dog - breed field visible
- [ ] Enter breed - saves with dog
- [ ] Edit dog settings - breed field shows existing value
- [ ] Change breed - saves successfully

### Login
- [ ] Only ONE login screen exists
- [ ] Navigation flow is clear

### Background
- [ ] Lock phone 30 seconds - should stay connected on unlock
- [ ] Lock phone 2 minutes - should auto-reconnect on unlock
- [ ] Only show login if reconnect fails

### Video
- [ ] Connect, see video
- [ ] Navigate away and back - video persists
- [ ] No manual reconnect needed
