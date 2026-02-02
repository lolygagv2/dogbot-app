# Build 28 Task Document

**Date:** 2026-01-28
**Previous Build:** 27
**Focus:** Mission mode protection, voice file restructure, mode state sync, upload fix

---

## Executive Summary

Build 27 testing revealed that missions were failing because:
1. Mode wasn't being protected during active missions
2. Drive screen auto-sets to Manual, killing mission detection
3. Voice files were in wrong folder structure (`voices/` instead of `VOICEMP3/`)
4. App screens have local mode state instead of single source of truth

---

## Log Analysis Findings

### Mission Timeline (What Actually Happened)
```
03:16:06 - start_mission: 'sit_training' → SUCCESS
03:16:06 - Stage 1: wait_for_dog started
03:17:53 - set_mode: mission → coach ← MODE CHANGE KILLED DETECTION
03:18:02 - Stage 2: wait_for_sit (dog detected)
03:18:08 - BehaviorInterpreter: "watching for 'sit'"
03:18:18 - set_mode: coach → manual ← ANOTHER MODE CHANGE
... no more pose detections ...
03:28:02 - Mission FAILED (stage_timeout)
```

**Root Cause:** Mission started, dog was detected, but mode changes killed the AI detection pipeline. The mission engine kept waiting for behavior events that would never come.

### Other Issues Found
- `good.mp3` file missing: `Audio file not found: /home/morgan/dogbot/VOICEMP3/talks/good.mp3`
- Voice files in wrong structure (using `voices/` folder)
- Upload using Apple Music picker instead of FilePicker

---

## P0 - Critical Fixes

---

### 🤖 ROBOT TASK 1: Mission Mode Lock/Unlock

**Problem:** Mode can be changed while mission is active, killing detection.

**Solution:** Mission controls mode lock. Only mission menu can lock/unlock.

**File:** `core/state_manager.py` (or wherever mode changes happen)

```python
class StateManager:
    def __init__(self):
        self._mode_locked = False
        self._mode_lock_reason = None
    
    def lock_mode(self, reason: str):
        """Lock mode - only mission system should call this."""
        self._mode_locked = True
        self._mode_lock_reason = reason
        logger.info(f"[MODE] Locked: {reason}")
    
    def unlock_mode(self):
        """Unlock mode - only mission system should call this."""
        self._mode_locked = False
        self._mode_lock_reason = None
        logger.info("[MODE] Unlocked")
    
    def set_mode(self, new_mode: str, reason: str, force: bool = False):
        """Set mode with lock protection."""
        
        # Check lock (unless force override for emergencies)
        if self._mode_locked and not force:
            logger.warning(f"[MODE] BLOCKED '{new_mode}' - mode locked: {self._mode_lock_reason}")
            
            # Notify app that mode change was rejected
            self.bus.publish('mode_change_rejected', {
                'requested': new_mode,
                'current': self._current_mode,
                'reason': self._mode_lock_reason
            })
            return False
        
        # Normal mode change
        old_mode = self._current_mode
        self._current_mode = new_mode
        logger.info(f"[MODE] Changed: {old_mode} → {new_mode} ({reason})")
        
        # Notify
        self.bus.publish('mode_changed', {
            'old': old_mode,
            'new': new_mode,
            'reason': reason
        })
        return True
```

**File:** `orchestrators/mission_engine.py`

```python
async def start(self, mission_id: str) -> bool:
    """Start a mission."""
    mission = self._load_mission(mission_id)
    if not mission:
        logger.error(f"[MISSION] Not found: {mission_id}")
        return False
    
    # Set mode to mission AND lock it
    self.state_manager.set_mode('mission', reason=f'Mission: {mission_id}')
    self.state_manager.lock_mode(f'Mission active: {mission_id}')
    
    self._running = True
    self._current_mission = mission
    # ... rest of start logic
    
    logger.info(f"[MISSION] Started: {mission_id}, mode locked to 'mission'")
    return True

async def stop(self, reason: str = 'user_stopped') -> bool:
    """Stop current mission."""
    if not self._running:
        return False
    
    mission_name = self._current_mission.name if self._current_mission else 'unknown'
    
    # Unlock mode FIRST
    self.state_manager.unlock_mode()
    
    # Then set to idle
    self.state_manager.set_mode('idle', reason=f'Mission ended: {reason}')
    
    self._running = False
    self._current_mission = None
    
    # Publish completion event
    self.bus.publish('system.mission.completed', {
        'mission': mission_name,
        'success': reason == 'completed',
        'reason': reason
    })
    
    logger.info(f"[MISSION] Stopped: {mission_name} ({reason}), mode unlocked")
    return True
```

