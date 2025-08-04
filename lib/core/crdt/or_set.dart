import 'vector_clock.dart';

/// Observed-Remove Set CRDT
/// A state-based CRDT that supports add and remove operations on sets
/// Uses unique tags to track when elements were added and removed
class ORSet<T> {
  final Map<T, Set<String>>
      _elements; // element -> set of unique tags that added it
  final Set<String> _removedTags; // tags of elements that have been removed
  final String _nodeId;
  late VectorClock _vectorClock;
  int _tagCounter = 0;

  ORSet(this._nodeId)
      : _elements = {},
        _removedTags = {} {
    _vectorClock = VectorClock(_nodeId);
  }

  ORSet._(this._nodeId, this._elements, this._removedTags, this._vectorClock,
      this._tagCounter);

  /// Create from JSON map
  factory ORSet.fromJson(Map<String, dynamic> json) {
    final nodeId = json['node_id'] as String;
    final tagCounter = json['tag_counter'] as int? ?? 0;
    final removedTags = Set<String>.from(json['removed_tags'] as List);
    final vectorClock = VectorClock.fromJson(
        json['vector_clock'] as Map<String, dynamic>, nodeId);

    final elements = <T, Set<String>>{};
    final elementsJson = json['elements'] as Map<String, dynamic>;
    elementsJson.forEach((key, value) {
      // Assuming T can be reconstructed from string representation
      final element = _parseElement<T>(key);
      final tags = Set<String>.from(value as List);
      elements[element] = tags;
    });

    return ORSet._(nodeId, elements, removedTags, vectorClock, tagCounter);
  }

  /// Helper method to parse element from string representation
  static T _parseElement<T>(String elementStr) {
    // For most basic types, this works. For complex types, you'd need custom serialization
    if (T == String) return elementStr as T;
    if (T == int) return int.parse(elementStr) as T;
    if (T == double) return double.parse(elementStr) as T;
    if (T == bool) return (elementStr.toLowerCase() == 'true') as T;
    // For other types, assume the string representation is sufficient
    return elementStr as T;
  }

  /// Helper method to convert element to string representation
  String _elementToString(T element) {
    return element.toString();
  }

  /// Get current set of elements (elements with live tags minus removed tags)
  Set<T> get elements {
    final result = <T>{};

    for (final entry in _elements.entries) {
      final element = entry.key;
      final elementTags = entry.value;

      // Element is in the set if it has at least one tag that hasn't been removed
      final liveTags = elementTags.difference(_removedTags);
      if (liveTags.isNotEmpty) {
        result.add(element);
      }
    }

    return result;
  }

  /// Check if set contains an element
  bool contains(T element) {
    final elementTags = _elements[element];
    if (elementTags == null) return false;

    // Element exists if it has at least one live tag
    final liveTags = elementTags.difference(_removedTags);
    return liveTags.isNotEmpty;
  }

  /// Get the size of the set
  int get length => elements.length;

  /// Check if the set is empty
  bool get isEmpty => length == 0;

  /// Check if the set is not empty
  bool get isNotEmpty => length > 0;

  /// Get the vector clock for this set
  VectorClock get vectorClock => _vectorClock;

  /// Get node ID
  String get nodeId => _nodeId;

  /// Add an element to the set
  ORSet<T> add(T element) {
    final newElements = <T, Set<String>>{};
    for (final entry in _elements.entries) {
      newElements[entry.key] = Set<String>.from(entry.value);
    }

    // Create unique tag for this add operation
    final tag =
        '${_nodeId}_${_tagCounter}_${DateTime.now().millisecondsSinceEpoch}';

    final existingTags = newElements[element] ?? <String>{};
    newElements[element] = {...existingTags, tag};

    final newVectorClock = _vectorClock.tick();

    return ORSet._(
      _nodeId,
      newElements,
      Set<String>.from(_removedTags),
      newVectorClock,
      _tagCounter + 1,
    );
  }

  /// Remove an element from the set
  ORSet<T> remove(T element) {
    final elementTags = _elements[element];
    if (elementTags == null) {
      // Element doesn't exist, no change needed
      return copy();
    }

    // Remove all current tags for this element
    final newRemovedTags = Set<String>.from(_removedTags);
    newRemovedTags.addAll(elementTags);

    final newVectorClock = _vectorClock.tick();

    return ORSet._(
      _nodeId,
      <T, Set<String>>{
        for (final entry in _elements.entries)
          entry.key: Set<String>.from(entry.value)
      },
      newRemovedTags,
      newVectorClock,
      _tagCounter,
    );
  }

  /// Add multiple elements to the set
  ORSet<T> addAll(Iterable<T> elements) {
    ORSet<T> result = this;
    for (final element in elements) {
      result = result.add(element);
    }
    return result;
  }

  /// Remove multiple elements from the set
  ORSet<T> removeAll(Iterable<T> elements) {
    ORSet<T> result = this;
    for (final element in elements) {
      result = result.remove(element);
    }
    return result;
  }

  /// Clear all elements from the set
  ORSet<T> clear() {
    final allTags = <String>{};
    for (final tags in _elements.values) {
      allTags.addAll(tags);
    }

    final newRemovedTags = Set<String>.from(_removedTags);
    newRemovedTags.addAll(allTags);

    final newVectorClock = _vectorClock.tick();

    return ORSet._(
      _nodeId,
      <T, Set<String>>{
        for (final entry in _elements.entries)
          entry.key: Set<String>.from(entry.value)
      },
      newRemovedTags,
      newVectorClock,
      _tagCounter,
    );
  }

