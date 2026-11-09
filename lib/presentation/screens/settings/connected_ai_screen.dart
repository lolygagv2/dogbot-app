import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/ai_connection.dart';
import '../../../domain/providers/ai_connect_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Settings → Connected AI. One screen, never scrolls as a whole: the
/// assistant list and the audit log scroll inside their own panes.
/// Setup guides open as bottom sheets (no extra navigation level).
class ConnectedAiScreen extends ConsumerStatefulWidget {
  const ConnectedAiScreen({super.key});

  @override
  ConsumerState<ConnectedAiScreen> createState() => _ConnectedAiScreenState();
}

class _ConnectedAiScreenState extends ConsumerState<ConnectedAiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(aiConnectProvider.notifier).load();
    });
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.aiConnectorUrlCopied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmRevoke(AiAssistant a) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.aiRevoke),
        content: Text(l.aiRevokeConfirm(a.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(Icons.link_off,
                size: 18, color: Theme.of(ctx).colorScheme.error),
            label: Text(l.aiRevoke,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(aiConnectProvider.notifier).revoke(a.id);
    }
  }

  Future<void> _confirmRevokeAll() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.aiDisconnectAll),
        content: Text(l.aiDisconnectAllConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(Icons.block,
                size: 18, color: Theme.of(ctx).colorScheme.error),
            label: Text(l.aiDisconnectAll,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final n = await ref.read(aiConnectProvider.notifier).revokeAll();
    if (!mounted || n == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.aiDisconnectAllDone(n)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openGuide(AiProvider p, String? url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SetupGuideSheet(provider: p, connectorUrl: url, onCopy: _copyUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiConnectProvider);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.connectedAiTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.loading
                ? null
                : () => ref.read(aiConnectProvider.notifier).load(),
          ),
        ],
      ),
      body: state.unsupported
          ? _Unsupported(text: l.aiUnsupported)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ConnectorUrlRow(
                    url: state.connectorUrl,
                    loading: state.loading && state.connectorUrl == null,
                    onCopy: _copyUrl,
                  ),
                  const SizedBox(height: 8),
                  _DisconnectAllTile(
                    count: state.assistants.length,
                    busy: state.revokingAll,
                    onPressed: _confirmRevokeAll,
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber,
                              size: 14, color: context.wimz.inkMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: TextStyle(
                                  color: context.wimz.inkMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _Header(l.aiAssistantsHeader, count: state.assistants.length),
                  Expanded(
                    flex: 5,
                    child: state.assistants.isEmpty
                        ? _Empty(state.loading ? l.loading : l.aiNoAssistants)
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: state.assistants.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => _AssistantRow(
                              assistant: state.assistants[i],
                              onRevoke: () => _confirmRevoke(state.assistants[i]),
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  _Header(l.aiAuditHeader),
                  Expanded(
                    flex: 4,
                    child: state.audit.isEmpty
                        ? _Empty(l.aiAuditEmpty)
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: state.audit.length,
                            itemBuilder: (_, i) =>
                                _AuditRow(entry: state.audit[i]),
                          ),
                  ),
                  const SizedBox(height: 8),
                  _Header(l.aiSetupGuides),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final p in AiProvider.values) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              side: BorderSide(color: context.wimz.lineStrong),
                            ),
                            onPressed: () => _openGuide(p, state.connectorUrl),
                            child: Text(
                              p.displayName,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (p != AiProvider.values.last) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _ConnectorUrlRow extends StatelessWidget {
  final String? url;
  final bool loading;
  final Future<void> Function(String) onCopy;
  const _ConnectorUrlRow(
      {required this.url, required this.loading, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: context.wimz.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.wimz.line),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: context.wimz.signal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.aiConnectorUrl,
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: context.wimz.inkMuted),
                ),
                Text(
                  loading
                      ? l.loading
                      : (url ?? l.aiConnectorUrlMissing),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: url != null
                        ? context.wimz.ink
                        : context.wimz.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            color: Theme.of(context).colorScheme.primary,
            tooltip: l.aiCopyUrl,
            onPressed: url == null ? null : () => onCopy(url!),
          ),
        ],
      ),
    );
  }
}

