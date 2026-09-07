import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'saved_region_service.dart';

class RouteSpot {
  final int? savedRegionSpotId;
  final String? contentId;
  final String name;
  final String categoryLabel;
  final double? latitude;
  final double? longitude;
  final double? distanceFromPreviousKm;
  final int? durationFromPreviousMinutes;
  final String? mobilityChoice;

  const RouteSpot({
    required this.savedRegionSpotId,
    required this.contentId,
    required this.name,
    required this.categoryLabel,
    required this.latitude,
    required this.longitude,
    required this.distanceFromPreviousKm,
    required this.durationFromPreviousMinutes,
    required this.mobilityChoice,
  });

  factory RouteSpot.fromJson(Map<String, dynamic> json) {
    double? number(Object? value) =>
        value is num ? value.toDouble() : double.tryParse('$value');
    int? integer(Object? value) {
      if (value is num) return value.round();
      final text = '$value';
      return int.tryParse(text) ?? double.tryParse(text)?.round();
    }

    return RouteSpot(
      savedRegionSpotId: integer(json['saved_region_spot_id']),
      contentId: json['content_id'] is String
          ? json['content_id'] as String
          : null,
      name: json['name'] is String ? json['name'] as String : '여행지',
      categoryLabel: json['category_label'] is String
          ? json['category_label'] as String
          : '기타',
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
      distanceFromPreviousKm: number(json['distance_from_prev_km']),
      durationFromPreviousMinutes: integer(json['duration_from_prev_minutes']),
        mobilityChoice: json['mobility_choice'] is String
          ? json['mobility_choice'] as String
          : null,
    );
  }

  RouteSpot withSavedRegionSpotId(int id) => RouteSpot(
        savedRegionSpotId: id,
        contentId: contentId,
        name: name,
        categoryLabel: categoryLabel,
        latitude: latitude,
        longitude: longitude,
        distanceFromPreviousKm: distanceFromPreviousKm,
        durationFromPreviousMinutes: durationFromPreviousMinutes,
        mobilityChoice: mobilityChoice,
      );
}

class RoutePlan {
  final Map<int, List<RouteSpot>> byDay;

  const RoutePlan(this.byDay);

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    final rawDays = json['route_by_day'];
    final days = <int, List<RouteSpot>>{};
    if (rawDays is Map) {
      rawDays.forEach((key, value) {
        final dayKey = '$key'.replaceFirst(RegExp(r'^day'), '');
        final day = int.tryParse(dayKey);
        if (day == null) return;
        final rawSpots = value is List
            ? value
            : value is Map
                ? value['spots']
                : null;
        if (rawSpots is! List) return;
        final parsedSpots = rawSpots
            .whereType<Map<String, dynamic>>()
            .map(RouteSpot.fromJson)
            .toList(growable: false);
        final seen = <String>{};
        days[day] = parsedSpots.where((spot) {
          final key = spot.savedRegionSpotId?.toString() ??
              spot.contentId ??
              '${spot.name}:${spot.latitude}:${spot.longitude}';
          return seen.add(key);
        }).toList(growable: false);
      });
    }
    debugPrint('[Route API] parsed route days: ${days.map(
      (day, spots) => MapEntry(day, spots.length),
    )}');
    return RoutePlan(days);
  }
}

class RouteService {
  static const _baseUrl = 'https://soomtrip-api.cspc.me';

  static Future<String> _jwt() async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) throw Exception('로그인이 필요합니다.');
    return jwt;
  }

  static Future<RoutePlan> optimize({
    required List<SavedSpot> spots,
    required int dayCount,
    required String mobilityChoice,
  }) async {
    final jwt = await _jwt();
    final uniqueSpots = <SavedSpot>[];
    final seenSpotKeys = <String>{};
    for (final spot in spots) {
      final key = spot.id?.toString() ??
          (spot.contentId.isNotEmpty
              ? spot.contentId
              : '${spot.name}:${spot.latitude}:${spot.longitude}');
      if (seenSpotKeys.add(key)) uniqueSpots.add(spot);
    }
    final selectedSpots = uniqueSpots.map((spot) => {
          'content_id': spot.contentId,
          'name': spot.name,
          'address': '',
          'latitude': spot.latitude,
          'longitude': spot.longitude,
          'category_label': spot.categoryLabel,
        });
    final response = await http
        .post(
          Uri.parse('$_baseUrl/route/optimize'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode({
            'selected_spots': selectedSpots.toList(),
            'num_days': dayCount,
            'mobility_choice': mobilityChoice,
          }),
        )
        .timeout(const Duration(seconds: 30));

    debugPrint('[Route API] optimize ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('여행 경로 계산 실패 (${response.statusCode})');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const FormatException('여행 경로 응답 형식이 올바르지 않습니다.');
    }
    final plan = RoutePlan.fromJson(body);
    final idsByContentId = <String, int>{
      for (final spot in uniqueSpots)
        if (spot.id != null && spot.contentId.isNotEmpty)
          spot.contentId: spot.id!,
    };
    final mappedDays = <int, List<RouteSpot>>{};
    plan.byDay.forEach((day, daySpots) {
      mappedDays[day] = daySpots
          .map((spot) => spot.savedRegionSpotId == null && spot.contentId != null
              ? (idsByContentId[spot.contentId!] == null
                  ? spot
                  : spot.withSavedRegionSpotId(idsByContentId[spot.contentId!]!))
              : spot)
          .toList(growable: false);
    });
    return RoutePlan(mappedDays);
  }

  static Future<void> save({
    required int savedRegionId,
    required RoutePlan plan,
    required String mobilityChoice,
  }) async {
    final jwt = await _jwt();
    final entries = <Map<String, dynamic>>[];
    plan.byDay.forEach((day, spots) {
      for (var index = 0; index < spots.length; index++) {
        final spotId = spots[index].savedRegionSpotId;
        if (spotId == null) continue;
        entries.add({
          'saved_region_spot_id': spotId,
          'visit_day': day,
          'visit_order': index + 1,
          'distance_from_prev_km': spots[index].distanceFromPreviousKm,
          'duration_from_prev_minutes': spots[index].durationFromPreviousMinutes,
        });
      }
    });
    final response = await http
        .post(
          Uri.parse('$_baseUrl/route/save'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode({
            'saved_region_id': savedRegionId,
            'mobility_choice': mobilityChoice,
            'entries': entries,
          }),
        )
        .timeout(const Duration(seconds: 15));
    debugPrint('[Route API] save ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('여행 경로 저장 실패 (${response.statusCode})');
    }
  }

  static Future<RoutePlan> getSaved(int savedRegionId) async {
    final jwt = await _jwt();
    final response = await http.get(
      Uri.parse('$_baseUrl/route/saved-region/$savedRegionId'),
      headers: {'Authorization': 'Bearer $jwt'},
    ).timeout(const Duration(seconds: 15));
    debugPrint('[Route API] get ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('저장된 여행 경로 불러오기 실패 (${response.statusCode})');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const FormatException('저장된 경로 응답 형식이 올바르지 않습니다.');
    }
    return RoutePlan.fromJson(body);
  }
}