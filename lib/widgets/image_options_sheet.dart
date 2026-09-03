import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';

/// Shown when the user taps/long-presses a placed image, per spec:
/// Apply image to all frames, or paste it into one specific frame.
Future<void> showImageOptionsSheet(
  BuildContext context, {
  required Uint8List sourceBytes,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheetContext) {
      final provider = sheetContext.read<ProjectProvider>();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const Text('Use this image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text(
                'Duplicate into every frame or place it in one specific frame.',
                style: TextStyle(fontSize: 11, color: AppColors.textMid),
              ),
              const SizedBox(height: 10),
              _SheetOption(
                icon: Icons.grid_view_rounded,
                label: 'Apply image to all frames',
                primary: true,
                onTap: () {
                  provider.applyImageToAllFrames(sourceBytes);
                  Navigator.pop(sheetContext);
                },
              ),
              for (final kind in FrameKind.values)
                _SheetOption(
                  icon: Icons.image_outlined,
                  label: 'Paste to ${kind.label}',
                  onTap: () {
                    provider.pasteToFrame(kind, sourceBytes);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primary ? AppColors.accent : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: primary ? Colors.white : AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}
