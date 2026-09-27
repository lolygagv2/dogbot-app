import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/websocket_client.dart';
import '../../../core/utils/conn_trace.dart';
import '../../../l10n/l10n.dart';
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
      SnackBar(content: Text(context.l10n.connDiagCopied)),
    );
  }

  Future<void> _share() async {
    final subject = context.l10n.connDiagShareSubject;
    await Share.share(
      ConnTraceLog.asText,
      subject: subject,
    );
  }

  void _clear() {
    ConnTraceLog.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.connDiagCleared)),
    );
  }

  bool _pinging = false;

  /// A-LED: round-trip LED ping. Separates app-fault from robot-fault in one
  /// tap: an ack proves the command left the phone and was accepted on the
  /// far end (if the strip still didn't light, it's robot/electrical — see
  /// R-LED); a timeout means the command path itself is broken.
  Future<void> _ledPing() async {
    final l = context.l10n;
    final ws = WebSocketClient.instance;
    if (ws.state != WsConnectionState.connected) {
      connTrace('led-ping-skip', 'ws state=${ws.state.name}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.connDiagNotConnected)),
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
      result = l.connDiagLedAcked(stopwatch.elapsedMilliseconds);
    } on TimeoutException {
      connTrace('led-ping-timeout', 'no ack within 3000ms');
      result = l.connDiagLedTimeout;
    } catch (e) {
      connTrace('led-ping-error', '$e');
      result = l.connDiagLedFailed('$e');
    }
    if (!mounted) return;
    setState(() => _pinging = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ConnTraceLog.entries;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.connDiagTitle),
        actions: [
          IconButton(
            icon: _pinging
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb_outline),
            tooltip: l.connDiagLedPing,
            onPressed: _pinging ? null : _ledPing,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l.connDiagCopy,
            onPressed: entries.isEmpty ? null : _copy,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l.connDiagShare,
            onPressed: entries.isEmpty ? null : _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l.connDiagClear,
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
              l.connDiagHeader(entries.length),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.connDiagEmpty,
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