  /// Merge with another ORSet
  ORSet<T> mergeWith(ORSet<T> other) {
    final mergedElements = <T, Set<String>>{};

    // Merge elements from both sets
    final allElements = <T>{..._elements.keys, ...other._elements.keys};
    for (final element in allElements) {
      final thisTags = _elements[element] ?? <String>{};
      final otherTags = other._elements[element] ?? <String>{};
      mergedElements[element] = {...thisTags, ...otherTags};
    }

    // Merge removed tags
    final mergedRemovedTags = {..._removedTags, ...other._removedTags};

    // Merge vector clocks
    final mergedVectorClock = _vectorClock.update(other._vectorClock);

    // Use the higher tag counter
    final mergedTagCounter =
        _tagCounter > other._tagCounter ? _tagCounter : other._tagCounter;

    return ORSet._(
      _nodeId,
      mergedElements,
      mergedRemovedTags,
      mergedVectorClock,
      mergedTagCounter,
    );
  }

  /// Create a copy of this set
  ORSet<T> copy() {
    return ORSet._(
      _nodeId,
      <T, Set<String>>{
        for (final entry in _elements.entries)
          entry.key: Set<String>.from(entry.value)
      },
      Set<String>.from(_removedTags),
      _vectorClock.copy(),
      _tagCounter,
    );
  }

  /// Union with another set (mathematical union)
  ORSet<T> union(ORSet<T> other) {
    return mergeWith(other);
  }

  /// Intersection with another set (elements present in both)
  Set<T> intersection(ORSet<T> other) {
    final thisElements = elements;
    final otherElements = other.elements;
    return thisElements.intersection(otherElements);
  }

  /// Difference with another set (elements in this but not in other)
  Set<T> difference(ORSet<T> other) {
    final thisElements = elements;
    final otherElements = other.elements;
    return thisElements.difference(otherElements);
  }

  /// Check if this set is a subset of another
  bool isSubsetOf(ORSet<T> other) {
    final thisElements = elements;
    final otherElements = other.elements;
    return thisElements.every((element) => otherElements.contains(element));
  }

  /// Check if this set is a superset of another
  bool isSupersetOf(ORSet<T> other) {
    return other.isSubsetOf(this);
  }

  /// Check if this set can be compared with another (not concurrent)
  bool isComparableWith(ORSet<T> other) {
    return !_vectorClock.isConcurrentWith(other._vectorClock);
  }

  /// Check if this set happens before another
  bool happensBefore(ORSet<T> other) {
    return _vectorClock.happensBefore(other._vectorClock);
  }

  /// Check if this set happens after another
  bool happensAfter(ORSet<T> other) {
    return _vectorClock.happensAfter(other._vectorClock);
  }

  /// Get all known tags for an element (including removed ones)
  Set<String> getTagsForElement(T element) {
    return Set<String>.from(_elements[element] ?? <String>{});
  }

  /// Get all removed tags
  Set<String> get removedTags => Set<String>.from(_removedTags);

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    final elementsJson = <String, dynamic>{};
    _elements.forEach((element, tags) {
      elementsJson[_elementToString(element)] = tags.toList();
    });

    return {
      'node_id': _nodeId,
      'elements': elementsJson,
      'removed_tags': _removedTags.toList(),
      'vector_clock': _vectorClock.toJson(),
      'tag_counter': _tagCounter,
      'current_elements': elements.map(_elementToString).toList(),
    };
  }

  /// Convert to string representation
  @override
  String toString() {
    return 'ORSet(elements: ${elements.toList()}, node: $_nodeId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ORSet<T> &&
        other._nodeId == _nodeId &&
        _mapEquals(other._elements, _elements) &&
        _setEquals(other._removedTags, _removedTags) &&
        other._vectorClock == _vectorClock &&
        other._tagCounter == _tagCounter;
  }

  @override
  int get hashCode {
    return Object.hash(
      _nodeId,
      _elements.entries.fold<int>(
          0,
          (hash, entry) =>
              hash ^
              Object.hash(entry.key,
                  entry.value.fold<int>(0, (h, tag) => h ^ tag.hashCode))),
      _removedTags.fold<int>(0, (hash, tag) => hash ^ tag.hashCode),
      _vectorClock.hashCode,
      _tagCounter,
    );
  }

  /// Helper method to compare maps with set values
  bool _mapEquals<K, V>(Map<K, Set<V>> map1, Map<K, Set<V>> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!_setEquals(map1[key]!, map2[key] ?? <V>{})) return false;
    }
    return true;
  }

  /// Helper method to compare sets
  bool _setEquals<V>(Set<V> set1, Set<V> set2) {
    if (set1.length != set2.length) return false;
    return set1.every((element) => set2.contains(element));
  }

  /// Get debug information
  String get debugString {
    return 'ORSet{current_elements: ${elements.toList()}, '
        'all_elements: $_elements, removed_tags: $_removedTags, '
        'tag_counter: $_tagCounter, vector_clock: ${_vectorClock.debugString}}';
  }

  /// Iterator support
  Iterator<T> get iterator => elements.iterator;

  /// Convert to List for easy iteration
  List<T> toList() => elements.toList();

  /// Convert to regular Dart Set for compatibility
  Set<T> toSet() => Set<T>.from(elements);
}
