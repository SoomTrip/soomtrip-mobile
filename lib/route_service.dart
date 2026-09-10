import 'dart:convert';

import 'package:flutter/foundation.dart';

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
      contentId:
          json['content_id'] is String ? json['content_id'] as String : null,
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

  factory RoutePlan.fromJson(Map<String, dynamic> json,
      {String? mobilityChoice}) {
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
        final segments = value is Map && value['segments'] is List
            ? value['segments'] as List
            : const [];
        final parsedSpots = <RouteSpot>[];
        for (var index = 0; index < rawSpots.length; index++) {
          final rawSpot = rawSpots[index];
          if (rawSpot is! Map<String, dynamic>) {
            throw const FormatException('여행 경로의 장소 형식이 올바르지 않습니다.');
          }
          final spotJson = Map<String, dynamic>.of(rawSpot);
          spotJson['mobility_choice'] ??= mobilityChoice;
          // The first spot has no incoming trip. segments[1] is spots[0]
          // -> spots[1], segments[2] is spots[1] -> spots[2], and so on.
          if (index == 0) {
            spotJson['distance_from_prev_km'] = null;
            spotJson['duration_from_prev_minutes'] = null;
          }
          if (index > 0 && index < segments.length) {
            final segment = segments[index];
            if (segment is Map) {
              // New responses own these fields, including explicit nulls
              // when routing fails. Only backfill older response formats.
              if (!spotJson.containsKey('distance_from_prev_km')) {
                spotJson['distance_from_prev_km'] =
                    segment['distance_km'] ?? segment['distance_from_prev_km'];
              }
              if (!spotJson.containsKey('duration_from_prev_minutes')) {
                spotJson['duration_from_prev_minutes'] =
                    segment['duration_minutes'] ??
                        segment['duration_from_prev_minutes'];
              }
              spotJson['mobility_choice'] =
                  segment['mobility_choice'] ?? spotJson['mobility_choice'];
            }
          }
          final spot = RouteSpot.fromJson(spotJson);
          // Collapse only consecutive copies of the same place. A later
          // return visit remains valid, and segment parsing keeps raw indices.
          if (parsedSpots.isNotEmpty) {
            final previous = parsedSpots.last;
            final sameContent = spot.contentId != null &&
                spot.contentId!.isNotEmpty &&
                spot.contentId == previous.contentId;
            final sameSavedId = spot.savedRegionSpotId != null &&
                spot.savedRegionSpotId == previous.savedRegionSpotId;
            if (sameContent || sameSavedId) continue;
          }
          parsedSpots.add(spot);
        }
        days[day] = parsedSpots;
      });
    }
    debugPrint('[Route API] parsed route days: ${days.map(
      (day, spots) => MapEntry(day, spots.length),
    )}');
    return RoutePlan(days);
  }

  List<Map<String, dynamic>> toSaveEntries() {
    final entries = <Map<String, dynamic>>[];
    byDay.forEach((day, spots) {
      for (var index = 0; index < spots.length; index++) {
        final spotId = spots[index].savedRegionSpotId;
        if (spotId == null) {
          throw const FormatException('저장할 경로의 장소 ID가 없습니다.');
        }
        entries.add({
          'saved_region_spot_id': spotId,
          'visit_day': day,
          'visit_order': index + 1,
          'distance_from_prev_km': spots[index].distanceFromPreviousKm,
          'duration_from_prev_minutes':
              spots[index].durationFromPreviousMinutes,
        });
      }
    });
    return entries;
  }
}

class RouteService {
  static const _baseUrl = 'https://soomtrip-api.cspc.me';

  static void _logTravelValues(String stage, RoutePlan plan) {
    if (!kDebugMode) return;
    plan.byDay.forEach((day, spots) {
      for (var index = 0; index < spots.length; index++) {
        final spot = spots[index];
        debugPrint('[Route Time][$stage] day$day #${index + 1} '
            'content=${spot.contentId} savedId=${spot.savedRegionSpotId} '
            'km=${spot.distanceFromPreviousKm} '
            'min=${spot.durationFromPreviousMinutes}');
      }
    });
  }

