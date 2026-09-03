import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/frame_model.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';

// Font family names shown in the picker. None are bundled by default in
// this drop (see README) — Flutter falls back to the platform default
// silently if a named family isn't registered, so this is safe to ship
// as-is; add real font assets later for these to actually render.
const _kFonts = ['Inter', 'Roboto', 'Poppins', 'Montserrat', 'Playfair Display'];
const _kSwatches = [0xFF12151C, 0xFF2F6FED, 0xFFFF9F43, 0xFFE5484D, 0xFFFFFFFF, 0xFF1BAA6D];

class TextEditorPanel extends StatelessWidget {
  final FrameKind frameKind;
  final String layerId;
  const TextEditorPanel({super.key, required this.frameKind, required this.layerId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final layer = provider.project.frameOf(frameKind).textLayers.firstWhere((t) => t.id == layerId);

    void update(void Function(TextLayerModel) fn) => provider.updateTextLayer(frameKind, layerId, fn);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x1A12151C), blurRadius: 30, offset: Offset(0, -8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Edit text', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ],
          ),
          TextFormField(
            initialValue: layer.text,
            onChanged: (v) => update((t) => t.text = v),
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 14),
          const _Label('FONT'),
          DropdownButtonFormField<String>(
            value: layer.fontFamily,
            items: _kFonts.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => v == null ? null : update((t) => t.fontFamily = v),
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SliderField(
                  label: 'SIZE',
                  value: layer.fontSize,
                  min: 10,
                  max: 80,
                  display: '${layer.fontSize.round()} px',
                  onChanged: (v) => update((t) => t.fontSize = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SliderField(
                  label: 'LETTER SPACING',
                  value: layer.letterSpacing,
                  min: -1,
                  max: 6,
                  display: '${layer.letterSpacing.toStringAsFixed(1)} px',
                  onChanged: (v) => update((t) => t.letterSpacing = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _Label('STYLE'),
          Row(
            children: [
              _StyleToggle(label: 'B', active: layer.bold, onTap: () => update((t) => t.bold = !t.bold)),
              const SizedBox(width: 8),
              _StyleToggle(label: 'I', active: layer.italic, onTap: () => update((t) => t.italic = !t.italic)),
              const SizedBox(width: 8),
              _StyleToggle(label: 'S', active: layer.strikethrough, onTap: () => update((t) => t.strikethrough = !t.strikethrough)),
            ],
          ),
          const SizedBox(height: 12),
          const _Label('COLOR'),
          Row(
            children: [
              for (final c in _kSwatches)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => update((t) => t.colorValue = c),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: layer.colorValue == c ? AppColors.accent : AppColors.border,
                          width: layer.colorValue == c ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SliderField(
            label: 'SHADOW OPACITY',
            value: layer.shadowOpacity,
            min: 0,
            max: 1,
            display: '${(layer.shadowOpacity * 100).round()}%',
            onChanged: (v) => update((t) => t.shadowOpacity = v),
          ),
          const SizedBox(height: 6),
          const _Label('POSITION — drag the text directly on the canvas to move it'),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textLow, letterSpacing: 0.3)),
      );
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value, min, max;
  final String display;
  final ValueChanged<double> onChanged;
  const _SliderField({required this.label, required this.value, required this.min, required this.max, required this.display, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 3, activeTrackColor: AppColors.accent, thumbColor: AppColors.accent, inactiveTrackColor: AppColors.border),
                child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
              ),
            ),
            SizedBox(width: 52, child: Text(display, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          ],
        ),
      ],
    );
  }
}

class _StyleToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _StyleToggle({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 36,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textMid)),
      ),
    );
  }
}