/// The relay's kill switch is `POST …/ai/revoke_all`: every assistant's
/// tokens are revoked at once (one-way; they must re-authorize).
class _DisconnectAllTile extends StatelessWidget {
  final int count;
  final bool busy;
  final VoidCallback onPressed;
  const _DisconnectAllTile(
      {required this.count, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final enabled = count > 0 && !busy;
    return Container(
      decoration: BoxDecoration(
        color: context.wimz.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.6)
              : context.wimz.line,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(Icons.block,
            color: enabled
                ? Theme.of(context).colorScheme.error
                : context.wimz.inkMuted),
        title: Text(l.aiDisconnectAll,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          l.aiDisconnectAllSubtitle,
          style: TextStyle(fontSize: 11, color: context.wimz.inkMuted),
        ),
        trailing: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.chevron_right, color: context.wimz.inkMuted),
        enabled: enabled,
        onTap: enabled ? onPressed : null,
      ),
    );
  }
}

class _AssistantRow extends StatelessWidget {
  final AiAssistant assistant;
  final VoidCallback onRevoke;
  const _AssistantRow({required this.assistant, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final lastUsed = assistant.lastUsedAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _ProviderBadge(provider: assistant.provider, name: assistant.name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assistant.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: context.wimz.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  assistant.scopes.isEmpty
                      ? l.aiScopesNone
                      : assistant.scopes.join(' · '),
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  lastUsed != null
                      ? l.aiLastUsed(
                          DateFormat.MMMd(locale).add_jm().format(lastUsed.toLocal()))
                      : l.aiNeverUsed,
                  style: TextStyle(
                      fontSize: 10, color: context.wimz.inkMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onRevoke,
            icon: const Icon(Icons.link_off, size: 16),
            label: Text(l.aiRevoke),
          ),
        ],
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  final AiProvider? provider;
  final String name;
  const _ProviderBadge({required this.provider, required this.name});

  /// Vendor colours are gone: the provider's name text carries identity.
  static Color colorFor(BuildContext context, AiProvider? p) =>
      context.wimz.ink;

  @override
  Widget build(BuildContext context) {
    final c = colorFor(context, provider);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: context.wimz.surfaceSunken,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.wimz.lineStrong),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontWeight: FontWeight.bold, color: c),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final AiAuditEntry entry;
  const _AuditRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final color = entry.isOk ? context.wimz.inkMuted : context.wimz.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            DateFormat.Hm(locale).format(entry.ts.toLocal()),
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: context.wimz.inkMuted),
          ),
          const SizedBox(width: 8),
          Icon(
            entry.isOk ? Icons.check : Icons.warning_amber,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${entry.assistant} · ${entry.action}'
              '${entry.scope != null ? ' (${entry.scope})' : ''}'
              '${entry.detail != null ? ' — ${entry.detail}' : ''}',
              style: TextStyle(fontSize: 12, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  final int? count;
  const _Header(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        count != null ? '${text.toUpperCase()} ($count)' : text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text,
          style: TextStyle(color: context.wimz.inkMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
}

class _Unsupported extends StatelessWidget {
  final String text;
  const _Unsupported({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: context.wimz.inkMuted),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.wimz.inkMuted)),
            ],
          ),
        ),
      );
}

/// One-screen setup guide per assistant: numbered steps + the connector URL
/// with a copy button. Content fits a phone without scrolling.
class _SetupGuideSheet extends StatelessWidget {
  final AiProvider provider;
  final String? connectorUrl;
  final Future<void> Function(String) onCopy;
  const _SetupGuideSheet({
    required this.provider,
    required this.connectorUrl,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = provider.displayName;
    final note = switch (provider) {
      AiProvider.chatgpt => l.aiGuideNoteChatgpt,
      AiProvider.claude => l.aiGuideNoteClaude,
      AiProvider.grok => l.aiGuideNoteGrok,
      AiProvider.perplexity => l.aiGuideNotePerplexity,
    };
    final steps = [
      l.aiGuideStep1(name),
      l.aiGuideStep2,
      l.aiGuideStep3,
      l.aiGuideStep4,
      l.aiGuideStep5(name),
    ];
    final c = context.wimz.inkMuted;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderBadge(provider: provider, name: name),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.aiGuideTitle(name),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.wimz.ink),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: TextStyle(fontSize: 12, color: c),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.wimz.surfaceSunken,
                        border: Border.all(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(steps[i],
                          style: TextStyle(
                              fontSize: 14, color: context.wimz.ink)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: context.wimz.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      connectorUrl ?? l.aiConnectorUrlMissing,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: connectorUrl != null
                            ? context.wimz.ink
                            : context.wimz.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: connectorUrl == null
                        ? null
                        : () => onCopy(connectorUrl!),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(l.aiCopyUrl),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
