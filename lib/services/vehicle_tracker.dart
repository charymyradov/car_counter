import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../models/counter_stats.dart';
import '../models/vehicle_track.dart';
import '../models/vehicle_type.dart';

/// Configuration options for vehicle line counting.
class CounterConfig {
  /// Normalized position of counting line across the screen (0.0 to 1.0).
  final double linePosition;

  /// False = vertical line (x-axis crossing), True = horizontal line (y-axis crossing).
  final bool isHorizontal;

  /// Minimum detection confidence threshold to consider.
  final double minConfidence;

  /// Max frames a track can be missing before being dropped.
  final int maxMissedFrames;

  /// Max normalized Euclidean distance for linking detections across frames.
  final double maxMatchDistance;

  /// Detections a track needs before its line crossings are accepted.
  final int minHits;

  /// Upper bound on simultaneously tracked vehicles.
  ///
  /// Protects the tracking loop from runaway track creation on noisy frames.
  final int maxTracks;

  const CounterConfig({
    this.linePosition = 0.55,
    this.isHorizontal = false,
    this.minConfidence = 0.35,
    this.maxMissedFrames = 10,
    this.maxMatchDistance = 0.20,
    this.minHits = 2,
    this.maxTracks = 64,
  });

  CounterConfig copyWith({
    double? linePosition,
    bool? isHorizontal,
    double? minConfidence,
    int? maxMissedFrames,
    double? maxMatchDistance,
    int? minHits,
    int? maxTracks,
  }) {
    return CounterConfig(
      linePosition: linePosition ?? this.linePosition,
      isHorizontal: isHorizontal ?? this.isHorizontal,
      minConfidence: minConfidence ?? this.minConfidence,
      maxMissedFrames: maxMissedFrames ?? this.maxMissedFrames,
      maxMatchDistance: maxMatchDistance ?? this.maxMatchDistance,
      minHits: minHits ?? this.minHits,
      maxTracks: maxTracks ?? this.maxTracks,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CounterConfig &&
            other.linePosition == linePosition &&
            other.isHorizontal == isHorizontal &&
            other.minConfidence == minConfidence &&
            other.maxMissedFrames == maxMissedFrames &&
            other.maxMatchDistance == maxMatchDistance &&
            other.minHits == minHits &&
            other.maxTracks == maxTracks;
  }

  @override
  int get hashCode => Object.hash(
        linePosition,
        isHorizontal,
        minConfidence,
        maxMissedFrames,
        maxMatchDistance,
        minHits,
        maxTracks,
      );
}

/// High-performance vehicle tracking and line-crossing counting engine.
class VehicleTracker {
  CounterConfig _config;

  /// Current tracking configuration. Updates through [updateConfig] notify
  /// [configNotifier] so overlays can repaint without rebuilding the page.
  CounterConfig get config => _config;

  final ValueNotifier<CounterConfig> configNotifier;

  final ValueNotifier<CounterStats> statsNotifier =
      ValueNotifier<CounterStats>(const CounterStats());

  final ValueNotifier<int> activeVehiclesNotifier = ValueNotifier<int>(0);

  /// Measured processing frame rate, refreshed at most twice per second.
  final ValueNotifier<int> fpsNotifier = ValueNotifier<int>(0);

  /// When false, incoming frames are ignored (app in background).
  bool _processingEnabled = true;

  final Stopwatch _frameClock = Stopwatch();
  int _framesSinceFpsSample = 0;
  int _lastFpsSampleMicros = 0;

  static const int _fpsSampleIntervalMicros = 500000;

  int _nextTrackId = 0;
  final List<VehicleTrack> _activeTracks = [];

  /// Monotonic frame counter used for O(1) match bookkeeping.
  int _frameStamp = 0;

  // Squared distance threshold cache to avoid square-root computation
  late double _maxMatchDistSq;

  // Reusable detection buffers. Scanning these parallel lists avoids building
  // a fresh list of records for every camera frame.
  final List<VehicleType> _detectionTypes = <VehicleType>[];
  final List<double> _detectionX = <double>[];
  final List<double> _detectionY = <double>[];
  final List<double> _detectionConfidence = <double>[];

  VehicleTracker({CounterConfig? initialConfig})
      : _config = initialConfig ?? const CounterConfig(),
        configNotifier = ValueNotifier<CounterConfig>(
          initialConfig ?? const CounterConfig(),
        ) {
    _updateDistanceThreshold();
  }

  void _updateDistanceThreshold() {
    _maxMatchDistSq = _config.maxMatchDistance * _config.maxMatchDistance;
  }

  void updateConfig(CounterConfig newConfig) {
    if (newConfig == _config) return;
    _config = newConfig;
    _updateDistanceThreshold();
    configNotifier.value = newConfig;
  }

  List<VehicleTrack> get activeTracks => List.unmodifiable(_activeTracks);

  /// Enables or disables frame processing, e.g. while the app is backgrounded.
  void setProcessingEnabled(bool enabled) {
    if (_processingEnabled == enabled) return;
    _processingEnabled = enabled;

    if (enabled) {
      _frameClock.reset();
      _frameClock.start();
      _framesSinceFpsSample = 0;
      _lastFpsSampleMicros = 0;
    } else {
      _frameClock.stop();
      fpsNotifier.value = 0;
    }
  }

