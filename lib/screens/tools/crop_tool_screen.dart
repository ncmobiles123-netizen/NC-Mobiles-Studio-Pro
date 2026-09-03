import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/frame_model.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';

class CropToolScreen extends StatefulWidget {
  final FrameKind frameKind;
  const CropToolScreen({super.key, required this.frameKind});

  @override
  State<CropToolScreen> createState() => _CropToolScreenState();
}

class _CropToolScreenState extends State<CropToolScreen> {
  // Crop rectangle as fractions (0..1) of the displayed image area.
  Rect _rect = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
  double? _aspect; // null = free

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProjectProvider>();
    final bytes = provider.project.frameOf(widget.frameKind).imageLayer?.currentBytes;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Crop'),
        actions: [
          TextButton(
            onPressed: bytes == null
                ? null
                : () {
                    provider.applyCrop(
                      widget.frameKind,
                      CropRect(left: _rect.left, top: _rect.top, width: _rect.width, height: _rect.height),
                    );
                    Navigator.pop(context);
                  },
            child: const Text('Apply'),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: bytes == null
          ? const Center(child: Text('No image in this frame', style: TextStyle(color: Colors.white70)))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final area = Size(constraints.maxWidth, constraints.maxHeight);
                      return Stack(
                        children: [
                          Center(
                            child: Image.memory(bytes, fit: BoxFit.contain),
                          ),
                          Positioned.fill(
                            child: _CropOverlay(
                              rect: _rect,
                              areaSize: area,
                              aspect: _aspect,
                              onChanged: (r) => setState(() => _rect = r),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  color: const Color(0xFF12151C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AspectChip(label: 'Free', selected: _aspect == null, onTap: () => setState(() => _aspect = null)),
                      _AspectChip(label: '1:1', selected: _aspect == 1, onTap: () => setState(() => _aspect = 1)),
                      _AspectChip(label: '4:5', selected: _aspect == 4 / 5, onTap: () => setState(() => _aspect = 4 / 5)),
                      _AspectChip(label: '16:9', selected: _aspect == 16 / 9, onTap: () => setState(() => _aspect = 16 / 9)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _AspectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AspectChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// A minimal, dependency-free crop rectangle: drag the body to move it,
/// drag the corner handle to resize (optionally constrained to
/// [aspect]). Coordinates are tracked as fractions of [areaSize] so the
/// resulting CropRect maps directly onto the source image regardless of
/// how it's displayed on screen.
class _CropOverlay extends StatelessWidget {
  final Rect rect;
  final Size areaSize;
  final double? aspect;
  final ValueChanged<Rect> onChanged;

  const _CropOverlay({required this.rect, required this.areaSize, required this.aspect, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pxRect = Rect.fromLTWH(
      rect.left * areaSize.width,
      rect.top * areaSize.height,
      rect.width * areaSize.width,
      rect.height * areaSize.height,
    );

    return Stack(
      children: [
        // Dim everything outside the crop rect.
        CustomPaint(
          size: areaSize,
          painter: _DimPainter(pxRect),
        ),
        Positioned(
          left: pxRect.left,
          top: pxRect.top,
          width: pxRect.width,
          height: pxRect.height,
          child: GestureDetector(
            onPanUpdate: (d) {
              var newLeft = (rect.left + d.delta.dx / areaSize.width).clamp(0.0, 1.0 - rect.width);
              var newTop = (rect.top + d.delta.dy / areaSize.height).clamp(0.0, 1.0 - rect.height);
              onChanged(Rect.fromLTWH(newLeft, newTop, rect.width, rect.height));
            },
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5)),
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
        ),
        // Bottom-right resize handle.
        Positioned(
          left: pxRect.right - 11,
          top: pxRect.bottom - 11,
          child: GestureDetector(
            onPanUpdate: (d) {
              var newWidth = (rect.width + d.delta.dx / areaSize.width).clamp(0.08, 1.0 - rect.left);
              var newHeight = aspect == null
                  ? (rect.height + d.delta.dy / areaSize.height).clamp(0.08, 1.0 - rect.top)
                  : (newWidth * areaSize.width / aspect!) / areaSize.height;
              newHeight = newHeight.clamp(0.08, 1.0 - rect.top);
              onChanged(Rect.fromLTWH(rect.left, rect.top, newWidth, newHeight));
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 2)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect hole;
  _DimPainter(this.hole);
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cut = Path()..addRect(hole);
    final diff = Path.combine(PathOperation.difference, full, cut);
    canvas.drawPath(diff, Paint()..color = Colors.black.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(covariant _DimPainter oldDelegate) => oldDelegate.hole != hole;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 0.6;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
