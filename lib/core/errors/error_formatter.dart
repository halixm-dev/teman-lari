import 'dart:convert';

import 'exceptions.dart';
import 'failures.dart';

class AppErrorFormatter {
  /// Formats an arbitrary [error] into a clean, human-readable string suitable for display.
  static String format(Object error) {
    if (error is StravaApiException) {
      return formatMessage(error.message, statusCode: error.statusCode);
    }
    if (error is Failure) {
      return formatMessage(error.message, statusCode: error.statusCode);
    }
    return formatMessage(error.toString());
  }

  /// Parses and cleans up raw error messages, especially JSON payloads returned by APIs.
  static String formatMessage(String rawMessage, {int? statusCode}) {
    var message = rawMessage.trim();

    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }

    if (message.contains('"resource":"Application"') &&
        message.contains('"code":"Inactive"')) {
      return 'Strava application is inactive. Please check your Strava developer settings.';
    }

    try {
      if ((message.startsWith('{') && message.endsWith('}')) ||
          (message.startsWith('[') && message.endsWith(']'))) {
        final decoded = jsonDecode(message);
        if (decoded is Map<String, dynamic>) {
          final errors = decoded['errors'];
          if (errors is List && errors.isNotEmpty) {
            final first = errors.first;
            if (first is Map<String, dynamic>) {
              final resource = first['resource'];
              final field = first['field'];
              final code = first['code'];
              if (resource == 'Application' &&
                  field == 'Status' &&
                  code == 'Inactive') {
                return 'Strava application is inactive. Please check your Strava developer settings.';
              }
            }
          }
          if (decoded['message'] is String &&
              (decoded['message'] as String).isNotEmpty) {
            final decodedMsg = decoded['message'] as String;
            if (decodedMsg == 'Forbidden' && statusCode == 403) {
              return 'Access forbidden (403). Please verify your Strava integration permissions.';
            }
            return decodedMsg;
          }
        }
      }
    } catch (_) {
      // Fallback
    }

    if (statusCode == 403) {
      return 'Access forbidden (403). Please verify your Strava integration permissions.';
    }
    if (statusCode == 401) {
      return 'Authentication expired. Please reconnect your Strava account.';
    }
    if (statusCode == 429) {
      return 'Rate limit reached, try again in 15 minutes.';
    }

    return message;
  }
}
