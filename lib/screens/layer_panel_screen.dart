import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';

class LayerPanelScreen extends StatelessWidget {
  const LayerPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final kind = provider.activeFrame;
    final frame = provider.active;

    final rows = <_LayerRow>[
      for (final t in frame.textLayers)
        _LayerRow(
          name: 'Text',
          sub: t.text,
          color: AppColors.accent,
          visible: t.visible,
          locked: t.locked,
          onToggleVisible: () => provider.toggleTextVisible(kind, t.id),
          onToggleLock: () => provider.toggleTextLocked(kind, t.id),
          onDuplicate: () => provider.duplicateTextLayer(kind, t.id),
          onDelete: () => provider.removeTextLayer(kind, t.id),
        ),
      _LayerRow(
        name: 'Frame',
        sub: frame.kind.label,
        color: AppColors.cardAlt,
        visible: true,
        locked: frame.templateLocked,
        onToggleLock: () => provider.toggleFrameLocked(kind),
      ),
      if (frame.imageLayer != null)
        _LayerRow(
          name: 'Product Image',
          sub: 'Source photo',
          color: AppColors.border,
          visible: frame.imageLayer!.visible,
          onToggleVisible: () => provider.toggleImageVisible(kind),
          onDelete: () => provider.deleteImage(kind),
        ),
      _LayerRow(
        name: 'Background',
        sub: frame.backgroundVisible ? 'Visible' : 'Hidden',
        color: AppColors.cardAlt,
        visible: frame.backgroundVisible,
        onToggleVisible: () => provider.toggleBackgroundVisible(kind),
      ),
    ];

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text('Layers · ${frame.kind.label}')),
      body: frame.imageLayer == null && frame.textLayers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No layers yet — add a photo or text on the Editing tab.', style: TextStyle(color: AppColors.textMid), textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                const Text('TOP → BOTTOM', style: TextStyle(fontSize: 11, color: AppColors.textLow, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 10),
                for (final r in rows) _LayerTile(row: r),
              ],
            ),
    );
  }
}

class _LayerRow {
  final String name, sub;
  final Color color;
  final bool visible, locked;
  final VoidCallback? onToggleVisible;
  final VoidCallback? onToggleLock;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  _LayerRow({
    required this.name,
    required this.sub,
    required this.color,
    this.visible = true,
    this.locked = false,
    this.onToggleVisible,
    this.onToggleLock,
    this.onDuplicate,
    this.onDelete,
  });
}

class _LayerTile extends StatelessWidget {
  final _LayerRow row;
  const _LayerTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: row.visible ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator, size: 16, color: AppColors.textLow),
            const SizedBox(width: 8),
            Container(width: 26, height: 26, decoration: BoxDecoration(color: row.color, borderRadius: BorderRadius.circular(7))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  Text(row.sub, style: const TextStyle(fontSize: 9, color: AppColors.textLow), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (row.onToggleVisible != null)
              IconButton(
                icon: Icon(row.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16),
                onPressed: row.onToggleVisible,
              ),
            if (row.onToggleLock != null)
              IconButton(
                icon: Icon(row.locked ? Icons.lock_outline : Icons.lock_open_outlined, size: 16, color: row.locked ? AppColors.signalAmber : AppColors.textMid),
                onPressed: row.onToggleLock,
              ),
            if (row.onDuplicate != null)
              IconButton(icon: const Icon(Icons.copy_all_outlined, size: 16), onPressed: row.onDuplicate),
            if (row.onDelete != null)
              IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: row.onDelete),
          ],
        ),
      ),
    );
  }
}
