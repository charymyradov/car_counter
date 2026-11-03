import 'package:flutter/material.dart';
import 'vehicle_type.dart';

/// Represents an actively tracked vehicle across consecutive camera frames.
class VehicleTrack {
  final int id;
  final VehicleType type;
  Offset position;
  Offset? previousPosition;
  Offset velocity;
  double confidence;
  int missedFrames;
  bool counted;
  final List<Offset> history;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Frame stamp of the last detection associated with this track.
  ///
  /// The tracker compares this against its current frame counter instead of
  /// maintaining a per-frame `Set<int>` of matched track ids, which removes an
  /// allocation (and hash lookups) from every processed frame.
  int lastMatchedFrame;

  VehicleTrack({
    required this.id,
    required this.type,
    required this.position,
    this.confidence = 1.0,
    this.lastMatchedFrame = -1,
  })  : previousPosition = null,
        velocity = Offset.zero,
        missedFrames = 0,
        counted = false,
        history = [position],
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  /// Updates the track with a newly matched detection.
  void update(Offset newPosition, double newConfidence) {
    updatePosition(newPosition.dx, newPosition.dy, newConfidence);
  }

  /// Updates the track from raw normalized coordinates.
  ///
  /// Avoids creating a temporary [Offset] for every matched detection.
  void updatePosition(double x, double y, double confidence) {
    previousPosition = position;
    // Exponential smoothing for the velocity vector
    velocity = Offset(
      velocity.dx * 0.4 + (x - position.dx) * 0.6,
      velocity.dy * 0.4 + (y - position.dy) * 0.6,
    );
    position = Offset(x, y);
    this.confidence = confidence;
    missedFrames = 0;
    updatedAt = DateTime.now();

    history.add(position);
    if (history.length > 8) {
      history.removeAt(0);
    }
  }

  /// Predicted position in the next frame based on smoothed velocity.
  Offset get predictedPosition => position + velocity;

  /// Calculates squared euclidean distance to a candidate point for fast association.
  double distanceSquaredTo(Offset target) {
    final dx = position.dx - target.dx;
    final dy = position.dy - target.dy;
    return dx * dx + dy * dy;
  }
}
