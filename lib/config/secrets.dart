class Secrets {
  static String directionsApiKey = const String.fromEnvironment(
    'DIRECTIONS_API_KEY',
    defaultValue: '',
  );
}