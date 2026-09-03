import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../services/image_edit_service.dart';
import '../theme/app_theme.dart';

enum EditTool { crop, resize, rotate, flip, upscale, bgRemove, erase, duplicate, replace, delete }

extension on EditTool {
  String get label => switch (this) {
        EditTool.crop => 'Crop',
        EditTool.resize => 'Resize',
        EditTool.rotate => 'Rotate',
        EditTool.flip => 'Flip',
        EditTool.upscale => 'Upscale',
        EditTool.bgRemove => 'BG Remove',
        EditTool.erase => 'Erase',
        EditTool.duplicate => 'Duplicate',
        EditTool.replace => 'Replace',
        EditTool.delete => 'Delete',
      };

  IconData get icon => switch (this) {
        EditTool.crop => Icons.crop,
        EditTool.resize => Icons.aspect_ratio,
        EditTool.rotate => Icons.rotate_90_degrees_ccw,
        EditTool.flip => Icons.flip,
        EditTool.upscale => Icons.zoom_in_map,
        EditTool.bgRemove => Icons.auto_fix_high,
        EditTool.erase => Icons.remove_circle_outline,
        EditTool.duplicate => Icons.copy_all_outlined,
        EditTool.replace => Icons.find_replace,
        EditTool.delete => Icons.delete_outline,
      };
}

class EditingToolbar extends StatelessWidget {
  final FrameKind targetFrame;
  const EditingToolbar({super.key, required this.targetFrame});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final hasImage = provider.project.frameOf(targetFrame).imageLayer != null;
    final bgRemoveSoon = provider.backgroundRemovalChecked && !provider.backgroundRemovalAvailable;

    return SizedBox(
      height: 68,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: EditTool.values.map((tool) {
          final disabled = !hasImage && tool != EditTool.replace;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ToolPill(
              tool: tool,
              enabled: !disabled,
              soon: tool == EditTool.bgRemove && bgRemoveSoon,
              onTap: disabled ? null : () => _handle(context, tool),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handle(BuildContext context, EditTool tool) async {
    final provider = context.read<ProjectProvider>();

    switch (tool) {
      case EditTool.rotate:
        Navigator.of(context).pushNamed('/tool/rotateFree', arguments: targetFrame);
        break;

      case EditTool.flip:
        provider.flipHorizontal(targetFrame);
        break;

      case EditTool.duplicate:
        _showFramePicker(context, title: 'Duplicate to…', onPicked: (dest) {
          provider.duplicateFrameImageTo(targetFrame, dest);
        });
        break;

      case EditTool.delete:
        provider.deleteImage(targetFrame);
        break;

      case EditTool.bgRemove:
        if (!provider.backgroundRemovalAvailable) {
          _showComingSoonDialog(context);
          return;
        }
        try {
          await provider.removeBackground(targetFrame);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Background removed — original photo kept for undo.')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Background removal failed: $e')),
            );
          }
        }
        break;

      case EditTool.upscale:
        final layer = provider.project.frameOf(targetFrame).imageLayer;
        if (layer == null) return;
        layer.currentBytes = ImageEditService.upscale(layer.currentBytes);
        provider.notifyListeners();
        break;

      case EditTool.replace:
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        provider.replaceImage(targetFrame, bytes);
        break;

      case EditTool.crop:
      case EditTool.resize:
      case EditTool.erase:
        // Each opens its own dedicated full-screen editor — see
        // lib/screens/tools/. Routed by name so this toolbar file stays
        // focused on the tool strip itself.
        Navigator.of(context).pushNamed('/tool/${tool.name}', arguments: targetFrame);
        break;
    }
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: AppColors.accent, size: 20),
            SizedBox(width: 8),
            Text('Coming soon', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Offline background removal ships in the next update. '
          'Every other tool works normally in this build — you can '
          'still clean up a background manually with Erase.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMid, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  void _showFramePicker(
    BuildContext context, {
    required String title,
    required void Function(FrameKind) onPicked,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              for (final k in FrameKind.values)
                if (k != targetFrame)
                  ListTile(
                    title: Text(k.label),
                    onTap: () {
                      Navigator.pop(context);
                      onPicked(k);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolPill extends StatelessWidget {
  final EditTool tool;
  final bool enabled;
  final bool soon;
  final VoidCallback? onTap;
  const _ToolPill({required this.tool, required this.enabled, required this.onTap, this.soon = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tool.icon, size: 18, color: AppColors.textMid),
                  const SizedBox(height: 6),
                  Text(tool.label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: AppColors.textMid)),
                ],
              ),
            ),
            if (soon)
              Positioned(
                top: -5,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.signalAmber, borderRadius: BorderRadius.circular(6)),
                  child: const Text('SOON', style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
