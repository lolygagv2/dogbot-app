# WIM-Z App UI Spec v2.0 - Tesla-Inspired Features

> **For Claude Code**: Read this spec and implement the features described below.
> Reference the existing app structure in ~/wimzapp and build on top of it.

---

## Overview

We're adding Tesla app-inspired features to the WIM-Z dog training robot app:

1. **Notifications Center** - Event history with icons
2. **Dog Profile Page** - Dog info, stats, quick mission launch
3. **Analytics Dashboard** - Graphs, trends, goals
4. **Video Gallery** - Review, tag, share clips
5. **Live Stream** (already scaffolded, refine it)

---

## 1. Notifications Center

### Purpose
Show a chronological feed of events from the robot, similar to Tesla's activity feed.

### Screen: `lib/presentation/screens/notifications/notifications_screen.dart`

### Event Types & Icons

| Event Type | Icon | Color | Description |
|------------|------|-------|-------------|
| `bark` | Custom dog barking icon | `Colors.orange` | Dog barked |
| `sit` | Dog sitting silhouette | `AppTheme.accent` (green) | Dog sat (goal achieved) |
| `lie_down` | Dog lying down | `AppTheme.primary` (cyan) | Dog lying/relaxed |
| `stand` | Dog standing | `Colors.amber` | Dog standing |
| `treat_dispensed` | Bone icon | `AppTheme.accent` | Treat was given |
| `mission_started` | Play circle | `AppTheme.primary` | Mission began |
| `mission_completed` | Checkmark circle | `AppTheme.accent` | Mission succeeded |
| `mission_failed` | X circle | `AppTheme.error` | Mission failed |
| `low_battery` | Battery low | `AppTheme.error` | Battery < 20% |
| `alert` | Warning triangle | `Colors.orange` | General alert |
| `happy` | Happy dog face | `AppTheme.accent` | Positive behavior detected |
| `connected` | Wifi | `AppTheme.accent` | Robot came online |
| `disconnected` | Wifi off | `AppTheme.error` | Robot went offline |

### Data Model: `lib/data/models/notification_event.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_event.freezed.dart';
part 'notification_event.g.dart';

enum NotificationEventType {
  bark,
  sit,
  lieDown,
  stand,
  treatDispensed,
  missionStarted,
  missionCompleted,
  missionFailed,
  lowBattery,
  alert,
  happy,
  connected,
  disconnected,
}

@freezed
class NotificationEvent with _$NotificationEvent {
  const factory NotificationEvent({
    required String id,
    required NotificationEventType type,
    required DateTime timestamp,
    required String title,
    String? subtitle,
    String? dogId,
    String? missionId,
    String? videoClipId,
    Map<String, dynamic>? metadata,
    @Default(false) bool isRead,
  }) = _NotificationEvent;

  factory NotificationEvent.fromJson(Map<String, dynamic> json) =>
      _$NotificationEventFromJson(json);
}
```

### UI Layout

```
┌─────────────────────────────────────┐
│ ← Notifications                     │
├─────────────────────────────────────┤
│ Today                               │
├─────────────────────────────────────┤
│ 🦴 Treat Dispensed          2:34 PM │
│    Max earned a reward for sitting  │
├─────────────────────────────────────┤
│ 🐕 Sitting Detected         2:33 PM │
│    94% confidence                   │
├─────────────────────────────────────┤
│ 🔔 Barking Alert            1:15 PM │
│    3 barks detected                 │
├─────────────────────────────────────┤
│ Yesterday                           │
├─────────────────────────────────────┤
│ ✓ Mission Completed        11:30 AM │
│    "Sit Training" - 5/5 treats      │
├─────────────────────────────────────┤
│ ▶ Mission Started          11:00 AM │
│    "Sit Training"                   │
└─────────────────────────────────────┘
```

### Features
- Group by day (Today, Yesterday, This Week, Earlier)
- Tap notification to navigate to related screen (video clip, mission, etc.)
- Pull to refresh
- Mark all as read
- Filter by event type
- Badge count on bottom nav icon

---

## 2. Dog Profile Page

### Purpose
Central hub for a specific dog's information, stats, and quick actions.

### Screen: `lib/presentation/screens/dog_profile/dog_profile_screen.dart`

### Data Model: `lib/data/models/dog_profile.dart`

```dart
@freezed
class DogProfile with _$DogProfile {
  const factory DogProfile({
    required String id,
    required String name,
    String? breed,
    String? photoUrl,
    DateTime? birthDate,
    double? weight,
    String? notes,
    @Default([]) List<String> goals,
    String? lastMissionId,
    DateTime? createdAt,
  }) = _DogProfile;

