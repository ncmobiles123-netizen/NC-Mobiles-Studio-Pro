import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/image_options_sheet.dart';
import 'template_manager_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickAndOpenOptions(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    await showImageOptionsSheet(context, sourceBytes: bytes);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentGlow]),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            const Text('NC Mobiles '),
            const Text('Studio Pro', style: TextStyle(color: AppColors.textLow, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TemplateManagerScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New product set', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Upload one image — the app fills all four frames automatically.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMid, height: 1.4),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _pickAndOpenOptions(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFC7D6FB), style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        const Text('Upload product image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        const Text('JPG, PNG · up to 25MP', style: TextStyle(fontSize: 10.5, color: AppColors.textLow)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('TEMPLATES LOADED', style: TextStyle(fontSize: 11, color: AppColors.textLow, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: FrameKind.values.map((k) {
              final has = provider.project.frameOf(k).imageLayer != null;
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.cardAlt,
                          borderRadius: BorderRadius.circular(9),
                          image: has
                              ? DecorationImage(image: MemoryImage(provider.project.frameOf(k).imageLayer!.currentBytes), fit: BoxFit.cover)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(k.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/editing'),
                  child: const Text('Upload per frame'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _pickAndOpenOptions(context),
                  child: const Text('Apply to all frames'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
