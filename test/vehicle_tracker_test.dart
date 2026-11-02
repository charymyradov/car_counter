import 'package:flutter_test/flutter_test.dart';
import 'package:car_counter/models/vehicle_type.dart';
import 'package:car_counter/models/vehicle_track.dart';
import 'package:car_counter/models/counter_stats.dart';
import 'package:car_counter/services/vehicle_tracker.dart';

void main() {
  group('VehicleType Tests', () {
    test('Correctly identifies vehicle classes from strings', () {
      expect(VehicleType.fromClassName('car'), equals(VehicleType.car));
      expect(VehicleType.fromClassName('CAR'), equals(VehicleType.car));
      expect(VehicleType.fromClassName('automobile'), equals(VehicleType.car));
      expect(VehicleType.fromClassName('bus'), equals(VehicleType.bus));
      expect(VehicleType.fromClassName('truck'), equals(VehicleType.truck));
      expect(VehicleType.fromClassName('motorcycle'), equals(VehicleType.motorcycle));
      expect(VehicleType.fromClassName('person'), isNull);
    });
  });

  group('CounterStats Tests', () {
    test('Increment works correctly', () {
      const stats = CounterStats();
      expect(stats.total, 0);

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
    });
  });

  group('VehicleTracker Engine Tests', () {
    test('Configuration and reset', () {
      final tracker = VehicleTracker();
      expect(tracker.config.linePosition, 0.55);
      expect(tracker.config.isHorizontal, false);

      tracker.updateConfig(const CounterConfig(linePosition: 0.7, isHorizontal: true));
      expect(tracker.config.linePosition, 0.7);
      expect(tracker.config.isHorizontal, true);

      tracker.reset();
      expect(tracker.statsNotifier.value.total, 0);
    });
  });
}
