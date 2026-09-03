import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/frame_model.dart';
import '../../providers/project_provider.dart';
import '../../theme/app_theme.dart';

class RotateToolScreen extends StatefulWidget {
  final FrameKind frameKind;
  const RotateToolScreen({super.key, required this.frameKind});

  @override
  State<RotateToolScreen> createState() => _RotateToolScreenState();
}

class _RotateToolScreenState extends State<RotateToolScreen> {
  double _angle = 0; // preview-only; baked into pixels on Apply

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProjectProvider>();
    final bytes = provider.project.frameOf(widget.frameKind).imageLayer?.currentBytes;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Rotate'),
        actions: [
          TextButton(
            onPressed: bytes == null
                ? null
                : () {
                    if (_angle != 0) {
                      provider.rotateFreeAngle(widget.frameKind, _angle);
                    }
                    Navigator.pop(context);
                  },
            child: const Text('Apply'),
          ),
        ],
      ),
      body: bytes == null
          ? const Center(child: Text('No image in this frame', style: TextStyle(color: AppColors.textMid)))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Transform.rotate(
                      angle: _angle * 3.1415926535 / 180,
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Text('-180°', style: TextStyle(fontSize: 10, color: AppColors.textLow)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.accent, thumbColor: AppColors.accent, inactiveTrackColor: AppColors.border),
                          child: Slider(value: _angle, min: -180, max: 180, onChanged: (v) => setState(() => _angle = v)),
                        ),
                      ),
                      const Text('180°', style: TextStyle(fontSize: 10, color: AppColors.textLow)),
                    ],
                  ),
                ),
                Text('${_angle.round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _angle = (_angle - 90).clamp(-180, 180)),
                      icon: const Icon(Icons.rotate_left, size: 16),
                      label: const Text('-90°'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _angle = 0),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _angle = (_angle + 90).clamp(-180, 180)),
                      icon: const Icon(Icons.rotate_right, size: 16),
                      label: const Text('+90°'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
