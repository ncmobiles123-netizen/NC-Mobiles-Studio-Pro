import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device background removal.
///
/// Model: U2-Netp (the "portable" 4.7MB variant of U2-Net used by the
/// open-source `rembg` project) converted from ONNX/PyTorch to
/// TensorFlow Lite. This ships fully inside the app bundle at
/// `assets/models/u2netp.tflite` — no network call is ever made, so
/// there is no API cost and no internet requirement at runtime.
///
/// --- HOW TO GET THE MODEL FILE (do this once, before building) -----
/// This repo does not include the binary .tflite weights (they're a
/// separate download, not source code). To obtain a free, open-source,
/// offline-capable model:
///   1. Easiest: use the pre-converted U2Netp TFLite file published by
///      the `danielgatis/rembg` community / PINTO0309's "model-zoo"
///      TFLite conversions (search "u2netp.tflite" — several MIT/Apache
///      licensed conversions exist).
///   2. Or convert yourself: download u2netp.onnx from the official
///      rembg model releases, then run it through `onnx-tf` -> SavedModel
///      -> `tflite_convert` to produce a .tflite file. Quantize to
///      float16 or int8 for faster mobile inference.
///   3. Drop the resulting file at assets/models/u2netp.tflite (already
///      wired into pubspec.yaml's assets list).
/// Input: 320x320x3 float32, normalized to [0,1] then standardized with
/// mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225] (matches the
/// original U2Net training pipeline). Output: 320x320x1 float32 saliency
/// mask in [0,1].
/// ----------------------------------------------------------------------
class BackgroundRemovalService {
  BackgroundRemovalService._internal();
  static final BackgroundRemovalService instance = BackgroundRemovalService._internal();

  Interpreter? _interpreter;
  bool _loading = false;
  static const int _inputSize = 320;
  static const _mean = [0.485, 0.456, 0.406];
  static const _std = [0.229, 0.224, 0.225];

  bool get isReady => _interpreter != null;

  /// Cheap existence check for the bundled model asset, without paying
  /// the cost of constructing a full TFLite interpreter. Used at app
  /// startup so the UI can show "Background Remove — coming soon"
  /// instead of letting the user tap it and hit a runtime error.
  Future<bool> isModelBundled() async {
    try {
      final data = await rootBundle.load('assets/models/u2netp.tflite');
      return data.lengthInBytes > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> warmUp() async {
    if (_interpreter != null || _loading) return;
    _loading = true;
    try {
      final options = InterpreterOptions()..threads = 4;
      // NNAPI/Metal delegate is picked up automatically on supported
      // devices when available; falls back to pure CPU otherwise.
      _interpreter = await Interpreter.fromAsset(
        'assets/models/u2netp.tflite',
        options: options,
      );
    } catch (e) {
      // Model missing or failed to load — caller should surface a
      // friendly error rather than crash the editor.
      _interpreter = null;
      rethrow;
    } finally {
      _loading = false;
    }
  }

  /// Runs background removal on [inputBytes] (any common image format)
  /// and returns PNG bytes with transparency where the background was.
  /// Caller is responsible for keeping the original bytes elsewhere for
  /// undo — this method never mutates or discards the source.
  Future<Uint8List> removeBackground(Uint8List inputBytes) async {
    if (_interpreter == null) {
      await warmUp();
    }
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError(
        'Background removal model not available. Confirm '
        'assets/models/u2netp.tflite is bundled (see setup notes in '
        'background_removal_service.dart).',
      );
    }

    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      throw ArgumentError('Could not decode image for background removal.');
    }
    final origW = decoded.width;
    final origH = decoded.height;

    // --- Preprocess: resize to model input, normalize ---
    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final p = resized.getPixel(x, y);
            return [
              (p.r / 255.0 - _mean[0]) / _std[0],
              (p.g / 255.0 - _mean[1]) / _std[1],
              (p.b / 255.0 - _mean[2]) / _std[2],
            ];
          },
        ),
      ),
    );

    // Output shape [1, 320, 320, 1] — one saliency value per pixel.
    final outputBuffer = List.generate(
      1,
      (_) => List.generate(_inputSize, (_) => List.generate(_inputSize, (_) => [0.0])),
    );

    interpreter.run(input, outputBuffer);

    // --- Build a full-resolution alpha mask from the 320x320 saliency map ---
    final maskImage = img.Image(width: _inputSize, height: _inputSize);
    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final v = (outputBuffer[0][y][x][0].clamp(0.0, 1.0) * 255).round();
        maskImage.setPixelRgba(x, y, v, v, v, 255);
      }
    }
    final maskResized = img.copyResize(
      maskImage,
      width: origW,
      height: origH,
      interpolation: img.Interpolation.cubic,
    );

    // --- Composite alpha onto the original full-resolution image ---
    final result = img.Image(width: origW, height: origH, numChannels: 4);
    for (var y = 0; y < origH; y++) {
      for (var x = 0; x < origW; x++) {
        final srcPixel = decoded.getPixel(x, y);
        final maskVal = maskResized.getPixel(x, y).r; // 0..255 saliency
        // Slight edge feathering: soften the threshold instead of a hard
        // cut, which keeps flex-cable / connector edges from looking
        // jagged on product photos.
        final alpha = _feather(maskVal);
        result.setPixelRgba(
          x,
          y,
          srcPixel.r.toInt(),
          srcPixel.g.toInt(),
          srcPixel.b.toInt(),
          alpha,
        );
      }
    }

    return Uint8List.fromList(img.encodePng(result));
  }

  int _feather(num maskVal0to255) {
    const lowerCut = 40;
    const upperCut = 215;
    final v = maskVal0to255.toDouble();
    if (v <= lowerCut) return 0;
    if (v >= upperCut) return 255;
    final t = (v - lowerCut) / (upperCut - lowerCut);
    return (t * 255).round();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Simple helper so screens can show a spinner without caring about the
/// warm-up/inference distinction.
class BackgroundRemovalResult {
  final Uint8List pngBytes;
  final Duration elapsed;
  BackgroundRemovalResult(this.pngBytes, this.elapsed);
}

Future<BackgroundRemovalResult> runBackgroundRemoval(Uint8List bytes) async {
  final sw = Stopwatch()..start();
  final out = await BackgroundRemovalService.instance.removeBackground(bytes);
  sw.stop();
  return BackgroundRemovalResult(out, sw.elapsed);
}
