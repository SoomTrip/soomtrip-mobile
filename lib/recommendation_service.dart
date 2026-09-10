import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class RecommendationService {
  static const _recommendationsUrl =
      'https://soomtrip.cspc.me/recommendations';

  static Future<Map<String, dynamic>> create(int preferenceId) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final requestBody = jsonEncode({'preference_id': preferenceId});
    debugPrint('[Recommendation API] POST $_recommendationsUrl');
    debugPrint('[Recommendation API] Request: $requestBody');
    debugPrint('[Recommendation API] Authorization: Bearer token included');

    final response = await AuthService.client
        .post(
          Uri.parse(_recommendationsUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: requestBody,
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () =>
              throw Exception('여행지 추천 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.'),
        );

    debugPrint('[Recommendation API] Status: ${response.statusCode}');
    debugPrint('[Recommendation API] Response: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          '여행지 추천 실패 (${response.statusCode}): ${_errorMessage(response)}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('잘못된 여행지 추천 응답입니다.');
    }

    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('추천 여행지가 없습니다.');
    }

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) {
      throw const FormatException('잘못된 추천 여행지 형식입니다.');
    }

    final destinationName = firstCandidate['name'];
    if (destinationName is! String || destinationName.trim().isEmpty) {
      throw const FormatException('추천 여행지 이름이 없습니다.');
    }

    final mobilityChoice = body['mobility_choice'];
    if (mobilityChoice != 'car' && mobilityChoice != 'walk_transit') {
      throw const FormatException('추천 응답의 이동수단을 확인할 수 없습니다.');
    }
    // The API supplies mobility at the response root. Keep it with the
    // selected candidate so saving/re-rolling never loses that recommendation's mode.
    return {...firstCandidate, 'mobility_choice': mobilityChoice};
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
