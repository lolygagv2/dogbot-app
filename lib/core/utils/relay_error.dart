import 'package:dio/dio.dart';

/// Relay error bodies are uniform (brief 2026-11-06):
/// `{"detail": {"code": "...", ...extra}}`. Codes seen by the app:
/// guard_denied (403, guard/reason), treat_cap_reached (429, used/cap/
/// resets_at), treat_rate (429), robot_offline (409), command_not_allowed
/// (403), version_mismatch (409, current_version), invalid_value (422),
/// too_large (413), bad_format (422), draft_already_decided (409).
String? relayErrorCode(DioException e) {
  final body = e.response?.data;
  if (body is Map && body['detail'] is Map) {
    return (body['detail'] as Map)['code']?.toString();
  }
  return null;
}

/// Short, user-displayable description of a relay/robot HTTP error.
String relayErrorMessage(DioException e) {
  final status = e.response?.statusCode;
  final body = e.response?.data;
  if (body is Map) {
    final detail = body['detail'];
    if (detail is Map) {
      final code = detail['code']?.toString();
      final reason = detail['reason']?.toString();
      if (code != null && code.isNotEmpty) {
        switch (code) {
          case 'treat_cap_reached':
            return 'Treat cap reached (${detail['used']}/${detail['cap']})';
          case 'treat_rate':
            return 'Too many treats — try again in a minute';
          case 'robot_offline':
            return 'Robot is offline';
          case 'too_large':
            final max = (detail['max_bytes'] as num?)?.toInt();
            return max != null
                ? 'File too large (max ${(max / (1024 * 1024)).toStringAsFixed(0)} MB)'
                : 'File too large';
          case 'bad_format':
            final allowed = detail['allowed'];
            return allowed is List
                ? 'Unsupported format (use ${allowed.join(', ')})'
                : 'Unsupported format';
          case 'draft_already_decided':
            return 'Already ${detail['status'] ?? 'decided'}';
          case 'version_mismatch':
            return 'Changed elsewhere — reload and retry';
        }
        return reason != null && reason.isNotEmpty ? '$code: $reason' : code;
      }
    } else if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    final err = body['error'] ?? body['message'];
    if (err != null && err.toString().isNotEmpty) return err.toString();
  }
  if (status != null) return 'HTTP $status';
  return e.message ?? 'Network error';
}
