import 'package:uuid/uuid.dart';

class UuidGenerator {
  static const Uuid _uuid = Uuid();
  
  /// Generate a unique ID for database records
  static String generateId() {
    return _uuid.v4();
  }
  
  /// Generate a timestamp-based UUID (v1)
  static String generateTimeBasedId() {
    return _uuid.v1();
  }
  
  /// Generate a name-based UUID (v5) using namespace and name
  static String generateNameBasedId(String namespace, String name) {
    return _uuid.v5(namespace, name);
  }
  
  /// Check if a string is a valid UUID
  static bool isValidUuid(String uuid) {
    try {
      return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', 
                   caseSensitive: false).hasMatch(uuid);
    } catch (e) {
      return false;
    }
  }
}