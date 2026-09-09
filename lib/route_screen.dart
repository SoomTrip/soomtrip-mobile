import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 🌟 네이버 지도 임포트

import 'route_service.dart';
import 'saved_region_service.dart';

class RouteScreen extends StatefulWidget {
  final int savedRegionId;
  final String travelPeriod;
  final List<SavedSpot> selectedSpots;

  const RouteScreen({
    super.key,
    required this.savedRegionId,
    required this.travelPeriod,
    required this.selectedSpots,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final ScrollController _scrollController = ScrollController();

  // 애니메이션 상태 변수
  int _currentFrame = 1;
  bool _isFacingRight = true;
  double _lastOffset = 0.0;
  final List<int> _walkSequence = [1, 2, 3, 4, 3, 2];

  // 🌟 네이버 지도 컨트롤러
  NaverMapController? _mapController;
  Future<NOverlayImage?>? _spotIconFuture;
  int _selectedDay = 1;
  bool _showRouteList = false;
  RoutePlan? _routePlan;
  bool _isLoading = true;
  String? _errorMessage;

  int get _dayCount => switch (widget.travelPeriod) {
        '1박 2일' => 2,
        '2박 3일' => 3,
        _ => 1,
      };

  List<RouteSpot> get _currentSpots =>
      _routePlan?.byDay[_selectedDay] ?? const <RouteSpot>[];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    if (widget.selectedSpots.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '경로에 추가할 스팟을 하나 이상 선택해주세요.';
      });
      return;
    }

