import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'iras_config.dart';
import 'iras_exceptions.dart';

/// Core IRAS API client with retry logic and error handling
class IrasApiClient {
  final http.Client _httpClient;
  static IrasApiClient? _instance;

  IrasApiClient._({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Singleton instance
  static IrasApiClient get instance {
    _instance ??= IrasApiClient._();
    return _instance!;
  }

  /// Dispose the client
  void dispose() {
    _httpClient.close();
  }

  /// Make authenticated GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    String? accessToken,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final headers = accessToken != null
        ? IrasConfig.getAuthenticatedHeaders(accessToken)
        : IrasConfig.commonHeaders;

    return _executeWithRetry(
      () => _httpClient.get(uri, headers: headers),
      endpoint,
    );
  }

  /// Make authenticated POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    String? accessToken,
  }) async {
    final uri = Uri.parse(endpoint);
    final headers = accessToken != null
        ? IrasConfig.getAuthenticatedHeaders(accessToken)
        : IrasConfig.commonHeaders;

    final body = json.encode(data);

    IrasConfig.logApiCall(endpoint, data);

    return _executeWithRetry(
      () => _httpClient.post(uri, headers: headers, body: body),
      endpoint,
    );
  }

  /// Execute request with retry logic
  Future<Map<String, dynamic>> _executeWithRetry(
    Future<http.Response> Function() request,
    String endpoint,
  ) async {
    int attempts = 0;

    while (attempts < IrasConfig.maxRetries) {
      try {
        final response = await request().timeout(IrasConfig.defaultTimeout);

        IrasConfig.logApiResponse(endpoint, response.statusCode, null);

        if (response.statusCode == 200) {
          final responseData =
              json.decode(response.body) as Map<String, dynamic>;
          IrasConfig.logApiResponse(
              endpoint, response.statusCode, responseData);

          // Check IRAS return code
          if (responseData.containsKey('returnCode')) {
            final returnCode = responseData['returnCode'] as int;
            if (returnCode != 10 && returnCode != 30) {
              // 10 = success, 30 = success with data
              throw IrasApiException(
                'IRAS API returned error code: $returnCode',
                returnCode,
                responseData['info'],
              );
            }
          }

          return responseData;
        } else {
          throw IrasHttpException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}',
            response.statusCode,
          );
        }
      } on SocketException catch (e) {
        IrasConfig.logApiError(endpoint, 'Network error: $e');
        if (attempts == IrasConfig.maxRetries - 1) {
          throw IrasNetworkException('Network connection failed: ${e.message}');
        }
      } on TimeoutException catch (e) {
        IrasConfig.logApiError(endpoint, 'Timeout: $e');
        if (attempts == IrasConfig.maxRetries - 1) {
          throw IrasTimeoutException('Request timeout: ${e.message}');
        }
      } on FormatException catch (e) {
        IrasConfig.logApiError(endpoint, 'JSON parse error: $e');
        throw IrasParseException('Failed to parse response: ${e.message}');
      } on IrasApiException {
        // Don't retry API exceptions (business logic errors)
        rethrow;
      } catch (e) {
        IrasConfig.logApiError(endpoint, 'Unexpected error: $e');
        if (attempts == IrasConfig.maxRetries - 1) {
          throw IrasUnknownException('Unexpected error: $e');
        }
      }

      attempts++;
      if (attempts < IrasConfig.maxRetries) {
        await Future.delayed(IrasConfig.retryDelay * attempts);
      }
    }

    throw IrasUnknownException('Max retries exceeded');
  }

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final uri = Uri.parse(endpoint);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...queryParams,
      });
    }
    return uri;
  }
}

/// HTTP client wrapper for testing
class TestableIrasApiClient extends IrasApiClient {
  TestableIrasApiClient(http.Client httpClient)
      : super._(httpClient: httpClient);
}
