# Build 28 - Robot Claude Tasks

**Date:** 2026-01-28
**Priority:** Mission mode protection, voice handler consolidation

---

## Context

Build 27 testing revealed that missions fail because mode changes kill the AI detection pipeline. The logs showed:
- Mission started successfully at 03:16:06
- Mode changed from mission → coach at 03:17:53 (user navigated screens)
- Mode changed from coach → manual at 03:18:18
- No more pose detections after mode change
- Mission timed out at 03:28:02

**Root cause:** Nothing protects mission mode from being changed by other app actions.

---

## P0 TASK 1: Mission Mode Lock/Unlock

### Problem
Mode can be changed while mission is active, which stops AI detection and breaks the mission.

### Solution
Add mode locking. When mission starts, lock mode. Only mission stop/complete can unlock.

### File: `core/state_manager.py`

Add these methods to StateManager class:

```python
class StateManager:
    def __init__(self):
        # ... existing init ...
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
    
    @property
    def is_mode_locked(self) -> bool:
        return self._mode_locked
    
    def set_mode(self, new_mode: str, reason: str, force: bool = False) -> bool:
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
            'reason': reason,
            'locked': self._mode_locked
        })
        return True
```

### File: `orchestrators/mission_engine.py`

Update start() and stop() to use locking:

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
    
    # ... rest of existing start logic ...
    
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

Also update the completion handler (when mission completes naturally):

```python
def _on_mission_complete(self, success: bool):
    """Called when mission completes (success or timeout)."""
    reason = 'completed' if success else 'stage_timeout'
    
    # Unlock mode
    self.state_manager.unlock_mode()
    self.state_manager.set_mode('idle', reason=f'Mission {reason}')
    
    # ... rest of completion logic ...
```

---

## P0 TASK 2: Consolidate Voice Handlers

### Problem
Two separate handlers exist:
- `call_dog` → works
- `play_voice` → crashes with "cannot access local variable 'get_usb_audio_service'"

They do the same thing. One handler = one place to fix bugs.

### File: `services/audio/voice_lookup.py` (NEW FILE)

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
        voice_type: One of VOICE_TYPES (sit, down, come, stay, no, good, treat, quiet)
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
    """
    songs_base = f"{VOICEMP3_BASE}/songs"
    
    if dog_id:
        custom_folder = f"{songs_base}/{dog_id}"
        if os.path.isdir(custom_folder):
            files = [f for f in os.listdir(custom_folder) if f.endswith('.mp3')]
            if files:
                return custom_folder
    
    return f"{songs_base}/default"


def save_custom_voice(dog_id: str, voice_type: str, audio_data: bytes) -> str:
    """Save a custom voice recording for a dog."""
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
    After deletion, get_voice_path() will automatically use defaults.
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

### File: `main_treatbot.py`

Update/replace the voice handlers:

```python
from services.audio.voice_lookup import get_voice_path
from services.audio.usb_audio_service import get_usb_audio_service  # ENSURE THIS IMPORT EXISTS

# SINGLE HANDLER for all voice playback
async def _handle_play_voice(self, params):
    """
    Unified voice playback - handles both call_dog and play_voice commands.
    
    params:
        voice_type: 'come', 'sit', 'no', 'good', 'treat', 'quiet', etc.
        dog_id: 'dog_1769441492377'
        dog_name: 'Elsa' (optional, for call_dog compatibility)
    """
    voice_type = params.get('voice_type') or params.get('command') or 'come'
    dog_id = params.get('dog_id')
    
    logger.info(f"[VOICE] Request: type={voice_type}, dog={dog_id}")
    
    # Get path using new lookup (custom first, default fallback)
    audio_path = get_voice_path(voice_type, dog_id)
    
    if audio_path:
        try:
            audio_service = get_usb_audio_service()
            audio_service.play(audio_path)
            logger.info(f"[VOICE] Playing: {audio_path}")
            return {'success': True, 'path': audio_path}
        except Exception as e:
            logger.error(f"[VOICE] Playback error: {e}")
            return {'success': False, 'error': str(e)}
    else:
        logger.error(f"[VOICE] File not found: {voice_type} for {dog_id}")
        return {'success': False, 'error': f'Voice file not found: {voice_type}'}
```

In the command handler mapping, point BOTH commands to the same handler:

```python
# Find where command handlers are registered and update:
COMMAND_HANDLERS = {
    # ... other handlers ...
    'play_voice': self._handle_play_voice,
    'call_dog': self._handle_play_voice,  # SAME HANDLER!
    # ... other handlers ...
}
```

**IMPORTANT:** Remove any separate `_handle_call_dog` method if it exists. We want ONE code path.

---

## P1 TASK 3: Verify Voice Files

Morgan already restructured the folders. Just verify everything is in place:

```bash
#!/bin/bash
# Run this to verify

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
    echo "✅ All required voice files present!"
fi

# Also check folder structure
echo ""
echo "=== Folder Structure ==="
ls -la /home/morgan/dogbot/VOICEMP3/
ls -la /home/morgan/dogbot/VOICEMP3/talks/
```

---

## P2 TASK 4: Clean Up Asyncio Errors (Optional)

The logs show `Task exception was never retrieved` errors during WebRTC TURN operations. These don't crash anything but should be cleaned up:

```python
# Wrap TURN-related async calls
async def _handle_turn_operation(self):
    try:
        await self._turn_client.allocate()
    except Exception as e:
        logger.warning(f"[WEBRTC] TURN operation failed (non-fatal): {e}")
```

---

## Testing

After implementing:

1. **Mode Lock Test:**
   - Start a mission
   - Check logs for `[MODE] Locked: Mission active: ...`
   - Try to change mode via app (should see `[MODE] BLOCKED`)
   - Stop mission
   - Check logs for `[MODE] Unlocked`
   - Mode changes should work again

2. **Voice Test:**
   - Send `play_voice` command with `voice_type: 'good'`
   - Should play `/home/morgan/dogbot/VOICEMP3/talks/default/good.mp3`
   - Send `call_dog` command
   - Should use same handler, play `come.mp3`

3. **Verify no crashes:**
   - All voice buttons should work
   - No more "cannot access local variable" errors

---

## Voice Type → File Mapping Reference

| App Button | voice_type | File |
|------------|------------|------|
| Call Dog | `come` | `come.mp3` |
| Sit | `sit` | `sit.mp3` |
| Down | `down` | `down.mp3` |
| Stay | `stay` | `stay.mp3` |
| No | `no` | `no.mp3` |
| Good | `good` | `good.mp3` |
| Treat | `treat` | `treat.mp3` |
| Quiet | `quiet` | `quiet.mp3` |
