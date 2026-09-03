import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';

/// Renders a single frame's full composition: background, product image
/// (with independent pan / pinch-zoom / rotate), frame template overlay,
/// and any text/logo layers. Used both inside the live quad-frame
/// editing grid and — wrapped in a RepaintBoundary at export resolution
/// — as the source pixels for the exported WebP file, so what the user
/// sees is exactly what gets saved.
class FrameCanvas extends StatefulWidget {
  final FrameKind kind;
  final bool isActive;
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPressImage;

  const FrameCanvas({
    super.key,
    required this.kind,
    this.isActive = false,
    this.interactive = true,
    this.onTap,
    this.onLongPressImage,
  });

  @override
  State<FrameCanvas> createState() => _FrameCanvasState();
}

class _FrameCanvasState extends State<FrameCanvas> {
  Offset _dragStart = Offset.zero;
  LayerTransform _transformAtDragStart = LayerTransform.identity;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final frame = provider.project.frameOf(widget.kind);
    final imageLayer = frame.imageLayer;

    return GestureDetector(
      onTap: widget.onTap,
      onScaleStart: (imageLayer == null || !widget.interactive)
          ? null
          : (details) {
              _dragStart = details.focalPoint;
              _transformAtDragStart = imageLayer.transform;
            },
      onScaleUpdate: (imageLayer == null || !widget.interactive)
          ? null
          : (details) {
              final delta = details.focalPoint - _dragStart;
              provider.updateTransform(widget.kind, (t) {
                return _transformAtDragStart.copyWith(
                  offsetX: _transformAtDragStart.offsetX + delta.dx,
                  offsetY: _transformAtDragStart.offsetY + delta.dy,
                  scale: (_transformAtDragStart.scale * details.scale).clamp(0.2, 6.0),
                  rotationRadians: _transformAtDragStart.rotationRadians + details.rotation,
                );
              });
            },
      child: Container(
        decoration: BoxDecoration(
          color: frame.backgroundVisible ? Color(frame.backgroundColorValue) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isActive ? AppColors.accent : AppColors.border,
            width: widget.isActive ? 1.5 : 1,
          ),
          boxShadow: widget.isActive
              ? [BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 0, spreadRadius: 3)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageLayer != null && imageLayer.visible)
              Center(
                child: GestureDetector(
                  onLongPress: widget.onLongPressImage,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translate(imageLayer.transform.offsetX, imageLayer.transform.offsetY)
                      ..rotateZ(imageLayer.transform.rotationRadians)
                      ..rotateZ(imageLayer.rotationDegrees * 3.1415926535 / 180)
                      ..scale(
                        imageLayer.flippedHorizontal ? -imageLayer.transform.scale : imageLayer.transform.scale,
                        imageLayer.flippedVertical ? -imageLayer.transform.scale : imageLayer.transform.scale,
                      ),
                    child: Image.memory(imageLayer.currentBytes, fit: BoxFit.contain),
                  ),
                ),
              )
            else
              _EmptyFrameHint(kind: widget.kind),

            // Text / logo layers, positioned by fraction-based transform.
            for (final t in frame.textLayers)
              if (t.visible)
                Positioned(
                  left: null,
                  child: FractionalTranslation(
                    translation: Offset(t.transform.offsetX / 200, t.transform.offsetY / 200),
                    child: Center(
                      child: Text(
                        t.text,
                        style: TextStyle(
                          fontFamily: t.fontFamily,
                          fontSize: t.fontSize,
                          fontWeight: t.bold ? FontWeight.w700 : FontWeight.w400,
                          fontStyle: t.italic ? FontStyle.italic : FontStyle.normal,
                          decoration: t.strikethrough ? TextDecoration.lineThrough : TextDecoration.none,
                          letterSpacing: t.letterSpacing,
                          color: Color(t.colorValue),
                          shadows: t.shadowOpacity > 0
                              ? [
                                  Shadow(
                                    color: Colors.black.withOpacity(t.shadowOpacity),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

            // Frame template overlay (border art) — sits above the photo,
            // below nothing; kept as a decorative asset image if provided.
            if (frame.templateAssetPath.isNotEmpty)
              IgnorePointer(
                child: Image.asset(frame.templateAssetPath, fit: BoxFit.cover),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFrameHint extends StatelessWidget {
  final FrameKind kind;
  const _EmptyFrameHint({required this.kind});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: AppColors.textLow, size: 22),
          const SizedBox(height: 6),
          Text(
            kind.label,
            style: const TextStyle(fontSize: 10, color: AppColors.textLow, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
