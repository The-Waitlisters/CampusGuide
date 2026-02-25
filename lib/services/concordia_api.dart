import 'dart:convert';
import 'package:http/http.dart' as http;

class ConcordiaApiService {
  final String userId;
  final String apiKey;

  ConcordiaApiService({
    required this.userId,
    required this.apiKey,
  });

  Future<List<dynamic>> fetchSchedule({
    required String subject,
    required String catalog,
  }) async {
    if (userId.isEmpty || apiKey.isEmpty) {
      throw Exception('Concordia API credentials missing.');
    }

    final auth = base64Encode(utf8.encode('$userId:$apiKey'));

    final uri = Uri.parse(
      'https://opendata.concordia.ca/API/v1/course/schedule/filter/*/$subject/$catalog',
    );

    final response = await http.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Basic $auth',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('OpenData error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);

    return decoded as List<dynamic>;
  }
}