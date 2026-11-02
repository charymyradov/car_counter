import 'vehicle_type.dart';

/// Immutable snapshot of vehicle count statistics.
class CounterStats {
  final int total;
  final Map<VehicleType, int> counts;
  final int inbound;
  final int outbound;

  const CounterStats({
    this.total = 0,
    this.counts = const {
      VehicleType.car: 0,
      VehicleType.bus: 0,
      VehicleType.truck: 0,
      VehicleType.motorcycle: 0,
    },
    this.inbound = 0,
    this.outbound = 0,
  });

  int getCount(VehicleType type) => counts[type] ?? 0;

  CounterStats copyWithIncrement(VehicleType type, {bool isInbound = true}) {
    final updatedCounts = Map<VehicleType, int>.from(counts);
    updatedCounts[type] = (updatedCounts[type] ?? 0) + 1;

    return CounterStats(
      total: total + 1,
      counts: updatedCounts,
      inbound: isInbound ? inbound + 1 : inbound,
      outbound: !isInbound ? outbound + 1 : outbound,
    );
  }

  CounterStats reset() => const CounterStats();
}