**File:** `main_treatbot.py` - Update command handler

```python
async def _handle_start_mission(self, params):
    mission_id = params.get('mission_id') or params.get('mission_name')
    success = await self.mission_engine.start(mission_id)
    return {'success': success, 'mission_id': mission_id}

async def _handle_stop_mission(self, params):
    success = await self.mission_engine.stop(reason='user_stopped')
    return {'success': success}
```

---

### 🤖 ROBOT TASK 2: VOICEMP3 Folder Restructure

**Problem:** Voice files scattered, wrong paths, `good.mp3` missing.

**New Structure:**
```
/home/morgan/dogbot/VOICEMP3/
├── talks/
│   ├── default/           # System defaults (shipped with robot)
│   │   ├── sit.mp3
│   │   ├── down.mp3
│   │   ├── come.mp3
│   │   ├── stay.mp3
│   │   ├── no.mp3
│   │   ├── good.mp3       # CREATE THIS!
│   │   ├── treat.mp3
│   │   └── quiet.mp3
│   │
│   └── dog_XXXXX/         # Custom per-dog (user recordings)
│       └── come.mp3       # Overrides default
│
├── songs/
│   ├── default/           # Default ambient music
│   └── dog_XXXXX/         # User-uploaded songs
│
└── wimz/                  # System sounds (unchanged)
    ├── IdleMode.mp3
    ├── ManualMode.mp3
    ├── CoachMode.mp3
    └── MissionMode.mp3
```

**Migration: ALREADY DONE MANUALLY by Morgan**

Morgan has already restructured the folders and renamed good_dog.mp3 → good.mp3.

**Robot Claude: Just verify the structure exists:**

```bash
#!/bin/bash
# verify_voice_structure.sh - Quick verification only

DEFAULTS="/home/morgan/dogbot/VOICEMP3/talks/default"
REQUIRED=("come" "sit" "down" "stay" "no" "good" "treat" "quiet")

echo "=== Voice File Verification ==="
missing=0
for cmd in "${REQUIRED[@]}"; do
    file="$DEFAULTS/${cmd}.mp3"
    if [ -f "$file" ]; then
        echo "✅ $cmd.mp3"
    else
        echo "❌ $cmd.mp3 MISSING"
        missing=$((missing + 1))
    fi
done

if [ $missing -eq 0 ]; then
    echo ""
    echo "✅ All required voice files present!"
else
    echo ""
    echo "⚠️  $missing files missing - need to create"
fi
```

**Voice Command → File Mapping (for App Claude reference):**

| Button | `voice_type` | File |
|--------|--------------|------|
| Call Dog | `come` | `come.mp3` |
| Sit | `sit` | `sit.mp3` |
| Down | `down` | `down.mp3` |
| Stay | `stay` | `stay.mp3` |
| No | `no` | `no.mp3` |
| Good | `good` | `good.mp3` |
| Treat | `treat` | `treat.mp3` |
| Quiet | `quiet` | `quiet.mp3` |

**File:** `services/audio/voice_lookup.py` (new file)

