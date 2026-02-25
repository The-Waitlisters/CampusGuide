class Secrets {
  static const directionsApiKey = String.fromEnvironment(
    'DIRECTIONS_API_KEY',
    defaultValue: '',
  );
}