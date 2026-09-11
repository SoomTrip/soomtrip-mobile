import 'route_service.dart';
import 'home_logo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';

import 'route_screen.dart';
import 'saved_region_service.dart';

class DestinationDetailScreen extends StatefulWidget {
  final SavedRegion destination;
  final bool resetRoute;

  const DestinationDetailScreen({super.key, required this.destination, this.resetRoute = false});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  RoutePlan? _savedPlan;
  bool _checkingRoute = true;
  String? _routeCheckError;

  @override
  void initState() {
    super.initState();
    if (widget.resetRoute) {
      _checkingRoute = false;
    } else {
      _checkSavedRoute();
    }
  }

  Future<void> _checkSavedRoute() async {
    try {
      final plan = await RouteService.getSaved(widget.destination.id);
      if (!mounted) return;
      setState(() {
        _savedPlan =
            plan.byDay.values.any((spots) => spots.isNotEmpty) ? plan : null;
        if (_savedPlan != null) {
          _selectedPlaces
            ..clear()
            ..addAll(plan.byDay.values.expand((spots) => spots).map((spot) =>
                spot.contentId != null && spot.contentId!.isNotEmpty
                    ? spot.contentId!
                    : '${spot.categoryLabel}:${spot.name}'));
          final lastDay = plan.byDay.keys.reduce((a, b) => a > b ? a : b);
          _selectedTravelPeriod = _travelPeriods[(lastDay - 1).clamp(0, 2)];
        }
        _checkingRoute = false;
        _routeCheckError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checkingRoute = false;
        _routeCheckError = '저장된 경로를 확인하지 못했어요. 다시 시도해주세요.';
      });
    }
  }

  final Set<String> _selectedPlaces = {};
  String? _selectedTravelPeriod;
  static const _travelPeriods = ['당일치기', '1박 2일', '2박 3일'];

