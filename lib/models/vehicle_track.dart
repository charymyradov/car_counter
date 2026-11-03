import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'vehicle_type.dart';

/// Represents an actively tracked vehicle across consecutive camera frames.
class VehicleTrack {
  /// Number of recent positions kept for trajectory visualisation.
  static const int historyCapacity = 8;

  final int id;
  final VehicleType type;
  Offset position;
  Offset? previousPosition;
  double confidence;
  int missedFrames;
  bool counted;

  /// Number of detections associated with this track so far.
  ///
  /// Line crossings are only accepted once a track has been confirmed, which
  /// filters single-frame detector noise without dropping real vehicles.
  int hits;

  /// Frame stamp of the last detection associated with this track.
  ///
  /// The tracker compares this against its current frame counter instead of
  /// maintaining a per-frame `Set<int>` of matched track ids, which removes an
  /// allocation (and hash lookups) from every processed frame.
  int lastMatchedFrame;

  // Smoothing coefficients for the velocity vector.
  static const double _velocityRetain = 0.4;
  static const double _velocityGain = 0.6;

  double _velocityX = 0;
  double _velocityY = 0;

  // Fixed-size ring buffer for the recent trajectory. A `removeAt(0)` based
  // list shifts every element on each update, so the ring buffer keeps history
  // updates O(1) and allocation free.
  final Float32List _historyXY = Float32List(historyCapacity * 2);
  int _historyStart = 0;
  int _historyLength = 0;

  VehicleTrack({
    required this.id,
    required this.type,
    required this.position,
    this.confidence = 1.0,
    this.lastMatchedFrame = -1,
  })  : previousPosition = null,
        missedFrames = 0,
        counted = false,
        hits = 1 {
    _pushHistory(position.dx, position.dy);
  }

  /// Smoothed velocity vector in normalized units per frame.
  Offset get velocity => Offset(_velocityX, _velocityY);

  /// Predicted X position in the next frame based on smoothed velocity.
  double get predictedX => position.dx + _velocityX;

  /// Predicted Y position in the next frame based on smoothed velocity.
  double get predictedY => position.dy + _velocityY;

  /// Predicted position in the next frame based on smoothed velocity.
  Offset get predictedPosition => Offset(predictedX, predictedY);

  /// Recent positions from oldest to newest.
  ///
  /// Materialised on demand; the tracking loop never reads it.
  List<Offset> get history {
    final positions = List<Offset>.filled(_historyLength, Offset.zero);
    for (var i = 0; i < _historyLength; i++) {
      final index = (_historyStart + i) % historyCapacity;
      positions[i] = Offset(
        _historyXY[index * 2],
        _historyXY[index * 2 + 1],
      );
    }
    return positions;
  }

  /// Updates the track with a newly matched detection.
  void update(Offset newPosition, double newConfidence) {
    updatePosition(newPosition.dx, newPosition.dy, newConfidence);
  }

  /// Updates the track from raw normalized coordinates.
  ///
  /// Avoids creating a temporary [Offset] for every matched detection.
  void updatePosition(double x, double y, double confidence) {
    previousPosition = position;

    // Exponential smoothing for the velocity vector, computed on scalar fields
    // so no intermediate Offset is allocated.
    _velocityX = _velocityX * _velocityRetain + (x - position.dx) * _velocityGain;
    _velocityY = _velocityY * _velocityRetain + (y - position.dy) * _velocityGain;

    position = Offset(x, y);
    this.confidence = confidence;
    missedFrames = 0;
    hits++;

    _pushHistory(x, y);
  }

  void _pushHistory(double x, double y) {
    if (_historyLength < historyCapacity) {
      final index = (_historyStart + _historyLength) % historyCapacity;
      _historyXY[index * 2] = x;
      _historyXY[index * 2 + 1] = y;
      _historyLength++;
      return;
    }

    // Buffer is full: overwrite the oldest entry and advance the read cursor.
    _historyXY[_historyStart * 2] = x;
    _historyXY[_historyStart * 2 + 1] = y;
    _historyStart = (_historyStart + 1) % historyCapacity;
  }

  /// Calculates squared euclidean distance to a candidate point for fast association.
  double distanceSquaredTo(Offset target) {
    final dx = position.dx - target.dx;
    final dy = position.dy - target.dy;
    return dx * dx + dy * dy;
  }
}
