import 'package:json_annotation/json_annotation.dart';

part 'singpass_auth_models.g.dart';

/// SingPass Authentication API models based on SingPass_Authentication-apigw-2.0.1.yaml
/// This implements the exact structure from the IRAS API specification

/// SingPass Authorization Request parameters
@JsonSerializable()
class SingPassAuthRequest {
  final String? scope;
  final String callbackUrl;
  final String? state;

  const SingPassAuthRequest({
    this.scope,
    required this.callbackUrl,
    this.state,
  });

  factory SingPassAuthRequest.fromJson(Map<String, dynamic> json) =>
      _$SingPassAuthRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassAuthRequestToJson(this);
  
  /// Convert to query parameters for GET request
  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'callback_url': callbackUrl,
    };
    
    if (scope != null) params['scope'] = scope!;
    if (state != null) params['state'] = state!;
    
    return params;
  }
}

/// SingPass Authorization Response
@JsonSerializable()
class SingPassAuthResponse {
  final int returnCode;
  final SingPassAuthData? data;
  final SingPassAuthInfo? info;

  const SingPassAuthResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  /// Check if the response indicates success
  bool get isSuccess => returnCode == 10 || returnCode == 200;

  factory SingPassAuthResponse.fromJson(Map<String, dynamic> json) =>
      _$SingPassAuthResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassAuthResponseToJson(this);
}

/// SingPass Authorization Data
@JsonSerializable()
class SingPassAuthData {
  final String? authUrl;
  final String? authorizationCode;
  final String? state;

  const SingPassAuthData({
    this.authUrl,
    this.authorizationCode,
    this.state,
  });

  factory SingPassAuthData.fromJson(Map<String, dynamic> json) =>
      _$SingPassAuthDataFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassAuthDataToJson(this);
}

/// SingPass Token Request
@JsonSerializable()
class SingPassTokenRequest {
  final String authorizationCode;
  final String? state;

  const SingPassTokenRequest({
    required this.authorizationCode,
    this.state,
  });

  factory SingPassTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$SingPassTokenRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassTokenRequestToJson(this);
}

/// SingPass Token Response
@JsonSerializable()
class SingPassTokenResponse {
  final int returnCode;
  final SingPassTokenData? data;
  final SingPassAuthInfo? info;

  const SingPassTokenResponse({
    required this.returnCode,
    this.data,
    this.info,
  });

  /// Check if the response indicates success
  bool get isSuccess => returnCode == 10 || returnCode == 200;

  factory SingPassTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$SingPassTokenResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassTokenResponseToJson(this);
}

/// SingPass Token Data
@JsonSerializable()
class SingPassTokenData {
  final String? token;
  final String? code;
  final int? expiresIn;
  final String? tokenType;
  final String? refreshToken;

  const SingPassTokenData({
    this.token,
    this.code,
    this.expiresIn,
    this.tokenType,
    this.refreshToken,
  });

  factory SingPassTokenData.fromJson(Map<String, dynamic> json) =>
      _$SingPassTokenDataFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassTokenDataToJson(this);
}

/// SingPass Authentication Error Information
@JsonSerializable()
class SingPassAuthInfo {
  final String? message;
  final int? messageCode;
  final List<SingPassFieldInfo>? fieldInfoList;

  const SingPassAuthInfo({
    this.message,
    this.messageCode,
    this.fieldInfoList,
  });

  factory SingPassAuthInfo.fromJson(Map<String, dynamic> json) =>
      _$SingPassAuthInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassAuthInfoToJson(this);
}

/// Field-level error information
@JsonSerializable()
class SingPassFieldInfo {
  final String? field;
  final String? message;

  const SingPassFieldInfo({
    this.field,
    this.message,
  });

  factory SingPassFieldInfo.fromJson(Map<String, dynamic> json) =>
      _$SingPassFieldInfoFromJson(json);

  Map<String, dynamic> toJson() => _$SingPassFieldInfoToJson(this);
}

/// Authentication state for managing the flow
class SingPassAuthState {
  final String state;
  final String callbackUrl;
  final String? scope;
  final DateTime createdAt;
  final String? authorizationCode;
  final String? accessToken;
  final DateTime? tokenExpiry;

  SingPassAuthState({
    required this.state,
    required this.callbackUrl,
    this.scope,
    required this.createdAt,
    this.authorizationCode,
    this.accessToken,
    this.tokenExpiry,
  });

  /// Check if the access token is still valid
  bool get isTokenValid {
    if (accessToken == null || tokenExpiry == null) return false;
    return DateTime.now().isBefore(tokenExpiry!);
  }

  /// Check if the auth state has expired (default 10 minutes)
  bool get hasExpired {
    final expiry = createdAt.add(const Duration(minutes: 10));
    return DateTime.now().isAfter(expiry);
  }

  /// Create a copy with updated fields
  SingPassAuthState copyWith({
    String? authorizationCode,
    String? accessToken,
    DateTime? tokenExpiry,
  }) {
    return SingPassAuthState(
      state: state,
      callbackUrl: callbackUrl,
      scope: scope,
      createdAt: createdAt,
      authorizationCode: authorizationCode ?? this.authorizationCode,
      accessToken: accessToken ?? this.accessToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
    );
  }
}

/// SingPass Authentication scopes
enum SingPassScope {
  profile('profile'),
  email('email'),
  phone('phone'),
  corppass('corppass');

  const SingPassScope(this.value);
  final String value;

  @override
  String toString() => value;
}

/// Factory methods for creating sample requests
SingPassAuthRequest createSampleAuthRequest({
  required String callbackUrl,
  String? state,
}) {
  return SingPassAuthRequest(
    scope: SingPassScope.corppass.value,
    callbackUrl: callbackUrl,
    state: state ?? 'sample_state_${DateTime.now().millisecondsSinceEpoch}',
  );
}

SingPassTokenRequest createSampleTokenRequest({
  required String authorizationCode,
  String? state,
}) {
  return SingPassTokenRequest(
    authorizationCode: authorizationCode,
    state: state,
  );
}