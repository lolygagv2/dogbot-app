import '../../core/network/websocket_client.dart';

/// A refused `dispense_treat` (relay brief 2026-11-09 §7).
///
/// The robot now refuses over-limit treats with `treat_cap_reached`,
/// `treat_rate` or `treat_window_closed`. The reply shape is still being
/// agreed with the robot team, so [tryParse] accepts every plausible frame:
/// - `{"type":"error","code":"treat_cap_reached",...}` (the app's existing
///   error-frame convention; the proposed shape — see APP_REPLY 2026-11-09)
/// - `{"type":"command_result","command":"dispense_treat","success":false,
///    "code"|"reason"|"error":"treat_cap_reached",...}`
/// - `{"type":"treat_cap_reached",...}` (code as the frame type)
/// Extra fields `used`, `cap`, `resets_at` are read when present. Codes are
/// matched case-insensitively (robot error codes are often UPPER_CASE).
class TreatRefusal {
  static const capReached = 'treat_cap_reached';
  static const rate = 'treat_rate';
  static const windowClosed = 'treat_window_closed';
  static const codes = {capReached, rate, windowClosed};

  final String code;
  final int? used;
  final int? cap;
  final DateTime? resetsAt;
  final String? message;

  const TreatRefusal({
    required this.code,
    this.used,
    this.cap,
    this.resetsAt,
    this.message,
  });

  static TreatRefusal? tryParse(WsEvent e) {
    final d = e.data;
    String? code;
    final type = e.type.toLowerCase();
    if (codes.contains(type)) {
      code = type;
    } else if (type == 'error') {
      code = _code(d['code']) ?? _code(d['reason']);
    } else if (type == 'command_result' ||
        type == 'command_ack' ||
        type == 'command_response' ||
        type == 'response' ||
        type == 'ack') {
      final cmd = (d['command'] ?? d['cmd'])?.toString();
      if (cmd != null && cmd != 'dispense_treat' && cmd != 'treat') return null;
      final refused = d['success'] == false ||
          d['refused'] == true ||
          d['ok'] == false ||
          d['status']?.toString() == 'refused';
      if (!refused) return null;
      final result = d['result'];
      code = _code(d['code']) ??
          _code(d['reason']) ??
          _code(d['error']) ??
          (result is Map ? _code(result['code']) ?? _code(result['reason']) : null);
    }
    if (code == null) return null;
    final result = d['result'] is Map ? d['result'] as Map : const {};
    return TreatRefusal(
      code: code,
      used: _int(d['used'] ?? result['used']),
      cap: _int(d['cap'] ?? result['cap'] ?? d['limit']),
      resetsAt: _time(d['resets_at'] ?? result['resets_at']),
      message: (d['message'] ?? d['detail'])?.toString(),
    );
  }

  static String? _code(dynamic v) {
    if (v == null) return null;
    final s = v.toString().toLowerCase();
    return codes.contains(s) ? s : null;
  }

  static int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _time(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      // epoch seconds (or ms)
      final ms = v > 1e12 ? v.toInt() : (v * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    }
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
