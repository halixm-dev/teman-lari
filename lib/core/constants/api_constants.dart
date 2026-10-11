class ApiConstants {
  static const String stravaClientId = String.fromEnvironment(
    'STRAVA_CLIENT_ID',
    defaultValue: '245641',
  );
  static const String stravaClientSecret = String.fromEnvironment(
    'STRAVA_CLIENT_SECRET',
    defaultValue: 'ee210eb8a43b7c429b498c7dbda65f97ea250060',
  );
  static const String stravaRedirectUri = String.fromEnvironment(
    'STRAVA_REDIRECT_URI',
    defaultValue: 'dev.halixm.temanlari://temanlari.vercel.app',
  );

  static const String stravaAccessToken = String.fromEnvironment(
    'STRAVA_ACCESS_TOKEN',
    defaultValue: '',
  );
  static const String stravaRefreshToken = String.fromEnvironment(
    'STRAVA_REFRESH_TOKEN',
    defaultValue: '',
  );

  static const String stravaBaseUrl = 'https://www.strava.com/api/v3';
  static const String stravaAuthUrl = 'https://www.strava.com/oauth/authorize';
  static const String stravaTokenUrl = 'https://www.strava.com/oauth/token';
}
