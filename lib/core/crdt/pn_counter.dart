import 'vector_clock.dart';

/// Positive-Negative Counter CRDT
/// A state-based CRDT that supports increment and decrement operations
/// Uses two separate G-Counter structures for positive and negative operations
class PNCounter {
  final Map<String, int> _positiveCounters;
  final Map<String, int> _negativeCounters;
  final String _nodeId;
  late VectorClock _vectorClock;
  
  PNCounter(this._nodeId) 
      : _positiveCounters = {_nodeId: 0},
        _negativeCounters = {_nodeId: 0} {
    _vectorClock = VectorClock(_nodeId);
  }
  
  PNCounter._(this._nodeId, this._positiveCounters, this._negativeCounters, this._vectorClock);
  
  /// Create from JSON map
  factory PNCounter.fromJson(Map<String, dynamic> json) {
    final nodeId = json['node_id'] as String;
    final positiveCounters = Map<String, int>.from(json['positive_counters'] as Map);
    final negativeCounters = Map<String, int>.from(json['negative_counters'] as Map);
    final vectorClock = VectorClock.fromJson(json['vector_clock'] as Map<String, dynamic>, nodeId);
    
    return PNCounter._(nodeId, positiveCounters, negativeCounters, vectorClock);
  }
  
  /// Get current value (positive - negative)
  int get value {
    final positiveSum = _positiveCounters.values.fold<int>(0, (sum, count) => sum + count);
    final negativeSum = _negativeCounters.values.fold<int>(0, (sum, count) => sum + count);
    return positiveSum - negativeSum;
  }
  
  /// Get the vector clock for this counter
  VectorClock get vectorClock => _vectorClock;
  
  /// Get node ID
  String get nodeId => _nodeId;
  
  /// Increment the counter by the specified amount
  PNCounter increment([int amount = 1]) {
    if (amount < 0) {
      throw ArgumentError('Use decrement() for negative amounts');
    }
    
    final newPositiveCounters = Map<String, int>.from(_positiveCounters);
    newPositiveCounters[_nodeId] = (newPositiveCounters[_nodeId] ?? 0) + amount;
    
    final newVectorClock = _vectorClock.tick();
    
    return PNCounter._(_nodeId, newPositiveCounters, Map<String, int>.from(_negativeCounters), newVectorClock);
  }
  
  /// Decrement the counter by the specified amount
  PNCounter decrement([int amount = 1]) {
    if (amount < 0) {
      throw ArgumentError('Use increment() for negative amounts');
    }
    
    final newNegativeCounters = Map<String, int>.from(_negativeCounters);
    newNegativeCounters[_nodeId] = (newNegativeCounters[_nodeId] ?? 0) + amount;
    
    final newVectorClock = _vectorClock.tick();
    
    return PNCounter._(_nodeId, Map<String, int>.from(_positiveCounters), newNegativeCounters, newVectorClock);
  }
  
  /// Add a specific value (positive increments, negative decrements)
  PNCounter add(int amount) {
    if (amount >= 0) {
      return increment(amount);
    } else {
      return decrement(-amount);
    }
  }
  
  /// Merge with another PNCounter (union of all counters)
  PNCounter mergeWith(PNCounter other) {
    final mergedPositive = <String, int>{};
    final mergedNegative = <String, int>{};
    
    // Merge positive counters (take maximum for each node)
    final allPositiveNodes = <String>{..._positiveCounters.keys, ...other._positiveCounters.keys};
    for (final nodeId in allPositiveNodes) {
      final thisCount = _positiveCounters[nodeId] ?? 0;
      final otherCount = other._positiveCounters[nodeId] ?? 0;
      mergedPositive[nodeId] = thisCount > otherCount ? thisCount : otherCount;
    }
    
    // Merge negative counters (take maximum for each node)
    final allNegativeNodes = <String>{..._negativeCounters.keys, ...other._negativeCounters.keys};
    for (final nodeId in allNegativeNodes) {
      final thisCount = _negativeCounters[nodeId] ?? 0;
      final otherCount = other._negativeCounters[nodeId] ?? 0;
      mergedNegative[nodeId] = thisCount > otherCount ? thisCount : otherCount;
    }
    
    // Merge vector clocks
    final mergedVectorClock = _vectorClock.update(other._vectorClock);
    
    return PNCounter._(_nodeId, mergedPositive, mergedNegative, mergedVectorClock);
  }
  
  /// Create a copy of this counter
  PNCounter copy() {
    return PNCounter._(
      _nodeId,
      Map<String, int>.from(_positiveCounters),
      Map<String, int>.from(_negativeCounters),
      _vectorClock.copy(),
    );
  }
  
  /// Reset counter to zero (create new counter with incremented vector clock)
  PNCounter reset() {
    final newVectorClock = _vectorClock.tick();
    return PNCounter._(_nodeId, {_nodeId: 0}, {_nodeId: 0}, newVectorClock);
  }
  
  /// Check if this counter can be compared with another (not concurrent)
  bool isComparableWith(PNCounter other) {
    return !_vectorClock.isConcurrentWith(other._vectorClock);
  }
  
  /// Check if this counter happens before another
  bool happensBefore(PNCounter other) {
    return _vectorClock.happensBefore(other._vectorClock);
  }
  
  /// Check if this counter happens after another
  bool happensAfter(PNCounter other) {
    return _vectorClock.happensAfter(other._vectorClock);
  }
  
  /// Get all known nodes in this counter
  Set<String> get knownNodes {
    return <String>{..._positiveCounters.keys, ..._negativeCounters.keys};
  }
  
  /// Get positive count for a specific node
  int getPositiveCount(String nodeId) => _positiveCounters[nodeId] ?? 0;
  
  /// Get negative count for a specific node
  int getNegativeCount(String nodeId) => _negativeCounters[nodeId] ?? 0;
  
  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'node_id': _nodeId,
      'positive_counters': _positiveCounters,
      'negative_counters': _negativeCounters,
      'vector_clock': _vectorClock.toJson(),
      'current_value': value,
    };
  }
  
  /// Convert to string representation
  @override
  String toString() {
    return 'PNCounter(value: $value, node: $_nodeId, positive: $_positiveCounters, negative: $_negativeCounters)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PNCounter &&
        other._nodeId == _nodeId &&
        _mapEquals(other._positiveCounters, _positiveCounters) &&
        _mapEquals(other._negativeCounters, _negativeCounters) &&
        other._vectorClock == _vectorClock;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      _nodeId,
      _positiveCounters.entries.fold<int>(0, (hash, entry) => hash ^ Object.hash(entry.key, entry.value)),
      _negativeCounters.entries.fold<int>(0, (hash, entry) => hash ^ Object.hash(entry.key, entry.value)),
      _vectorClock.hashCode,
    );
  }
  
  /// Helper method to compare maps
  bool _mapEquals<K, V>(Map<K, V> map1, Map<K, V> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (map1[key] != map2[key]) return false;
    }
    return true;
  }
  
  /// Get debug information
  String get debugString {
    final positiveSum = _positiveCounters.values.fold<int>(0, (sum, count) => sum + count);
    final negativeSum = _negativeCounters.values.fold<int>(0, (sum, count) => sum + count);
    return 'PNCounter{value: $value, positive_sum: $positiveSum, negative_sum: $negativeSum, '
           'positive: $_positiveCounters, negative: $_negativeCounters, '
           'vector_clock: ${_vectorClock.debugString}}';
  }
}