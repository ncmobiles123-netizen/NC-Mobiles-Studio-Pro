import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/frame_model.dart';
import '../../providers/project_provider.dart';
import '../../services/image_edit_service.dart';
import '../../theme/app_theme.dart';

class EraseToolScreen extends StatefulWidget {
  final FrameKind frameKind;
  const EraseToolScreen({super.key, required this.frameKind});

  @override
  State<EraseToolScreen> createState() => _EraseToolScreenState();
}

class _EraseToolScreenState extends State<EraseToolScreen> {
  double _brushFraction = 0.06; // radius as a fraction of image width
  Uint8List? _working;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProjectProvider>();
    _working ??= provider.project.frameOf(widget.frameKind).imageLayer?.currentBytes;
    final bytes = _working;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Erase'),
        actions: [
          TextButton(
            onPressed: bytes == null
                ? null
                : () {
                    final layer = provider.project.frameOf(widget.frameKind).imageLayer;
                    if (layer != null) {
                      layer.currentBytes = bytes;
                      provider.notifyListeners();
                    }
                    Navigator.pop(context);
                  },
            child: const Text('Done'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F6F8),
      body: bytes == null
          ? const Center(child: Text('No image in this frame', style: TextStyle(color: AppColors.textMid)))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onPanUpdate: (details) {
                            final box = context.findRenderObject() as RenderBox;
                            final local = box.globalToLocal(details.globalPosition);
                            final xFrac = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
                            final yFrac = (local.dy / constraints.maxHeight).clamp(0.0, 1.0);
                            setState(() {
                              _working = ImageEditService.eraseCircle(
                                _working!,
                                centerXFraction: xFrac,
                                centerYFraction: yFrac,
                                radiusFraction: _brushFraction,
                              );
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            // A light checkerboard would normally show
                            // through the erased (transparent) areas;
                            // simplified to a flat card color here so
                            // this screen has no extra asset dependency.
                            child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.brush_outlined, size: 16, color: AppColors.textMid),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.accent, thumbColor: AppColors.accent, inactiveTrackColor: AppColors.border),
                          child: Slider(value: _brushFraction, min: 0.02, max: 0.18, onChanged: (v) => setState(() => _brushFraction = v)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Drag over the background to erase it. Original photo is kept for undo.', style: TextStyle(fontSize: 10.5, color: AppColors.textLow)),
                ),
              ],
            ),
    );
  }

}
