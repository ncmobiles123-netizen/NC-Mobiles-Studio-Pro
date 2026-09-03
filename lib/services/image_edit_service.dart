import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/frame_model.dart';

/// Pure, stateless pixel operations. Kept separate from the provider so
/// they can run on an isolate later if a given photo is large enough to
/// risk jank on the UI thread (see [decodeAndDownsampleForEditing]).
class ImageEditService {
  ImageEditService._();

  /// Product photos from phone cameras can be 12MP+. Editing at full
  /// resolution live on the canvas is wasted work — we keep a
  /// downsampled "working" copy for interactive gestures and only touch
  /// full-resolution pixels at export time. This is the main lever for
  /// the "no freezing" performance requirement.
  static img.Image decodeAndDownsampleForEditing(Uint8List bytes, {int maxDim = 1600}) {
    final decoded = img.decodeImage(bytes)!;
    if (decoded.width <= maxDim && decoded.height <= maxDim) return decoded;
    final scale = maxDim / (decoded.width > decoded.height ? decoded.width : decoded.height);
    return img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }

  static Uint8List cropFraction(Uint8List bytes, CropRect crop) {
    final decoded = img.decodeImage(bytes)!;
    final x = (crop.left * decoded.width).round();
    final y = (crop.top * decoded.height).round();
    final w = (crop.width * decoded.width).round().clamp(1, decoded.width - x);
    final h = (crop.height * decoded.height).round().clamp(1, decoded.height - y);
    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodePng(cropped));
  }

  static Uint8List rotate(Uint8List bytes, double degrees) {
    final decoded = img.decodeImage(bytes)!;
    final rotated = img.copyRotate(decoded, angle: degrees);
    return Uint8List.fromList(img.encodePng(rotated));
  }

  static Uint8List flip(Uint8List bytes, {bool horizontal = false, bool vertical = false}) {
    final decoded = img.decodeImage(bytes)!;
    var out = decoded;
    if (horizontal) out = img.flipHorizontal(out);
    if (vertical) out = img.flipVertical(out);
    return Uint8List.fromList(img.encodePng(out));
  }

  static Uint8List resize(Uint8List bytes, {required int width, required int height}) {
    final decoded = img.decodeImage(bytes)!;
    final resized = img.copyResize(
      decoded,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodePng(resized));
  }

  /// "Upscale" — a fast, fully offline bicubic upscale (2x by default).
  /// This is intentionally lightweight rather than a super-resolution
  /// network: it keeps the tool instant on mid-range phones and needs no
  /// extra bundled model. If sharper AI upscaling is wanted later, a
  /// second small TFLite model (e.g. a mobile ESRGAN variant) can be
  /// dropped in alongside u2netp.tflite using the same Interpreter
  /// pattern as BackgroundRemovalService.
  static Uint8List upscale(Uint8List bytes, {double factor = 2.0}) {
    final decoded = img.decodeImage(bytes)!;
    final upscaled = img.copyResize(
      decoded,
      width: (decoded.width * factor).round(),
      height: (decoded.height * factor).round(),
      interpolation: img.Interpolation.cubic,
    );
    return Uint8List.fromList(img.encodePng(upscaled));
  }

  /// Soft eraser — punches transparency into a circular region. Used by
  /// the "Erase" tool for manual cleanup after Background Remove.
  static Uint8List eraseCircle(
    Uint8List bytes, {
    required double centerXFraction,
    required double centerYFraction,
    required double radiusFraction,
  }) {
    var decoded = img.decodeImage(bytes)!;
    if (!decoded.hasAlpha) {
      decoded = decoded.convert(numChannels: 4);
    }
    final cx = centerXFraction * decoded.width;
    final cy = centerYFraction * decoded.height;
    final r = radiusFraction * decoded.width;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= r * r) {
          final p = decoded.getPixel(x, y);
          decoded.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(decoded));
  }
}
