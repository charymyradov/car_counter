
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CarCounterApp());
}

class CarCounterApp extends StatelessWidget {
  const CarCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Car Counter AI',
      theme: ThemeData.dark(),
      home: const CarCounterPage(),
    );
  }
}

// Her algilanan aracin takip bilgisi
class CarTrack {
  final int id;
  Offset position;
  int missedFrames = 0;
  bool counted = false;

  CarTrack({
    required this.id,
    required this.position,
  });
}

class CarCounterPage extends StatefulWidget {
  const CarCounterPage({super.key});

  @override
  State<CarCounterPage> createState() => _CarCounterPageState();
}

class _CarCounterPageState extends State<CarCounterPage> {
  bool _cameraGranted = false;
  bool _checkingPermission = true;

  int _totalCars = 0;
  int _nextTrackId = 0;

  final List<CarTrack> _tracks = [];

  // Araclar bu dikey cizgiyi gectiginde sayilir.
  static const double _countingLine = 0.55;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  // Kamera izni
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (!mounted) return;

    setState(() {
      _cameraGranted = status.isGranted;
      _checkingPermission = false;
    });
  }

  // YOLO algilama sonuclarini isleme
  void _handleResults(List<YOLOResult> results) {
    // Yalnizca araba algilamalarini al.
    final cars = results.where((result) {
      return result.className.toLowerCase() == 'car' &&
          result.confidence >= 0.35;
    }).toList();

    final matchedTrackIds = <int>{};
    int newlyCounted = 0;

    for (final car in cars) {
      // Nesnenin merkez noktasini al.
      final center = Offset(
        car.normalizedBox.center.dx,
        car.normalizedBox.center.dy,
      );

      CarTrack? nearestTrack;
      double minDistance = 0.18;

      // Onceki karedeki en yakin araci bul.
      for (final track in _tracks) {
        if (matchedTrackIds.contains(track.id)) continue;

        final distance =
            (track.position - center).distance;

        if (distance < minDistance) {
          minDistance = distance;
          nearestTrack = track;
        }
      }

      if (nearestTrack != null) {
        final previousX = nearestTrack.position.dx;
        final currentX = center.dx;

        // Arac sayim cizgisini gecti mi?
        final crossedLine =
            (previousX < _countingLine &&
                currentX >= _countingLine) ||
            (previousX > _countingLine &&
                currentX <= _countingLine);

        if (crossedLine && !nearestTrack.counted) {
          newlyCounted++;
          nearestTrack.counted = true;
        }

        nearestTrack.position = center;
        nearestTrack.missedFrames = 0;

        matchedTrackIds.add(nearestTrack.id);
      } else {
        // Yeni bir arac takip kaydi olustur.
        final newTrack = CarTrack(
          id: _nextTrackId++,
          position: center,
        );

        _tracks.add(newTrack);
        matchedTrackIds.add(newTrack.id);
      }
    }

    // Goruntuden kaybolan araclari takipten cikar.
    for (final track in _tracks) {
      if (!matchedTrackIds.contains(track.id)) {
        track.missedFrames++;
      }
    }

    _tracks.removeWhere(
      (track) => track.missedFrames > 10,
    );

    // Sayaci guncelle.
    if (newlyCounted > 0 && mounted) {
      setState(() {
        _totalCars += newlyCounted;
      });
    }
  }

  // Sayaci sifirla
  void _resetCounter() {
    setState(() {
      _totalCars = 0;
      _tracks.clear();
      _nextTrackId = 0;
    });
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
        child: CircularProgressIndicator(),
      );
    }

    if (!_cameraGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography,
              size: 60,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text('Camera permission required'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestCameraPermission,
              child: const Text('Allow Camera'),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gercek zamanli YOLO kamera
        YOLOView(
          modelPath: 'yolo26n',
          task: YOLOTask.detect,
          onResult: _handleResults,
        ),

        // Sayim cizgisi
        IgnorePointer(
          child: CustomPaint(
            painter: CountingLinePainter(
              linePosition: _countingLine,
            ),
          ),
        ),

        // Ust bilgi
        Positioned(
          top: 55,
          left: 20,
          right: 20,
          child: _buildHeader(),
        ),

        // Alt kontrol paneli
        Positioned(
          bottom: 35,
          left: 20,
          right: 20,
          child: _buildBottomPanel(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.directions_car,
              color: Colors.greenAccent,
              size: 30,
            ),
            const SizedBox(width: 10),
            const Text(
              'CAR COUNTER AI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.circle,
              color: Colors.greenAccent,
              size: 10,
            ),
            const SizedBox(width: 6),
            const Text('LIVE'),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.greenAccent.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL CARS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$_totalCars',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 55,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Vehicles crossed the line',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.center_focus_strong,
                color: Colors.greenAccent,
              ),
              SizedBox(width: 8),
              Text(
                'AI VEHICLE DETECTION ACTIVE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _resetCounter,
              icon: const Icon(Icons.refresh),
              label: const Text('RESET COUNTER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// Ekrandaki sanal sayim cizgisi
class CountingLinePainter extends CustomPainter {
  final double linePosition;

  CountingLinePainter({
    required this.linePosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * linePosition;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Kesikli cizgi
    const dashWidth = 14.0;
    const dashSpace = 8.0;

    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(x, startY),
        Offset(
          x,
          (startY + dashWidth).clamp(0.0, size.height),
        ),
        paint,
      );

      startY += dashWidth + dashSpace;
    }

    // Cizgi etiketi
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'COUNTING LINE',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Etiketi dikey cizginin yanina yerlestir.
    final labelX =
        x + 10 + textPainter.width <= size.width ? x + 10 : x - 10 - textPainter.width;

    textPainter.paint(
      canvas,
      Offset(labelX, 12),
    );
  }

  @override
  bool shouldRepaint(covariant CountingLinePainter oldDelegate) {
    return oldDelegate.linePosition != linePosition;
  }
}
