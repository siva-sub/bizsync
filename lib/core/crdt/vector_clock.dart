import 'dart:convert';
import 'dart:math';

/// Vector Clock implementation for tracking causality in distributed systems
class VectorClock {
  final Map<String, int> _clock;
  final String _nodeId;

  VectorClock(this._nodeId) : _clock = {_nodeId: 0};

  VectorClock._(this._nodeId, this._clock);

  /// Create empty vector clock
  VectorClock.empty()
      : _nodeId = '',
        _clock = {};

  /// Create from JSON map
  factory VectorClock.fromJson(Map<String, dynamic> json, String nodeId) {
    final clock = <String, int>{};
    json.forEach((key, value) {
      clock[key] = value as int;
    });

    // Ensure current node exists in clock
    if (!clock.containsKey(nodeId)) {
      clock[nodeId] = 0;
    }

    return VectorClock._(nodeId, clock);
  }

  /// Create from encoded string
  factory VectorClock.fromString(String encoded, String nodeId) {
    if (encoded.isEmpty) {
      return VectorClock(nodeId);
    }

    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      return VectorClock.fromJson(json, nodeId);
    } catch (e) {
      return VectorClock(nodeId);
    }
  }

  /// Create a copy of this vector clock
  VectorClock copy() {
    return VectorClock._(_nodeId, Map<String, int>.from(_clock));
  }

  /// Increment local clock for new event
  VectorClock tick() {
    final newClock = copy();
    newClock._clock[_nodeId] = (_clock[_nodeId] ?? 0) + 1;
    return newClock;
  }

  /// Update clock on receiving message from remote node
  VectorClock update(VectorClock remoteClock) {
    final newClock = copy();

    // Merge all entries from remote clock
    for (final entry in remoteClock._clock.entries) {
      final nodeId = entry.key;
      final remoteTime = entry.value;
      final localTime = newClock._clock[nodeId] ?? 0;

      newClock._clock[nodeId] = max(localTime, remoteTime);
    }

    // Increment local counter
    newClock._clock[_nodeId] = (newClock._clock[_nodeId] ?? 0) + 1;

    return newClock;
  }

  /// Get time for specific node
  int getTime(String nodeId) => _clock[nodeId] ?? 0;

  /// Get local time
  int get localTime => _clock[_nodeId] ?? 0;

  /// Get all known nodes
  Set<String> get nodes => _clock.keys.toSet();

  /// Check if this clock happens before another
  bool happensBefore(VectorClock other) {
    bool anyLess = false;

    // Check all nodes in both clocks
    final allNodes = <String>{..._clock.keys, ...other._clock.keys};

    for (final nodeId in allNodes) {
      final thisTime = _clock[nodeId] ?? 0;
      final otherTime = other._clock[nodeId] ?? 0;

      if (thisTime > otherTime) {
        return false; // Not less if any component is greater
      } else if (thisTime < otherTime) {
        anyLess = true;
      }
    }

    return anyLess;
  }

  /// Check if this clock happens after another
  bool happensAfter(VectorClock other) => other.happensBefore(this);

  /// Check if clocks are concurrent (neither happens before the other)
  bool isConcurrentWith(VectorClock other) {
    return !happensBefore(other) && !happensAfter(other) && !equals(other);
  }

  /// Check if clocks are equal
  bool equals(VectorClock other) {
    final allNodes = <String>{..._clock.keys, ...other._clock.keys};

    for (final nodeId in allNodes) {
      final thisTime = _clock[nodeId] ?? 0;
      final otherTime = other._clock[nodeId] ?? 0;

      if (thisTime != otherTime) {
        return false;
      }
    }

    return true;
  }

  /// Check if this clock dominates another (is greater or equal in all components)
  bool dominates(VectorClock other) {
    final allNodes = <String>{..._clock.keys, ...other._clock.keys};

    for (final nodeId in allNodes) {
      final thisTime = _clock[nodeId] ?? 0;
      final otherTime = other._clock[nodeId] ?? 0;

      if (thisTime < otherTime) {
        return false;
      }
    }

    return true;
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(_clock);
  }

  /// Encode as string for storage
  @override
  String toString() => jsonEncode(_clock);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VectorClock && equals(other);
  }

  @override
  int get hashCode {
    // Create hash based on all entries
    int hash = 0;
    final sortedEntries = _clock.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedEntries) {
      hash = hash ^ Object.hash(entry.key, entry.value);
    }

    return hash;
  }

  /// Create from device ID
  factory VectorClock.fromDeviceId(String deviceId) {
    return VectorClock(deviceId);
  }

  /// Create from map (for deserialization)
  factory VectorClock.fromMap(Map<String, dynamic> map) {
    final nodeId = map['node_id'] as String? ?? '';
    final clock = Map<String, int>.from(map['clock'] as Map? ?? {});
    return VectorClock._(nodeId, clock);
  }

  /// Convert to map (for serialization)
  Map<String, dynamic> toMap() {
    return {
      'node_id': _nodeId,
      'clock': _clock,
    };
  }

  /// Update with another node's time (creates new VectorClock)
  VectorClock updateNode(String nodeId, int time) {
    final newClock = copy();
    newClock._clock[nodeId] = time;
    return newClock;
  }

  /// Tick for a specific node (creates new VectorClock)
  VectorClock tickNode(String nodeId) {
    final newClock = copy();
    newClock._clock[nodeId] = (newClock._clock[nodeId] ?? 0) + 1;
    return newClock;
  }

  /// Get summary string for debugging
  String get debugString {
    final sortedEntries = _clock.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final parts = sortedEntries.map((e) => '${e.key}:${e.value}').toList();
    return '{${parts.join(', ')}}';
  }
}

/// Represents a versioned value with vector clock
class VersionedValue<T> {
  final T value;
  final VectorClock version;
  final DateTime timestamp;

  const VersionedValue(this.value, this.version, this.timestamp);

  /// Create from JSON
  factory VersionedValue.fromJson(
    Map<String, dynamic> json,
    String nodeId,
    T Function(dynamic) valueFromJson,
  ) {
    return VersionedValue(
      valueFromJson(json['value']),
      VectorClock.fromJson(json['version'] as Map<String, dynamic>, nodeId),
      DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson(dynamic Function(T) valueToJson) {
    return {
      'value': valueToJson(value),
      'version': version.toJson(),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VersionedValue<T> &&
        other.value == value &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(value, version);
}
