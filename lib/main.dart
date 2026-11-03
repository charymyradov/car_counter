import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'services/vehicle_tracker.dart';
import 'widgets/counting_line_painter.dart';
import 'widgets/hud_bottom_controls.dart';
import 'widgets/hud_header.dart';
import 'widgets/settings_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const CarCounterApp());
}

class CarCounterApp extends StatelessWidget {
  const CarCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Car Counter AI',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF14171A),
        ),
      ),
      home: const CarCounterPage(),
    );
  }
}

class CarCounterPage extends StatefulWidget {
  const CarCounterPage({super.key});

  @override
  State<CarCounterPage> createState() => _CarCounterPageState();
}

class _CarCounterPageState extends State<CarCounterPage>
    with WidgetsBindingObserver {
  late final VehicleTracker _tracker;

  bool _cameraGranted = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tracker = VehicleTracker();
    _requestCameraPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_cameraGranted) {
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() {
      _cameraGranted = status.isGranted;
      _checkingPermission = false;
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _cameraGranted = status.isGranted;
      _checkingPermission = false;
    });
  }

  /// High-throughput callback directly processed by the vehicle tracking engine.
  /// Does NOT trigger parent widget rebuilds (zero setState during inference).
  void _onDetectionsReceived(List<YOLOResult> results) {
    _tracker.processFrame(results);
  }

  void _openSettings() {
    SettingsSheet.show(context, tracker: _tracker);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_checkingPermission) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00E5FF),
        ),
      );
    }

    if (!_cameraGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_rounded,
                  size: 54,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Camera Access Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'To detect and count vehicles in real-time, please allow camera permission.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('ALLOW CAMERA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Real-time YOLO AI Camera Feed
        YOLOView(
          modelPath: 'yolo26n',
          task: YOLOTask.detect,
          onResult: _onDetectionsReceived,
        ),

        // 2. Optimized Counting Boundary Line. The overlay listens to the
        //    tracker config directly, so dragging the settings slider repaints
        //    only this layer instead of rebuilding the whole page.
        IgnorePointer(
          child: RepaintBoundary(
            child: ValueListenableBuilder<CounterConfig>(
              valueListenable: _tracker.configNotifier,
              builder: (context, config, _) {
                return CustomPaint(
                  painter: CountingLinePainter(
                    linePosition: config.linePosition,
                    isHorizontal: config.isHorizontal,
                  ),
                );
              },
            ),
          ),
        ),

        // 3. Top HUD Dashboard
        Positioned(
          top: MediaQuery.paddingOf(context).top + 10,
          left: 16,
          right: 16,
          child: HudHeader(
            statsNotifier: _tracker.statsNotifier,
            activeVehiclesNotifier: _tracker.activeVehiclesNotifier,
          ),
        ),

        // 4. Bottom Controls Deck
        Positioned(
          bottom: MediaQuery.paddingOf(context).bottom + 16,
          left: 16,
          right: 16,
          child: HudBottomControls(
            onReset: _tracker.reset,
            onToggleSettings: _openSettings,
          ),
        ),
      ],
    );
  }
}
