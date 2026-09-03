import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/frame_model.dart';
import 'providers/project_provider.dart';
import 'screens/editing_screen.dart';
import 'screens/export_screen.dart';
import 'screens/home_screen.dart';
import 'screens/layer_panel_screen.dart';
import 'screens/tools/crop_tool_screen.dart';
import 'screens/tools/erase_tool_screen.dart';
import 'screens/tools/resize_tool_screen.dart';
import 'screens/tools/rotate_tool_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final projectProvider = ProjectProvider();
  // Checked once at launch: confirms whether the TFLite model is
  // actually bundled before any screen tries to use it, so the UI can
  // show "Background Remove — coming soon" instead of a runtime error
  // when it isn't (expected for this build — see README).
  unawaited(projectProvider.initBackgroundRemoval());

  runApp(NCStudioProApp(provider: projectProvider));
}

class NCStudioProApp extends StatelessWidget {
  final ProjectProvider provider;
  const NCStudioProApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        title: 'NC Mobiles Product Image Studio Pro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const RootShell(),
        onGenerateRoute: (settings) {
          if (settings.name == '/editing') {
            return MaterialPageRoute(builder: (_) => const EditingScreen());
          }
          if (settings.name != null && settings.name!.startsWith('/tool/')) {
            final toolName = settings.name!.substring('/tool/'.length);
            final frameKind = settings.arguments as FrameKind;
            switch (toolName) {
              case 'crop':
                return MaterialPageRoute(builder: (_) => CropToolScreen(frameKind: frameKind));
              case 'resize':
                return MaterialPageRoute(builder: (_) => ResizeToolScreen(frameKind: frameKind));
              case 'erase':
                return MaterialPageRoute(builder: (_) => EraseToolScreen(frameKind: frameKind));
              case 'rotateFree':
                return MaterialPageRoute(builder: (_) => RotateToolScreen(frameKind: frameKind));
            }
          }
          return null;
        },
      ),
    );
  }
}

/// Bottom-nav shell matching the approved design: Home / Edit / Layers /
/// Export as persistent tabs.
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _tabs = const [
    HomeScreen(),
    EditingScreen(),
    LayerPanelScreen(),
    ExportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_outlined), activeIcon: Icon(Icons.edit_rounded), label: 'Edit'),
          BottomNavigationBarItem(icon: Icon(Icons.layers_outlined), activeIcon: Icon(Icons.layers_rounded), label: 'Layers'),
          BottomNavigationBarItem(icon: Icon(Icons.ios_share_rounded), label: 'Export'),
        ],
      ),
    );
  }
}
