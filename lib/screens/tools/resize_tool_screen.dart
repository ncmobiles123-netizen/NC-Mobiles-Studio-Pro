import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/frame_model.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';

class ResizeToolScreen extends StatefulWidget {
  final FrameKind frameKind;
  const ResizeToolScreen({super.key, required this.frameKind});

  @override
  State<ResizeToolScreen> createState() => _ResizeToolScreenState();
}

class _ResizeToolScreenState extends State<ResizeToolScreen> {
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _lockAspect = true;
  double _sourceAspect = 1;
  bool _loaded = false;

  Future<void> _loadDims(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _sourceAspect = frame.image.width / frame.image.height;
    _widthCtrl.text = frame.image.width.toString();
    _heightCtrl.text = frame.image.height.toString();
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProjectProvider>();
    final bytes = provider.project.frameOf(widget.frameKind).imageLayer?.currentBytes;

    if (bytes != null && !_loaded) {
      _loadDims(bytes);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Resize'),
        actions: [
          TextButton(
            onPressed: bytes == null || !_loaded
                ? null
                : () {
                    final w = int.tryParse(_widthCtrl.text) ?? 0;
                    final h = int.tryParse(_heightCtrl.text) ?? 0;
                    if (w > 0 && h > 0) {
                      provider.resizeImage(widget.frameKind, w, h);
                      Navigator.pop(context);
                    }
                  },
            child: const Text('Apply'),
          ),
        ],
      ),
      body: bytes == null
          ? const Center(child: Text('No image in this frame', style: TextStyle(color: AppColors.textMid)))
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(aspectRatio: _sourceAspect == 0 ? 1 : _sourceAspect, child: Image.memory(bytes, fit: BoxFit.contain)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _widthCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Width (px)', border: OutlineInputBorder(), isDense: true),
                          onChanged: (v) {
                            if (!_lockAspect) return;
                            final w = int.tryParse(v);
                            if (w != null) _heightCtrl.text = (w / _sourceAspect).round().toString();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.close, size: 16, color: AppColors.textLow),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Height (px)', border: OutlineInputBorder(), isDense: true),
                          onChanged: (v) {
                            if (!_lockAspect) return;
                            final h = int.tryParse(v);
                            if (h != null) _widthCtrl.text = (h * _sourceAspect).round().toString();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Switch(value: _lockAspect, activeColor: AppColors.accent, onChanged: (v) => setState(() => _lockAspect = v)),
                      const Text('Lock aspect ratio', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [1200, 1600, 2000].map((size) {
                      return OutlinedButton(
                        onPressed: () {
                          _widthCtrl.text = size.toString();
                          _heightCtrl.text = _lockAspect ? (size / _sourceAspect).round().toString() : size.toString();
                        },
                        child: Text('$size px'),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }
}
