import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';

class TemplateManagerScreen extends StatelessWidget {
  const TemplateManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final res = await FilePicker.platform.pickFiles(type: FileType.image);
              if (res == null || res.files.single.path == null) return;
              // Importing a custom frame template attaches it as the
              // overlay art for the currently active frame.
              provider.project.frameOf(provider.activeFrame).templateAssetPath = res.files.single.path!;
              provider.notifyListeners();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Template applied to ${provider.activeFrame.label}')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('ACTIVE SET', style: TextStyle(fontSize: 11, color: AppColors.textLow, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 10),
          for (final frame in provider.project.frames)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.cardAlt, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(frame.kind.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(frame.kind == FrameKind.feature ? '1600×1600 px' : '1200×1200 px', style: const TextStyle(fontSize: 9.5, color: AppColors.textLow)),
                        ],
                      ),
                    ),
                    Switch(
                      value: frame.templateLocked,
                      activeColor: AppColors.accent,
                      onChanged: (v) {
                        frame.templateLocked = v;
                        provider.notifyListeners();
                      },
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border, style: BorderStyle.solid), borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('+ Import a custom frame template', style: TextStyle(fontSize: 11, color: AppColors.textLow))),
          ),
        ],
      ),
    );
  }
}