  factory DogProfile.fromJson(Map<String, dynamic> json) =>
      _$DogProfileFromJson(json);
}
```

### UI Layout

```
┌─────────────────────────────────────┐
│ ← Dog Profile                    ⚙️ │
├─────────────────────────────────────┤
│                                     │
│         ┌───────────┐               │
│         │   🐕📷    │               │  ← Dog photo (tap to change)
│         │   MAX     │               │
│         └───────────┘               │
│      Golden Retriever · 3 years     │
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ ▶ LAUNCH LAST MISSION           │ │  ← Primary CTA button
│ │   "Sit Training" - ran 2h ago   │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│                                     │
│  Today's Summary                    │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   │
│  │  5  │ │  3  │ │ 12  │ │ 85% │   │
│  │Treat│ │Sits │ │Bark│ │Goal │   │
│  └─────┘ └─────┘ └─────┘ └─────┘   │
│                                     │
├─────────────────────────────────────┤
│  Quick Actions                      │
│  ┌────────┐ ┌────────┐ ┌────────┐  │
│  │📊 Stats│ │🎯 Goals│ │📹 Video│  │
│  └────────┘ └────────┘ └────────┘  │
├─────────────────────────────────────┤
│  Recent Activity                    │
│  • Completed "Sit Training" - 2h    │
│  • 3 treats earned today            │
│  • Barking reduced 15% this week    │
└─────────────────────────────────────┘
```

### Features
- Edit dog info (name, breed, photo, notes)
- Quick launch last/favorite mission
- Today's stats summary cards
- Navigation to detailed stats, goals, videos
- Recent activity feed (last 5 events)

---

## 3. Analytics Dashboard

### Purpose
Visualize dog behavior trends, training progress, and goals.

### Screen: `lib/presentation/screens/analytics/analytics_screen.dart`

### Dependencies
Add to pubspec.yaml (already included):
```yaml
fl_chart: ^0.66.0
```

### Charts to Implement

#### 3.1 Barks Per Session (Line Chart)
- X-axis: Date (last 7/30 days)
- Y-axis: Bark count
- Goal line overlay (if set)

#### 3.2 Training Success Rate (Bar Chart)
- X-axis: Mission type
- Y-axis: Success percentage
- Color coded: green > 80%, yellow 50-80%, red < 50%

#### 3.3 Treats Dispensed (Area Chart)
- X-axis: Date
- Y-axis: Treat count
- Show daily limit line

#### 3.4 Behavior Distribution (Pie Chart)
- Segments: Sitting, Standing, Lying, Barking, Unknown
- Show percentages

#### 3.5 Goal Progress (Circular Progress Indicators)
- Multiple circular gauges for each active goal
- Example: "Reduce barking to < 5/day" - 60% complete

### Data Model: `lib/data/models/analytics_data.dart`

```dart
@freezed
class DailyStats with _$DailyStats {
  const factory DailyStats({
    required DateTime date,
    required int barkCount,
    required int sitCount,
    required int treatCount,
    required int missionCount,
    required int missionSuccessCount,
    required Duration totalActiveTime,
  }) = _DailyStats;

  factory DailyStats.fromJson(Map<String, dynamic> json) =>
      _$DailyStatsFromJson(json);
}

@freezed
class Goal with _$Goal {
  const factory Goal({
    required String id,
    required String title,
    required String metric, // 'bark_count', 'sit_count', etc.
    required String comparison, // 'less_than', 'greater_than', 'equal'
    required double targetValue,
    required double currentValue,
    required String period, // 'daily', 'weekly', 'monthly'
    DateTime? deadline,
  }) = _Goal;

