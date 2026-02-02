# Build 40 - App Claude Instructions

**Date:** February 2, 2026
**Based on:** Build 39 test results cross-referenced across all three Claude instances
**Build 39 test window:** 21:01-21:22 local / 02:01-02:22 UTC

---

## What's Actually Broken on Your Side

Good news first: Build 39 shows the app is doing a lot right. Coach commands route correctly, scheduler backend works, and mission UI logic is structurally sound. Most visible failures trace to the robot sending wrong field names.

That said, there are real app bugs to fix — especially the MP3 upload.

---

## Architecture Rules (Non-Negotiable)

- App is a thin display layer — show what robot sends, nothing more
- NEVER send commands during screen navigation (dispose, PopScope, etc.)
- Commands fire ONLY from explicit user button taps
- Trust robot state, don't cache or override it
- HTTP for file transfers, not WebSocket

---

## P0-A1: Fix MP3 Upload 422 Error (ROOT CAUSE CONFIRMED)

### The Problem

MP3 upload returns **422 Unprocessable Entity**. We confirmed this live:
- ✅ Nginx is fixed (no more 413)
- ✅ Request reaches FastAPI relay
- ✅ Auth token is accepted
- ❌ FastAPI rejects the form data — missing required field

### Root Cause

The relay endpoint requires **three** form fields. The app is almost certainly not sending `device_id`:

```python
# Relay's endpoint signature (confirmed from server code):
async def upload_music(
    file: UploadFile = File(...),      # REQUIRED
    dog_id: str = Form(...),           # REQUIRED
    device_id: str = Form(...),        # REQUIRED ← THIS IS MISSING
    user: dict = Depends(get_current_user)
)
```

If ANY of these three fields is missing, FastAPI returns 422.

### What to Do

```bash
# Find your upload code
grep -rn "music/upload\|uploadMP3\|uploadSong\|MultipartRequest" lib/
```

Fix the upload to include all three fields:

```dart
Future<void> uploadMP3(File file, String dogId, String deviceId) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$relayBaseUrl/api/music/upload'),
  );
  request.headers['Authorization'] = 'Bearer $token';
  request.files.add(await http.MultipartFile.fromPath('file', file.path));
  request.fields['dog_id'] = dogId;
  request.fields['device_id'] = deviceId;  // ← ADD THIS

  try {
    final response = await request.send();
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      // json contains: {"status": "ok", "file_id": "...", "message": "..."}
      showSuccess("Song uploaded");
    } else {
      final body = await response.stream.bytesToString();
      showError("Upload failed: ${response.statusCode} - $body");
    }
  } catch (e) {
    showError("Upload error: $e");
  }
}
```

### Also Check: Is it Still Using WebSocket?

```bash
grep -rn "upload_song\|audio_upload" lib/
```

If the app is still sending MP3s via WebSocket `upload_song` command instead of HTTP POST, that's wrong — the relay rejects WebSocket messages over 1MB. Switch to HTTP multipart as shown above.

### What Happens After Upload Succeeds

The relay stages the file and sends a `download_song` command to the robot. The robot fetches it via HTTP GET. Then the relay forwards an `upload_complete` event back to you:

```json
{"type": "upload_complete", "success": true, "filename": "song.mp3", "device_id": "wimz_robot_01"}
```

Make sure you have a handler for `upload_complete` and `upload_error` events.

---

## P0-A2: Defensive Handling of NULL mission_progress

### The Problem

Robot sends `mission_progress` with all NULL values. App gets stuck showing "Initializing" forever because `action` is null.

