import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PreferenceService {
  static const _preferencesUrl = 'https://soomtrip-api.cspc.me/preferences';

  static Future<int> save(Map<String, dynamic> preferences) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final requestBody = jsonEncode(preferences);
    debugPrint('[Preference API] POST $_preferencesUrl');
    debugPrint('[Preference API] Request: $requestBody');

    final response = await AuthService.client
        .post(
          Uri.parse(_preferencesUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 15));

    debugPrint('[Preference API] Status: ${response.statusCode}');
    debugPrint('[Preference API] Response: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          '취향 저장 실패 (${response.statusCode}): ${_errorMessage(response)}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('잘못된 취향 저장 응답입니다.');
    }

    final preferenceId = body['id'];
    if (preferenceId is! int) {
      throw const FormatException('취향 저장 응답에 id가 없습니다.');
    }

    return preferenceId;
  }

  static String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {
      // Fall back to the status code when the server response is not JSON.
    }
    return '서버 응답을 확인해 주세요.';
  }
}
