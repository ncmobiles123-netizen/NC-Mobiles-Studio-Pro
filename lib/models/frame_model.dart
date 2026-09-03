import 'dart:typed_data';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Which of the four fixed template slots a frame represents.
enum FrameKind { feature, gallery1, gallery2, gallery3 }

extension FrameKindX on FrameKind {
  String get label => switch (this) {
        FrameKind.feature => 'Feature Image',
        FrameKind.gallery1 => 'Gallery 1',
        FrameKind.gallery2 => 'Gallery 2',
        FrameKind.gallery3 => 'Gallery 3',
      };

  /// Export filename per the required 0.webp..4.webp naming.
  /// Feature -> 0.webp, Gallery1 -> 1.webp, Gallery2 -> 2.webp, Gallery3 -> 3.webp
  /// (4.webp is reserved for a duplicated/alternate gallery crop — see
  /// ProjectModel.exportSlots).
  int get exportIndex => switch (this) {
        FrameKind.feature => 0,
        FrameKind.gallery1 => 1,
        FrameKind.gallery2 => 2,
        FrameKind.gallery3 => 3,
      };
}

/// Pan / pinch-zoom / rotate state for a layer inside its frame.
/// Kept as plain doubles (not a Matrix4) so it's trivial to serialize
/// and to feed into both the live gesture canvas and the offline
/// compositor used at export time.
class LayerTransform {
  final double offsetX; // fraction of frame width, -1..1 range typical
  final double offsetY; // fraction of frame height
  final double scale;
  final double rotationRadians;

  const LayerTransform({
    this.offsetX = 0,
    this.offsetY = 0,
    this.scale = 1.0,
    this.rotationRadians = 0,
  });

  LayerTransform copyWith({
    double? offsetX,
    double? offsetY,
    double? scale,
    double? rotationRadians,
  }) {
    return LayerTransform(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      scale: scale ?? this.scale,
      rotationRadians: rotationRadians ?? this.rotationRadians,
    );
  }

  static const identity = LayerTransform();
}

/// A crop rectangle expressed as fractions (0..1) of the source image,
/// so it survives re-applying to a replaced/upscaled source image.
class CropRect {
  final double left, top, width, height;
  const CropRect({this.left = 0, this.top = 0, this.width = 1, this.height = 1});

  static const full = CropRect();
}

/// The product-photo layer inside one frame.
///
/// Undo requirement: [originalBytes] is captured once, the first time an
/// image is placed into a frame, and is never overwritten by edits —
/// only [currentBytes] changes as the user crops / removes background /
/// upscales. "Reset image" restores currentBytes = originalBytes and
/// clears crop/transform/backgroundRemoved.
class ImageLayerModel {
  final String id;
  Uint8List originalBytes; // untouched backup, captured on first import
  Uint8List currentBytes; // live, edited pixels shown on canvas
  LayerTransform transform;
  CropRect crop;
  bool backgroundRemoved;
  bool flippedHorizontal;
  bool flippedVertical;
  double rotationDegrees; // discrete rotate (90-degree steps) on top of gesture rotation
  bool visible;

  ImageLayerModel({
    String? id,
    required this.originalBytes,
    required this.currentBytes,
    this.transform = LayerTransform.identity,
    this.crop = CropRect.full,
    this.backgroundRemoved = false,
    this.flippedHorizontal = false,
    this.flippedVertical = false,
    this.rotationDegrees = 0,
    this.visible = true,
  }) : id = id ?? _uuid.v4();

  factory ImageLayerModel.fromBytes(Uint8List bytes) {
    return ImageLayerModel(originalBytes: bytes, currentBytes: bytes);
  }

  /// Restores the pre-edit pixels and clears all edit state. Used by
  /// "Reset image" in the editing toolbar.
  void resetToOriginal() {
    currentBytes = originalBytes;
    transform = LayerTransform.identity;
    crop = CropRect.full;
    backgroundRemoved = false;
    flippedHorizontal = false;
    flippedVertical = false;
    rotationDegrees = 0;
    visible = true;
  }

  ImageLayerModel clone() {
    return ImageLayerModel(
      id: id,
      originalBytes: originalBytes,
      currentBytes: currentBytes,
      transform: transform,
      crop: crop,
      backgroundRemoved: backgroundRemoved,
      flippedHorizontal: flippedHorizontal,
      flippedVertical: flippedVertical,
      rotationDegrees: rotationDegrees,
      visible: visible,
    );
  }
}

class TextLayerModel {
  final String id;
  String text;
  String fontFamily;
  double fontSize;
  bool bold;
  bool italic;
  bool strikethrough;
  int colorValue; // ARGB
  double letterSpacing;
  double shadowOpacity;
  LayerTransform transform;
  bool visible;
  bool locked;

  TextLayerModel({
    String? id,
    required this.text,
    this.fontFamily = 'Inter',
    this.fontSize = 28,
    this.bold = true,
    this.italic = false,
    this.strikethrough = false,
    this.colorValue = 0xFF12151C,
    this.letterSpacing = 0.2,
    this.shadowOpacity = 0.0,
    this.transform = LayerTransform.identity,
    this.visible = true,
    this.locked = false,
  }) : id = id ?? _uuid.v4();
}

/// One of the four editable output slots. Each frame owns its own
/// image layer, text layers, logo, and background — fully independent
/// editing even when the same source photo was applied to all four.
class FrameModel {
  final String id;
  final FrameKind kind;
  String templateAssetPath; // frame overlay / border template
  bool templateLocked;
  ImageLayerModel? imageLayer;
  TextLayerModel? logoLayer;
  List<TextLayerModel> textLayers;
  bool backgroundVisible;
  int backgroundColorValue;

  FrameModel({
    String? id,
    required this.kind,
    this.templateAssetPath = '',
    this.templateLocked = false,
    this.imageLayer,
    this.logoLayer,
    List<TextLayerModel>? textLayers,
    this.backgroundVisible = true,
    this.backgroundColorValue = 0xFFFFFFFF,
  })  : id = id ?? _uuid.v4(),
        textLayers = textLayers ?? [];

  /// Deep-ish copy used when "Apply image to all frames" duplicates a
  /// source photo into every slot but must NOT share mutable state —
  /// each frame's edits (crop, background removal, position) must stay
  /// independent per the spec.
  FrameModel withDuplicatedImage(ImageLayerModel source) {
    return FrameModel(
      id: id,
      kind: kind,
      templateAssetPath: templateAssetPath,
      templateLocked: templateLocked,
      imageLayer: source.clone(),
      logoLayer: logoLayer,
      textLayers: textLayers,
      backgroundVisible: backgroundVisible,
      backgroundColorValue: backgroundColorValue,
    );
  }
}

class ProjectModel {
  final String id;
  String name;
  final List<FrameModel> frames;
  final DateTime createdAt;

  ProjectModel({
    String? id,
    required this.name,
    List<FrameModel>? frames,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        frames = frames ??
            [
              FrameModel(kind: FrameKind.feature),
              FrameModel(kind: FrameKind.gallery1),
              FrameModel(kind: FrameKind.gallery2),
              FrameModel(kind: FrameKind.gallery3),
            ],
        createdAt = createdAt ?? DateTime.now();

  FrameModel frameOf(FrameKind kind) => frames.firstWhere((f) => f.kind == kind);
}