  /// Process incoming detections from YOLO frame callback.
  void processFrame(List<YOLOResult> results) {
    if (!_processingEnabled) return;

    _sampleFps();
    _frameStamp++;

    final hasDetections = _collectDetections(results);
    if (!hasDetections && _activeTracks.isEmpty) return;

    var currentStats = statsNotifier.value;
    var statsChanged = false;

    // 2. Associate detections with existing tracks using greedy nearest-neighbor
    final detectionCount = _detectionTypes.length;

    for (var i = 0; i < detectionCount; i++) {
      final type = _detectionTypes[i];
      final centerX = _detectionX[i];
      final centerY = _detectionY[i];
      final confidence = _detectionConfidence[i];

      VehicleTrack? bestTrack;
      double bestDistSq = _maxMatchDistSq;

      for (var t = 0; t < _activeTracks.length; t++) {
        final track = _activeTracks[t];
        if (track.lastMatchedFrame == _frameStamp) continue;

        // Use predicted position for better fast-moving vehicle association
        final dx = track.predictedX - centerX;
        final dy = track.predictedY - centerY;
        double distSq = dx * dx + dy * dy;

        // Slight distance penalty if types do not match
        if (track.type != type) {
          distSq *= 1.3;
        }

        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          bestTrack = track;
        }
      }

      if (bestTrack != null) {
        // Line-crossing verification. The current detection will become a
        // confirmed hit, so crossings are accepted from the `minHits`-th hit.
        if (!bestTrack.counted &&
            bestTrack.hits + 1 >= config.minHits &&
            _checkLineCrossing(
              previousX: bestTrack.position.dx,
              previousY: bestTrack.position.dy,
              currentX: centerX,
              currentY: centerY,
            )) {
          bestTrack.counted = true;
          final isInbound = config.isHorizontal
              ? (centerY >= bestTrack.position.dy)
              : (centerX >= bestTrack.position.dx);

          currentStats = currentStats.copyWithIncrement(
            bestTrack.type,
            isInbound: isInbound,
          );
          statsChanged = true;
        }

        bestTrack.updatePosition(centerX, centerY, confidence);
        bestTrack.lastMatchedFrame = _frameStamp;
      } else {
        // Create new track, but keep the tracking loop bounded.
        if (_activeTracks.length >= config.maxTracks) continue;

        final newTrack = VehicleTrack(
          id: _nextTrackId++,
          type: type,
          position: Offset(centerX, centerY),
          confidence: confidence,
          lastMatchedFrame: _frameStamp,
        );
        _activeTracks.add(newTrack);
      }
    }

    // 3. Mark missed frames and compact lost tracks in place. This replaces
    //    `removeWhere` + closure allocation on every frame.
    var writeIndex = 0;
    for (var readIndex = 0; readIndex < _activeTracks.length; readIndex++) {
      final track = _activeTracks[readIndex];
      if (track.lastMatchedFrame != _frameStamp) {
        track.missedFrames++;
        if (track.missedFrames > config.maxMissedFrames) continue;
      }
      _activeTracks[writeIndex++] = track;
    }
    if (writeIndex != _activeTracks.length) {
      _activeTracks.length = writeIndex;
    }

    // Update listeners only when necessary to preserve 60fps UI smoothness
    if (statsChanged) {
      statsNotifier.value = currentStats;
    }

    if (activeVehiclesNotifier.value != _activeTracks.length) {
      activeVehiclesNotifier.value = _activeTracks.length;
    }
  }

  /// Samples the detection callback rate without allocating timers.
  void _sampleFps() {
    if (!_frameClock.isRunning) {
      _frameClock.start();
      _lastFpsSampleMicros = 0;
      _framesSinceFpsSample = 0;
      return;
    }

    _framesSinceFpsSample++;
    final elapsed = _frameClock.elapsedMicroseconds - _lastFpsSampleMicros;
    if (elapsed < _fpsSampleIntervalMicros) return;

    final fps = (_framesSinceFpsSample * 1000000 / elapsed).round();
    _framesSinceFpsSample = 0;
    _lastFpsSampleMicros = _frameClock.elapsedMicroseconds;
    if (fpsNotifier.value != fps) {
      fpsNotifier.value = fps;
    }
  }

  /// Filters YOLO results into the reusable detection buffers.
  bool _collectDetections(List<YOLOResult> results) {    _detectionTypes.clear();
    _detectionX.clear();
    _detectionY.clear();
    _detectionConfidence.clear();

    final minConfidence = config.minConfidence;
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result.confidence < minConfidence) continue;

      final type = VehicleType.fromClassName(result.className);
      if (type == null) continue;

      _detectionTypes.add(type);
      _detectionX.add(result.normalizedBox.center.dx);
      _detectionY.add(result.normalizedBox.center.dy);
      _detectionConfidence.add(result.confidence);
    }

    return _detectionTypes.isNotEmpty;
  }

  /// Evaluates whether the motion segment crossed the defined counting line.
  bool _checkLineCrossing({
    required double previousX,
    required double previousY,
    required double currentX,
    required double currentY,
  }) {
    final line = config.linePosition;

    if (config.isHorizontal) {
      // Horizontal line: vehicle crosses vertically across screen (Y axis)
      return (previousY < line && currentY >= line) ||
          (previousY > line && currentY <= line);
    }
    // Vertical line: vehicle crosses horizontally across screen (X axis)
    return (previousX < line && currentX >= line) ||
        (previousX > line && currentX <= line);
  }

  /// Resets all counters and tracks.
  void reset() {
    _activeTracks.clear();
    _detectionTypes.clear();
    _detectionX.clear();
    _detectionY.clear();
    _detectionConfidence.clear();
    _nextTrackId = 0;
    statsNotifier.value = const CounterStats();
    activeVehiclesNotifier.value = 0;
  }

  void dispose() {
    configNotifier.dispose();
    statsNotifier.dispose();
    activeVehiclesNotifier.dispose();
    fpsNotifier.dispose();
  }
}
