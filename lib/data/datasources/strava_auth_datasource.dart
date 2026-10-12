import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../models/strava_tokens.dart';

class StravaAuthDataSource {
  final http.Client _httpClient;

  StravaAuthDataSource(this._httpClient);

  Future<StravaTokens> authenticate() async {
    final redirectUri = kIsWeb
        ? (kDebugMode ? Uri.base.origin : 'https://temanlari.halixm.dev')
        : ApiConstants.stravaRedirectUri;
    final callbackScheme = kIsWeb ? 'http' : 'dev.halixm.temanlari';

    final authUrl = Uri.https('www.strava.com', '/oauth/authorize', {
      'client_id': ApiConstants.stravaClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'activity:read,activity:read_all,activity:write',
      'approval_prompt': 'auto',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: callbackScheme,
    ).timeout(const Duration(seconds: 120));

    final code = Uri.parse(result).queryParameters['code']!;

    final response = await _httpClient.post(
      Uri.parse(ApiConstants.stravaTokenUrl),
      body: {
        'client_id': ApiConstants.stravaClientId,
        'client_secret': ApiConstants.stravaClientSecret,
        'code': code,
        'grant_type': 'authorization_code',
      },
    );

    final json = jsonDecode(response.body);
    return StravaTokens.fromJson(json);
  }

  Future<StravaTokens> refreshToken(String refreshToken) async {
    final response = await _httpClient.post(
      Uri.parse(ApiConstants.stravaTokenUrl),
      body: {
        'client_id': ApiConstants.stravaClientId,
        'client_secret': ApiConstants.stravaClientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );
    return StravaTokens.fromJson(jsonDecode(response.body));
  }
}