  factory Goal.fromJson(Map<String, dynamic> json) =>
      _$GoalFromJson(json);
}
```

### UI Layout

```
┌─────────────────────────────────────┐
│ ← Analytics          [7D][30D][All] │
├─────────────────────────────────────┤
│                                     │
│  Barking Trend                      │
│  ┌─────────────────────────────┐    │
│  │     📈 Line Chart           │    │
│  │  ---Goal Line---            │    │
│  │  ╱╲    ╱╲                   │    │
│  │ ╱  ╲__╱  ╲___               │    │
│  └─────────────────────────────┘    │
│  ↓ 23% from last week               │
│                                     │
├─────────────────────────────────────┤
│  Training Success                   │
│  ┌─────────────────────────────┐    │
│  │  ██████░░  Sit: 85%         │    │
│  │  ████░░░░  Stay: 62%        │    │
│  │  ██░░░░░░  Quiet: 34%       │    │
│  └─────────────────────────────┘    │
│                                     │
├─────────────────────────────────────┤
│  Goals                              │
│  ┌─────────┐ ┌─────────┐           │
│  │  ◐ 60%  │ │  ◕ 85%  │           │
│  │ <5 bark │ │ 10 sits │           │
│  └─────────┘ └─────────┘           │
│                                     │
└─────────────────────────────────────┘
```

---

## 4. Video Gallery

### Purpose
Review recorded clips, tag events, assign to missions, share highlights.

### Screen: `lib/presentation/screens/video_gallery/video_gallery_screen.dart`

### Data Model: `lib/data/models/video_clip.dart`

```dart
@freezed
class VideoClip with _$VideoClip {
  const factory VideoClip({
    required String id,
    required String url,
    required DateTime timestamp,
    required Duration duration,
    String? thumbnailUrl,
    String? dogId,
    String? missionId,
    @Default([]) List<String> tags,
    @Default([]) List<VideoEvent> events,
    @Default(false) bool isFavorite,
    @Default(false) bool isShared,
  }) = _VideoClip;

  factory VideoClip.fromJson(Map<String, dynamic> json) =>
      _$VideoClipFromJson(json);
}

@freezed
class VideoEvent with _$VideoEvent {
  const factory VideoEvent({
    required Duration timestamp,
    required String type, // 'bark', 'sit', 'treat', etc.
    String? label,
  }) = _VideoEvent;

  factory VideoEvent.fromJson(Map<String, dynamic> json) =>
      _$VideoEventFromJson(json);
}
```

### UI Layout - Gallery View

```
┌─────────────────────────────────────┐
│ ← Video Gallery      🔍  ☰ Filter   │
├─────────────────────────────────────┤
│ Today                               │
├─────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐│
│ │ 📹 0:32 │ │ 📹 1:05 │ │ 📹 0:15 ││
│ │ ⭐ 🐕   │ │    🦴   │ │    🔔   ││
│ └─────────┘ └─────────┘ └─────────┘│
├─────────────────────────────────────┤
│ Yesterday                           │
├─────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐│
│ │ 📹 2:30 │ │ 📹 0:45 │ │ 📹 1:20 ││
│ │ Mission │ │    🐕   │ │         ││
│ └─────────┘ └─────────┘ └─────────┘│
└─────────────────────────────────────┘
```

### UI Layout - Video Detail/Player

```
┌─────────────────────────────────────┐
│ ←                              ⋮    │
├─────────────────────────────────────┤
│                                     │
│     ┌───────────────────────┐       │
│     │                       │       │
│     │    VIDEO PLAYER       │       │
│     │       ▶               │       │
│     │                       │       │
│     └───────────────────────┘       │
│      advancement w time bar w events│
│     ──●────🐕──────🦴───────        │
│     0:00              0:32          │
│                                     │
├─────────────────────────────────────┤
│ Jan 18, 2025 · 2:34 PM · 32 sec     │
│                                     │
│ Events in this clip:                │
│ • 0:05 - Dog detected (sitting)     │
│ • 0:12 - Treat dispensed            │
│ • 0:28 - Dog lying down             │
│                                     │
├─────────────────────────────────────┤
│ Tags: #training #goodboy            │
│ [+ Add Tag]                         │
│                                     │
├─────────────────────────────────────┤
│ ┌────────┐ ┌────────┐ ┌────────┐   │
│ │⭐ Fave │ │📤 Share│ │🗑 Delete│   │
│ └────────┘ └────────┘ └────────┘   │
└─────────────────────────────────────┘
```

### Features
- Grid view of thumbnails
- Filter by: date, tags, events, favorites
- Video player with event markers on timeline
- Add/edit tags
- Favorite clips
- Share to Instagram/social (export video file)
- Assign clip to dog profile
- Link clip to mission

---

## 5. Live Stream Refinements

### Already scaffolded, but add:

1. **Recording indicator** - Red dot + "REC" when recording
2. **Screenshot button** - Capture current frame
3. **Event markers** - Show recent events as toast notifications overlaid
4. **Quick treat button** - Always visible, large, easy to tap
5. **Detection box** - Bounding box around detected dog with behavior label

---

## 6. Navigation Updates

### Bottom Navigation Bar

```dart
// 5 tabs
enum NavTab {
  home,      // Live stream + controls
  dogs,      // Dog profiles list
  missions,  // Mission library
  gallery,   // Video gallery
  activity,  // Notifications (with badge)
}
```

### Icons
- Home: `Icons.home` or custom robot icon
- Dogs: `Icons.pets`
- Missions: `Icons.flag` or `Icons.track_changes`
- Gallery: `Icons.video_library`
- Activity: `Icons.notifications` (with unread badge)

---

## 7. Custom Icons

Create custom SVG icons for dog behaviors. Store in `assets/icons/`:

- `dog_sitting.svg`
- `dog_standing.svg`
- `dog_lying.svg`
- `dog_barking.svg`
- `dog_happy.svg`
- `bone_treat.svg`
- `paw_print.svg`

Use `flutter_svg` package to render them.

For now, can use placeholder icons from `Icons` or `phosphor_flutter` until custom SVGs are designed.

---

## 8. Provider Updates

### New Providers Needed

```dart
// lib/domain/providers/

