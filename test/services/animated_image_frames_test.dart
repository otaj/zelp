import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zelp/services/animated_image_frames.dart';

Uint8List _solidPng({required int r, required int g, required int b}) {
  final img.Image image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

img.Image _redBlueRedAnimation() {
  final img.Image anim = img.Image(width: 4, height: 4)..frameType = img.FrameType.animation;
  img.fill(anim, color: img.ColorRgb8(255, 0, 0));
  anim.frameDuration = 50;

  final img.Image blue = img.Image(width: 4, height: 4);
  img.fill(blue, color: img.ColorRgb8(0, 0, 255));
  blue.frameDuration = 50;
  anim.addFrame(blue);

  final img.Image redAgain = img.Image(width: 4, height: 4);
  img.fill(redAgain, color: img.ColorRgb8(255, 0, 0));
  redAgain.frameDuration = 50;
  anim.addFrame(redAgain);
  return anim;
}

void main() {
  group('animated_image_frames', () {
    test('looksLikeGif detects magic bytes', () {
      expect(
        looksLikeGif(Uint8List.fromList(<int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61])),
        isTrue,
      );
      expect(looksLikeGif(_solidPng(r: 1, g: 2, b: 3)), isFalse);
    });

    test('uniqueFramesFromBytes returns empty for static images', () {
      expect(uniqueFramesFromBytes(_solidPng(r: 10, g: 20, b: 30)), isEmpty);
    });

    test('uniqueFramesFromImage drops exact duplicate frames', () {
      final List<Uint8List> frames = uniqueFramesFromImage(_redBlueRedAnimation());
      expect(frames.length, 2);
      for (final Uint8List frame in frames) {
        expect(looksLikeGif(frame), isFalse);
        expect(img.decodePng(frame), isNotNull);
      }
    });

    test('uniqueFramesFromBytes expands animated GIF into stills', () {
      final Uint8List gif = Uint8List.fromList(img.encodeGif(_redBlueRedAnimation()));
      expect(looksLikeGif(gif), isTrue);
      final List<Uint8List> frames = uniqueFramesFromBytes(gif);
      // GIF palette round-trip can keep near-duplicate reds as distinct pixels;
      // decomposition must still yield more than one still.
      expect(frames.length, greaterThanOrEqualTo(2));
      for (final Uint8List frame in frames) {
        expect(looksLikeGif(frame), isFalse);
        expect(img.decodePng(frame), isNotNull);
      }
    });
  });
}
