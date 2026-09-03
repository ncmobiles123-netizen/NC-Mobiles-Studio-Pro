import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/frame_model.dart';
import '../services/background_removal_service.dart';
import '../services/image_edit_service.dart';

/// Central app state. Kept as a single ChangeNotifier (Provider) rather
/// than per-screen state so the quad-frame editing view, the layer
/// panel, and the export screen always see the same live project.
class ProjectProvider extends ChangeNotifier {
  ProjectModel project = ProjectModel(name: 'Untitled product set');

  FrameKind activeFrame = FrameKind.feature;
  bool _busy = false;
  String? _busyLabel;

  /// Background removal availability — checked once at startup (see
  /// initBackgroundRemoval, called from main.dart). Kept as an explicit
  /// tri-state rather than a bare bool so the UI can distinguish
  /// "still checking" from "confirmed unavailable" during the brief
  /// window right after launch.
  bool backgroundRemovalChecked = false;
  bool backgroundRemovalAvailable = false;

  Future<void> initBackgroundRemoval() async {
    final bundled = await BackgroundRemovalService.instance.isModelBundled();
    backgroundRemovalAvailable = bundled;
    backgroundRemovalChecked = true;
    if (bundled) {
      // Only pay the interpreter-construction cost if the model is
      // actually there.
      try {
        await BackgroundRemovalService.instance.warmUp();
      } catch (_) {
        backgroundRemovalAvailable = false;
      }
    }
    notifyListeners();
  }

  bool get isBusy => _busy;
  String? get busyLabel => _busyLabel;

  FrameModel get active => project.frameOf(activeFrame);

  void setActiveFrame(FrameKind kind) {
    activeFrame = kind;
    notifyListeners();
  }

  void newProject(String name) {
    project = ProjectModel(name: name);
    activeFrame = FrameKind.feature;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // IMAGE IMPORT
  // ---------------------------------------------------------------------

  /// "Apply image to all frames": duplicates the same source photo into
  /// every frame. Each frame gets its OWN ImageLayerModel instance (via
  /// clone()) so that cropping frame A never affects frame B, per spec —
  /// e.g. Feature keeps the full LCD, Gallery 1 gets cropped to front,
  /// Gallery 2 to back, Gallery 3 to the flex, all independently.
  void applyImageToAllFrames(Uint8List bytes) {
    final source = ImageLayerModel.fromBytes(bytes);
    for (final kind in FrameKind.values) {
      final frame = project.frameOf(kind);
      final idx = project.frames.indexWhere((f) => f.kind == kind);
      project.frames[idx] = frame.withDuplicatedImage(source);
    }
    notifyListeners();
  }

  /// "Paste to <frame>" — advanced image-options sheet single-target action.
  void pasteToFrame(FrameKind kind, Uint8List bytes) {
    final frame = project.frameOf(kind);
    frame.imageLayer = ImageLayerModel.fromBytes(bytes);
    notifyListeners();
  }

  /// Individual upload for one frame only (no duplication to others).
  void setFrameImage(FrameKind kind, Uint8List bytes) {
    pasteToFrame(kind, bytes);
  }

  /// Replace Image tool — swaps pixels but the caller decides whether to
  /// keep or reset transform/crop; default keeps position so a like-for-
  /// like photo swap doesn't require re-positioning.
  void replaceImage(FrameKind kind, Uint8List bytes, {bool keepTransform = true}) {
    final frame = project.frameOf(kind);
    final existing = frame.imageLayer;
    frame.imageLayer = ImageLayerModel(
      originalBytes: bytes,
      currentBytes: bytes,
      transform: keepTransform ? (existing?.transform ?? LayerTransform.identity) : LayerTransform.identity,
      crop: keepTransform ? (existing?.crop ?? CropRect.full) : CropRect.full,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // TOOLBAR ACTIONS
  // ---------------------------------------------------------------------

  void updateTransform(FrameKind kind, LayerTransform Function(LayerTransform) update) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.transform = update(layer.transform);
    notifyListeners();
  }

  void rotate90(FrameKind kind) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.rotationDegrees = (layer.rotationDegrees + 90) % 360;
    notifyListeners();
  }

  void flipHorizontal(FrameKind kind) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.flippedHorizontal = !layer.flippedHorizontal;
    notifyListeners();
  }

