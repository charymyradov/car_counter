import 'vehicle_type.dart';

/// Immutable snapshot of vehicle count statistics.
///
/// Counts live in a fixed-length list indexed by [VehicleType.index] instead of
/// a map. Incrementing therefore copies four integers rather than rebuilding a
/// hash map on every counted vehicle, and the fixed layout keeps lookups O(1)
/// without hashing.
class CounterStats {
  static const int _typeCount = 4;

  final int total;
  final int inbound;
  final int outbound;

  final List<int> _counts;

  const CounterStats({
    this.total = 0,
    this.inbound = 0,
    this.outbound = 0,
  }) : _counts = const <int>[0, 0, 0, 0];

  const CounterStats._(
    this.total,
    this.inbound,
    this.outbound,
    this._counts,
  );
  /// Number of counted vehicles of the given [type].
  int getCount(VehicleType type) => _counts[type.index];

  /// Number of counted vehicles per type, indexed by [VehicleType.index].
  List<int> get counts => List<int>.unmodifiable(_counts);

  CounterStats copyWithIncrement(VehicleType type, {bool isInbound = true}) {
    final index = type.index;
    // Fixed-length copy: no map rehash, no growable list bookkeeping.
    final updatedCounts = List<int>.of(_counts, growable: false);
    updatedCounts[index] = updatedCounts[index] + 1;

    return CounterStats._(
      total + 1,
      isInbound ? inbound + 1 : inbound,
      isInbound ? outbound : outbound + 1,
      updatedCounts,
    );
  }

  CounterStats reset() => const CounterStats();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CounterStats) return false;
    if (other.total != total ||
        other.inbound != inbound ||
        other.outbound != outbound) {
      return false;
    }
    for (var i = 0; i < _typeCount; i++) {
      if (other._counts[i] != _counts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        total,
        inbound,
        outbound,
        Object.hashAll(_counts),
      );
}
