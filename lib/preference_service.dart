import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PreferenceService {
  static const _preferencesUrl = 'https://soomtrip-api.cspc.me/preferences';

  static Future<void> save(Map<String, dynamic> preferences) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http
        .post(
          Uri.parse(_preferencesUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode(preferences),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('취향 저장 실패 (${response.statusCode})');
    }
  }
}
