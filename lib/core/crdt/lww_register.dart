import 'hybrid_logical_clock.dart';

/// Last-Write-Wins Register CRDT
/// This implementation resolves conflicts by choosing the value with the latest timestamp
class LWWRegister<T> {
  T _value;
  HLCTimestamp _timestamp;
  
  LWWRegister(this._value, this._timestamp);
  
  /// Create a new LWWRegister with current timestamp
  LWWRegister.now(T value, String nodeId) 
      : _value = value,
        _timestamp = HLCTimestamp.now(nodeId);
  
  /// Get the current value
  T get value => _value;
  
  /// Get the timestamp of the current value
  HLCTimestamp get timestamp => _timestamp;
  
  /// Set a new value with the given timestamp
  void setValue(T newValue, HLCTimestamp newTimestamp) {
    if (newTimestamp.compareTo(_timestamp) > 0) {
      _value = newValue;
      _timestamp = newTimestamp;
    }
  }
  
  /// Set a new value with current timestamp
  void setValueNow(T newValue, String nodeId) {
    final newTimestamp = HLCTimestamp.now(nodeId);
    setValue(newValue, newTimestamp);
  }
  
  /// Merge with another LWWRegister (last-write-wins)
  void mergeWith(LWWRegister<T> other) {
    if (other._timestamp.compareTo(_timestamp) > 0) {
      _value = other._value;
      _timestamp = other._timestamp;
    }
  }
  
  /// Create a copy of this register
  LWWRegister<T> copy() {
    return LWWRegister<T>(_value, _timestamp);
  }
  
  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'value': _value,
      'timestamp': _timestamp.toString(),
    };
  }
  
  /// Create from JSON map
  static LWWRegister<T> fromJson<T>(Map<String, dynamic> json) {
    return LWWRegister<T>(
      json['value'] as T,
      HLCTimestamp.parse(json['timestamp'] as String),
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LWWRegister<T> &&
        other._value == _value &&
        other._timestamp == _timestamp;
  }
  
  @override
  int get hashCode => Object.hash(_value, _timestamp);
  
  @override
  String toString() {
    return 'LWWRegister(value: $_value, timestamp: $_timestamp)';
  }
}