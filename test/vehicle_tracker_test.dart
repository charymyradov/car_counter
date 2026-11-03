import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:car_counter/models/vehicle_type.dart';
import 'package:car_counter/models/vehicle_track.dart';
import 'package:car_counter/models/counter_stats.dart';
import 'package:car_counter/services/vehicle_tracker.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Builds a normalized detection centred on ([x], [y]).
YOLOResult detectionAt(
  double x,
  double y, {
  String className = 'car',
  double confidence = 0.9,
}) {
  const half = 0.05;
  return YOLOResult(
    classIndex: 2,
    className: className,
    confidence: confidence,
    boundingBox: const Rect.fromLTWH(0, 0, 64, 64),
    normalizedBox: Rect.fromLTWH(x - half, y - half, half * 2, half * 2),
  );
}

void main() {
  group('VehicleType Tests', () {
    test('Correctly identifies vehicle classes from strings', () {
      expect(VehicleType.fromClassName('car'), equals(VehicleType.car));
      expect(VehicleType.fromClassName('CAR'), equals(VehicleType.car));
      expect(VehicleType.fromClassName(' Car '), equals(VehicleType.car));
      expect(VehicleType.fromClassName('automobile'), equals(VehicleType.car));
      expect(VehicleType.fromClassName('bus'), equals(VehicleType.bus));
      expect(VehicleType.fromClassName('truck'), equals(VehicleType.truck));
      expect(
        VehicleType.fromClassName('motorcycle'),
        equals(VehicleType.motorcycle),
      );
      expect(VehicleType.fromClassName('person'), isNull);
    });
  });

  group('CounterStats Tests', () {
    test('Increment works correctly', () {
      const stats = CounterStats();
      expect(stats.total, 0);
      expect(stats.counts.length, VehicleType.values.length);

      final s1 = stats.copyWithIncrement(VehicleType.car, isInbound: true);
      expect(s1.total, 1);
      expect(s1.getCount(VehicleType.car), 1);
      expect(s1.inbound, 1);
      expect(s1.outbound, 0);

      final s2 = s1.copyWithIncrement(VehicleType.truck, isInbound: false);
      expect(s2.total, 2);
      expect(s2.getCount(VehicleType.truck), 1);
      expect(s2.getCount(VehicleType.car), 1);
      expect(s2.inbound, 1);
      expect(s2.outbound, 1);

      final reset = s2.reset();
      expect(reset.total, 0);
      expect(reset.getCount(VehicleType.car), 0);
    });

    test('Value equality compares every count', () {
      const stats = CounterStats();
      final car = stats.copyWithIncrement(VehicleType.car);
      final sameCar = stats.copyWithIncrement(VehicleType.car);
      final truck = stats.copyWithIncrement(VehicleType.truck);

      expect(car, equals(sameCar));
      expect(car.hashCode, equals(sameCar.hashCode));
      expect(car == truck, isFalse);
      expect(const CounterStats() == stats.reset(), isTrue);
    });
  });

  group('VehicleTrack Tests', () {
    test('Updates position, velocity and history', () {
      final track = VehicleTrack(
        id: 1,
        type: VehicleType.car,
        position: const Offset(0.2, 0.5),
      );

      expect(track.position, const Offset(0.2, 0.5));
      expect(track.history.length, 1);

      track.update(const Offset(0.3, 0.5), 0.9);
      expect(track.position, const Offset(0.3, 0.5));
      expect(track.previousPosition, const Offset(0.2, 0.5));
      expect(track.history.length, 2);
      expect(track.velocity.dx, greaterThan(0));
      expect(track.hits, 2);
    });

    test('History is a ring buffer capped at historyCapacity', () {
      final track = VehicleTrack(
        id: 1,
        type: VehicleType.car,
        position: const Offset(0, 0),
      );

      for (var i = 1; i <= 20; i++) {
        track.update(Offset(i / 100, 0), 0.9);
      }

      expect(track.history.length, VehicleTrack.historyCapacity);
      expect(track.history.last.dx, closeTo(0.20, 1e-6));
      expect(track.history.last.dy, closeTo(0, 1e-6));
      expect(track.history.first.dx, closeTo(0.13, 1e-6));
    });
  });

  group('VehicleTracker Engine Tests', () {
    test('Configuration and reset', () {
      final tracker = VehicleTracker();
      expect(tracker.config.linePosition, 0.55);
      expect(tracker.config.isHorizontal, false);

      tracker.updateConfig(
        const CounterConfig(linePosition: 0.7, isHorizontal: true),
      );
      expect(tracker.config.linePosition, 0.7);
      expect(tracker.config.isHorizontal, true);

      tracker.reset();
      expect(tracker.statsNotifier.value.total, 0);
    });

    test('Config notifier only fires for real changes', () {
      final tracker = VehicleTracker();
      var notifications = 0;
      tracker.configNotifier.addListener(() => notifications++);

      tracker.updateConfig(const CounterConfig());
      expect(notifications, 0);

      tracker.updateConfig(const CounterConfig(linePosition: 0.4));
      expect(notifications, 1);

      tracker.updateConfig(const CounterConfig(linePosition: 0.4));
      expect(notifications, 1);
    });

    test('Counts an inbound crossing once per track', () {
      final tracker = VehicleTracker(
        initialConfig: const CounterConfig(linePosition: 0.5),
      );

      for (final x in [0.30, 0.38, 0.46, 0.54]) {
        tracker.processFrame([detectionAt(x, 0.5)]);
      }

      final stats = tracker.statsNotifier.value;
      expect(stats.total, 1);
      expect(stats.getCount(VehicleType.car), 1);
      expect(stats.inbound, 1);
      expect(stats.outbound, 0);

      // Continuing past the line must not increment again.
      tracker.processFrame([detectionAt(0.62, 0.5)]);
      expect(tracker.statsNotifier.value.total, 1);
    });

    test('Counts an outbound crossing', () {
      final tracker = VehicleTracker(
        initialConfig: const CounterConfig(linePosition: 0.5),
      );

      for (final x in [0.80, 0.72, 0.64, 0.56, 0.48]) {
        tracker.processFrame([detectionAt(x, 0.5)]);
      }

      final stats = tracker.statsNotifier.value;
      expect(stats.total, 1);
      expect(stats.inbound, 0);
      expect(stats.outbound, 1);
    });

    test('minHits suppresses crossings from unconfirmed tracks', () {
      final tracker = VehicleTracker(
        initialConfig: const CounterConfig(linePosition: 0.5, minHits: 3),
      );

      tracker.processFrame([detectionAt(0.30, 0.5)]);
      tracker.processFrame([detectionAt(0.55, 0.5)]);
      tracker.processFrame([detectionAt(0.60, 0.5)]);

      expect(tracker.statsNotifier.value.total, 0);
    });

    test('Drops tracks after maxMissedFrames', () {
      final tracker = VehicleTracker(
        initialConfig: const CounterConfig(maxMissedFrames: 2),
      );

      tracker.processFrame([detectionAt(0.3, 0.5)]);
      expect(tracker.activeTracks.length, 1);

      for (var i = 0; i < 3; i++) {
        tracker.processFrame(const []);
      }

      expect(tracker.activeTracks, isEmpty);
      expect(tracker.activeVehiclesNotifier.value, 0);
    });

    test('Respects maxTracks when detections flood a frame', () {
      final tracker = VehicleTracker(
        initialConfig: const CounterConfig(maxTracks: 2),
      );

      tracker.processFrame([
        detectionAt(0.1, 0.2),
        detectionAt(0.3, 0.2),
        detectionAt(0.5, 0.2),
        detectionAt(0.7, 0.2),
        detectionAt(0.9, 0.2),
      ]);

      expect(tracker.activeTracks.length, 2);
      expect(tracker.activeVehiclesNotifier.value, 2);
    });

    test('Ignores frames while processing is disabled', () {
      final tracker = VehicleTracker();

      tracker.setProcessingEnabled(false);
      tracker.processFrame([detectionAt(0.4, 0.5)]);
      expect(tracker.activeTracks, isEmpty);

      tracker.setProcessingEnabled(true);
      tracker.processFrame([detectionAt(0.4, 0.5)]);
      expect(tracker.activeTracks.length, 1);
    });
  });
}
