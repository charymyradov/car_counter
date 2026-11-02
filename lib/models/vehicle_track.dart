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

  VehicleTrack({
    required this.id,
    required this.type,
    required this.position,
    this.confidence = 1.0,
  })  : previousPosition = null,
        velocity = Offset.zero,
        missedFrames = 0,
        counted = false,
        history = [position],
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  /// Updates the track with a newly matched detection.
  void update(Offset newPosition, double newConfidence) {
    previousPosition = position;
    // Exponential smoothing for velocity vector
    final instantVelocity = newPosition - position;
    velocity = Offset(
      velocity.dx * 0.4 + instantVelocity.dx * 0.6,
      velocity.dy * 0.4 + instantVelocity.dy * 0.6,
    );
    position = newPosition;
    confidence = newConfidence;
    missedFrames = 0;
    updatedAt = DateTime.now();

    history.add(newPosition);
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

