import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// True when [bytes] looks like a GIF (GIF87a / GIF89a).
bool looksLikeGif(Uint8List bytes) {
  if (bytes.length < 6) return false;
  return bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38 &&
      (bytes[4] == 0x37 || bytes[4] == 0x39) &&
      bytes[5] == 0x61;
}

/// Decodes an animated image and returns PNG bytes for each unique frame.
///
/// Duplicate frames (common in market GIF previews) are dropped by hashing
/// RGBA pixels. Non-animated / undecodable input yields an empty list so the
/// caller can keep showing the original network image.
List<Uint8List> uniqueFramesFromBytes(Uint8List bytes) {
  final img.Image? decoded = looksLikeGif(bytes) ? img.decodeGif(bytes) : img.decodeImage(bytes);
  if (decoded == null || decoded.numFrames <= 1) {
    return const <Uint8List>[];
  }
  return uniqueFramesFromImage(decoded);
}

/// Dedupes animation frames into PNG stills (hash of RGBA pixels).
@visibleForTesting
List<Uint8List> uniqueFramesFromImage(img.Image decoded) {
  if (decoded.numFrames <= 1) return const <Uint8List>[];

  final Set<String> seen = <String>{};
  final List<Uint8List> unique = <Uint8List>[];
  for (final img.Image frame in decoded.frames) {
    final Digest digest = sha256.convert(
      frame.getBytes(order: img.ChannelOrder.rgba),
    );
    if (!seen.add(digest.toString())) continue;
    unique.add(Uint8List.fromList(img.encodePng(frame)));
  }
  // A single unique visual among many identical frames is not useful as a
  // gallery — treat it as a static image (caller keeps the network URL).
  if (unique.length <= 1) return const <Uint8List>[];
  return unique;
}

/// Isolate-friendly entry for [compute].
List<Uint8List> uniqueFramesFromBytesIsolate(Uint8List bytes) => uniqueFramesFromBytes(bytes);

/// Fetches [url] and, when animated, returns unique PNG frames.
///
/// Returns an empty list for static images, fetch failures, or single-frame
/// animations so the caller can fall back to a network image.
Future<List<Uint8List>> fetchUniqueAnimatedFrames(
  String url, {
  http.Client? httpClient,
}) async {
  final http.Client client = httpClient ?? http.Client();
  final bool ownsClient = httpClient == null;
  try {
    final http.Response response = await client.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <Uint8List>[];
    }
    final Uint8List bytes = response.bodyBytes;
    if (bytes.isEmpty) return const <Uint8List>[];
    // Fast path: only decode when the payload looks animated (GIF) or the URL
    // hints at GIF; WebP/APNG still go through decodeImage when needed.
    final String lower = url.toLowerCase();
    final bool maybeAnimated = looksLikeGif(bytes) || lower.contains('.gif') || lower.contains('.webp');
    if (!maybeAnimated) return const <Uint8List>[];
    return compute(uniqueFramesFromBytesIsolate, bytes);
  } on Exception {
    return const <Uint8List>[];
  } finally {
    if (ownsClient) client.close();
  }
}
