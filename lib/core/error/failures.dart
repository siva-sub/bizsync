// Failure classes for error handling with Riverpod

abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => message.hashCode ^ code.hashCode;

  @override
  String toString() =>
      '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(String message, {String? code})
      : super(message, code: code);
}

class EncryptionFailure extends Failure {
  const EncryptionFailure(String message, {String? code})
      : super(message, code: code);
}

class P2PFailure extends Failure {
  const P2PFailure(String message, {String? code}) : super(message, code: code);
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message, {String? code})
      : super(message, code: code);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, {String? code})
      : super(message, code: code);
}

class StorageFailure extends Failure {
  const StorageFailure(String message, {String? code})
      : super(message, code: code);
}

class UnknownFailure extends Failure {
  const UnknownFailure(String message, {String? code})
      : super(message, code: code);
}
