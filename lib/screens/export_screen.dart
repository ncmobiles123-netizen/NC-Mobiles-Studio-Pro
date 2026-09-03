import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../services/image_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/frame_canvas.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final Map<FrameKind, GlobalKey> _boundaryKeys = {
    for (final k in FrameKind.values) k: GlobalKey(),
  };

  String? _outputPath;
  bool _exporting = false;
  double _progress = 0;
  List<ExportedFile> _results = [];

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose export folder');
    if (path != null) setState(() => _outputPath = path);
  }

  Future<void> _export() async {
    if (_outputPath == null) {
      await _pickFolder();
      if (_outputPath == null) return;
    }
    setState(() {
      _exporting = true;
      _progress = 0;
      _results = [];
    });

    final provider = context.read<ProjectProvider>();
    // Give the off-screen full-resolution boundaries a frame to paint
    // before capture.
    await Future.delayed(const Duration(milliseconds: 80));

    final results = await ImageExportService.exportAll(
      project: provider.project,
      boundaryKeys: _boundaryKeys,
      outputDirectoryPath: _outputPath!,
      pixelRatio: 2.0,
    );

    setState(() {
      _results = results;
      _exporting = false;
      _progress = 1;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${results.length} images to $_outputPath')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final framesWithImages = provider.project.frames.where((f) => f.imageLayer != null).length;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Export set')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              Text(
                '$framesWithImages IMAGES READY',
                style: const TextStyle(fontSize: 11, color: AppColors.textLow, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
              const SizedBox(height: 10),
              for (final frame in provider.project.frames)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.cardAlt,
                            borderRadius: BorderRadius.circular(8),
                            image: frame.imageLayer != null
                                ? DecorationImage(image: MemoryImage(frame.imageLayer!.currentBytes), fit: BoxFit.cover)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${frame.kind.exportIndex}.webp — ${frame.kind.label}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              const Text('WebP · exported at 2x for crisp downscaling', style: TextStyle(fontSize: 9.5, color: AppColors.textLow)),
                            ],
                          ),
                        ),
                        Icon(
                          frame.imageLayer != null ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: frame.imageLayer != null ? AppColors.accent : AppColors.textLow,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_outputPath ?? 'No folder selected', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textMid)),
                    ),
                    TextButton(onPressed: _pickFolder, child: const Text('Change')),
                  ],
                ),
              ),
              if (_exporting) ...[
                const SizedBox(height: 16),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(minHeight: 6, backgroundColor: AppColors.cardAlt)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: framesWithImages == 0 || _exporting ? null : _export,
                child: Text(_exporting ? 'Exporting…' : 'Export all $framesWithImages'),
              ),
            ],
          ),

          // Off-screen, full-resolution render targets used purely for
          // pixel capture — kept outside the viewport so the user never
          // sees a flash of duplicate content.
          Positioned(
            left: -4000,
            top: 0,
            child: Column(
              children: FrameKind.values.map((kind) {
                final size = kind == FrameKind.feature ? 1600.0 : 1200.0;
                return RepaintBoundary(
                  key: _boundaryKeys[kind],
                  child: SizedBox(width: size, height: size, child: FrameCanvas(kind: kind, interactive: false)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