```python
"""
Voice file lookup with custom-first, default-fallback logic.
"""
import os
import logging

logger = logging.getLogger(__name__)

VOICEMP3_BASE = "/home/morgan/dogbot/VOICEMP3"

# Valid voice commands
VOICE_TYPES = ['sit', 'down', 'come', 'stay', 'no', 'good', 'treat', 'quiet']


def get_voice_path(voice_type: str, dog_id: str = None) -> str | None:
    """
    Get path to voice file. Checks custom first, falls back to default.
    
    Args:
        voice_type: One of VOICE_TYPES
        dog_id: e.g. 'dog_1769441492377' or None for default only
    
    Returns:
        Path to mp3 file, or None if not found
    """
    if voice_type not in VOICE_TYPES:
        logger.warning(f"[VOICE] Unknown voice type: {voice_type}")
    
    talks_base = f"{VOICEMP3_BASE}/talks"
    
    # 1. Try custom dog-specific file first
    if dog_id:
        custom_path = f"{talks_base}/{dog_id}/{voice_type}.mp3"
        if os.path.exists(custom_path):
            logger.debug(f"[VOICE] Using custom: {custom_path}")
            return custom_path
    
    # 2. Fall back to default
    default_path = f"{talks_base}/default/{voice_type}.mp3"
    if os.path.exists(default_path):
        logger.debug(f"[VOICE] Using default: {default_path}")
        return default_path
    
    # 3. Not found
    logger.error(f"[VOICE] File not found: {voice_type} (dog={dog_id})")
    return None


def get_songs_folder(dog_id: str = None) -> str:
    """
    Get folder for songs. Uses custom if exists and has files, else default.
    
    Args:
        dog_id: e.g. 'dog_1769441492377' or None
    
    Returns:
        Path to songs folder
    """
    songs_base = f"{VOICEMP3_BASE}/songs"
    
    if dog_id:
        custom_folder = f"{songs_base}/{dog_id}"
        if os.path.isdir(custom_folder):
            files = [f for f in os.listdir(custom_folder) if f.endswith('.mp3')]
            if files:
                logger.debug(f"[SONGS] Using custom folder: {custom_folder} ({len(files)} files)")
                return custom_folder
    
    default_folder = f"{songs_base}/default"
    logger.debug(f"[SONGS] Using default folder: {default_folder}")
    return default_folder


def save_custom_voice(dog_id: str, voice_type: str, audio_data: bytes) -> str:
    """
    Save a custom voice recording for a dog.
    
    Returns:
        Path where file was saved
    """
    dog_folder = f"{VOICEMP3_BASE}/talks/{dog_id}"
    os.makedirs(dog_folder, exist_ok=True)
    
    file_path = f"{dog_folder}/{voice_type}.mp3"
    with open(file_path, 'wb') as f:
        f.write(audio_data)
    
    logger.info(f"[VOICE] Saved custom voice: {file_path}")
    return file_path


def restore_dog_to_defaults(dog_id: str) -> dict:
    """
    Delete all custom voice/song files for a dog.
    
    How it works:
    - Deletes the dog's custom folders (talks/{dog_id}/ and songs/{dog_id}/)
    - The get_voice_path() function will then automatically fall back to default/
    - No need to "restore" anything - just remove custom = defaults used
    
    Returns:
        Dict with deleted file counts
    """
    import shutil
    
    deleted = {'talks': 0, 'songs': 0}
    
    talks_custom = f"{VOICEMP3_BASE}/talks/{dog_id}"
    if os.path.exists(talks_custom):
        files = os.listdir(talks_custom)
        deleted['talks'] = len(files)
        shutil.rmtree(talks_custom)
        logger.info(f"[VOICE] Removed {len(files)} custom talks for {dog_id}")
    
    songs_custom = f"{VOICEMP3_BASE}/songs/{dog_id}"
    if os.path.exists(songs_custom):
        files = os.listdir(songs_custom)
        deleted['songs'] = len(files)
        shutil.rmtree(songs_custom)
        logger.info(f"[VOICE] Removed {len(files)} custom songs for {dog_id}")
    
    return deleted
```

**File:** `main_treatbot.py` - Update play_voice handler AND consolidate with call_dog

```python
from services.audio.voice_lookup import get_voice_path

# CONSOLIDATE: One handler for all voice playback
async def _handle_play_voice(self, params):
    """
    Unified voice playback - handles both call_dog and voice commands.
    
    params:
        voice_type: 'come', 'sit', 'no', 'good', 'treat', 'quiet', etc.
        dog_id: 'dog_1769441492377'
        dog_name: 'Elsa' (optional, for call_dog compatibility)
    """
    voice_type = params.get('voice_type') or params.get('command') or 'come'
    dog_id = params.get('dog_id')
    
    # Get path using new lookup (custom first, default fallback)
    audio_path = get_voice_path(voice_type, dog_id)
    
    if audio_path:
        audio_service = get_usb_audio_service()  # Make sure this import exists!
        audio_service.play(audio_path)
        logger.info(f"[VOICE] Playing: {audio_path}")
        return {'success': True, 'path': audio_path}
    else:
        logger.error(f"[VOICE] File not found: {voice_type} for {dog_id}")
        return {'success': False, 'error': f'Voice file not found: {voice_type}'}

# In command handler mapping - BOTH commands use same handler
COMMAND_HANDLERS = {
    'play_voice': self._handle_play_voice,
    'call_dog': self._handle_play_voice,  # SAME HANDLER - no separate code paths!
    # ... other handlers
}
```