  Map<String, List<SavedSpot>> get _placesByCategory {
    final grouped = <String, List<SavedSpot>>{};
    for (final spot in widget.destination.spots) {
      final isDuplicatedRegionName = spot.categoryLabel == '기타' &&
          spot.name.trim() == widget.destination.regionName.trim();
      if (isDuplicatedRegionName) continue;

      grouped.putIfAbsent(spot.categoryLabel, () => []).add(spot);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final placesByCategory = _placesByCategory;
    final spotCount = placesByCategory.values
        .expand((spots) => spots)
        .map((spot) => spot.contentId.isNotEmpty
            ? spot.contentId
            : '${spot.name}:${spot.latitude}:${spot.longitude}')
        .toSet()
        .length;
    final showFewSpotsNotice = spotCount <= 15;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      appBar: AppBar(
        actions: const [HomeLogoButton()],
        title: Text(
          '${widget.destination.regionName} 🌿',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '여행 경로에 추가하고 싶은 스팟을 모두 선택해주세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: placesByCategory.isEmpty
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                          '저장된 장소가 없어요.\n\n사람이 많지 않은 숨겨진 여행지는 추천 장소가 적을 수 있어요😢',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54)),
                    ))
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      itemCount: placesByCategory.length +
                          1 +
                          (showFewSpotsNotice ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildTravelPeriodSection();
                        if (index == placesByCategory.length + 1) {
                          return const Text(
                            '사람이 많지 않은 숨겨진 여행지는 추천 장소가 적을 수 있어요😢',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                height: 1.5),
                          );
                        }
                        final entry =
                            placesByCategory.entries.elementAt(index - 1);
                        return _buildCategorySection(entry.key, entry.value);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A7C59),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _checkingRoute
                      ? null
                      : () async {
                          if (_routeCheckError != null) {
                            setState(() => _checkingRoute = true);
                            await _checkSavedRoute();
                            return;
                          }
                          if (_savedPlan != null) {
                            final result = await Navigator.push<Object>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RouteScreen(
                                    initialPlan: _savedPlan,
                                    savedRegionId: widget.destination.id,
                                    travelPeriod: _selectedTravelPeriod ??
                                        _travelPeriods[
                                            (_savedPlan!.byDay.length - 1)
                                                .clamp(0, 2)],
                                    selectedSpots: widget.destination.spots,
                                  ),
                                ));
                            if (!mounted) return;
                            if (result == 'reset') {
                              setState(() {
                                final previous = _savedPlan!;
                                _selectedTravelPeriod = _travelPeriods[
                                    (previous.byDay.length - 1).clamp(0, 2)];
                                _selectedPlaces
                                  ..clear()
                                  ..addAll(previous.byDay.values
                                      .expand((spots) => spots)
                                      .map((spot) =>
                                          spot.contentId ??
                                          '${spot.categoryLabel}:${spot.name}'));
                                _savedPlan = null;
                              });
                            }
                            return;
                          }
                          if (_selectedTravelPeriod == null) {
                            _showTravelPeriodRequiredDialog();
                            return;
                          }
                          debugPrint('선택된 장소들: $_selectedPlaces');
                          final result = await Navigator.push<Object>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RouteScreen(
                                savedRegionId: widget.destination.id,
                                travelPeriod: _selectedTravelPeriod!,
                                selectedSpots: widget.destination.spots
                                    .where((spot) => _selectedPlaces.contains(spot
                                            .contentId.isNotEmpty
                                        ? spot.contentId
                                        : '${spot.categoryLabel}:${spot.name}'))
                                    .toList(growable: false),
                              ),
                            ),
                          );
                          if (!mounted) return;
                          if (result != 'reset') await _checkSavedRoute();
                        },
                  child: Text(
                    _checkingRoute
                        ? '경로 확인 중...'
                        : _routeCheckError != null
                            ? '경로 확인 다시 시도'
                            : _savedPlan != null
                                ? '경로 확인하기'
                                : '이대로 경로 작성하기',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelPeriodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 20, color: Color(0xFF4A7C59)),
            SizedBox(width: 8),
            Text(
              '여행기간',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F5),
            border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (var index = 0; index < _travelPeriods.length; index++) ...[
                Expanded(
                  child: _buildTravelPeriodOption(_travelPeriods[index]),
                ),
                if (index < _travelPeriods.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTravelPeriodOption(String period) {
    final isSelected = _selectedTravelPeriod == period;
    return GestureDetector(
      onTap: () async {
        if (_selectedTravelPeriod == period) return;
        if (!await _confirmSelectionChange() || !mounted) return;
        setState(() => _selectedTravelPeriod = period);
      },
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A7C59) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4A7C59) : const Color(0xFFF0F0F0),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          period,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  bool _isRestaurant(SavedSpot spot) {
    final category = spot.categoryLabel;
    return category.contains('식당') ||
        category.contains('음식') ||
        category.contains('맛집');
  }

  ({int restaurant, int other}) get _selectionLimits {
    return switch (_selectedTravelPeriod) {
      '당일치기' => (restaurant: 3, other: 5),
      '1박 2일' => (restaurant: 6, other: 10),
      '2박 3일' => (restaurant: 9, other: 15),
      _ => (restaurant: 0, other: 0),
    };
  }

  Future<void> _showSelectionLimitDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: const Text(
          '선택 가능한 스팟 수를 확인해주세요😢',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  bool _confirmingReset = false;

  Future<bool> _confirmSelectionChange() async {
    if (_checkingRoute || _routeCheckError != null || _confirmingReset)
      return false;
    if (_savedPlan == null) return true;
    _confirmingReset = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: const Text('경로를 재설정하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니요', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('예', style: TextStyle(color: Color(0xFF4A7C59)))),
        ],
      ),
    );
    _confirmingReset = false;
    if (!mounted || confirmed != true) return false;
    setState(() => _savedPlan = null);
    return true;
  }

  Future<void> _toggleSpotSelection(SavedSpot place) async {
    final selectionKey = place.contentId.isNotEmpty
        ? place.contentId
        : '${place.categoryLabel}:${place.name}';
    final isSelected = _selectedPlaces.contains(selectionKey);
    if (isSelected) {
      if (!await _confirmSelectionChange() || !mounted) return;
      setState(() => _selectedPlaces.remove(selectionKey));
      return;
    }

    if (_selectedTravelPeriod == null) {
      await _showSelectionLimitDialog('먼저 여행기간을 선택해주세요.');
      return;
    }

    final limits = _selectionLimits;
    final selectedRestaurantCount = widget.destination.spots
        .where((spot) => _selectedPlaces.contains(spot.contentId.isNotEmpty
            ? spot.contentId
            : '${spot.categoryLabel}:${spot.name}'))
        .where(_isRestaurant)
        .length;
    final selectedOtherCount = _selectedPlaces.length - selectedRestaurantCount;
    final selectingRestaurant = _isRestaurant(place);
    final nextCount = selectingRestaurant
        ? selectedRestaurantCount + 1
        : selectedOtherCount + 1;
    final limit = selectingRestaurant ? limits.restaurant : limits.other;

    if (nextCount > limit) {
      await _showSelectionLimitDialog(
        selectingRestaurant
            ? '식당은 최대 ${limits.restaurant}개까지 선택가능해요!'
            : '식당 외 스팟은 최대 ${limits.other}개까지 선택가능해요!',
      );
      return;
    }

    if (!await _confirmSelectionChange() || !mounted) return;
    setState(() => _selectedPlaces.add(selectionKey));
  }

  Future<void> _showTravelPeriodRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: const Text('여행기간을 선택해주세요'),
        content: const Text('코스를 작성하려면 여행기간을 먼저 선택해야 해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String categoryName, List<SavedSpot> places) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_iconForCategory(categoryName),
                size: 20, color: const Color(0xFF4A7C59)),
            const SizedBox(width: 8),
            Text(
              categoryName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F5),
            border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              for (var index = 0; index < places.length; index++) ...[
                _buildPlaceItem(places[index]),
                if (index < places.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceItem(SavedSpot place) {
    final selectionKey = place.contentId.isNotEmpty
        ? place.contentId
        : '${place.categoryLabel}:${place.name}';
    final isSelected = _selectedPlaces.contains(selectionKey);

    return GestureDetector(
      onTap: () => _toggleSpotSelection(place),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF3EA) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4A7C59) : const Color(0xFFF0F0F0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                place.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF4A7C59)
                      : const Color(0xFF333333),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFDDE9D9)
                    : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: GestureDetector(
                onTap: () => _showSpotMap(place),
                child: Icon(
                  Icons.map_rounded,
                  color: isSelected
                      ? const Color(0xFF4A7C59)
                      : Colors.grey.shade400,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNaverMap(SavedSpot spot) async {
    final query = '${widget.destination.regionName} ${spot.name}';
    final uri = Uri(
      scheme: 'https',
      host: 'map.naver.com',
      pathSegments: ['p', 'search', query],
    );
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Show the same retry guidance when the platform cannot open the link.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('네이버 지도를 열지 못했어요. 잠시 후 다시 시도해주세요.')),
    );
  }

  Future<void> _showSpotMap(SavedSpot spot) async {
    final latitude = spot.latitude;
    final longitude = spot.longitude;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: Text(
          spot.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: latitude == null || longitude == null
              ? const Center(child: Text('이 스팟의 위치 정보가 없어요.'))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: NLatLng(latitude, longitude),
                        zoom: 15,
                      ),
                      logoClickEnable: false,
                    ),
                    onMapReady: (controller) {
                      controller.addOverlay(
                        NMarker(
                          id: 'spot_${spot.contentId}_${spot.name}',
                          position: NLatLng(latitude, longitude),
                          caption: NOverlayCaption(text: spot.name),
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _openNaverMap(spot),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A7C59),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new_rounded, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      spot.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  // Balance the leading icon so the text itself is centered.
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    if (category.contains('카페')) return Icons.local_cafe_rounded;
    if (category.contains('식당') ||
        category.contains('음식') ||
        category.contains('맛집')) {
      return Icons.restaurant_rounded;
    }
    if (category.contains('숙박') || category.contains('호텔')) {
      return Icons.hotel_rounded;
    }
    if (category.contains('쇼핑')) return Icons.shopping_bag_rounded;
    if (category.contains('전시') || category.contains('문화')) {
      return Icons.museum_rounded;
    }
    if (category.contains('관광') || category.contains('여행')) {
      return Icons.camera_alt_rounded;
    }
    return Icons.place_rounded;
  }
}
