import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/websocket_client.dart';
import '../../core/utils/conn_trace.dart';
import '../../core/utils/time_utils.dart';
import '../../core/services/local_connection_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/datasources/robot_api.dart';
import '../../data/models/notification_event.dart';
import 'auth_provider.dart';
import 'connection_provider.dart';
import 'dog_profiles_provider.dart';
import 'missions_provider.dart';
import 'settings_provider.dart';

/// Provider for notification events list
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationEvent>>((ref) {
  return NotificationsNotifier(ref);
});

/// Provider for unread notification count
final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

/// Provider to filter notifications by type
final filteredNotificationsProvider =
    Provider.family<List<NotificationEvent>, Set<NotificationEventType>?>(
        (ref, filter) {
  final notifications = ref.watch(notificationsProvider);
  if (filter == null || filter.isEmpty) return notifications;
  return notifications.where((n) => filter.contains(n.type)).toList();
});

/// Notifications state notifier
class NotificationsNotifier extends StateNotifier<List<NotificationEvent>> {
  final Ref _ref;
  StreamSubscription? _wsSubscription;

  NotificationsNotifier(this._ref) : super(const []) {
    // Listen for WebSocket events to add real notifications
    _ref.listen<ConnectionState>(connectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true) {
        _startListening();
      } else if (!next.isConnected) {
        _stopListening();
      }
    });

    if (_ref.read(connectionProvider).isConnected) {
      _startListening();
    }
  }

  void _startListening() {
    _wsSubscription?.cancel();
    _wsSubscription =
        _ref.read(websocketClientProvider).eventStream.listen(_handleWsEvent);
  }

  void _stopListening() {
    _wsSubscription?.cancel();
  }

  void _handleWsEvent(WsEvent event) {
    // Store-and-forward: a replayed (buffered) event must keep its real time
    // and stable id, not be stamped "now" with an ephemeral id on arrival.
    // Prefer the relay's ts_server / id; fall back to live/local behaviour.
    final eventTime = _resolveTimestamp(event);
    final eventId = event.id;
    // Convert WebSocket events to notifications
    NotificationEvent? notification;

    switch (event.type) {
      case 'detection':
        // Only show notifications for known dogs (ignore ArUco false positives
        // like tags on water bottles, furniture, etc.)
        final behavior = event.data['behavior'] as String?;
        if (behavior != null && _isKnownDog(event.data)) {
          notification =
              _createBehaviorNotification(behavior, event.data, eventTime, eventId);
        }
        break;

      // Bark events (forwarded as 'event' type with event_type: 'barking').
      // Build 125: the robot now attributes barks to a dog (dog_id/dog_name) —
      // carry dog_id through so per-dog stats count it.
      case 'event':
        final eventType = event.data['event_type'] as String?;
        if (eventType == 'barking') {
          notification = NotificationEvent(
            id: eventId ?? eventTime.millisecondsSinceEpoch.toString(),
            type: NotificationEventType.bark,
            timestamp: eventTime,
            title: 'Barking Detected',
            subtitle: event.data['details'] as String?,
            dogId: event.data['dog_id'] as String?,
            metadata: _attributionMeta(event.data),
          );
        }
        break;

      // Silent Guardian events. The robot emits these as {event:'guardian',
      // action:'started'|'stopped'|'escalation'|'reset'|...} (Build 125 robot
      // contract). Session-lifecycle actions are skipped; an intervention/
      // escalation surfaces as an alert — see _guardianNotification.
      case 'guardian':
        notification = _guardianNotification(event.data, eventTime, eventId);
        break;

      // Robot 137a5e8: panic episode push. `message` is pre-phrased
      // owner-friendly text — display verbatim, never rewrite.
      case 'panic_alert':
        final panicAction = event.data['action'] as String? ?? 'started';
        final severity = event.data['severity'] as String?;
        notification = NotificationEvent(
          id: eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.panicAlert,
          timestamp: eventTime,
          title: panicAction == 'ended' ? 'Panic Episode Ended' : 'Panic Alert',
          subtitle: event.data['message'] as String?,
          dogId: event.data['dog_id'] as String?,
          metadata: {
            'action': panicAction,
            if (severity != null) 'severity': severity,
            if (event.data['trigger'] != null) 'trigger': event.data['trigger'],
            if (event.data['episode_num'] != null)
              'episode_num': event.data['episode_num'],
            if (event.data['duration_sec'] != null)
              'duration_sec': event.data['duration_sec'],
          },
        );
        break;

      // Robot 137a5e8: SG session summary. Only the automatic Level-4
      // escalation variant notifies (once per session, robot-side); the
      // status_pull response renders as a card via sgSummaryProvider, not
      // as a feed entry.
      case 'sg_summary':
        if (event.data['action'] == 'level4_escalation') {
          notification = NotificationEvent(
            id: eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            type: NotificationEventType.sgSummary,
            timestamp: eventTime,
            title: 'Silent Guardian: Level 4',
            subtitle: event.data['headline'] as String? ??
                'Escalation reached the highest level',
            dogId: event.data['dog_id'] as String?,
            metadata: {'action': 'level4_escalation'},
          );
        }
        break;

      // Build 140: treat events carry dog_id/dog_name when the robot resolved
      // the dog OR when the app named it on the dispense_treat command (the
      // robot echoes it back — attribution contract 2026-07-13). Untagged
      // treats stay untagged; per-dog stats only count what's honestly known.
      case 'treat':
        final treatDogName = event.data['dog_name'] as String?;
        notification = NotificationEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.treatDispensed,
          timestamp: eventTime,
          title: 'Treat Dispensed',
          subtitle: treatDogName != null ? 'For $treatDogName' : 'Good job!',
          dogId: event.data['dog_id'] as String?,
          metadata: _attributionMeta(event.data),
        );
        break;

      case 'reward':
        if (event.data['subtype'] == 'treat_dispensed') {
          final remaining = event.data['treats_remaining'] as int?;
          notification = NotificationEvent(
            id: eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            type: NotificationEventType.treatDispensed,
            timestamp: eventTime,
            title: 'Treat Dispensed',
            subtitle: remaining != null ? '$remaining treats remaining' : 'Good job!',
            dogId: event.data['dog_id'] as String?,
            metadata: _attributionMeta(event.data),
          );
        }
        break;

      case 'treat_status':
      case 'treats_low':
        // Only notify when treats are running low. Robot 8e8c91c: treats_low
        // events carry treats_given/treat_capacity too; remaining is derived
        // server-side and never negative.
        final treatsLow = event.type == 'treats_low' ||
            (event.data['treats_low'] as bool? ?? false);
        if (treatsLow) {
          final remaining = event.data['treats_remaining'] as int? ?? 0;
          notification = NotificationEvent(
            id: eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            type: NotificationEventType.alert,
            timestamp: eventTime,
            title: 'Treats Running Low',
            subtitle: '$remaining treats remaining — time to refill!',
          );
        }
        break;

      case 'treats_empty':
        // Robot 8e8c91c: fires ONCE on the transition to empty (latched,
        // cleared by refill/reset) — no dedup needed app-side.
        notification = NotificationEvent(
          id: eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.alert,
          timestamp: eventTime,
          title: 'Treats Empty',
          subtitle: 'Refill the carousel to keep dispensing',
        );
        break;

      case 'mission_start':
        notification = NotificationEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.missionStarted,
          timestamp: eventTime,
          title: 'Mission Started',
          subtitle: event.data['name'] as String?,
          missionId: event.data['id'] as String?,
          dogId: _missionDogId(event.data),
          metadata: _attributionMeta(event.data),
        );
        break;

      case 'mission_complete':
        notification = NotificationEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.missionCompleted,
          timestamp: eventTime,
          title: 'Mission Completed',
          subtitle: event.data['name'] as String?,
          missionId: event.data['id'] as String?,
          dogId: _missionDogId(event.data),
          metadata: _attributionMeta(event.data),
        );
        break;

      case 'coach_reward':
        final behavior = event.data['behavior'] as String? ?? 'trick';
        final dogName = event.data['dog_name'] as String?;
        final behaviorLabel = behavior[0].toUpperCase() + behavior.substring(1);
        notification = NotificationEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: NotificationEventType.coachReward,
          timestamp: eventTime,
          title: dogName != null ? '$dogName: $behaviorLabel rewarded' : '$behaviorLabel rewarded',
          subtitle: 'Coach mode',
          dogId: event.data['dog_id'] as String?,
          metadata: _attributionMeta(event.data),
        );
        break;

      case 'battery':
        final level = (event.data['level'] as num?)?.toDouble() ?? 100;
        if (level < 20) {
          notification = NotificationEvent(
            id: eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
            type: NotificationEventType.lowBattery,
            timestamp: eventTime,
            title: 'Low Battery',
            subtitle: '${level.toInt()}% remaining',
          );
        }
        break;
    }

    if (notification != null) {
      addNotification(notification);
    }
  }

  /// Feed timestamp for a live or buffered event: prefer the relay's
  /// authoritative `ts_server`, then any timestamp in the payload, then now.
  /// This keeps store-and-forward replays at their real moment in the feed.
  DateTime _resolveTimestamp(WsEvent event) {
    final raw = event.tsServer ?? event.data['timestamp'];
    if (raw is String) {
      return parseServerTimestamp(raw);
    }
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.now();
  }

  /// Build 140: dog for a live mission event. Robot payload dog_id wins
  /// (covers scheduler/robot-started missions once the attribution contract
  /// lands); otherwise fall back to the dog the APP started the mission for
  /// (C2 effectiveDogId, tracked in MissionsState.activeDogId). This is a
  /// join on real knowledge, not a display-time guess — the app either named
  /// the dog on start_mission or it stays untagged.
  String? _missionDogId(Map<String, dynamic> data) =>
      data['dog_id'] as String? ?? _ref.read(missionsProvider).activeDogId;

  /// Build 140: attribution provenance. The robot ALWAYS assigns a dog now
  /// (sole profile → that dog; multi-dog → last identified/commanded dog) and
  /// marks HOW via id_method ('qr'/'vision'/'owner_selected'/'sole_dog'/
  /// 'last_dog'). Keep it on the notification so a fallback guess stays
  /// distinguishable from a real identification — per-dog stats count both
  /// today, but a future UI badge / correction pass needs the difference.
  Map<String, dynamic>? _attributionMeta(Map<String, dynamic> data) {
    final idMethod = data['id_method'] as String?;
    final dogName = data['dog_name'] as String?;
    if (idMethod == null && dogName == null) return null;
    return {
      if (idMethod != null) 'id_method': idMethod,
      if (dogName != null) 'dog_name': dogName,
    };
  }

  /// Check if detection is from a known dog (has dog_id, or aruco_id matches a profile,
  /// or no aruco at all — generic detection without ArUco is allowed through)
  bool _isKnownDog(Map<String, dynamic> data) {
    // If robot sent a dog_id, it's identified
    if (data['dog_id'] != null) return true;
    // If no aruco_id, it's a generic detection (no ArUco tag) — allow
    final arucoId = data['aruco_id'] as int?;
    if (arucoId == null) return true;
    // Has aruco_id — check if it matches any profile
    final profiles = _ref.read(dogProfilesProvider);
    return profiles.any((p) => p.arucoMarkerId == arucoId);
  }

  NotificationEvent? _createBehaviorNotification(
      String behavior, Map<String, dynamic> data, DateTime eventTime,
      String? eventId) {
    final type = switch (behavior.toLowerCase()) {
      'sit' || 'sitting' => NotificationEventType.sit,
      'laydown' || 'lie' || 'lying' || 'down' || 'lie_down' => NotificationEventType.lieDown,
      'come' || 'stand' || 'standing' => NotificationEventType.stand,
      'spin' => NotificationEventType.stand, // reuse stand type for spin
      'speak' => NotificationEventType.bark, // reuse bark type for speak
      'bark' || 'barking' => NotificationEventType.bark,
      _ => null,
    };

    if (type == null) return null;

    final confidence = (data['confidence'] as num?)?.toDouble();
    final confidenceStr =
        confidence != null ? '${(confidence * 100).toInt()}% confidence' : null;

    // Use the resolved event time / stable id passed in by the caller, NOT
    // DateTime.now(). Buffered store-and-forward replays must keep their real
    // moment and id so ordering and id-dedup work (a "now" stamp would float
    // a 2-hour-old detection to the top and a fresh id would defeat dedup).
    return NotificationEvent(
      id: eventId ?? eventTime.millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: eventTime,
      title: _getDefaultTitle(type),
      subtitle: confidenceStr,
      dogId: data['dog_id'] as String?,
      metadata: _attributionMeta(data),
    );
  }

  /// Normalize a robot guardian action: lowercase + strip the `sg_` /
  /// `silent_guardian_` prefixes so 'sg_escalation' and 'escalation' match.
  String _normalizeGuardianAction(String? raw) =>
      (raw ?? '')
          .toLowerCase()
          .replaceAll('silent_guardian_', '')
          .replaceAll('sg_', '');

  /// True for SG session-lifecycle actions (start/stop/reset) that are NOT
  /// per-dog activity and shouldn't clutter the history feed.
  bool _isGuardianLifecycle(String action) =>
      action == 'started' ||
      action == 'start' ||
      action == 'stopped' ||
      action == 'stop' ||
      action == 'reset' ||
      action.isEmpty;

  /// Build a notification from a robot 'guardian' event. Lifecycle actions are
  /// dropped (return null); an escalation/intervention (or any other meaningful
  /// action) becomes an alert. Action strings are normalized defensively since
  /// the exact escalation payload couldn't be live-captured robot-side.
  NotificationEvent? _guardianNotification(
      Map<String, dynamic> data, DateTime eventTime, String? eventId) {
    final action = _normalizeGuardianAction(data['action'] as String?);

    // Robot 137a5e8: guardian stopped now carries a session wrap-up
    // (bark_types, headline, aggressive_tag, panic_episodes). Surface it as
    // a summary entry when the payload has one; bare stops (older robots)
    // stay dropped with the other lifecycle actions.
    if ((action == 'stopped' || action == 'stop') &&
        (data['headline'] != null || data['bark_types'] != null)) {
      final aggressive = data['aggressive_tag'] == true;
      final panicEpisodes = (data['panic_episodes'] as num?)?.toInt() ?? 0;
      final headline = data['headline'] as String? ?? 'Session ended';
      final extras = [
        if (aggressive) 'Your dog was aggressive today',
        if (panicEpisodes > 0)
          '$panicEpisodes panic episode${panicEpisodes == 1 ? '' : 's'}',
      ].join(' · ');
      return NotificationEvent(
        id: eventId ?? eventTime.millisecondsSinceEpoch.toString(),
        type: NotificationEventType.sgSummary,
        timestamp: eventTime,
        title: 'Guardian Session Ended',
        subtitle: extras.isEmpty ? headline : '$headline — $extras',
        dogId: data['dog_id'] as String?,
        metadata: {
          'action': 'stopped',
          'aggressive_tag': aggressive,
          'panic_episodes': panicEpisodes,
          if (data['bark_types'] is Map) 'bark_types': data['bark_types'],
        },
      );
    }

    if (_isGuardianLifecycle(action)) return null;

    final reason = data['reason'] as String? ??
        data['details'] as String? ??
        data['message'] as String?;
    return NotificationEvent(
      id: eventId ?? eventTime.millisecondsSinceEpoch.toString(),
      type: NotificationEventType.alert,
      timestamp: eventTime,
      title: 'Guardian Alert',
      subtitle: reason ?? 'Intervention',
      dogId: data['dog_id'] as String?,
      metadata: _attributionMeta(data),
    );
  }

  String _getDefaultTitle(NotificationEventType type) {
    return switch (type) {
      NotificationEventType.bark => 'Barking Detected',
      NotificationEventType.sit => 'Sitting Detected',
      NotificationEventType.lieDown => 'Lay Down',
      NotificationEventType.stand => 'Come',
      NotificationEventType.treatDispensed => 'Treat Dispensed',
      NotificationEventType.missionStarted => 'Mission Started',
      NotificationEventType.missionCompleted => 'Mission Completed',
      NotificationEventType.missionFailed => 'Mission Failed',
      NotificationEventType.lowBattery => 'Low Battery',
      NotificationEventType.alert => 'Alert',
      NotificationEventType.happy => 'Happy Dog',
      NotificationEventType.connected => 'Connected',
      NotificationEventType.disconnected => 'Disconnected',
      NotificationEventType.coachReward => 'Coach Reward',
      NotificationEventType.panicAlert => 'Panic Alert',
      NotificationEventType.sgSummary => 'Guardian Summary',
    };
  }

  /// Add a new notification to the list.
  ///
  /// Per-type channel routing:
  /// - [NotificationChannel.off]: drop entirely; nothing in-app, nothing on lock screen.
  /// - [NotificationChannel.inApp]: append to in-app feed only.
  /// - [NotificationChannel.inAppAndPush]: in-app feed + OS push (when
  ///   backgrounded and global notifications are enabled).
  void addNotification(NotificationEvent notification) {
    final settings = _ref.read(settingsProvider);
    final channel = settings.channelFor(notification.type);

    if (channel == NotificationChannel.off) return;

    // Idempotent by id: store-and-forward can deliver the same event twice —
    // once from the REST activity hydrate (7-day history) and once from the WS
    // replay buffer (24h) — on app launch. Drop the duplicate so it shows once.
    // Relies on the relay sharing a stable id across both sources; WS-vs-WS
    // dupes are already dropped by the seq watermark in WebSocketClient.
    if (state.any((n) => n.id == notification.id)) return;

    state = [notification, ...state];
    if (state.length > 100) {
      state = state.sublist(0, 100);
    }

    if (channel == NotificationChannel.inAppAndPush &&
        settings.notificationsEnabled) {
      final notifService = NotificationService.instance;
      if (notifService.isAppBackgrounded) {
        notifService.showForEvent(notification);
      }
    }
  }

  /// Mark a notification as read
  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  /// Remove a single notification by ID
  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  /// Clear all notifications
  void clearAll() {
    state = [];
  }

  /// Refresh notifications (would fetch from API in real implementation)
  Future<void> refresh() async {
    await hydrateFromRelay();
  }

  /// A3: Hydrate notifications from the relay activity log.
  /// Strategy: fetch the last 7 days of events for this user across all dogs,
  /// merge with existing in-memory list (de-dup by id), keep newest 200.
  /// Skipped silently in local mode or when no token is available.
  Future<void> hydrateFromRelay() async {
    final isLocal = _ref.read(localConnectionProvider).isConnected;
    final token = _ref.read(authProvider).token;
    if (isLocal || token == null) {
      connTrace('activity-hydrate-skip',
          'local=$isLocal hasToken=${token != null}');
      return;
    }

    try {
      final api = _ref.read(robotApiProvider);
      final since = DateTime.now().toUtc().subtract(const Duration(days: 7));
      connTrace('activity-hydrate-begin', 'since=$since limit=200');
      final result = await api.getActivity(
        token: token,
        since: since,
        limit: 200,
      );

      // Build 132 diagnostics: dump the raw relay response (chunked — the
      // trace viewer/copy works line-wise) so "missing at the server" vs
      // "dropped during parse" is decidable on-device.
      final raw = jsonEncode(result);
      const chunk = 800;
      const maxChunks = 6;
      for (var i = 0; i < raw.length && i ~/ chunk < maxChunks; i += chunk) {
        connTrace('activity-raw[${i ~/ chunk}]',
            raw.substring(i, i + chunk > raw.length ? raw.length : i + chunk));
      }
      if (raw.length > chunk * maxChunks) {
        connTrace('activity-raw-truncated',
            '${raw.length} chars total, logged first ${chunk * maxChunks}');
      }

      final eventsJson = (result['events'] as List?) ?? [];

      final hydrated = <NotificationEvent>[];
      // Count rows the converter dropped, by raw type, so silent skips
      // (unknown type / guardian lifecycle) are visible in the trace.
      final dropped = <String, int>{};
      for (final e in eventsJson) {
        if (e is! Map) continue;
        final row = e.cast<String, dynamic>();
        final n = _activityEventToNotification(row);
        if (n != null) {
          hydrated.add(n);
        } else {
          final t = row['type'] as String? ?? '<no-type>';
          dropped[t] = (dropped[t] ?? 0) + 1;
        }
      }

      // Merge: existing state first (most recent in-memory events win on id
      // collision), then anything new from the relay we don't already have.
      final existingIds = state.map((n) => n.id).toSet();
      final merged = [
        ...state,
        ...hydrated.where((n) => !existingIds.contains(n.id)),
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = merged.take(200).toList();
      connTrace(
          'activity-hydrate-done',
          'fetched=${eventsJson.length} kept=${hydrated.length} '
          'dropped=$dropped cursor=${result['next_cursor']} '
          'newest=${state.isNotEmpty ? state.first.timestamp.toIso8601String() : '-'} '
          'oldest=${state.isNotEmpty ? state.last.timestamp.toIso8601String() : '-'} '
          'feed=${state.length}');
    } catch (e) {
      connTrace('activity-hydrate-error', '$e');
    }
  }

  /// A3: Convert a relay activity_events row to a NotificationEvent.
  /// Returns null for unknown types (don't crash on schema drift).
  NotificationEvent? _activityEventToNotification(Map<String, dynamic> event) {
    final id = event['id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final typeStr = event['type'] as String? ?? '';
    final timestampStr = event['timestamp'] as String?;
    final timestamp = parseServerTimestamp(timestampStr);
    final payload = (event['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    // Row-level dog_id shipped relay-side 2026-07-26 (commit 0592da7), but
    // only rows ingested since then have the column populated. Older rows
    // keep NULL there while the original event payload — which may carry the
    // robot's dog_id at its top level or nested under data — is still stored,
    // so dig it out as a fallback to recover attribution for old history.
    // '' normalizes to null (relay does the same for new rows).
    final nested = payload['data'] is Map
        ? (payload['data'] as Map)['dog_id']
        : null;
    final rawDogId =
        (event['dog_id'] ?? payload['dog_id'] ?? nested)?.toString();
    final dogId = (rawDogId == null || rawDogId.isEmpty) ? null : rawDogId;

    NotificationEventType? mapped;
    String title;
    String? subtitle;

    switch (typeStr) {
      case 'bark':
        mapped = NotificationEventType.bark;
        title = 'Barking Detected';
        final emotion = payload['emotion'] as String?;
        subtitle = emotion != null ? 'Emotion: $emotion' : null;
        break;
      case 'treat_dispensed':
        mapped = NotificationEventType.treatDispensed;
        title = 'Treat Dispensed';
        final remaining = payload['treats_remaining_after'] as int? ??
            payload['treats_remaining'] as int?;
        subtitle = remaining != null ? '$remaining treats remaining' : null;
        break;
      case 'coach_reward':
        mapped = NotificationEventType.coachReward;
        final trick = payload['trick'] as String? ?? 'trick';
        final success = payload['success'] as bool? ?? true;
        title = success ? '$trick rewarded' : '$trick attempt';
        break;
      case 'guardian_alert':
        mapped = NotificationEventType.alert;
        final reason = payload['reason'] as String? ?? 'Alert';
        title = 'Guardian: $reason';
        subtitle = payload['severity'] as String?;
        break;
      // Robot 137a5e8: panic + SG summary rows from relay history
      case 'panic_alert':
        mapped = NotificationEventType.panicAlert;
        final panicAction =
            (payload['action'] ?? event['action']) as String? ?? 'started';
        title = panicAction == 'ended' ? 'Panic Episode Ended' : 'Panic Alert';
        subtitle = payload['message'] as String?;
        break;
      case 'sg_summary':
        // Only the level4 escalation is feed history; status_pull responses
        // are transient and should never be persisted rows anyway.
        if ((payload['action'] ?? event['action']) != 'level4_escalation') {
          return null;
        }
        mapped = NotificationEventType.sgSummary;
        title = 'Silent Guardian: Level 4';
        subtitle = payload['headline'] as String?;
        break;
      // Build 125: robot's unified guardian event ({type:'guardian',
      // action:...}). Lifecycle actions (start/stop/reset) are skipped; an
      // escalation/intervention surfaces as an alert. action may live in the
      // payload or at the row top-level depending on relay persistence.
      case 'guardian':
        final action = _normalizeGuardianAction(
            (payload['action'] ?? event['action']) as String?);
        if (_isGuardianLifecycle(action)) return null;
        mapped = NotificationEventType.alert;
        title = 'Guardian Alert';
        subtitle = payload['reason'] as String? ??
            payload['details'] as String? ??
            payload['message'] as String?;
        break;
      case 'mission_started':
        mapped = NotificationEventType.missionStarted;
        title = 'Mission Started';
        subtitle = payload['mission_id'] as String?;
        break;
      case 'mission_completed':
        mapped = NotificationEventType.missionCompleted;
        final success = payload['success'] as bool? ?? true;
        title = success ? 'Mission Completed' : 'Mission Failed';
        if (!success) mapped = NotificationEventType.missionFailed;
        subtitle = payload['mission_id'] as String?;
        break;
      case 'behavior_flag':
        final behavior = (payload['behavior'] as String? ?? '').toLowerCase();
        mapped = switch (behavior) {
          'sit' || 'sitting' => NotificationEventType.sit,
          'laydown' || 'lie_down' || 'down' => NotificationEventType.lieDown,
          'come' || 'stand' => NotificationEventType.stand,
          'bark' => NotificationEventType.bark,
          _ => NotificationEventType.alert,
        };
        title = behavior.isEmpty
            ? 'Behavior Detected'
            : '${behavior[0].toUpperCase()}${behavior.substring(1)} Detected';
        break;
      default:
        return null;
    }

    return NotificationEvent(
      id: id,
      type: mapped,
      timestamp: timestamp,
      title: title,
      subtitle: subtitle,
      dogId: dogId,
      missionId: payload['mission_id'] as String?,
      metadata: payload,
    );
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
