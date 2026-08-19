import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _authUrl = 'https://soomtrip-api.cspc.me/auth/kakao';
  static const _jwtKey = 'soomtrip_access_token';

  static Future<void> loginWithKakao(String kakaoAccessToken) async {
    final response = await http
        .post(
          Uri.parse(_authUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'kakao_access_token': kakaoAccessToken}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('백엔드 로그인 실패 (${response.statusCode})');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('잘못된 로그인 응답입니다.');
    }

    final jwt = body['access_token'];
    if (jwt is! String || jwt.isEmpty) {
      throw const FormatException('로그인 응답에 access_token이 없습니다.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_jwtKey, jwt);
  }

  static Future<bool> hasJwt() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_jwtKey)?.isNotEmpty ?? false;
  }

  static Future<String?> getJwt() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_jwtKey);
  }

  static Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_jwtKey);
  }
}
