/// Base exception for all IRAS API related errors
abstract class IrasException implements Exception {
  final String message;
  final dynamic details;

  const IrasException(this.message, [this.details]);

  @override
  String toString() =>
      'IrasException: $message${details != null ? ' - $details' : ''}';
}

/// Exception for IRAS API business logic errors (non-success return codes)
class IrasApiException extends IrasException {
  final int returnCode;
  final Map<String, dynamic>? info;

  const IrasApiException(super.message, this.returnCode, [this.info]) : super();

  /// Extract field-specific error messages
  List<String> get fieldErrors {
    if (info?['fieldInfoList'] is List) {
      return (info!['fieldInfoList'] as List)
          .map((field) => '${field['field']}: ${field['message']}')
          .toList()
          .cast<String>();
    }
    return [];
  }

  /// Get user-friendly error message
  String get userFriendlyMessage {
    if (info?['message'] is String) {
      return info!['message'] as String;
    }
    return message;
  }

  @override
  String toString() =>
      'IrasApiException: $message (Return Code: $returnCode)${fieldErrors.isNotEmpty ? ' - Fields: ${fieldErrors.join(', ')}' : ''}';
}

/// Exception for HTTP transport errors
class IrasHttpException extends IrasException {
  final int statusCode;

  const IrasHttpException(super.message, this.statusCode) : super();

  @override
  String toString() => 'IrasHttpException: $message (Status: $statusCode)';
}

/// Exception for network connectivity issues
class IrasNetworkException extends IrasException {
  const IrasNetworkException(super.message) : super();

  @override
  String toString() => 'IrasNetworkException: $message';
}

/// Exception for request timeouts
class IrasTimeoutException extends IrasException {
  const IrasTimeoutException(super.message) : super();

  @override
  String toString() => 'IrasTimeoutException: $message';
}

/// Exception for response parsing errors
class IrasParseException extends IrasException {
  const IrasParseException(super.message) : super();

  @override
  String toString() => 'IrasParseException: $message';
}

/// Exception for authentication/authorization errors
class IrasAuthException extends IrasException {
  const IrasAuthException(super.message) : super();

  @override
  String toString() => 'IrasAuthException: $message';
}

/// Exception for configuration errors
class IrasConfigException extends IrasException {
  const IrasConfigException(super.message) : super();

  @override
  String toString() => 'IrasConfigException: $message';
}

/// Exception for validation errors
class IrasValidationException extends IrasException {
  final Map<String, List<String>> fieldErrors;

  const IrasValidationException(super.message, this.fieldErrors) : super();

  @override
  String toString() =>
      'IrasValidationException: $message - Fields: ${fieldErrors.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('; ')}';
}

/// Exception for unknown/unexpected errors
class IrasUnknownException extends IrasException {
  const IrasUnknownException(super.message) : super();

  @override
  String toString() => 'IrasUnknownException: $message';
}
