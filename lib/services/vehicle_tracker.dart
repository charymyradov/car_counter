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

  const CounterConfig({
    this.linePosition = 0.55,
    this.isHorizontal = false,
    this.minConfidence = 0.35,
    this.maxMissedFrames = 10,
    this.maxMatchDistance = 0.20,
  });

  CounterConfig copyWith({
    double? linePosition,
    bool? isHorizontal,
    double? minConfidence,
    int? maxMissedFrames,
    double? maxMatchDistance,
  }) {
    return CounterConfig(
      linePosition: linePosition ?? this.linePosition,
      isHorizontal: isHorizontal ?? this.isHorizontal,
      minConfidence: minConfidence ?? this.minConfidence,
      maxMissedFrames: maxMissedFrames ?? this.maxMissedFrames,
      maxMatchDistance: maxMatchDistance ?? this.maxMatchDistance,
    );
  }
}

/// High-performance vehicle tracking and line-crossing counting engine.
class VehicleTracker {
  CounterConfig config;

  final ValueNotifier<CounterStats> statsNotifier =
      ValueNotifier<CounterStats>(const CounterStats());

  final ValueNotifier<int> activeVehiclesNotifier = ValueNotifier<int>(0);

  int _nextTrackId = 0;
  final List<VehicleTrack> _activeTracks = [];

  // Squared distance threshold cache to avoid square-root computation
  late double _maxMatchDistSq;

  VehicleTracker({CounterConfig? initialConfig})
      : config = initialConfig ?? const CounterConfig() {
    _updateDistanceThreshold();
  }

  void _updateDistanceThreshold() {
    _maxMatchDistSq = config.maxMatchDistance * config.maxMatchDistance;
  }

  void updateConfig(CounterConfig newConfig) {
    config = newConfig;
    _updateDistanceThreshold();
  }

  List<VehicleTrack> get activeTracks => List.unmodifiable(_activeTracks);

  /// Process incoming detections from YOLO frame callback.
  void processFrame(List<YOLOResult> results) {
    if (results.isEmpty && _activeTracks.isEmpty) return;

    // 1. Filter relevant vehicle detections
    final List<({VehicleType type, Offset center, double confidence})> detections = [];

    for (int i = 0; i < results.length; i++) {
      final res = results[i];
      if (res.confidence < config.minConfidence) continue;

      final type = VehicleType.fromClassName(res.className);
      if (type == null) continue;

      final center = Offset(
        res.normalizedBox.center.dx,
        res.normalizedBox.center.dy,
      );

      detections.add((
        type: type,
        center: center,
        confidence: res.confidence,
      ));
    }

    // 2. Associate detections with existing tracks using greedy nearest-neighbor
    final matchedTrackIds = <int>{};
    var currentStats = statsNotifier.value;
    bool statsChanged = false;

    for (int i = 0; i < detections.length; i++) {
      final det = detections[i];
      VehicleTrack? bestTrack;
      double bestDistSq = _maxMatchDistSq;

      for (int t = 0; t < _activeTracks.length; t++) {
        final track = _activeTracks[t];
        if (matchedTrackIds.contains(track.id)) continue;

        // Use predicted position for better fast-moving vehicle association
        final predicted = track.predictedPosition;
        final dx = predicted.dx - det.center.dx;
        final dy = predicted.dy - det.center.dy;
        double distSq = dx * dx + dy * dy;

        // Slight distance penalty if types do not match
        if (track.type != det.type) {
          distSq *= 1.3;
        }

        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          bestTrack = track;
        }
      }

      if (bestTrack != null) {
        // Line-crossing verification
        if (!bestTrack.counted) {
          final crossed = _checkLineCrossing(
            previous: bestTrack.position,
            current: det.center,
          );

          if (crossed) {
            bestTrack.counted = true;
            final isInbound = config.isHorizontal
                ? (det.center.dy >= bestTrack.position.dy)
                : (det.center.dx >= bestTrack.position.dx);

            currentStats = currentStats.copyWithIncrement(
              bestTrack.type,
              isInbound: isInbound,
            );
            statsChanged = true;
          }
        }

        bestTrack.update(det.center, det.confidence);
        matchedTrackIds.add(bestTrack.id);
      } else {
        // Create new track
        final newTrack = VehicleTrack(
          id: _nextTrackId++,
          type: det.type,
          position: det.center,
          confidence: det.confidence,
        );
        _activeTracks.add(newTrack);
        matchedTrackIds.add(newTrack.id);
      }
    }

    // 3. Mark missed frames and purge lost tracks
    for (int t = 0; t < _activeTracks.length; t++) {
      final track = _activeTracks[t];
      if (!matchedTrackIds.contains(track.id)) {
        track.missedFrames++;
      }
    }

    _activeTracks.removeWhere((track) => track.missedFrames > config.maxMissedFrames);

    // Update listeners only when necessary to preserve 60fps UI smoothness
    if (statsChanged) {
      statsNotifier.value = currentStats;
    }

    if (activeVehiclesNotifier.value != _activeTracks.length) {
      activeVehiclesNotifier.value = _activeTracks.length;
    }
  }

  /// Evaluates whether the motion segment crossed the defined counting line.
  bool _checkLineCrossing({required Offset previous, required Offset current}) {
    final line = config.linePosition;

    if (config.isHorizontal) {
      // Horizontal line: vehicle crosses vertically across screen (Y axis)
      return (previous.dy < line && current.dy >= line) ||
          (previous.dy > line && current.dy <= line);
    } else {
      // Vertical line: vehicle crosses horizontally across screen (X axis)
      return (previous.dx < line && current.dx >= line) ||
          (previous.dx > line && current.dx <= line);
    }
  }

  /// Resets all counters and tracks.
  void reset() {
    _activeTracks.clear();
    _nextTrackId = 0;
    statsNotifier.value = const CounterStats();
    activeVehiclesNotifier.value = 0;
  }

  void dispose() {
    statsNotifier.dispose();
    activeVehiclesNotifier.dispose();
  }
}
