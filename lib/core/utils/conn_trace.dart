import 'dart:collection';

/// Timestamped trace logger for diagnosing the WebRTC signaling/connection
/// flow (login -> WS open -> SDP exchange -> ICE -> first video frame).
///
/// Output format: [HH:MM:SS.mmm] [event] [details]
///
/// Pure diagnostic logging — added to investigate the ~60s video-feed delay.
/// Does NOT alter any connection behavior. Safe to delete once diagnosed.
///
/// Lines are kept in an in-memory ring buffer ([ConnTraceLog]) so they can be
/// read on-device via the Connection Diagnostics screen (Settings). This
/// project's workflow has no Mac/Xcode console, so the in-app viewer is the
/// only way to read the trace from a TestFlight build.
void connTrace(String event, [String details = '']) {
  final now = DateTime.now();
  String pad2(int n) => n.toString().padLeft(2, '0');
  final ts = '${pad2(now.hour)}:${pad2(now.minute)}:${pad2(now.second)}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  final line = '[$ts] [$event] [$details]';
  // Uses print (not debugPrint) so a burst of ICE candidates is never
  // rate-limited / dropped — visible under `flutter run` when on USB.
  print(line);
  ConnTraceLog.add(line);
}

/// In-memory ring buffer of [connTrace] lines, surfaced by the on-device
/// Connection Diagnostics screen. Capped so a long session can't grow
/// unbounded.
class ConnTraceLog {
  ConnTraceLog._();

  static const int maxEntries = 500;
  static final ListQueue<String> _entries = ListQueue<String>();
  static final List<void Function()> _listeners = [];

  /// Append a line and notify listeners (the diagnostics screen).
  static void add(String line) {
    _entries.addLast(line);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    _notify();
  }

  /// Snapshot of all buffered lines, oldest first.
  static List<String> get entries => List.unmodifiable(_entries);

  /// All buffered lines joined with newlines — for copy / share.
  static String get asText => _entries.join('\n');

  /// Number of buffered lines.
  static int get length => _entries.length;

  static void clear() {
    _entries.clear();
    _notify();
  }

  static void addListener(void Function() listener) =>
      _listeners.add(listener);

  static void removeListener(void Function() listener) =>
      _listeners.remove(listener);

  static void _notify() {
    for (final l in List<void Function()>.from(_listeners)) {
      l();
    }
  }
}