**Why consolidate?**
- `call_dog` was working, `play_voice` was crashing with import error
- They do the exact same thing (play MP3 for dog)
- One handler = one place to fix bugs
```

---

### 📱 APP TASK 1: Single Source of Truth for Mode

**Problem:** Each screen has local mode state. Drive screen auto-sets Manual.

**Solution:** Global ModeService that all screens read from.

**File:** `lib/services/mode_service.dart` (new file)

```dart
import 'package:flutter/foundation.dart';

class ModeService extends ChangeNotifier {
  static final ModeService _instance = ModeService._internal();
  factory ModeService() => _instance;
  ModeService._internal();
  
  String _currentMode = 'idle';
  String? _activeMissionId;
  String? _activeMissionName;
  bool _modeLocked = false;
  
  // Getters
  String get currentMode => _currentMode;
  bool get isMissionActive => _activeMissionId != null;
  bool get isModeLocked => _modeLocked;
  String? get activeMissionId => _activeMissionId;
  String? get activeMissionName => _activeMissionName;
  
  /// Called when robot sends mode_changed event
  void updateFromRobot(Map<String, dynamic> data) {
    final newMode = data['new'] as String? ?? data['mode'] as String?;
    if (newMode != null && newMode != _currentMode) {
      _currentMode = newMode;
      print('[MODE] Updated from robot: $_currentMode');
      notifyListeners();
    }
  }
  
  /// Called when robot sends mode_change_rejected event
  void handleModeRejected(Map<String, dynamic> data) {
    final reason = data['reason'] as String?;
    print('[MODE] Change rejected: $reason');
    // Could show snackbar/toast here
  }
  
  /// Called when mission starts
  void missionStarted(String missionId, String missionName) {
    _activeMissionId = missionId;
    _activeMissionName = missionName;
    _modeLocked = true;
    _currentMode = 'mission';
    print('[MODE] Mission started: $missionName, mode locked');
    notifyListeners();
  }
  
  /// Called when mission ends
  void missionEnded() {
    _activeMissionId = null;
    _activeMissionName = null;
    _modeLocked = false;
    _currentMode = 'idle';
    print('[MODE] Mission ended, mode unlocked');
    notifyListeners();
  }
  
  /// Request mode change (will be rejected if locked)
  Future<bool> requestModeChange(String newMode) async {
    if (_modeLocked) {
      print('[MODE] Cannot change to $newMode - mission active');
      return false;
    }
    
    // Send to robot
    // Robot will send mode_changed event back
    return true;
  }
}
```

**File:** `lib/main.dart` - Register provider

```dart
import 'services/mode_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ModeService()),
        // ... other providers
      ],
      child: MyApp(),
    ),
  );
}
```

**File:** `lib/services/websocket_service.dart` - Handle mode events

```dart
void _handleMessage(Map<String, dynamic> message) {
  final type = message['type'];
  
  switch (type) {
    case 'mode_changed':
    case 'status_update':
      ModeService().updateFromRobot(message['data'] ?? message);
      break;
      
    case 'mode_change_rejected':
      ModeService().handleModeRejected(message['data'] ?? message);
      break;
      
    case 'mission_progress':
      final data = message['data'];
      if (data['action'] == 'started') {
        ModeService().missionStarted(
          data['mission_id']?.toString() ?? '',
          data['mission'] ?? '',
        );
      } else if (data['action'] == 'completed' || data['action'] == 'stopped') {
        ModeService().missionEnded();
      }
      break;
    
    // ... other handlers
  }
}
```

**File:** `lib/screens/drive_screen.dart` - Respect mode state

```dart
class _DriveScreenState extends State<DriveScreen> {
  @override
  void initState() {
    super.initState();
    
    // DON'T auto-set mode to manual!
    // Check current mode instead
    final modeService = context.read<ModeService>();
    
    if (modeService.isMissionActive) {
      // Show mission indicator, maybe limit some controls
      print('[DRIVE] Mission active: ${modeService.activeMissionName}');
    }
    
    // Only request manual if NOT in mission
    if (!modeService.isModeLocked) {
      _requestManualMode();
    }
  }
  
