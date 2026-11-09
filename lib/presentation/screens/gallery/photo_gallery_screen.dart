import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/services/photo_service.dart';
import '../../../domain/providers/dog_profiles_provider.dart';
import '../../../domain/providers/photo_provider.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_theme.dart';

/// Photo gallery screen showing all captured photos
class PhotoGalleryScreen extends ConsumerStatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  ConsumerState<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends ConsumerState<PhotoGalleryScreen> {
  /// Relay brief 2026-11-07 §3: refresh relay photos while the screen is open
  /// so a photo asked for via the assistant shows up without a manual pull.
  static const Duration _relayRefreshInterval = Duration(seconds: 20);
  Timer? _relayRefresh;

  @override
  void initState() {
    super.initState();
    // §2: catch-up when the Photos screen is opened.
    Future.microtask(
        () => ref.read(photoProvider.notifier).syncRelayPhotos(reason: 'gallery'));
    _relayRefresh = Timer.periodic(_relayRefreshInterval, (_) {
      if (!mounted) return;
      ref.read(photoProvider.notifier).syncRelayPhotos(reason: 'gallery-tick');
    });
  }

  @override
  void dispose() {
    _relayRefresh?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final n = ref.read(photoProvider.notifier);
    await n.loadPhotos();
    await n.syncRelayPhotos(reason: 'gallery-refresh');
  }

  @override
  Widget build(BuildContext context) {
    final photoState = ref.watch(photoProvider);
    final photos = photoState.photos;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.galleryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: context.l10n.galleryRefresh,
          ),
        ],
      ),
      body: photos.isEmpty
          ? _buildEmptyState(context)
          : _buildPhotoGrid(context, ref, photos),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.galleryNoPhotos,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.galleryTakePhotosHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(
    BuildContext context,
    WidgetRef ref,
    List<CapturedPhoto> photos,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return _PhotoThumbnail(
          photo: photo,
          onTap: () => _showPhotoViewer(context, ref, photo),
        );
      },
    );
  }

  void _showPhotoViewer(
    BuildContext context,
    WidgetRef ref,
    CapturedPhoto photo,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PhotoViewerScreen(photo: photo),
      ),
    );
  }
}

/// Photo thumbnail widget
class _PhotoThumbnail extends StatelessWidget {
  final CapturedPhoto photo;
  final VoidCallback onTap;

  const _PhotoThumbnail({
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Overlays on a photo: scrim + on-video tokens.
    final w = context.wimz;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(photo.localPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image, size: 32),
                );
              },
            ),
            if (photo.isAssistantPhoto)
              Positioned(
                top: 4,
                right: 4,
                child: Tooltip(
                  message: context.l10n.galleryAssistantPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: w.scrim(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: w.onVideo,
                    ),
                  ),
                ),
              ),
            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      w.scrim(0.7),
                    ],
                  ),
                ),
                child: Text(
                  photo.formattedTime(context),
                  style: TextStyle(
                    color: w.onVideo,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension to add locale-aware formatted time/date to CapturedPhoto
extension CapturedPhotoExt on CapturedPhoto {
  String formattedTime(BuildContext context) =>
      DateFormat.jm(Localizations.localeOf(context).toString())
          .format(timestamp);

  String formattedDate(BuildContext context) =>
      DateFormat.yMd(Localizations.localeOf(context).toString())
          .format(timestamp);
}

/// Full screen photo viewer
class _PhotoViewerScreen extends ConsumerWidget {
  final CapturedPhoto photo;

  const _PhotoViewerScreen({required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dogId = photo.dogId;
    final dogName =
        dogId == null ? null : ref.watch(dogProfileProvider(dogId))?.name;
    final subtitle = photo.isAssistantPhoto
        ? (dogName != null && dogName.isNotEmpty
            ? context.l10n.galleryAssistantPhotoFor(dogName)
            : context.l10n.galleryAssistantPhoto)
        : null;
    // Full-screen photo viewer: always a dark ground.
    final w = context.wimz;
    return Scaffold(
      backgroundColor: w.brandInk,
      appBar: AppBar(
        backgroundColor: w.brandInk,
        foregroundColor: w.onVideo,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${photo.formattedDate(context)} ${photo.formattedTime(context)}',
              style: const TextStyle(fontSize: 14),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: w.onVideo.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePhoto(context),
            tooltip: context.l10n.galleryShare,
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref),
            tooltip: context.l10n.delete,
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.file(
            File(photo.localPath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: w.onVideo.withValues(alpha: 0.54), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.galleryFailedToLoad,
                    style: TextStyle(color: w.onVideo.withValues(alpha: 0.6)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _sharePhoto(BuildContext context) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final shareOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.fromCenter(
              center: MediaQuery.of(context).size.center(Offset.zero),
              width: 100,
              height: 100,
            );

      await Share.shareXFiles(
        [XFile(photo.localPath)],
        text: context.l10n.galleryShareText(photo.formattedDate(context)),
        sharePositionOrigin: shareOrigin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.galleryShareFailed('$e'))),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.galleryDeleteTitle),
        content: Text(context.l10n.galleryDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          // Destructive: error slot, with icon + "Delete" label.
          FilledButton.icon(
            onPressed: () {
              // Close dialog first, then viewer, then delete
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close viewer (outer context)
              ref.read(photoProvider.notifier).deletePhoto(photo.localPath);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }
}