The **root fix** is on Robot (they're renaming fields). But you need defensive code so the app doesn't freeze.

### What to Do

In `missions_provider.dart`, in the `_onWsEvent` handler for `mission_progress`:

```dart
case 'mission_progress':
  final action = event.data['action'] as String?;
  final status = event.data['status'] as String?;

  // DEFENSIVE: If we get mission_progress with null action while
  // we're in 'starting' state, treat as implicit 'started'
  if (action == null && state.currentProgress?.status == 'starting') {
    _updateState(state.copyWith(
      currentProgress: MissionProgress(
        status: status ?? 'running',
        stageNumber: event.data['stage_number'] as int? ?? 1,
        totalStages: event.data['total_stages'] as int? ?? 1,
        missionId: event.data['mission_id'] as String? ?? 'unknown',
      ),
    ));
    return;
  }

  // DEFENSIVE: If all fields are null, show error instead of stuck forever
  if (action == null && status == null) {
    _updateState(state.copyWith(
      currentProgress: MissionProgress(
        status: 'error',
        errorMessage: 'Robot sent incomplete mission data',
      ),
    ));
    return;
  }

  // Normal handling continues below...
```

### Also Fix: Verification Timer

Extend the start_mission verification timer from 3 to 5 seconds. If no valid `mission_progress` arrives in time, show "Mission failed to start" instead of leaving the UI in a weird state.

---

## P0-A3: Confirm Ghost Commands Are Gone

### Context

Build 38 required killing all ghost commands. Build 39 testing doesn't show explicit evidence of ghost commands — **this may already be fixed.**

### What to Verify

```bash
grep -rn "dispose\|PopScope\|onPopInvokedWithResult\|deactivate" lib/ | grep -i "stop_mission\|stop_coach\|set_mode\|sendCommand"
```

If this returns ANY results, those are ghost commands — remove them. If it returns nothing, you're clean.

Also check the duplicate `stopCoaching()` bug:

```bash
grep -rn "stopCoaching" lib/
```

Should appear in exactly one lifecycle handler per screen, not two.

---

## P1-A4: Schedule Created Handler

### The Problem

Relay logs prove schedule creation succeeded:
```
02:19:35 [ROUTE] App -> Robot: create_schedule
02:19:35 [ROUTE] Robot -> App: schedule_created
02:19:35 [EVENT-OK] schedule_created delivered to 1 app(s)
```

But user saw "failed to create schedule."

### What to Do

```bash
grep -rn "schedule_created" lib/
```

Likely issues:
1. No handler exists for `schedule_created` events
2. Handler exists but uses wrong field names
3. Timeout timer fires before the event arrives

Fix:

```dart
case 'schedule_created':
  _scheduleCreateTimer?.cancel();
  _updateState(state.copyWith(
    scheduleStatus: 'created',
    schedules: [...state.schedules, Schedule.fromJson(event.data)],
  ));
  break;
```

---

## P2-A5: Remove GET /missions Call to Relay

### The Problem

App calls `GET /missions` on the relay → 404. The relay doesn't have this endpoint.

### What to Do

Robot is adding a `/missions` endpoint in Build 40. For now, either:
- Route via WebSocket: `ws.sendCommand('list_missions', {})`
- Hardcode the mission catalog temporarily
- Stop calling the non-existent relay endpoint

---

## DO NOT Do These Things

1. **Do NOT add "smart" state inference.** Don't guess what the robot meant when it sends null. Show an error.
2. **Do NOT add optimistic UI updates for missions.** Wait for robot confirmation.
3. **Do NOT add any new commands to screen lifecycle handlers.** No dispose() side-effects.
4. **Do NOT restructure the mission provider.** Just add defensive null handling.

---

## Testing Checklist

### Before Building
```bash
# No ghost commands in lifecycle handlers
grep -rn "dispose\|PopScope" lib/ | grep -i "stop_\|set_mode\|sendCommand"
# Should return NOTHING

# Schedule handler exists
grep -rn "schedule_created" lib/
# Should show a handler

# MP3 upload sends all 3 fields via HTTP
grep -rn "device_id\|dog_id" lib/ | grep -i "upload\|music\|multipart"
# Should show both fields in the upload code

# No WebSocket upload_song
grep -rn "upload_song" lib/
# Should return NOTHING (switched to HTTP)
```

### Live Test Sequence
1. Upload MP3 → Should succeed (no 413, no 422)
2. Start mission → If robot sends null data, app shows error (not "Initializing" forever)
3. Navigate away from mission → Navigate back → UI reflects robot's actual state
4. Create schedule → Should show success
5. Start coach → Navigate away → No duplicate stop_coach in relay logs

---

*Build 40 — Fix the upload fields. Add defensive null handling. Verify ghost commands are gone.*
