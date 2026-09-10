import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _authUrl = 'https://soomtrip.cspc.me/auth/kakao';
  static const _meUrl = 'https://soomtrip.cspc.me/users/me';
  static const _jwtKey = 'soomtrip_access_token';
  static const _refreshKey = 'soomtrip_refresh_token';
  static Future<String?>? _refreshInFlight;
  static int _sessionVersion = 0;
  static http.Client get client => _AuthenticatedClient();
  static const _introCompletedKey = 'soomtrip_intro_completed';

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
    final refresh = body['refresh_token'];
    if (jwt is! String || jwt.isEmpty) {
      throw const FormatException('로그인 응답에 access_token이 없습니다.');
    }
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException('로그인 응답에 refresh_token이 없습니다.');
    }

    final preferences = await SharedPreferences.getInstance();
    _sessionVersion++;
    await preferences.setString(_refreshKey, refresh);
    await preferences.setString(_jwtKey, jwt);
  }

  static Future<void> updateNickname(String nickname) async {
    final trimmedNickname = nickname.trim();
    if (trimmedNickname.isEmpty) return;

    final jwt = await getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await client
        .patch(
          Uri.parse(_meUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode({'nickname': trimmedNickname}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('닉네임 동기화 실패 (${response.statusCode})');
    }
  }

  static Future<bool> hasJwt() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_jwtKey)?.isNotEmpty ?? false;
  }

  static Future<bool> hasCompletedIntro() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_introCompletedKey) ?? false;
  }

  static Future<void> markIntroCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_introCompletedKey, true);
  }

  static Future<String?> getJwt() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_jwtKey);
  }

  static Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    final refresh = preferences.getString(_refreshKey);
    if (refresh != null && refresh.isNotEmpty) {
      final response = await http
          .post(
            Uri.parse('https://soomtrip.cspc.me/auth/logout'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('로그아웃 실패 (${response.statusCode})');
      }
    }
    _sessionVersion++;
    await preferences.remove(_jwtKey);
    await preferences.remove(_refreshKey);
  }

  // 회원 탈퇴: 서버가 저장한 여행지/일기/스탬프/친구/리프레시 토큰까지 전부
  // 삭제하므로, 여기서는 로컬 세션만 정리하면 된다.
  static Future<void> deleteAccount() async {
    final jwt = await getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await client
        .delete(
          Uri.parse(_meUrl),
          headers: {'Authorization': 'Bearer $jwt'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('회원 탈퇴 실패 (${response.statusCode})');
    }

    final preferences = await SharedPreferences.getInstance();
    _sessionVersion++;
    await preferences.remove(_jwtKey);
    await preferences.remove(_refreshKey);
  }

  static Future<String?> _refreshAfterUnauthorized(
      String? rejectedToken) async {
    final current = await getJwt();
    if (current != null && current != rejectedToken) return current;
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final future = _refreshAccessToken();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  static Future<String?> _refreshAccessToken() async {
    final version = _sessionVersion;
    final preferences = await SharedPreferences.getInstance();
    final refresh = preferences.getString(_refreshKey);
    if (refresh == null || refresh.isEmpty) return null;
    final response = await http
        .post(
          Uri.parse('https://soomtrip.cspc.me/auth/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refresh}),
        )
        .timeout(const Duration(seconds: 15));
    if (version != _sessionVersion) return null;
    if (response.statusCode == 401 || response.statusCode == 403) {
      _sessionVersion++;
      await preferences.remove(_jwtKey);
      await preferences.remove(_refreshKey);
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('로그인 갱신 실패 (${response.statusCode})');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final token = body is Map ? body['access_token'] : null;
    if (token is! String || token.isEmpty) {
      throw const FormatException('재발급 응답에 access_token이 없습니다.');
    }
    await preferences.setString(_jwtKey, token);
    return token;
  }
}

class _AuthenticatedClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.scheme != 'https' ||
        request.url.host != 'soomtrip.cspc.me') {
      throw ArgumentError('인증 클라이언트는 숨트립 API에만 사용할 수 있습니다.');
    }
    // Buffer once so JSON and multipart uploads can be replayed exactly once.
    final bytes = await request.finalize().toBytes();
    final version = AuthService._sessionVersion;
    final token = await AuthService.getJwt();
    Future<http.StreamedResponse> sendOnce(String? accessToken) async {
      final copy = http.Request(request.method, request.url)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..headers.addAll(request.headers)
        ..bodyBytes = bytes;
      copy.headers.remove('Authorization');
      if (accessToken != null) {
        copy.headers['Authorization'] = 'Bearer $accessToken';
      }
      final transport = http.Client();
      try {
        final response = await transport.send(copy);
        final body = await response.stream.toBytes();
        return http.StreamedResponse(Stream.value(body), response.statusCode,
            headers: response.headers,
            reasonPhrase: response.reasonPhrase,
            isRedirect: response.isRedirect,
            request: copy,
            contentLength: body.length,
            persistentConnection: response.persistentConnection);
      } finally {
        transport.close();
      }
    }

    final response = await sendOnce(token);
    if (response.statusCode != 401 || version != AuthService._sessionVersion) {
      return response;
    }
    final refreshed = await AuthService._refreshAfterUnauthorized(token);
    if (refreshed == null || version != AuthService._sessionVersion) {
      return response;
    }
    return sendOnce(refreshed);
  }
}
