import 'home_logo_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 🌟 네이버 지도 임포트

import 'route_service.dart';
import 'route_sign_label.dart';
import 'saved_region_service.dart';

class RouteScreen extends StatefulWidget {
  final RoutePlan? initialPlan;
  final int savedRegionId;
  final String travelPeriod;
  final List<SavedSpot> selectedSpots;

  const RouteScreen({
    super.key,
    this.initialPlan,
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
  NPolylineOverlay? _routePolyline;
  List<NLatLng> _routePathPoints = const [];
  bool _isAnimatingRoute = false;
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

  List<int> get _routeDays => List.generate(_dayCount, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialPlan != null) {
      _routePlan = widget.initialPlan;
      _selectedDay = _routePlan!.byDay.keys.reduce((a, b) => a < b ? a : b);
      _isLoading = false;
    } else {
      _loadRoute();
    }
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
        savedRegionId: widget.savedRegionId,
        spots: widget.selectedSpots,
        dayCount: _dayCount,
      );
      final savedPlan = plan;
      debugPrint('[Route Screen] selected day: $_selectedDay, spots: '
          '${savedPlan.byDay[_selectedDay]?.length ?? 0}');
      if (!mounted) return;
      setState(() {
        _routePlan = savedPlan;
        _dirty = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '여행 경로 불러오기 실패';
      });
    }
  }

  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;

  Future<void> _leave({bool home = false}) async {
    if (_saving || _isLoading) return;
    setState(() => _saving = true);
    try {
      if (_dirty && _routePlan != null) {
        await RouteService.save(
            savedRegionId: widget.savedRegionId, plan: _routePlan!);
        _dirty = false;
      }
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (home) {
          HomeLogoButton.goHome(context);
        } else {
          Navigator.pop(context);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('경로 저장에 실패했어요. 뒤로가기를 눌러 다시 시도해주세요.')));
    }
  }

  Future<void> _resetRoute() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFFFBF9F4),
              title: const Text('경로를 재설정 하시겠습니까?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('재설정',
                        style: TextStyle(color: Color(0xFF4A7C59)))),
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, 'reset');
    });
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
      _routePolyline = polyline;
      _routePathPoints = pathPoints;

      // 3. 모든 경로가 한눈에 보이도록 카메라 줌 자동 조절
      final cameraUpdate = NCameraUpdate.fitBounds(
        NLatLngBounds.from(pathPoints),
        padding: const EdgeInsets.all(50),
      );
      await controller.updateCamera(cameraUpdate);
    }
  }

  // 🌟 '경로보기' 버튼: 첫 스팟부터 마지막 스팟까지 선이 그려지는 과정을 애니메이션으로 보여줌
  Future<void> _animateRouteDrawing() async {
    final polyline = _routePolyline;
    final points = _routePathPoints;
    if (polyline == null || points.length < 2 || _isAnimatingRoute) return;

    setState(() => _isAnimatingRoute = true);
    try {
      // 구간마다 점을 촘촘히 보간해서 순간이동이 아니라 선이 자라나는 것처럼 보이게 함
      const stepsPerSegment = 24;
      final animatedPoints = <NLatLng>[points.first];
      for (var i = 0; i < points.length - 1; i++) {
        final start = points[i];
        final end = points[i + 1];
        for (var step = 1; step <= stepsPerSegment; step++) {
          final t = step / stepsPerSegment;
          animatedPoints.add(NLatLng(
            start.latitude + (end.latitude - start.latitude) * t,
            start.longitude + (end.longitude - start.longitude) * t,
          ));
        }
      }

      polyline.setCoords([animatedPoints.first]);
      for (var revealed = 2; revealed <= animatedPoints.length; revealed++) {
        if (!mounted || !identical(polyline, _routePolyline)) return;
        polyline.setCoords(animatedPoints.sublist(0, revealed));
        await Future.delayed(const Duration(milliseconds: 16));
      }
    } finally {
      if (mounted) setState(() => _isAnimatingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: _buildScreen(context),
      );

  Widget _buildScreen(BuildContext context) {
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
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87),
            onPressed: _saving ? null : () => _leave()),
        actions: [
          if (_dayCount > 1) _buildDayTabs(),
          IconButton(
              tooltip: '경로 재설정',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _saving ? null : _resetRoute),
          HomeLogoButton(onPressed: () => _leave(home: true)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildRouteContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTabs() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final day in _routeDays) ...[
          GestureDetector(
            onTap: () => setState(() {
              if (_selectedDay != day) _mapController = null;
              _selectedDay = day;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selectedDay == day
                    ? const Color(0xFF4A7C59)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE7E2D8)),
              ),
              child: Text(
                '$day일차',
                style: TextStyle(
                  color: _selectedDay == day
                      ? Colors.white
                      : const Color(0xFF777777),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          if (day != _routeDays.last) const SizedBox(width: 6),
        ],
      ],
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
                icon: Icon(
                    showList ? Icons.format_list_numbered : Icons.map_outlined,
                    size: 18),
                label: Text(showList ? '목록' : '지도'),
                style: TextButton.styleFrom(
                  backgroundColor: _showRouteList == showList
                      ? const Color(0xFF4A7C59)
                      : Colors.transparent,
                  foregroundColor: _showRouteList == showList
                      ? Colors.white
                      : const Color(0xFF777777),
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
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF4A7C59))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${spot.categoryLabel}: ${spot.name}',
                style: const TextStyle(
                  fontSize: 18,
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

  // 🌟 지도를 확대/이동해서 봤어도 전체 경로가 한눈에 보이는 초기 시점으로 되돌리는 버튼
  Future<void> _resetCameraToRoute() async {
    final controller = _mapController;
    final points = _routePathPoints;
    if (controller == null || points.length < 2) return;
    await controller.updateCamera(NCameraUpdate.fitBounds(
      NLatLngBounds.from(points),
      padding: const EdgeInsets.all(50),
    ));
  }

  Widget _buildResetCameraButton() {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _resetCameraToRoute,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.my_location_rounded, size: 22, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildRouteViewButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isAnimatingRoute ? null : _animateRouteDrawing,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4A7C59), width: 1.5),
          ),
          child: const Text('경로보기',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A7C59))),
        ),
      ),
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
            decoration: BoxDecoration(
              color: const Color(0xFFFBF9F4),
              border: Border.all(color: Colors.black87, width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
              ],
            ),
            // 🌟 NaverMap은 네이티브 뷰라 Container의 clipBehavior만으로는
            // 모서리가 완전히 잘리지 않아서 ClipRRect로 한 번 더 감싼다.
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _showRouteList
                  ? _buildRouteList()
                  : Stack(children: [
                      NaverMap(
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
                      Positioned(
                          left: 12, top: 12, child: _buildRouteViewButton()),
                      Positioned(
                          right: 12,
                          bottom: 12,
                          child: _buildResetCameraButton()),
                    ]),
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
                    width: 48,
                    child: Align(
                      alignment: const Alignment(0.5, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 72),
                        child: Transform.translate(
                          offset: const Offset(-20, 0),
                          child: OverflowBox(
                            minWidth: 160,
                            maxWidth: 160,
                            child: Text(
                              _travelTime(_currentSpots[index + 1]),
                              maxLines: 2,
                              softWrap: true,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _travelTime(_currentSpots[index + 1])
                                        .contains('\n')
                                    ? 16
                                    : 18,
                                color: Color(0xFF4A7C59),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                  child: Image.asset('assets/images/walk_$_currentFrame.png',
                      width: 100, height: 120, fit: BoxFit.contain),
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
            bottom: 35,
            left: 15,
            child: SizedBox(
              width: 120,
              height: 270,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Image.asset('assets/images/sign.png',
                      width: 120, height: 300, fit: BoxFit.fill),
                  Positioned(
                    top: 25,
                    left: 24,
                    right: 24,
                    height: 60,
                    child: RouteSignLabel(name: spot.name),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _travelTime(RouteSpot spot) => spot.travelLabel();
}
