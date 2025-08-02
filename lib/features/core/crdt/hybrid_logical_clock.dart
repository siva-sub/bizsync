import 'dart:convert';

/// Hybrid Logical Clock implementation for CRDT systems
/// Combines physical time with logical counter for total ordering
class HybridLogicalClock {
  static const int _maxLogicalTime = 0xFFFF; // 16-bit counter
  
  late int _physicalTime;
  late int _logicalTime;
  late String _nodeId;
  
  HybridLogicalClock(String nodeId) {
    _nodeId = nodeId;
    _physicalTime = DateTime.now().millisecondsSinceEpoch;
    _logicalTime = 0;
  }
  
  HybridLogicalClock.fromTimestamp(int physicalTime, int logicalTime, String nodeId) {
    _physicalTime = physicalTime;
    _logicalTime = logicalTime;
    _nodeId = nodeId;
  }
  
  /// Generate next timestamp for local event
  HLCTimestamp tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (now > _physicalTime) {
      _physicalTime = now;
      _logicalTime = 0;
    } else {
      _logicalTime = (_logicalTime + 1) % _maxLogicalTime;
    }
    
    return HLCTimestamp(_physicalTime, _logicalTime, _nodeId);
  }
  
  /// Update clock on receiving remote timestamp
  HLCTimestamp update(HLCTimestamp remoteTimestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxPhysical = [now, _physicalTime, remoteTimestamp.physicalTime].reduce((a, b) => a > b ? a : b);
    
    if (maxPhysical == now && now > _physicalTime && now > remoteTimestamp.physicalTime) {
      _physicalTime = now;
      _logicalTime = 0;
    } else if (maxPhysical == _physicalTime && _physicalTime > remoteTimestamp.physicalTime) {
      _logicalTime = (_logicalTime + 1) % _maxLogicalTime;
    } else if (maxPhysical == remoteTimestamp.physicalTime && remoteTimestamp.physicalTime > _physicalTime) {
      _physicalTime = remoteTimestamp.physicalTime;
      _logicalTime = (remoteTimestamp.logicalTime + 1) % _maxLogicalTime;
    } else {
      // All physical times are equal
      _physicalTime = maxPhysical;
      _logicalTime = ([_logicalTime, remoteTimestamp.logicalTime].reduce((a, b) => a > b ? a : b) + 1) % _maxLogicalTime;
    }
    
    return HLCTimestamp(_physicalTime, _logicalTime, _nodeId);
  }
  
  /// Current timestamp without advancing
  HLCTimestamp get current => HLCTimestamp(_physicalTime, _logicalTime, _nodeId);
  
  String get nodeId => _nodeId;
}

/// Represents a point in time with hybrid logical clock
class HLCTimestamp implements Comparable<HLCTimestamp> {
  final int physicalTime;
  final int logicalTime;
  final String nodeId;
  
  const HLCTimestamp(this.physicalTime, this.logicalTime, this.nodeId);
  
  /// Create a new timestamp with current time
  static HLCTimestamp now(String nodeId) {
    return HLCTimestamp(DateTime.now().millisecondsSinceEpoch, 0, nodeId);
  }
  
  /// Parse from string representation
  static HLCTimestamp parse(String str) {
    return HLCTimestamp.fromString(str);
  }
  
  /// Create from encoded string
  factory HLCTimestamp.fromString(String encoded) {
    final parts = encoded.split(':');
    if (parts.length != 3) {
      throw ArgumentError('Invalid HLC timestamp format');
    }
    
    return HLCTimestamp(
      int.parse(parts[0]),
      int.parse(parts[1]),
      parts[2],
    );
  }
  
  /// Create from JSON map
  factory HLCTimestamp.fromJson(Map<String, dynamic> json) {
    return HLCTimestamp(
      json['physical_time'] as int,
      json['logical_time'] as int,
      json['node_id'] as String,
    );
  }
  
  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'physical_time': physicalTime,
      'logical_time': logicalTime,
      'node_id': nodeId,
    };
  }
  
  /// Encode as string for storage
  @override
  String toString() => '$physicalTime:$logicalTime:$nodeId';
  
  /// Compare timestamps for total ordering
  @override
  int compareTo(HLCTimestamp other) {
    // First compare physical time
    if (physicalTime != other.physicalTime) {
      return physicalTime.compareTo(other.physicalTime);
    }
    
    // Then logical time
    if (logicalTime != other.logicalTime) {
      return logicalTime.compareTo(other.logicalTime);
    }
    
    // Finally node ID for deterministic ordering
    return nodeId.compareTo(other.nodeId);
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HLCTimestamp &&
        other.physicalTime == physicalTime &&
        other.logicalTime == logicalTime &&
        other.nodeId == nodeId;
  }
  
  @override
  int get hashCode => Object.hash(physicalTime, logicalTime, nodeId);
  
  /// Check if this timestamp happens before another
  bool happensBefore(HLCTimestamp other) => compareTo(other) < 0;
  
  /// Check if this timestamp happens after another
  bool happensAfter(HLCTimestamp other) => compareTo(other) > 0;
  
  /// Check if timestamps are concurrent (cannot be ordered)
  bool isConcurrentWith(HLCTimestamp other) {
    // In HLC, all events can be totally ordered
    return false;
  }
}