  static void _logOptimizeFields(Map<String, dynamic> body) {
    if (!kDebugMode) return;
    final days = body['route_by_day'];
    if (days is! Map) return;
    days.forEach((day, value) {
      if (value is! Map || value['spots'] is! List) return;
      final spots = value['spots'] as List;
      final segments = value['segments'];
      debugPrint('[Route Time][response] $day spots=${spots.length} '
          'segments=${segments is List ? segments.length : 0}');
      for (var index = 0; index < spots.length; index++) {
        final spot = spots[index];
        if (spot is! Map) continue;
        final km = spot.containsKey('distance_from_prev_km')
            ? spot['distance_from_prev_km']
            : 'missing';
        final minutes = spot.containsKey('duration_from_prev_minutes')
            ? spot['duration_from_prev_minutes']
            : 'missing';
        debugPrint('[Route Time][response] $day #${index + 1} '
            'content=${spot['content_id']} km=$km min=$minutes');
      }
    });
  }

  static Future<String> _jwt() async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) throw Exception('로그인이 필요합니다.');
    return jwt;
  }

  static Future<RoutePlan> optimize({
    required int savedRegionId,
    required List<SavedSpot> spots,
    required int dayCount,
  }) async {
    final jwt = await _jwt();
    final spotsByKey = <String, SavedSpot>{};
    for (final spot in spots) {
      final key = spot.contentId.isNotEmpty
          ? 'content:${spot.contentId}'
          : spot.id != null
              ? 'saved:${spot.id}'
              : '${spot.name}:${spot.latitude}:${spot.longitude}';
      final existing = spotsByKey[key];
      if (existing == null || (existing.isAnchor && !spot.isAnchor)) {
        spotsByKey[key] = spot;
      }
    }
    final uniqueSpots = spotsByKey.values.toList(growable: false);
    final selectedSpots = uniqueSpots.map((spot) => {
          'content_id': spot.contentId,
          'name': spot.name,
          'address': '',
          'latitude': spot.latitude,
          'longitude': spot.longitude,
          'category_label': spot.categoryLabel,
        });
    final response = await AuthService.client
        .post(
          Uri.parse('$_baseUrl/route/optimize'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode({
            'saved_region_id': savedRegionId,
            'selected_spots': selectedSpots.toList(),
            'num_days': dayCount,
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
    _logOptimizeFields(body);
    final plan = RoutePlan.fromJson(body);
    final idsByContentId = <String, int>{
      for (final spot in uniqueSpots)
        if (spot.id != null && spot.contentId.isNotEmpty)
          spot.contentId: spot.id!,
    };
    final mappedDays = <int, List<RouteSpot>>{};
    plan.byDay.forEach((day, daySpots) {
      mappedDays[day] = daySpots
          .map((spot) => spot.savedRegionSpotId == null &&
                  spot.contentId != null
              ? (idsByContentId[spot.contentId!] == null
                  ? spot
                  : spot
                      .withSavedRegionSpotId(idsByContentId[spot.contentId!]!))
              : spot)
          .toList(growable: false);
    });
    return RoutePlan(mappedDays);
  }

  static Future<void> save({
    required int savedRegionId,
    required RoutePlan plan,
  }) async {
    final jwt = await _jwt();
    final entries = plan.toSaveEntries();
    _logTravelValues('save-request', plan);
    final response = await AuthService.client
        .post(
          Uri.parse('$_baseUrl/route/save'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwt',
          },
          body: jsonEncode({
            'saved_region_id': savedRegionId,
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
    final response = await AuthService.client.get(
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
    final plan = RoutePlan.fromJson(body);
    _logTravelValues('get-response', plan);
    return plan;
  }
}
