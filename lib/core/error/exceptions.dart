// Custom exceptions for BizSync app

class BizSyncException implements Exception {
  final String message;
  final String? code;

  const BizSyncException(this.message, {this.code});

  @override
  String toString() =>
      'BizSyncException: $message${code != null ? ' (Code: $code)' : ''}';
}

class DatabaseException extends BizSyncException {
  const DatabaseException(String message, {String? code})
      : super(message, code: code);
}

class EncryptionException extends BizSyncException {
  const EncryptionException(String message, {String? code})
      : super(message, code: code);
}

class P2PException extends BizSyncException {
  const P2PException(String message, {String? code})
      : super(message, code: code);
}

class ValidationException extends BizSyncException {
  const ValidationException(String message, {String? code})
      : super(message, code: code);
}

class NetworkException extends BizSyncException {
  const NetworkException(String message, {String? code})
      : super(message, code: code);
}

class StorageException extends BizSyncException {
  const StorageException(String message, {String? code})
      : super(message, code: code);
}