  void _requestManualMode() {
    // Send mode change request
    // This will be rejected if mission is active
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ModeService>(
      builder: (context, modeService, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Drive'),
            actions: [
              // Show current mode
              Chip(
                label: Text(modeService.currentMode.toUpperCase()),
                backgroundColor: _getModeColor(modeService.currentMode),
              ),
              if (modeService.isMissionActive)
                Chip(
                  label: Text('🎯 ${modeService.activeMissionName}'),
                  backgroundColor: Colors.orange,
                ),
            ],
          ),
          body: Stack(
            children: [
              // Normal drive controls
              _buildDriveControls(),
              
              // Mission active overlay (optional)
              if (modeService.isMissionActive)
                _buildMissionOverlay(modeService.activeMissionName!),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMissionOverlay(String missionName) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.orange.withOpacity(0.9),
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(Icons.pets, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mission Active: $missionName',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: _stopMission,
              child: Text('STOP', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getModeColor(String mode) {
    switch (mode) {
      case 'mission': return Colors.orange;
      case 'manual': return Colors.blue;
      case 'coach': return Colors.green;
      default: return Colors.grey;
    }
  }
}
```

---

## P1 - Important Fixes

---

### 📱 APP TASK 2: Fix Upload Crash (FilePicker not Apple Music)

**Problem:** Upload button opens Apple Music library, then crashes.

**Solution:** Use FilePicker with MP3 filter.

**File:** Find the music upload screen/function

```dart
import 'package:file_picker/file_picker.dart';
import 'dart:io';

Future<void> pickAndUploadMusic() async {
  try {
    print('[UPLOAD] Opening file picker...');
    
    // Use FilePicker with custom extension filter - NOT FileType.audio!
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],  // Only MP3 files
      allowMultiple: false,
    );
    
    if (result == null || result.files.isEmpty) {
      print('[UPLOAD] Cancelled');
      return;
    }
    
    final file = result.files.first;
    print('[UPLOAD] Selected: ${file.name}, size: ${file.size}');
    
    // Validate extension (belt + suspenders)
    if (!file.name.toLowerCase().endsWith('.mp3')) {
      _showError('Please select an MP3 file');
      return;
    }
    
    // Read file bytes
    if (file.path == null) {
      _showError('Could not read file');
      return;
    }
    
    final bytes = await File(file.path!).readAsBytes();
    print('[UPLOAD] Read ${bytes.length} bytes');
    
    // Upload to robot
    await _uploadToRobot(file.name, bytes);
    
  } on PlatformException catch (e) {
    print('[UPLOAD] Platform error: ${e.code} - ${e.message}');
    _showError('Could not open file picker');
  } catch (e, stack) {
    print('[UPLOAD] Error: $e');
    print('[UPLOAD] Stack: $stack');
    _showError('Upload failed');
  }
}

void _showError(String message) {
  // Show snackbar or dialog
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
```

**IMPORTANT:** Remove any code using:
- `FileType.audio` (triggers Apple Music on iOS)
- `MediaPicker`
- Apple Music integration

---

### 📱 APP TASK 3: Fix Breed Field (Add to BOTH Add Dog AND Settings)

**Problem:** 
1. Breed field doesn't save in Settings (API call not firing)
2. Breed field is MISSING from Add Dog screen entirely

**Solution:** 

**Part A: Add breed to Add Dog screen**

The Add Dog screen should have:
- Dog name ✅
- Dog photo ✅
- Dog color ✅
- ARUCO marker ID ✅
- **Breed field** ❌ MISSING - ADD THIS

```dart
// In Add Dog screen, add breed TextField
TextFormField(
  controller: _breedController,
  decoration: InputDecoration(
    labelText: 'Breed',
    hintText: 'e.g. Golden Retriever, Mixed, Unknown',
  ),
),

// Include in the create dog API call
final response = await _apiService.createDog({
  'name': _nameController.text,
  'color': _selectedColor,
  'aruco_id': _arucoId,
  'breed': _breedController.text,  // ADD THIS
  // ... other fields
});
```

**Part B: Fix breed save in Dog Settings**

```dart
// Add debug logging to find where it's broken
Future<void> _saveBreed() async {
  final breed = _breedController.text.trim();
  print('[DOG] Saving breed: "$breed" for dog ${widget.dogId}');
  
  if (breed.isEmpty) {
    print('[DOG] Breed is empty, skipping');
    return;
  }
  
  try {
    final response = await _apiService.updateDog(
      dogId: widget.dogId,
      data: {'breed': breed},
    );
    
    print('[DOG] Update response: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      _showSuccess('Breed saved');
    } else {
      _showError('Failed to save breed');
    }
  } catch (e) {
    print('[DOG] Error saving breed: $e');
    _showError('Error saving breed');
  }
}

// Make sure this is called!
// Check: Is there an onSave callback? Is it wired up to a button?
// Check: Is the TextField controller actually connected?
```

---

### 🤖 ROBOT TASK 3: Verify Voice Files Exist (Quick Check)

**Morgan already restructured folders and renamed good_dog.mp3 → good.mp3**

Just run verification after code changes to confirm everything is in place:

```bash
# Quick verification
ls -la /home/morgan/dogbot/VOICEMP3/talks/default/

# Should see: come.mp3, sit.mp3, down.mp3, stay.mp3, no.mp3, good.mp3, treat.mp3, quiet.mp3
```

---

## P2 - Stability / Investigation

---

### 📱 APP TASK 4: Consolidate Login/Connect Screens

**Problem:** There are TWO login/connect screens. User gets kicked to one when returning from iOS background.

**Fix:** 
1. Find both screens in the codebase
2. Merge into ONE screen
3. Ensure consistent navigation

```dart
// Search for duplicate screens
// grep -r "LoginScreen\|ConnectScreen\|login\|connect" lib/screens/
```

---

### 📱 APP TASK 5: iOS Background Disconnect (Aggressive Timeout)

**Problem:** When phone locks (iOS background), user gets kicked out within ~1 minute even though timeout should be 5 minutes.

**Investigation:**
1. Is WebSocket being closed when app goes to background?
2. Is there a heartbeat that stops?
3. Is iOS killing the connection?

**Possible fixes:**
```dart
// In app lifecycle handler
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    // App going to background
    print('[LIFECYCLE] App paused - keeping connection alive');
    // Maybe send a "going_to_background" message to robot
    // Start a background task to maintain heartbeat (if iOS allows)
  }
  
  if (state == AppLifecycleState.resumed) {
    // App coming back
    print('[LIFECYCLE] App resumed - checking connection');
    if (!_isConnected) {
      // Auto-reconnect instead of showing login screen
      _attemptReconnect();
    }
  }
}

Future<void> _attemptReconnect() async {
  // Try to reconnect silently
  // Only show login screen if reconnect fails
}
```

---

### 📱 APP TASK 6: Video Feed Drops on Screen Navigation

**Problem:** Video disconnects when navigating between screens (Drive → Mission → back), takes 3+ seconds to reconnect or requires manual retry.

**Root cause possibilities:**
1. Each screen creates new WebRTC session instead of sharing one
2. Screen dispose() is closing the video connection
3. No session persistence across navigation

**Investigation:**
```dart
// Check if WebRTC service is singleton or created per-screen
// Should be SINGLETON - one video session for entire app

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  
  // Video should NOT be closed when navigating screens
  // Only close when explicitly disconnecting from robot
}
```

**Fix approach:**
1. Make WebRTC service a true singleton
2. Don't close video on screen navigation
3. Only close on explicit disconnect or app termination
4. Add auto-reconnect if video drops

---

### 🤖 ROBOT TASK 4: Clean Up Asyncio Errors

**Problem:** Logs show `Task exception was never retrieved` errors during WebRTC.

**These are warnings, not crashes, but should be cleaned up:**

```python
# Wrap TURN-related async calls in try/except
async def _handle_turn_operation(self):
    try:
        await self._turn_client.allocate()
    except Exception as e:
        logger.warning(f"[WEBRTC] TURN operation failed: {e}")
        # Don't crash, just log and continue
```

---

## Testing Checklist

### Mission Mode Lock
- [ ] Start mission from mission menu
- [ ] Navigate to Drive screen - should show "Mission Active" indicator
- [ ] Mode should stay 'mission', NOT switch to 'manual'
- [ ] Try buttons that change mode - should be blocked with message
- [ ] Stop mission from mission menu - mode should unlock and go to 'idle'
- [ ] Now Drive screen can switch to 'manual'

### Voice Files
- [ ] Verify `VOICEMP3/talks/default/` has all 8 voice files
- [ ] Test "Good" button - should play audio ✅
- [ ] Test "No" button - should play audio
- [ ] Test "Treat" button - should play audio
- [ ] Test "Call Dog" - should play custom or default come.mp3
- [ ] All buttons use same code path (no separate call_dog handler)

### Upload
- [ ] Tap upload button - should open FILE picker (not Apple Music)
- [ ] Select non-MP3 file - should show error
- [ ] Select MP3 file - should upload successfully
- [ ] No crash!

### Mode Display
- [ ] Mode chip visible on Drive screen
- [ ] Mode updates when robot sends mode_changed
- [ ] All screens show same mode (single source of truth)

### Breed Field
- [ ] Add new dog - breed field should be present
- [ ] Enter breed during add - should save with dog
- [ ] Edit breed in dog settings - should save
- [ ] Check console for API call on save

### Video Stability
- [ ] Connect to robot, see video
- [ ] Navigate to Mission screen and back - video should NOT disconnect
- [ ] Navigate to Settings and back - video should persist
- [ ] If video drops, should auto-reconnect quickly (not require manual retry)

### iOS Background Handling
- [ ] Lock phone for 30 seconds, unlock - should still be connected (or auto-reconnect)
- [ ] Lock phone for 2 minutes, unlock - should still be connected (or auto-reconnect)
- [ ] Should NOT show login screen unless actually disconnected for 5+ minutes

### Login Screen
- [ ] Only ONE login/connect screen exists
- [ ] Clear navigation flow to/from it

---

## Files to Modify Summary

### Robot
| File | Changes |
|------|---------|
| `core/state_manager.py` | Add lock_mode/unlock_mode, protect set_mode |
| `orchestrators/mission_engine.py` | Auto-lock on start, unlock on stop |
| `services/audio/voice_lookup.py` | NEW FILE - voice path lookup logic |
| `main_treatbot.py` | Consolidate play_voice + call_dog into ONE handler |
| `VOICEMP3/` | VERIFY structure only (already done manually) |

### App
| File | Changes |
|------|---------|
| `lib/services/mode_service.dart` | NEW FILE - global mode state |
| `lib/main.dart` | Register ModeService provider |
| `lib/services/websocket_service.dart` | Handle mode events, update ModeService |
| `lib/screens/drive_screen.dart` | Respect mode lock, show mission indicator, DON'T auto-set manual |
| `lib/screens/music_upload_screen.dart` | Fix FilePicker (use FileType.custom not FileType.audio) |
| `lib/screens/add_dog_screen.dart` | ADD breed field |
| `lib/screens/dog_settings_screen.dart` | FIX breed save (ensure API call fires) |
| `lib/screens/login_screen.dart` | CONSOLIDATE with connect screen |
| `lib/screens/connect_screen.dart` | MERGE into login_screen, delete this |
| `lib/services/webrtc_service.dart` | Make singleton, don't close on screen navigation |

### Relay
No changes needed this build.

---

## API Contract Additions

```yaml
# New events from robot

mode_change_rejected:
  type: "mode_change_rejected"
  data:
    requested: "manual"
    current: "mission"  
    reason: "Mission active: sit_training"

# Updated mission_progress includes lock status
mission_progress:
  type: "mission_progress"
  data:
    action: "started" | "stage_changed" | "completed" | "stopped"
    mission: "sit_training"
    mission_id: 11
    mode_locked: true
```

---

## Notes

- Mission mode protection is the #1 priority - without it, missions will never work
- Voice file restructure should be done once and forgotten
- Mode state sync affects multiple screens - test thoroughly
- Upload crash is embarrassing for demos - fix before any investor meetings
