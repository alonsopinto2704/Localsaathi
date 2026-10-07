import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/models/provider.dart';
import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../utils/image_metadata.dart';

/// The image for a [ProviderPhoto], whatever its source, or a neutral
/// placeholder when there is nothing to draw.
class ProviderPhotoImage extends StatelessWidget {
  const ProviderPhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });

  final ProviderPhoto photo;
  final BoxFit fit;

  // Decoding base64 on every build would stutter in scrolling lists.
  static final Expando<Uint8List> _decoded = Expando<Uint8List>();

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = _Placeholder(caption: photo.caption);
    final String? data = photo.imageBase64;
    if (data != null) {
      final Uint8List bytes = _decoded[photo] ??= base64Decode(data);
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    if (photo.assetPath != null) {
      return Image.asset(
        photo.assetPath!,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    if (photo.remoteUrl != null && photo.remoteUrl!.isNotEmpty) {
      return Image.network(
        photo.remoteUrl!,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return placeholder;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.image_outlined, color: theme.colorScheme.outline),
            if (caption.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                caption,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A rounded photo thumbnail. Tapping opens [showProviderPhotoViewer] unless
/// [onTap] is given.
class ProviderPhotoTile extends StatelessWidget {
  const ProviderPhotoTile({
    super.key,
    required this.photo,
    this.size = 112,
    this.onTap,
  });

  final ProviderPhoto photo;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            child: InkWell(
              onTap: onTap,
              child: ProviderPhotoImage(photo: photo),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal strip of photos; tapping one opens the full-screen viewer.
class ProviderPhotoStrip extends StatelessWidget {
  const ProviderPhotoStrip({
    super.key,
    required this.photos,
    this.size = 112,
  });

  final List<ProviderPhoto> photos;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) => ProviderPhotoTile(
          photo: photos[index],
          size: size,
          onTap: () => showProviderPhotoViewer(context, photos, index),
        ),
      ),
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer.
Future<void> showProviderPhotoViewer(
  BuildContext context,
  List<ProviderPhoto> photos,
  int initialIndex,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (BuildContext context) => _PhotoViewer(
      photos: photos,
      initialIndex: initialIndex,
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<ProviderPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProviderPhoto current = widget.photos[_index];
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pages,
            itemCount: widget.photos.length,
            onPageChanged: (int i) => setState(() => _index = i),
            itemBuilder: (BuildContext context, int i) => InteractiveViewer(
              child: Center(
                child: ProviderPhotoImage(
                  photo: widget.photos[i],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: SafeArea(
              child: IconButton(
                tooltip: context.strings.close,
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: SafeArea(
              child: Text(
                <String>[
                  if (current.caption.isNotEmpty) current.caption,
                  '${_index + 1} / ${widget.photos.length}',
                ].join('  ·  '),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets a provider add and remove photos of their work.
///
/// Images are resized and re-encoded on the device before they are kept, so a
/// 12-megapixel phone photo becomes a ~150 KB JPEG.
class ProviderPhotoEditor extends StatefulWidget {
  const ProviderPhotoEditor({
    super.key,
    required this.photos,
    required this.onChanged,
  });

  final List<ProviderPhoto> photos;
  final ValueChanged<List<ProviderPhoto>> onChanged;

  @override
  State<ProviderPhotoEditor> createState() => _ProviderPhotoEditorState();
}

class _ProviderPhotoEditorState extends State<ProviderPhotoEditor> {
  bool _picking = false;

  Future<void> _add() async {
    final strings = context.strings;
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.photoFromGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(strings.photoFromCamera),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _picking = true);
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (file == null) return;
      // Location, camera serial and owner metadata never leave the device.
      final Uint8List? clean = stripImageMetadata(await file.readAsBytes());
      if (clean == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.photoFormatUnsupported)),
          );
        }
        return;
      }
      widget.onChanged(<ProviderPhoto>[
        ...widget.photos,
        ProviderPhoto(
          id: 'photo-${DateTime.now().microsecondsSinceEpoch}',
          caption: '',
          imageBase64: base64Encode(clean),
          uploadedAt: DateTime.now(),
        ),
      ]);
    } on Object {
      // Permission denied, camera missing, unreadable file: say so, keep going.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.photoPickFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final ThemeData theme = Theme.of(context);
    final bool full = widget.photos.length >= AppConfig.freePhotoLimit;
    const double size = 104;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (int i = 0; i < widget.photos.length; i++)
              Stack(
                children: <Widget>[
                  ProviderPhotoTile(
                    photo: widget.photos[i],
                    size: size,
                    onTap: () =>
                        showProviderPhotoViewer(context, widget.photos, i),
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: strings.removePhoto,
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        color: Colors.white,
                        onPressed: () => widget.onChanged(
                          <ProviderPhoto>[...widget.photos]..removeAt(i),
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ],
              ),
            if (!full)
              SizedBox.square(
                dimension: size,
                child: OutlinedButton(
                  onPressed: _picking ? null : _add,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
                  child: _picking
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Icon(Icons.add_a_photo_outlined),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              strings.addPhoto,
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          full
              ? strings.photoLimitReached
              : '${widget.photos.length}/${AppConfig.freePhotoLimit} · ${strings.photoHelp}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
