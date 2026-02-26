import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:proj/services/concordia_api.dart';

String _joinPath(String a, String b) {
  if (a.endsWith(Platform.pathSeparator)) {
    return '$a$b';
  }
  return '$a${Platform.pathSeparator}$b';
}

String _findProjectRoot() {
  var dir = Directory.current;

  while (true) {
    final pubspec = File(_joinPath(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      return dir.path;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }

  throw Exception('Could not locate pubspec.yaml from ${Directory.current.path}');
}

void main() {
  setUpAll(() async {
    final root = _findProjectRoot();
    final envPath = _joinPath(root, '.env');

    final envFile = File(envPath);
    if (!envFile.existsSync()) {
      throw Exception('.env not found at: $envPath');
    }

    final contents = envFile.readAsStringSync();
    dotenv.testLoad(fileInput: contents);
  });

  test('Concordia API returns schedule data for SOEN 343', () async {
    final userId = dotenv.env['CONCORDIA_USER_ID'];
    final apiKey = dotenv.env['CONCORDIA_API_KEY'];

    expect(userId, isNotNull);
    expect(apiKey, isNotNull);

    final service = ConcordiaApiService(
      userId: userId!,
      apiKey: apiKey!,
    );

    final result = await service.fetchSchedule(
      subject: 'SOEN',
      catalog: '343',
    );

    expect(result, isNotEmpty);
  });

  test('throws if credentials are missing', () async {
    final service = ConcordiaApiService(
      userId: '',
      apiKey: '',
    );

    expect(
          () => service.fetchSchedule(subject: 'COMP', catalog: '248'),
      throwsException,
    );
  });

  test('throws on non-200 response', () async {
    final mockClient = MockClient((request) async {
      return http.Response('failure', 500);
    });

    final service = ConcordiaApiService(
      userId: 'abc',
      apiKey: 'xyz',
      client: mockClient,
    );

    expect(
          () => service.fetchSchedule(subject: 'COMP', catalog: '248'),
      throwsException,
    );
  });
}