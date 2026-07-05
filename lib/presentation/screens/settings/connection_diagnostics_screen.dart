import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/websocket_client.dart';
import '../../../core/utils/conn_trace.dart';
import '../../theme/app_theme.dart';

/// On-device viewer for the WebRTC signaling/connection trace ([connTrace]).
///
/// This project's workflow has no Mac/Xcode console, so this screen is the
/// only way to read the diagnostic trace from a TestFlight build. The trace
/// is captured in [ConnTraceLog]; here it can be read, copied, and shared.
class ConnectionDiagnosticsScreen extends StatefulWidget {
  const ConnectionDiagnosticsScreen({super.key});

  @override
  State<ConnectionDiagnosticsScreen> createState() =>
      _ConnectionDiagnosticsScreenState();
}

class _ConnectionDiagnosticsScreenState
    extends State<ConnectionDiagnosticsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    ConnTraceLog.addListener(_onTraceChanged);
  }

  @override
  void dispose() {
    ConnTraceLog.removeListener(_onTraceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTraceChanged() {
    if (!mounted) return;
    setState(() {});
    // Keep newest line in view as the trace grows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: ConnTraceLog.asText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trace copied to clipboard')),
    );
  }

  Future<void> _share() async {
    await Share.share(
      ConnTraceLog.asText,
      subject: 'WIM-Z connection trace',
    );
  }

  void _clear() {
    ConnTraceLog.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trace cleared')),
    );
  }

  bool _pinging = false;

  /// A-LED: round-trip LED ping. Separates app-fault from robot-fault in one
  /// tap: an ack proves the command left the phone and was accepted on the
  /// far end (if the strip still didn't light, it's robot/electrical — see
  /// R-LED); a timeout means the command path itself is broken.
  Future<void> _ledPing() async {
    final ws = WebSocketClient.instance;
    if (ws.state != WsConnectionState.connected) {
      connTrace('led-ping-skip', 'ws state=${ws.state.name}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected — connect to the robot first')),
      );
      return;
    }
    setState(() => _pinging = true);
    const ackTypes = {'ack', 'command_ack', 'command_response', 'response'};
    final stopwatch = Stopwatch()..start();
    final ackFuture = ws.eventStream
        .where((e) => ackTypes.contains(e.type))
        .first
        .timeout(const Duration(seconds: 3));
    connTrace('led-ping-sent', 'pattern=rainbow');
    ws.sendLedCommand('rainbow');
    String result;
    try {
      final ack = await ackFuture;
      stopwatch.stop();
      connTrace('led-ping-ack', '${stopwatch.elapsedMilliseconds}ms (${ack.type})');
      result = 'LED acknowledged in ${stopwatch.elapsedMilliseconds}ms — '
          'if nothing lit, the fault is on the robot';
    } on TimeoutException {
      connTrace('led-ping-timeout', 'no ack within 3000ms');
      result = 'LED sent but not acknowledged in 3s — command path broken';
    } catch (e) {
      connTrace('led-ping-error', '$e');
      result = 'LED ping failed: $e';
    }
    if (!mounted) return;
    setState(() => _pinging = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ConnTraceLog.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Diagnostics'),
        actions: [
          IconButton(
            icon: _pinging
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb_outline),
            tooltip: 'LED ping',
            onPressed: _pinging ? null : _ledPing,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
            onPressed: entries.isEmpty ? null : _copy,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: entries.isEmpty ? null : _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: entries.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppTheme.surfaceLight,
            child: Text(
              'WebRTC signaling trace — ${entries.length} event'
              '${entries.length == 1 ? '' : 's'} captured.\n'
              'Reproduce the slow video, then Share this trace.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No events captured yet.\n\n'
                        'Log in and open the video feed, then return here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          entries[index],
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
