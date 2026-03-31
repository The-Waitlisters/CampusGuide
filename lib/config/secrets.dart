class Secrets {
  static String directionsApiKey = const String.fromEnvironment(
    'DIRECTIONS_API_KEY',
    defaultValue: '',
  );

  static const concordiaUserId = String.fromEnvironment(
    'CONCORDIA_USER_ID',
    defaultValue: '',
  );

  static const concordiaApiKey = String.fromEnvironment(
    'CONCORDIA_API_KEY',
    defaultValue: '',
  );
}