// Notifications
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationEvent>>;
final unreadCountProvider = Provider<int>;

// Dog Profiles
final dogProfilesProvider = StateNotifierProvider<DogProfilesNotifier, List<DogProfile>>;
final selectedDogProvider = StateProvider<DogProfile?>;

// Analytics
final analyticsProvider = FutureProvider.family<AnalyticsData, String>; // by dogId
final goalsProvider = StateNotifierProvider<GoalsNotifier, List<Goal>>;

// Video Gallery
final videoClipsProvider = StateNotifierProvider<VideoClipsNotifier, List<VideoClip>>;
final selectedClipProvider = StateProvider<VideoClip?>;
```

---

## 9. Implementation Order

1. **Data Models** - Create all Freezed models first, run build_runner
2. **Providers** - Set up state management
3. **Notifications Screen** - Simple list, good starting point
4. **Dog Profile Screen** - Core feature
5. **Analytics Dashboard** - Charts with fl_chart
6. **Video Gallery** - Grid + player
7. **Navigation** - Update bottom nav to 5 tabs
8. **Polish** - Icons, animations, themes

---

## 10. File Structure

```
lib/
├── data/
│   └── models/
│       ├── notification_event.dart    # NEW
│       ├── dog_profile.dart           # NEW
│       ├── analytics_data.dart        # NEW
│       ├── video_clip.dart            # NEW
│       └── goal.dart                  # NEW
│
├── domain/
│   └── providers/
│       ├── notifications_provider.dart # NEW
│       ├── dog_profiles_provider.dart  # NEW
│       ├── analytics_provider.dart     # NEW
│       ├── video_gallery_provider.dart # NEW
│       └── goals_provider.dart         # NEW
│
└── presentation/
    ├── screens/
    │   ├── notifications/
    │   │   └── notifications_screen.dart      # NEW
    │   ├── dog_profile/
    │   │   ├── dog_profile_screen.dart        # NEW
    │   │   ├── dog_edit_screen.dart           # NEW
    │   │   └── widgets/
    │   │       ├── dog_header.dart
    │   │       ├── stats_summary.dart
    │   │       └── quick_actions.dart
    │   ├── analytics/
    │   │   ├── analytics_screen.dart          # NEW
    │   │   └── widgets/
    │   │       ├── bark_trend_chart.dart
    │   │       ├── success_rate_chart.dart
    │   │       └── goal_progress.dart
    │   └── video_gallery/
    │       ├── video_gallery_screen.dart      # NEW
    │       ├── video_player_screen.dart       # NEW
    │       └── widgets/
    │           ├── video_thumbnail.dart
    │           ├── video_timeline.dart
    │           └── event_marker.dart
    │
    └── widgets/
        ├── icons/
        │   └── dog_behavior_icon.dart         # NEW
        └── common/
            ├── stat_card.dart                 # NEW
            └── event_list_tile.dart           # NEW
```

---

## Notes for Claude Code

1. Use the existing `AppTheme` from `lib/presentation/theme/app_theme.dart`
2. Follow the existing Riverpod patterns in the codebase
3. Run `dart run build_runner build` after creating Freezed models
4. Use `fl_chart` for all charts - it's already in dependencies
5. For video playback, use `video_player` package or `chewie` for controls
6. Mock data is fine for now - we'll wire up real API later
7. Keep the premium dark "robotics HUD" aesthetic throughout
