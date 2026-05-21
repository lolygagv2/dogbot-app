/// Timestamped trace logger for diagnosing the WebRTC signaling/connection
/// flow (login -> WS open -> SDP exchange -> ICE -> first video frame).
///
/// Output format: [HH:MM:SS.mmm] [event] [details]
///
/// Pure diagnostic logging — added to investigate the ~60s video-feed delay.
/// Does NOT alter any connection behavior. Safe to delete once diagnosed.
void connTrace(String event, [String details = '']) {
  final now = DateTime.now();
  String pad2(int n) => n.toString().padLeft(2, '0');
  final ts = '${pad2(now.hour)}:${pad2(now.minute)}:${pad2(now.second)}'
      '.${now.millisecond.toString().padLeft(3, '0')}';
  // Uses print (not debugPrint) so a burst of ICE candidates is never
  // rate-limited / dropped from the diagnostic trace.
  print('[$ts] [$event] [$details]');
}
