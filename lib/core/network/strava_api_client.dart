import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import '../../data/datasources/strava_auth_datasource.dart';
import '../../data/datasources/token_storage.dart';
import '../errors/error_formatter.dart';
import '../errors/exceptions.dart';
import 'rate_limiter.dart';

class StravaApiClient {
  final TokenStorage _tokenStorage;
  final StravaAuthDataSource _authDataSource;
  final http.Client _httpClient;
  final RateLimiter _rateLimiter = RateLimiter();
  Future<void>? _refreshTokenFuture;

  StravaApiClient(this._tokenStorage, this._authDataSource, this._httpClient);

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    log('Strava API GET: $endpoint', name: 'StravaApiClient');
    await _rateLimiter.checkAndWait();
    final response = await _requestWithRetry(() async {
      final token = await _getValidToken();
      final uri = Uri.https('www.strava.com', '/api/v3/$endpoint', params);

      final response = await _httpClient.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      return response;
    });

    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getList(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    log('Strava API GET List: $endpoint', name: 'StravaApiClient');
    await _rateLimiter.checkAndWait();
    final response = await _requestWithRetry(() async {
      final token = await _getValidToken();
      final uri = Uri.https('www.strava.com', '/api/v3/$endpoint', params);

      return await _httpClient.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
    });

    return jsonDecode(response.body) as List;
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    log('Strava API POST: $endpoint', name: 'StravaApiClient');
    await _rateLimiter.checkAndWait();
    final response = await _requestWithRetry(() async {
      final token = await _getValidToken();
      final uri = Uri.https('www.strava.com', '/api/v3/$endpoint');

      return await _httpClient.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body ?? {}),
      );
    });

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    var response = await request();

    if (response.statusCode == 429) {
      log(
        'Rate limit reached on request',
        name: 'StravaApiClient',
        error: '429',
      );
      throw StravaApiException(
        429,
        'Rate limit reached, try again in 15 minutes',
      );
    }

    if (response.statusCode == 401) {
      // Token might be invalid despite our local expiration check
      await _forceRefreshToken();
      response = await request();
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (response.body.contains('Authorization Error') ||
          response.body.contains('read_permission')) {
        await _tokenStorage.clearTokens();
        throw UnauthenticatedException();
      }
    }

    final formattedMessage = AppErrorFormatter.formatMessage(
      response.body,
      statusCode: response.statusCode,
    );
    throw StravaApiException(response.statusCode, formattedMessage);
  }

  Future<void> _forceRefreshToken() {
    final existingFuture = _refreshTokenFuture;
    if (existingFuture != null) return existingFuture;

    final newFuture = _performTokenRefresh().whenComplete(() {
      _refreshTokenFuture = null;
    });
    _refreshTokenFuture = newFuture;
    return newFuture;
  }

  Future<void> _performTokenRefresh() async {
    var tokens = await _tokenStorage.getTokens();
    if (tokens == null) throw UnauthenticatedException();

    try {
      tokens = await _authDataSource.refreshToken(tokens.refreshToken);
      await _tokenStorage.saveTokens(tokens);
      log('Token refresh successful', name: 'StravaApiClient');
    } catch (e) {
      log('Token refresh failed', name: 'StravaApiClient', error: e);
      await _tokenStorage.clearTokens();
      throw UnauthenticatedException();
    }
  }

  Future<String> _getValidToken() async {
    var tokens = await _tokenStorage.getTokens();
    if (tokens == null) throw UnauthenticatedException();

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (tokens.expiresAt - now < 60) {
      tokens = await _authDataSource.refreshToken(tokens.refreshToken);
      await _tokenStorage.saveTokens(tokens);
    }

    return tokens.accessToken;
  }
}