  void flipVertical(FrameKind kind) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.flippedVertical = !layer.flippedVertical;
    notifyListeners();
  }

  /// Applies a fractional crop rect immediately: pixels outside the
  /// rect are discarded (not just hidden), and the crop is baked into
  /// currentBytes so downstream tools (resize, background remove,
  /// export) all operate on the cropped result. originalBytes is left
  /// untouched, so Reset image still recovers the full uncropped photo.
  void applyCrop(FrameKind kind, CropRect crop) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.crop = crop;
    layer.currentBytes = ImageEditService.cropFraction(layer.currentBytes, crop);
    notifyListeners();
  }

  /// Free-angle rotate (Rotate tool's slider), in addition to the
  /// quick 90-degree button (rotate90). Bakes the rotation into pixels
  /// so the canvas transform doesn't have to track two rotation sources.
  void rotateFreeAngle(FrameKind kind, double degrees) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.currentBytes = ImageEditService.rotate(layer.currentBytes, degrees);
    notifyListeners();
  }

  void resizeImage(FrameKind kind, int width, int height) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.currentBytes = ImageEditService.resize(layer.currentBytes, width: width, height: height);
    notifyListeners();
  }

  void eraseAt(FrameKind kind, {required double xFraction, required double yFraction, required double radiusFraction}) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.currentBytes = ImageEditService.eraseCircle(
      layer.currentBytes,
      centerXFraction: xFraction,
      centerYFraction: yFraction,
      radiusFraction: radiusFraction,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // LAYER PANEL — hide / lock / duplicate / delete
  // ---------------------------------------------------------------------

  void toggleImageVisible(FrameKind kind) {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    layer.visible = !layer.visible;
    notifyListeners();
  }

  void toggleBackgroundVisible(FrameKind kind) {
    final frame = project.frameOf(kind);
    frame.backgroundVisible = !frame.backgroundVisible;
    notifyListeners();
  }

  void toggleFrameLocked(FrameKind kind) {
    final frame = project.frameOf(kind);
    frame.templateLocked = !frame.templateLocked;
    notifyListeners();
  }

  void toggleTextVisible(FrameKind kind, String layerId) {
    updateTextLayer(kind, layerId, (t) => t.visible = !t.visible);
  }

  void toggleTextLocked(FrameKind kind, String layerId) {
    updateTextLayer(kind, layerId, (t) => t.locked = !t.locked);
  }

  void duplicateTextLayer(FrameKind kind, String layerId) {
    final frame = project.frameOf(kind);
    final source = frame.textLayers.firstWhere((t) => t.id == layerId);
    frame.textLayers.add(TextLayerModel(
      text: source.text,
      fontFamily: source.fontFamily,
      fontSize: source.fontSize,
      bold: source.bold,
      italic: source.italic,
      strikethrough: source.strikethrough,
      colorValue: source.colorValue,
      letterSpacing: source.letterSpacing,
      shadowOpacity: source.shadowOpacity,
      transform: source.transform.copyWith(offsetX: source.transform.offsetX + 12, offsetY: source.transform.offsetY + 12),
    ));
    notifyListeners();
  }

  void duplicateFrameImageTo(FrameKind from, FrameKind to) {
    final source = project.frameOf(from).imageLayer;
    if (source == null) return;
    project.frameOf(to).imageLayer = source.clone();
    notifyListeners();
  }

  void deleteImage(FrameKind kind) {
    project.frameOf(kind).imageLayer = null;
    notifyListeners();
  }

  /// Undo requirement: restores the pre-edit pixels captured the moment
  /// the photo was first imported into this frame — reverses crop,
  /// background removal, rotation, and flip in one action.
  void resetImageToOriginal(FrameKind kind) {
    project.frameOf(kind).imageLayer?.resetToOriginal();
    notifyListeners();
  }

  /// Background Remove — runs the offline TFLite model, keeps
  /// [ImageLayerModel.originalBytes] untouched so "Reset image" still
  /// works afterward, and only overwrites currentBytes on success.
  Future<void> removeBackground(FrameKind kind) async {
    final layer = project.frameOf(kind).imageLayer;
    if (layer == null) return;
    if (!backgroundRemovalAvailable) {
      // Defense in depth — the toolbar already intercepts this with a
      // friendly dialog before calling here, but guard the entry point
      // too in case this is ever called from elsewhere.
      throw StateError('Background removal model is not bundled in this build.');
    }

    _busy = true;
    _busyLabel = 'Removing background…';
    notifyListeners();

    try {
      final result = await runBackgroundRemoval(layer.currentBytes);
      layer.currentBytes = result.pngBytes;
      layer.backgroundRemoved = true;
    } finally {
      _busy = false;
      _busyLabel = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // TEXT LAYERS
  // ---------------------------------------------------------------------

  TextLayerModel addTextLayer(FrameKind kind, String text) {
    final layer = TextLayerModel(text: text);
    project.frameOf(kind).textLayers.add(layer);
    notifyListeners();
    return layer;
  }

  void updateTextLayer(FrameKind kind, String layerId, void Function(TextLayerModel) update) {
    final frame = project.frameOf(kind);
    final layer = frame.textLayers.firstWhere((t) => t.id == layerId);
    update(layer);
    notifyListeners();
  }

  void removeTextLayer(FrameKind kind, String layerId) {
    project.frameOf(kind).textLayers.removeWhere((t) => t.id == layerId);
    notifyListeners();
  }
}
