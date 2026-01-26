import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/services/photo_service.dart';
import '../../../domain/providers/photo_provider.dart';

/// Photo gallery screen showing all captured photos
class PhotoGalleryScreen extends ConsumerWidget {
  const PhotoGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoState = ref.watch(photoProvider);
    final photos = photoState.photos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Gallery'),
        actions: [
          if (photos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(photoProvider.notifier).loadPhotos(),
              tooltip: 'Refresh',
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No photos yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take photos from the video view',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Text(
                  photo.formattedTime,
                  style: const TextStyle(
                    color: Colors.white,
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

/// Extension to add formatted time to CapturedPhoto
extension CapturedPhotoExt on CapturedPhoto {
  String get formattedTime {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  String get formattedDate {
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }
}

/// Full screen photo viewer
class _PhotoViewerScreen extends ConsumerWidget {
  final CapturedPhoto photo;

  const _PhotoViewerScreen({required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${photo.formattedDate} ${photo.formattedTime}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePhoto(context),
            tooltip: 'Share',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref),
            tooltip: 'Delete',
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
                  const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
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
        text: 'WIM-Z Photo - ${photo.formattedDate}',
        sharePositionOrigin: shareOrigin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Close dialog first, then viewer, then delete
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close viewer (outer context)
              ref.read(photoProvider.notifier).deletePhoto(photo.localPath);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