    try {
      final plan = await RouteService.optimize(
        spots: widget.selectedSpots,
        dayCount: _dayCount,
        mobilityChoice: 'car',
      );
      await RouteService.save(
        savedRegionId: widget.savedRegionId,
        plan: plan,
        mobilityChoice: 'car',
      );
      RoutePlan savedPlan = plan;
      try {
        final loadedPlan = await RouteService.getSaved(widget.savedRegionId);
        if (loadedPlan.byDay.isNotEmpty) savedPlan = loadedPlan;
      } catch (_) {
        // Keep the freshly optimized plan if loading the saved copy fails.
      }
      debugPrint('[Route Screen] selected day: $_selectedDay, spots: '
          '${savedPlan.byDay[_selectedDay]?.length ?? 0}');
      if (!mounted) return;
      setState(() {
        _routePlan = savedPlan;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    double currentOffset = _scrollController.offset;
    if (currentOffset > _lastOffset)
      _isFacingRight = true;
    else if (currentOffset < _lastOffset) _isFacingRight = false;
    _lastOffset = currentOffset;

    int sequenceIndex =
        (currentOffset.abs() / 15).floor() % _walkSequence.length;
    int nextFrame = _walkSequence[sequenceIndex];
    if (_currentFrame != nextFrame) setState(() => _currentFrame = nextFrame);
  }

  // 🌟 지도에 마커와 선을 그리는 함수
  Future<NOverlayImage?> _loadSpotIcon() async {
    try {
      final data = await rootBundle.load('assets/images/spot.png');
      return await NOverlayImage.fromByteArray(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (error) {
      debugPrint('[Route Map] Failed to load spot icon: $error');
      return null;
    }
  }

  Future<void> _drawRouteOnMap() async {
    final controller = _mapController;
    if (controller == null) return;
    final spots = List<RouteSpot>.of(_currentSpots);
    final icon = await (_spotIconFuture ??= _loadSpotIcon());
    if (!mounted || !identical(controller, _mapController)) return;

    List<NLatLng> pathPoints = [];

    for (int i = 0; i < spots.length; i++) {
      final spot = spots[i];
      final latitude = spot.latitude;
      final longitude = spot.longitude;
      if (latitude == null || longitude == null) continue;
      final position = NLatLng(latitude, longitude);
      pathPoints.add(position);

      // 1. 마커(점) 찍기
      final marker = NMarker(
        id: 'marker_$i',
        position: position,
        icon: icon,
        size: const Size(40, 50),
        caption: NOverlayCaption(
          text: spot.name,
          textSize: 14,
        ),
      );
      try {
        await controller.addOverlay(marker);
      } catch (error) {
        if (!mounted || !identical(controller, _mapController)) return;
        debugPrint('[Route Map] Failed to add custom marker: $error');
        await controller.addOverlay(NMarker(
          id: 'marker_$i',
          position: position,
          caption: NOverlayCaption(text: spot.name, textSize: 16),
        ));
      }
      if (!mounted || !identical(controller, _mapController)) return;
    }

    // 2. 경로 선(폴리라인) 긋기
    if (pathPoints.length > 1) {
      final polyline = NPolylineOverlay(
        id: 'route_line',
        coords: pathPoints,
        color: const Color(0xFF4A7C59), // 숨트립 초록색
        width: 4, // 선 굵기
      );
      await controller.addOverlay(polyline);
      if (!mounted || !identical(controller, _mapController)) return;

      // 3. 모든 경로가 한눈에 보이도록 카메라 줌 자동 조절
      final cameraUpdate = NCameraUpdate.fitBounds(
        NLatLngBounds.from(pathPoints),
        padding: const EdgeInsets.all(50),
      );
      await controller.updateCamera(cameraUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBF9F4),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A7C59)),
              SizedBox(height: 20),
              Text(
                '추천 경로를 작성중이에요..🖌️',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A7C59),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBF9F4),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text(_errorMessage!, textAlign: TextAlign.center)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("추천 경로",
            style: TextStyle(
                color: Color(0xFF333333),
                fontWeight: FontWeight.bold,
                fontFamily: 'CustomHandwriting',
                fontSize: 24)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_dayCount > 1) _buildDayTabs(),
            Expanded(child: _buildRouteContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE7E2D8)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            for (var day = 1; day <= _dayCount; day++) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (_selectedDay != day) _mapController = null;
                    _selectedDay = day;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedDay == day
                          ? const Color(0xFF4A7C59)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '$day일차',
                      style: TextStyle(
                        color: _selectedDay == day
                            ? Colors.white
                            : const Color(0xFF777777),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              if (day < _dayCount) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final showList in [false, true])
            Expanded(
              child: TextButton.icon(
                onPressed: () => setState(() {
                  if (_showRouteList != showList) _mapController = null;
                  _showRouteList = showList;
                }),
                icon: Icon(showList ? Icons.format_list_numbered : Icons.map_outlined,
                    size: 18),
                label: Text(showList ? '목록' : '지도'),
                style: TextButton.styleFrom(
                  backgroundColor: _showRouteList == showList
                      ? const Color(0xFF4A7C59) : Colors.transparent,
                  foregroundColor: _showRouteList == showList
                      ? Colors.white : const Color(0xFF777777),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteList() {
    final spots = _currentSpots;
    if (spots.isEmpty) return const Center(child: Text('이날의 여행 경로가 없어요.'));
    return ListView.separated(
      key: ValueKey('route-list-$_selectedDay'),
      padding: const EdgeInsets.all(16),
      itemCount: spots.length,
      separatorBuilder: (_, __) => const Divider(height: 20),
      itemBuilder: (context, index) {
        final spot = spots[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFFEEF3EA),
              child: Text('${index + 1}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4A7C59))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${spot.categoryLabel}: ${spot.name}',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRouteContent() {
    return Column(
      children: [
            _buildViewTabs(),
            // ==========================================
            // 1. 상단: 진짜 네이버 지도 영역 (Flex: 5)
            // ==========================================
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF9F4),
                  border: Border.all(color: Colors.black87, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ],
                ),
                // 🌟 더미 텍스트를 지우고 NaverMap 위젯 삽입!
                child: _showRouteList ? _buildRouteList() : NaverMap(
                  key: ValueKey(_selectedDay),
                  options: const NaverMapViewOptions(
                    mapType: NMapType.basic,
                    logoClickEnable: false, // 네이버 로고 클릭 방지
                  ),
                  onMapReady: (controller) {
                    _mapController = controller;
                    _drawRouteOnMap(); // 지도가 로딩되면 마커와 선을 그림
                  },
                ),
              ),
            ),

            // ==========================================
            // 2. 하단: 횡스크롤 애니메이션 영역 (기존 유지)
            // ==========================================
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Image.asset('assets/images/road.png',
                        height: 64, fit: BoxFit.cover),
                  ),
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification)
                        setState(() => _currentFrame = 1);
                      return false;
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 100),
                      itemCount: _currentSpots.length,
                      separatorBuilder: (context, index) => SizedBox(
                        width: 110,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 72),
                            child: Text(
                              _travelTime(_currentSpots[index + 1]),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4A7C59),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        return _buildSpotItem(_currentSpots[index]);
                      },
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 25,
                    child: Transform.scale(
                      scaleX: _isFacingRight ? 1 : -1,
                      child: Image.asset(
                          'assets/images/walk_$_currentFrame.png',
                          width: 100,
                          height: 120,
                          fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
          ],
    );
  }

  // 하단 아이템 렌더링 (기존 동일)[cite: 4]
  Widget _buildSpotItem(RouteSpot spot) {
    return SizedBox(
      width: 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 15,
            left: 15,
            child: SizedBox(
              width: 150,
              height: 300,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Image.asset('assets/images/sign.png',
                      width: 120, height: 320, fit: BoxFit.fill),
                  Positioned(
                    top: 20,
                    left: 16,
                    right: 16,
                    height: 88,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(spot.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                fontFamily: 'CustomHandwriting')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _travelTime(RouteSpot spot) {
    final minutes = spot.durationFromPreviousMinutes;
    if (minutes == null) return '경로 정보를\n가져올 수 없습니다';
    final mode = switch (spot.mobilityChoice) {
      'walk_transit' => '도보',
      'car' => '자차',
      _ => '이동',
    };
    return '$mode $minutes분';
  }
}
