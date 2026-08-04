import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:zelp/services/animated_image_frames.dart';

/// Large horizontal gallery of market screenshots.
///
/// Animated images (GIF / animated WebP) are expanded into unique frames so
/// each distinct visual appears as its own tile.
class StoreItemScreenshots extends StatefulWidget {
  const StoreItemScreenshots({
    required this.urls,
    this.loadNetwork = true,
    super.key,
  });

  final List<String> urls;
  final bool loadNetwork;

  @override
  State<StoreItemScreenshots> createState() => _StoreItemScreenshotsState();
}

class _StoreItemScreenshotsState extends State<StoreItemScreenshots> {
  late Future<List<_GalleryTile>> _tilesFuture;

  @override
  void initState() {
    super.initState();
    _tilesFuture = _resolveTiles();
  }

  @override
  void didUpdateWidget(covariant StoreItemScreenshots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls != widget.urls || oldWidget.loadNetwork != widget.loadNetwork) {
      _tilesFuture = _resolveTiles();
    }
  }

  Future<List<_GalleryTile>> _resolveTiles() async {
    if (!widget.loadNetwork || widget.urls.isEmpty) {
      return const <_GalleryTile>[];
    }
    final List<_GalleryTile> tiles = <_GalleryTile>[];
    for (final String url in widget.urls) {
      final List<Uint8List> frames = await fetchUniqueAnimatedFrames(url);
      if (frames.isEmpty) {
        tiles.add(_GalleryTile.network(url));
      } else {
        for (int i = 0; i < frames.length; i++) {
          tiles.add(_GalleryTile.frame(url: url, index: i, bytes: frames[i]));
        }
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double height = (screenWidth * 0.72).clamp(280.0, 420.0);
    final double tileWidth = (screenWidth - 40).clamp(240.0, 480.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Screenshots', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: FutureBuilder<List<_GalleryTile>>(
            future: _tilesFuture,
            builder: (BuildContext context, AsyncSnapshot<List<_GalleryTile>> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return _loadingStrip(height: height, width: tileWidth);
              }
              final List<_GalleryTile> tiles = snapshot.data ?? const <_GalleryTile>[];
              if (tiles.isEmpty) {
                return _loadingStrip(height: height, width: tileWidth, urls: widget.urls);
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tiles.length,
                separatorBuilder: (_, int index) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final _GalleryTile tile = tiles[index];
                  return _ScreenshotFrame(
                    tile: tile,
                    width: tileWidth,
                    height: height,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _loadingStrip({
    required double height,
    required double width,
    List<String>? urls,
  }) {
    final List<String> sources = urls ?? widget.urls;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: sources.length,
      separatorBuilder: (_, int index) => const SizedBox(width: 12),
      itemBuilder: (BuildContext context, int index) {
        final String url = sources[index];
        return SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, Object error, StackTrace? stackTrace) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator.adaptive());
              },
            ),
          ),
        );
      },
    );
  }
}

class _GalleryTile {
  const _GalleryTile._({required this.key, this.url, this.bytes});

  factory _GalleryTile.network(String url) => _GalleryTile._(key: url, url: url);

  factory _GalleryTile.frame({
    required String url,
    required int index,
    required Uint8List bytes,
  }) => _GalleryTile._(key: '$url#$index', bytes: bytes);

  final String key;
  final String? url;
  final Uint8List? bytes;
}

class _ScreenshotFrame extends StatelessWidget {
  const _ScreenshotFrame({
    required this.tile,
    required this.width,
    required this.height,
  });

  final _GalleryTile tile;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget image = tile.bytes != null
        ? Image.memory(
            tile.bytes!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, Object error, StackTrace? stackTrace) =>
                Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
          )
        : Image.network(
            tile.url!,
            fit: BoxFit.contain,
            errorBuilder: (_, Object error, StackTrace? stackTrace) =>
                Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator.adaptive());
            },
          );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: image,
      ),
    );
  }
}
