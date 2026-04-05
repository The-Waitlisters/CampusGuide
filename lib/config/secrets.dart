import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  static String get directionsApiKey =>
      dotenv.env['DIRECTIONS_API_KEY'] ?? '';

  static String get concordiaUserId =>
      dotenv.env['CONCORDIA_USER_ID'] ?? '';

  static String get concordiaApiKey =>
      dotenv.env['CONCORDIA_API_KEY'] ?? '';
}