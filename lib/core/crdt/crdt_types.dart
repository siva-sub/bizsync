import 'hybrid_logical_clock.dart';
import 'vector_clock.dart';

/// Simple CRDT register that holds a value with timestamp
class CRDTRegister<T> {
  T _value;
  HLCTimestamp _timestamp;
  
  CRDTRegister(this._value, this._timestamp);
  
  T get value => _value;
  HLCTimestamp get timestamp => _timestamp;
  
  void setValue(T newValue, HLCTimestamp newTimestamp) {
    if (newTimestamp.compareTo(_timestamp) > 0) {
      _value = newValue;
      _timestamp = newTimestamp;
    }
  }
  
  void mergeWith(CRDTRegister<T> other) {
    if (other._timestamp.compareTo(_timestamp) > 0) {
      _value = other._value;
      _timestamp = other._timestamp;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'value': _value,
      'timestamp': _timestamp.toString(),
    };
  }
  
  static CRDTRegister<T> fromJson<T>(Map<String, dynamic> json) {
    return CRDTRegister<T>(
      json['value'] as T,
      HLCTimestamp.parse(json['timestamp'] as String),
    );
  }
}

/// Simple CRDT counter that can increment/decrement
class CRDTCounter {
  int _value;
  
  CRDTCounter(this._value);
  
  int get value => _value;
  
  void increment([int amount = 1]) {
    _value += amount;
  }
  
  void decrement([int amount = 1]) {
    _value -= amount;
  }
  
  void mergeWith(CRDTCounter other) {
    // Simple merge - take the maximum value (for demo purposes)
    _value = _value > other._value ? _value : other._value;
  }
  
  Map<String, dynamic> toJson() {
    return {'value': _value};
  }
  
  static CRDTCounter fromJson(Map<String, dynamic> json) {
    return CRDTCounter(json['value'] as int);
  }
}

/// Type alias for backward compatibility
typedef CRDTVectorClock = VectorClock;