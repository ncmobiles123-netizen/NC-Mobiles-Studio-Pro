import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/editing_toolbar.dart';
import '../widgets/frame_canvas.dart';
import '../widgets/image_options_sheet.dart';
import '../widgets/text_editor_panel.dart';

class EditingScreen extends StatelessWidget {
  const EditingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Editing · ${provider.project.name}'),
        actions: [
          IconButton(
            tooltip: 'Add text',
            onPressed: () {
              final layer = provider.addTextLayer(provider.activeFrame, 'Samsung Galaxy A01');
              _openTextEditor(context, provider.activeFrame, layer.id);
            },
            icon: const Icon(Icons.text_fields_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
            children: [
              // All four frames visible and independently editable at once —
              // tapping a cell makes it "active" (selected for the toolbar
              // below); dragging directly on a cell moves that frame's image.
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
                children: FrameKind.values.map((kind) {
                  return FrameCanvas(
                    kind: kind,
                    isActive: kind == provider.activeFrame,
                    onTap: () => provider.setActiveFrame(kind),
                    onLongPressImage: () {
                      final bytes = provider.project.frameOf(kind).imageLayer?.currentBytes;
                      if (bytes != null) {
                        showImageOptionsSheet(context, sourceBytes: bytes);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'EDITING · ${provider.activeFrame.label.toUpperCase()} FRAME',
                style: const TextStyle(fontSize: 11, color: AppColors.textLow, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
              const SizedBox(height: 10),
              EditingToolbar(targetFrame: provider.activeFrame),
              const SizedBox(height: 16),
              if (provider.project.frameOf(provider.activeFrame).imageLayer != null)
                OutlinedButton.icon(
                  onPressed: () => provider.resetImageToOriginal(provider.activeFrame),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Reset image to original'),
                ),
              const SizedBox(height: 8),
              if (provider.project.frameOf(provider.activeFrame).textLayers.isNotEmpty) ...[
                const Text('TEXT LAYERS', style: TextStyle(fontSize: 11, color: AppColors.textLow, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 8),
                for (final t in provider.project.frameOf(provider.activeFrame).textLayers)
                  Card(
                    child: ListTile(
                      dense: true,
                      title: Text(t.text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onTap: () => _openTextEditor(context, provider.activeFrame, t.id),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => provider.removeTextLayer(provider.activeFrame, t.id),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          if (provider.isBusy)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent)),
                      const SizedBox(width: 12),
                      Text(provider.busyLabel ?? 'Working…', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openTextEditor(BuildContext context, FrameKind kind, String layerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TextEditorPanel(frameKind: kind, layerId: layerId),
      ),
    );
  }
}
