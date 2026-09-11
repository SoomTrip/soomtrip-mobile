import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soomtrip/route_service.dart';

Map<String, dynamic> spot(String id) => {'content_id': id, 'name': id};

void main() {
  test('unconfirmed mode on a freshly optimized spot shows a neutral label',
      () {
    // A brand-new /route/optimize response has no per-spot mobility_choice
    // yet (that only gets echoed back after a save). The label must not
    // guess a specific mode from a client-side hint in that case, since a
    // wrong guess (e.g. showing "도보이동" for a route the server priced at
    // car speeds) misleads the traveler.
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [
            spot('A'),
            {
              ...spot('B'),
              'distance_from_prev_km': 3.3,
              'duration_from_prev_minutes': 6,
              'car_alternative': null,
            },
          ]
        }
      }
    });
    expect(plan.byDay[1]![1].mobilityChoice, isNull);
    expect(plan.byDay[1]![1].travelLabel(), '이동 6분');
  });

  test('car alternative is sent to save and survives grouped reload', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': {'spots': [
      {...spot('A'), 'saved_region_spot_id': 1},
      {...spot('B'), 'saved_region_spot_id': 2,
        'distance_from_prev_km': 2.1, 'duration_from_prev_minutes': 30,
        'mobility_used': 'walk_transit', 'is_fallback': false,
        'car_alternative': {'mobility_choice': 'car',
          'distance_from_prev_km': 3.2, 'duration_from_prev_minutes': 7}},
    ]}}});
    final entries = plan.toSaveEntries();
    expect(entries.first['car_alternative'], isNull);
    expect(entries.first['mobility_used'], isNull);
    expect(entries.last['duration_from_prev_minutes'], 30);
    expect(entries.last['mobility_used'], 'walk_transit');
    expect(entries.last['is_fallback'], false);
    expect(entries.last['car_alternative'], {'mobility_choice': 'car',
      'distance_from_prev_km': 3.2, 'duration_from_prev_minutes': 7, 'is_fallback': false});
    final reloaded = RoutePlan.fromJson({'route_by_day': {'day1': [
      {...spot('A'), 'saved_region_spot_id': 1},
      {...spot('B'), 'saved_region_spot_id': 2, 'mobility_options': [
        entries.last['car_alternative'],
        {'mobility_choice': 'walk_transit', 'distance_from_prev_km': 2.1,
          'duration_from_prev_minutes': 30},
      ]},
    ]}});
    expect(reloaded.byDay[1]![1].travelLabel(), '도보 30분\n택시 7분');
    expect(reloaded.toSaveEntries(), entries);
  });

  test('walking and car options render as two travel lines', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': [spot('A'), {
      ...spot('B'), 'mobility_options': [
        {'mobility_choice': 'walk_transit', 'duration_from_prev_minutes': 25},
        {'mobility_choice': 'car', 'duration_from_prev_minutes': 6},
      ],
    }]}});
    expect(plan.byDay[1]![1].travelLabel(), '도보 25분\n택시 6분');
  });

  test('two entries for one arrival preserve both transport times', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': [spot('A'),
      {...spot('B'), 'saved_region_spot_id': 2, 'mobility_choice': 'car', 'duration_from_prev_minutes': 6},
      {...spot('B'), 'saved_region_spot_id': 2, 'mobility_choice': 'walk_transit', 'duration_from_prev_minutes': 25},
    ]}});
    expect(plan.byDay[1]!.length, 2);
    expect(plan.byDay[1]![1].travelLabel(), '도보 25분\n택시 6분');
  });

  test('optimize car alternative survives saved ID mapping', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': {'spots': [spot('A'), {
      ...spot('B'), 'duration_from_prev_minutes': 30,
      'car_alternative': {'duration_minutes': 0, 'distance_km': 0.1},
    }]}}});
    expect(plan.byDay[1]![1].withSavedRegionSpotId(2).travelLabel(), '도보 30분\n택시 0분');
  });

  test('mobility_used normalizes into the legacy mobility_choice field', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': {'spots': [spot('A'), {
      ...spot('B'), 'distance_from_prev_km': 1.2, 'duration_from_prev_minutes': 14,
      'mobility_used': 'walk_transit', 'is_fallback': false, 'car_alternative': null,
    }]}}});
    expect(plan.byDay[1]![1].mobilityChoice, 'walk_transit');
    expect(plan.byDay[1]![1].travelLabel(), '도보 14분');
  });

  test('fallback_car shows the no-walk-route label using its own duration', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': {'spots': [spot('A'), {
      ...spot('B'), 'distance_from_prev_km': 5.4, 'duration_from_prev_minutes': 9,
      'mobility_used': 'fallback_car', 'is_fallback': true, 'car_alternative': null,
    }]}}});
    expect(plan.byDay[1]![1].travelLabel(), '택시 9분');
  });

  test('walk with a 25+ minute car alternative shows both legs in one line', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': {'spots': [spot('A'), {
      ...spot('B'), 'distance_from_prev_km': 2.1, 'duration_from_prev_minutes': 28,
      'mobility_used': 'walk_transit', 'is_fallback': false,
      'car_alternative': {'mobility_choice': 'car',
        'distance_from_prev_km': 5.4, 'duration_from_prev_minutes': 9, 'is_fallback': false},
    }]}}});
    expect(plan.byDay[1]![1].travelLabel(), '도보 28분\n택시 9분');
  });

  test('plain car mode (region-level car preference) shows a self-drive label', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': {'spots': [spot('A'), {
      ...spot('B'), 'distance_from_prev_km': 4.0, 'duration_from_prev_minutes': 10,
      'mobility_used': 'car', 'is_fallback': false, 'car_alternative': null,
    }]}}});
    expect(plan.byDay[1]![1].travelLabel(), '자차 10분');
  });

  test('fallback_car saved entry reports is_fallback true', () {
    final plan = RoutePlan.fromJson({'route_by_day': {'day1': {'spots': [
      {...spot('A'), 'saved_region_spot_id': 1},
      {...spot('B'), 'saved_region_spot_id': 2, 'distance_from_prev_km': 5.4,
        'duration_from_prev_minutes': 9, 'mobility_used': 'fallback_car'},
    ]}}});
    final entries = plan.toSaveEntries();
    expect(entries.last['mobility_used'], 'fallback_car');
    expect(entries.last['is_fallback'], true);
    expect(entries.last['car_alternative'], isNull);
  });

  test('saved mobility options preserve distance, duration and server mode', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': [
          {...spot('A'), 'saved_region_spot_id': 349,
            'mobility_options': [{'mobility_choice': 'car',
              'distance_from_prev_km': null, 'duration_from_prev_minutes': null}]},
          {...spot('B'), 'saved_region_spot_id': 348,
            'mobility_options': [{'mobility_choice': 'car',
              'distance_from_prev_km': 1.9, 'duration_from_prev_minutes': 6}]},
        ],
      },
    });
    expect(plan.byDay[1]!.first.durationFromPreviousMinutes, isNull);
    expect(plan.byDay[1]![1].distanceFromPreviousKm, 1.9);
    expect(plan.byDay[1]![1].durationFromPreviousMinutes, 6);
    expect(plan.byDay[1]![1].mobilityChoice, 'car');
    expect(plan.toSaveEntries().last['duration_from_prev_minutes'], 6);
  });

  test('mobility options select requested walking mode without car default', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {'day1': [spot('A'), {...spot('B'),
        'mobility_options': [
          {'mobility_choice': 'car', 'duration_from_prev_minutes': 6},
          {'mobility_choice': 'walk_transit', 'duration_from_prev_minutes': 25},
        ]}]},
    }, mobilityChoice: 'walk_transit');
    expect(plan.byDay[1]![1].durationFromPreviousMinutes, 25);
    expect(plan.byDay[1]![1].mobilityChoice, 'walk_transit');
  });

  test('consecutive duplicate anchors disappear without shifting travel times',
      () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [
            {...spot('A'), 'name': '실제 관광지'},
            {...spot('A'), 'name': '지역명'},
            spot('B'),
          ],
          'segments': [
            null,
            {'distance_km': 0, 'duration_minutes': 0},
            {'distance_km': 1.2, 'duration_minutes': 5}
          ],
        }
      }
    });
    expect(plan.byDay[1]!.map((s) => s.name), ['실제 관광지', 'B']);
    expect(plan.byDay[1]!.map((s) => s.durationFromPreviousMinutes), [null, 5]);
    final saved = RoutePlan.fromJson({
      'route_by_day': {
        'day1': [
          {...spot('A'), 'saved_region_spot_id': 218},
          {
            ...spot('A'),
            'saved_region_spot_id': 218,
            'duration_from_prev_minutes': 0
          },
          {
            ...spot('B'),
            'saved_region_spot_id': 221,
            'duration_from_prev_minutes': 5
          },
        ]
      }
    });
    expect(saved.toSaveEntries().map((e) => e['visit_order']), [1, 2]);
    expect(saved.toSaveEntries().last['duration_from_prev_minutes'], 5);
  });

  test('new spot fields take priority, including nulls, and survive saving',
      () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [
            {
              ...spot('A'),
              'distance_from_prev_km': null,
              'duration_from_prev_minutes': null
            },
            {
              ...spot('B'),
              'distance_from_prev_km': 0.9,
              'duration_from_prev_minutes': 3
            },
            {
              ...spot('C'),
              'distance_from_prev_km': null,
              'duration_from_prev_minutes': null
            },
          ],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'distance_km': 99, 'duration_minutes': 99},
            {'distance_km': 99, 'duration_minutes': 99},
          ],
        },
      },
    }, mobilityChoice: 'car');
    final ids = {'A': 120, 'B': 108, 'C': 130};
    final mapped = RoutePlan({
      1: plan.byDay[1]!
          .map((s) => s.withSavedRegionSpotId(ids[s.contentId]!))
          .toList()
    });
    final entries = mapped.toSaveEntries();
    expect(entries.map((e) => e['saved_region_spot_id']), [120, 108, 130]);
    expect(entries.map((e) => e['distance_from_prev_km']), [null, 0.9, null]);
    expect(
        entries.map((e) => e['duration_from_prev_minutes']), [null, 3, null]);
    final loaded = RoutePlan.fromJson({
      'route_by_day': {'day1': entries}
    });
    expect(loaded.byDay[1]![1].durationFromPreviousMinutes, 3);
    expect(loaded.byDay[1]![2].durationFromPreviousMinutes, isNull);
  });

  test('new spot fields work without segments', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [
            spot('A'),
            {
              ...spot('B'),
              'distance_from_prev_km': 1.2,
              'duration_from_prev_minutes': 5
            }
          ],
          'segments': [],
        }
      }
    });
    expect(plan.byDay[1]![1].distanceFromPreviousKm, 1.2);
    expect(plan.byDay[1]![1].durationFromPreviousMinutes, 5);
  });

  test('maps segments to arrival spots per day, saves and reloads the values',
      () {
    final optimized = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [spot('A'), spot('B'), spot('C')],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'distance_km': 1.2, 'duration_minutes': 4},
            {'distance_km': '3.5', 'duration_minutes': '12'},
          ],
        },
        'day2': {
          'spots': [spot('D'), spot('E')],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'distance_km': 0.0, 'duration_minutes': 0}
          ],
        },
      },
    }, mobilityChoice: 'car');
    var id = 0;
    final mapped = RoutePlan(optimized.byDay.map((day, spots) => MapEntry(
        day, spots.map((spot) => spot.withSavedRegionSpotId(++id)).toList())));
    final entries = jsonDecode(jsonEncode(mapped.toSaveEntries())) as List;
    expect(entries.map((e) => e['duration_from_prev_minutes']),
        [null, 4, 12, null, 0]);
    expect(entries.map((e) => e['distance_from_prev_km']),
        [null, 1.2, 3.5, null, 0.0]);
    expect(entries.map((e) => e['visit_order']), [1, 2, 3, 1, 2]);
    final loaded = RoutePlan.fromJson({
      'route_by_day': {
        for (final day in [1, 2])
          'day$day': entries
              .where((e) => e['visit_day'] == day)
              .map((e) => <String, dynamic>{...e, 'mobility_choice': 'car'})
              .toList(),
      },
    });
    expect(loaded.byDay[1]![1].durationFromPreviousMinutes, 4);
    expect(loaded.byDay[1]![2].durationFromPreviousMinutes, 12);
    expect(loaded.byDay[2]!.first.durationFromPreviousMinutes, isNull);
    expect(loaded.byDay[2]![1].durationFromPreviousMinutes, 0);
    expect(loaded.byDay[1]![1].mobilityChoice, 'car');
  });

  test('empty segments do not invent travel times', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [spot('A'), spot('B')],
          'segments': []
        },
      },
    });
    expect(
        plan.byDay[1]!.map((s) => s.durationFromPreviousMinutes), [null, null]);
  });

  test('repeated places keep segment indices and walking mode', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [spot('A'), spot('B'), spot('A')],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'duration_minutes': 10},
            {'duration_minutes': 15},
          ],
        },
      },
    }, mobilityChoice: 'walk_transit');
    expect(plan.byDay[1]!.map((s) => s.durationFromPreviousMinutes),
        [null, 10, 15]);
    expect(plan.byDay[1]!.last.mobilityChoice, 'walk_transit');
  });

  test('missing saved place ID cannot silently drop a route entry', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': [spot('A')]
      }
    });
    expect(plan.toSaveEntries, throwsFormatException);
  });
}
