import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/frame_model.dart';

class ExportedFile {
  final String filename;
  final int bytesSize;
  ExportedFile(this.filename, this.bytesSize);
}

/// Captures each frame's on-screen composition (image + text + logo,
/// already positioned exactly as the user left it) and writes it out as
/// a WebP file, following the required naming: 0.webp (Feature),
/// 1.webp (Gallery 1), 2.webp (Gallery 2), 3.webp (Gallery 3). If a
/// 5th slot/variant is present it is written as 4.webp.
class ImageExportService {
  ImageExportService._();

  /// [boundaryKeys] maps each frame to the GlobalKey of the
  /// RepaintBoundary that wraps its rendered canvas in the export
  /// screen — see ExportScreen, which renders every frame off-screen at
  /// full export resolution right before capture.
  static Future<List<ExportedFile>> exportAll({
    required ProjectModel project,
    required Map<FrameKind, GlobalKey> boundaryKeys,
    required String outputDirectoryPath,
    int webpQuality = 92,
    double pixelRatio = 1.0,
  }) async {
    final results = <ExportedFile>[];

    for (final kind in FrameKind.values) {
      final key = boundaryKeys[kind];
      final ctx = key?.currentContext;
      if (ctx == null) continue;

      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final uiImage = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) continue;
      final pngBytes = byteData.buffer.asUint8List();

      final webpBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        format: CompressFormat.webp,
        quality: webpQuality,
      );

      final filename = '${kind.exportIndex}.webp';
      final file = File('$outputDirectoryPath/$filename');
      await file.writeAsBytes(webpBytes);
      results.add(ExportedFile(filename, webpBytes.length));
    }

    return results;
  }
}
