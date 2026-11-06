import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/websocket_client.dart';
import '../../../data/datasources/robot_api.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/device_provider.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/settings_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Song upload (phone → robot). Public-domain / own recordings only — the
/// checkbox is the attestation. Cloud: HTTP multipart via the relay
/// (/api/music/upload). Local-AP: base64 over the robot WS (upload_song).
class SongUploadScreen extends ConsumerStatefulWidget {
  const SongUploadScreen({super.key});

  @override
  ConsumerState<SongUploadScreen> createState() => _SongUploadScreenState();
}

class _SongUploadScreenState extends ConsumerState<SongUploadScreen> {
  static const _maxBytes = 20 * 1024 * 1024;

  bool _attested = false;
  bool _uploading = false;
  double _progress = 0;
  String? _currentName;
  String? _resultText;
  bool _resultOk = false;

  Future<void> _pickAndUpload() async {
    final l = context.l10n;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) return;
    if (file.size > _maxBytes) {
      setState(() {
        _resultOk = false;
        _resultText = l.songUploadTooLarge;
      });
      return;
    }

    final selectedDog = ref.read(selectedDogProvider);
    if (selectedDog == null) {
      setState(() {
        _resultOk = false;
        _resultText = l.songUploadNoDog;
      });
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
      _currentName = file.name;
      _resultText = null;
    });

    String? error;
    final isLocal = ref.read(settingsProvider).localModeEnabled;
    final token = isLocal ? null : ref.read(authTokenProvider);
    if (token != null) {
      error = await ref.read(robotApiProvider).uploadMusic(
            token: token,
            filePath: file.path!,
            filename: file.name,
            dogId: selectedDog.id,
            deviceId: ref.read(deviceIdProvider),
            onProgress: (sent, total) {
              if (total > 0 && mounted) {
                setState(() => _progress = sent / total);
              }
            },
          );
    } else if (isLocal) {
      // Robot-direct path: the local WS accepts base64 song uploads.
      try {
        final bytes = await File(file.path!).readAsBytes();
        final ext = file.extension?.toLowerCase() ?? 'mp3';
        ref
            .read(websocketClientProvider)
            .sendUploadSong(file.name, base64Encode(bytes), ext);
        if (mounted) setState(() => _progress = 1);
      } catch (e) {
        error = '$e';
      }
    } else {
      error = l.songUploadNotSignedIn;
    }

    if (!mounted) return;
    setState(() {
      _uploading = false;
      _resultOk = error == null;
      _resultText =
          error == null ? l.songUploadDone(file.name) : l.songUploadFailed(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dog = ref.watch(selectedDogProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.songUploadTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.library_music, size: 64, color: AppTheme.primary),
              const SizedBox(height: 16),
              Text(
                l.songUploadPdNotice,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _attested,
                onChanged: _uploading
                    ? null
                    : (v) => setState(() => _attested = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
                title: Text(l.songUploadPdCheckbox,
                    style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
                onPressed: (!_attested || _uploading) ? null : _pickAndUpload,
                icon: const Icon(Icons.upload_file),
                label: Text(_uploading && _currentName != null
                    ? l.songUploadUploading(_currentName!)
                    : l.songUploadChoose),
              ),
              const SizedBox(height: 6),
              Text(
                l.songUploadFormats,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
              const SizedBox(height: 16),
              if (_uploading)
                LinearProgressIndicator(
                  value: _progress > 0 && _progress < 1 ? _progress : null,
                  minHeight: 4,
                ),
              if (_resultText != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_resultOk ? AppTheme.accent : AppTheme.error)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(_resultOk ? Icons.check_circle : Icons.error_outline,
                          color: _resultOk ? AppTheme.accent : AppTheme.error,
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resultOk
                              ? '${_resultText!}\n${l.songUploadPlayHint}'
                              : _resultText!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(flex: 2),
              Text(
                dog != null ? '${l.todayCardTitle}: ${dog.name}' : l.songUploadNoDog,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
