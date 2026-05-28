import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/models/dog_profile.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aruco_marker_view.dart';

/// Unified Edit Dog screen — replaces the bottom-sheet of one-off
/// rename/change-photo/change-breed dialogs. Single form, single Save.
/// Also exposes a Re-Print Marker action so users aren't forced to recreate
/// a dog just to reprint its ArUco tag (Build 104).
class EditDogScreen extends ConsumerStatefulWidget {
  final String dogId;

  const EditDogScreen({super.key, required this.dogId});

  @override
  ConsumerState<EditDogScreen> createState() => _EditDogScreenState();
}

class _EditDogScreenState extends ConsumerState<EditDogScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  DogColor _color = DogColor.mixed;
  bool _isSaving = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _breedController = TextEditingController();
  }

  void _hydrateFrom(DogProfile profile) {
    _nameController.text = profile.name;
    _breedController.text = profile.breed ?? '';
    _color = profile.color;
    _initialised = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(dogProfileProvider(widget.dogId));

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Dog')),
        body: const Center(child: Text('Dog not found')),
      );
    }

    if (!_initialised) _hydrateFrom(profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Dog'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _save(profile),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhotoEditor(profile: profile),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _breedController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Breed',
                hintText: 'e.g. Golden Retriever',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DogColor>(
              value: _color,
              decoration: const InputDecoration(
                labelText: 'Coat color',
                border: OutlineInputBorder(),
              ),
              items: DogColor.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _color = v);
              },
            ),
            const SizedBox(height: 24),
            _MarkerSection(profile: profile),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: BorderSide(color: AppTheme.error.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSaving ? null : () => _confirmDelete(profile),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Dog'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(DogProfile profile) async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final newBreed = _breedController.text.trim();
      await ref.read(dogProfilesProvider.notifier).updateProfile(
            profile.copyWith(
              name: newName,
              breed: newBreed.isEmpty ? null : newBreed,
              color: _color,
            ),
          );
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
      if (mounted) router.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete(DogProfile profile) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(dogProfilesProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Dog?'),
        content: Text(
          'Are you sure you want to delete ${profile.name}? '
          'This will remove all their data and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await notifier.removeProfile(profile.id);
    messenger.showSnackBar(SnackBar(content: Text('${profile.name} deleted')));
    if (mounted) router.go('/dogs');
  }
}

class _PhotoEditor extends ConsumerWidget {
  final DogProfile profile;
  const _PhotoEditor({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _changePhoto(context, ref),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceLight,
                border: Border.all(color: AppTheme.primary, width: 3),
              ),
              child: _buildPhoto(),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _changePhoto(context, ref),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Change photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    if (profile.localPhotoPath != null) {
      final file = File(profile.localPhotoPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 120,
            height: 120,
            key: ValueKey('edit_photo_${profile.id}_${profile.photoVersion}'),
          ),
        );
      }
    }
    if (profile.photoUrl != null) {
      return ClipOval(
        child: Image.network(profile.photoUrl!, fit: BoxFit.cover),
      );
    }
    return Icon(Icons.pets, color: AppTheme.primary, size: 48);
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(dogProfilesProvider.notifier);

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Photo Source'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
            ),
          ),
        ],
      ),
    );
    if (source == null) return;

    final image = await ImagePicker()
        .pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (image == null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/dog_photos');
      await photosDir.create(recursive: true);

      final permanentPath = '${photosDir.path}/${profile.id}.jpg';
      final oldFile = File(permanentPath);
      if (await oldFile.exists()) await oldFile.delete();
      await File(image.path).copy(permanentPath);

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      await notifier.updateProfilePhoto(profile.id, permanentPath);
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save photo: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

class _MarkerSection extends StatelessWidget {
  final DogProfile profile;
  const _MarkerSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final markerId = profile.arucoMarkerId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ArUco Marker',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            markerId == null
                ? 'No marker assigned. Re-create this dog to assign one.'
                : 'DICT_4X4_1000 — ID $markerId',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          if (markerId != null) ...[
            const SizedBox(height: 12),
            Center(child: ArucoMarkerView(markerId: markerId, size: 160)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _printMarker(context, markerId, profile.name),
              icon: const Icon(Icons.print),
              label: const Text('Print marker'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build 104 — robust print flow. If the marker PNG bundle is present we
  /// print the marker directly; if not (the assets line is still commented
  /// out in pubspec), we fall back to a one-page PDF that prominently lists
  /// the marker ID + a URL the user can use to generate the actual marker
  /// from a public ArUco tool. Either way the user gets something printable.
  Future<void> _printMarker(
      BuildContext context, int markerId, String dogName) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await loadArucoMarkerBytes(markerId);
    final pdf = pw.Document();
    final hasMarker = bytes != null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (ctx) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                dogName.isNotEmpty ? dogName : 'Dog',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'ARUCO DICT_4X4_1000 — ID $markerId',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 24),
              if (hasMarker)
                pw.Container(
                  width: 4 * PdfPageFormat.inch,
                  height: 4 * PdfPageFormat.inch,
                  child: pw.Image(pw.MemoryImage(bytes),
                      fit: pw.BoxFit.contain),
                )
              else ...[
                pw.Container(
                  width: 4 * PdfPageFormat.inch,
                  height: 4 * PdfPageFormat.inch,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 2),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text('ID $markerId',
                          style: pw.TextStyle(
                              fontSize: 96,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        'Marker image not bundled in this build.',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'To generate this marker, visit:',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'https://chev.me/arucogen/?dict=DICT_4X4_1000&id=$markerId',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'WIM-Z ArUco $markerId.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
