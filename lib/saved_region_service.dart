import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class SavedRegion {
  final int id;
  final String regionName;

  const SavedRegion({required this.id, required this.regionName});

  factory SavedRegion.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final regionName = json['region_name'];
    if (id is! int || regionName is! String || regionName.trim().isEmpty) {
      throw const FormatException('저장된 여행지 응답 형식이 올바르지 않습니다.');
    }
    return SavedRegion(id: id, regionName: regionName.trim());
  }
}

class SavedRegionService {
  static const _savedRegionsUrl = 'https://soomtrip-api.cspc.me/saved-regions';
  static List<SavedRegion>? _cachedRegions;

  static List<SavedRegion>? get cachedRegions {
    final cached = _cachedRegions;
    return cached == null ? null : List.unmodifiable(cached);
  }

  static Future<List<SavedRegion>> getAll() async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http.get(
      Uri.parse(_savedRegionsUrl),
      headers: {'Authorization': 'Bearer $jwt'},
    ).timeout(const Duration(seconds: 15));

    debugPrint('[Saved Region API] GET status: ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('저장한 여행지 불러오기 실패 (${response.statusCode})');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) {
      throw const FormatException('저장된 여행지 응답 형식이 올바르지 않습니다.');
    }

    final regions = body.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('저장된 여행지 항목이 올바르지 않습니다.');
      }
      return SavedRegion.fromJson(item);
    }).toList(growable: false);
    _cachedRegions = regions;
    return List.unmodifiable(regions);
  }

  static Future<void> save(Map<String, dynamic> candidate) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final regionName = candidate['name'];
    final contentId = candidate['content_id'];
    if (regionName is! String ||
        regionName.trim().isEmpty ||
        contentId is! String ||
        contentId.isEmpty) {
      throw const FormatException('저장할 추천 여행지 정보가 올바르지 않습니다.');
    }

    final spots = <Map<String, dynamic>>[
      {
        'content_id': contentId,
        'name': regionName.trim(),
        'latitude': candidate['latitude'],
        'longitude': candidate['longitude'],
        'is_anchor': true,
      },
    ];

    final nearbySpots = candidate['nearby_spots'];
    if (nearbySpots is List) {
      for (final spot in nearbySpots) {
        if (spot is! Map<String, dynamic>) continue;
        final spotContentId = spot['content_id'];
        final spotName = spot['name'];
        if (spotContentId is! String || spotName is! String) continue;
        spots.add({
          'content_id': spotContentId,
          'name': spotName,
          'latitude': spot['latitude'],
          'longitude': spot['longitude'],
          'is_anchor': false,
        });
      }
    }

    final score = candidate['score'];
    final request = <String, dynamic>{
      'region_name': regionName.trim(),
      'score': score is num ? score.round() : null,
      'spots': spots,
    };
    final requestBody = jsonEncode(request);

    debugPrint('[Saved Region API] POST $_savedRegionsUrl');
    debugPrint('[Saved Region API] Request: $requestBody');

    final response = await http
        .post(
          Uri.parse(_savedRegionsUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 15));

    debugPrint('[Saved Region API] Status: ${response.statusCode}');
    debugPrint('[Saved Region API] Response: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('여행지 저장 실패 (${response.statusCode})');
    }
  }

  static Future<void> remove(int savedRegionId) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final response = await http.delete(
      Uri.parse('$_savedRegionsUrl/$savedRegionId'),
      headers: {'Authorization': 'Bearer $jwt'},
    ).timeout(const Duration(seconds: 15));

    debugPrint('[Saved Region API] DELETE status: ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('여행지 삭제 실패 (${response.statusCode})');
    }

    _cachedRegions = _cachedRegions
        ?.where((region) => region.id != savedRegionId)
        .toList(growable: false);
  }
}
