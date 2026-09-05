import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 🌟 네이버 지도 임포트

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

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

  // 🌟 테스트 코스 데이터 (위도/경도 추가)
  final List<Map<String, dynamic>> routeSpots = [
    {
      'name': '올디벗구디',
      'type': '카페',
      'time': '도보 8분',
      'lat': 33.245,
      'lng': 126.412
    },
    {
      'name': '중문시장',
      'type': '식당',
      'time': '도보 15분',
      'lat': 33.249,
      'lng': 126.418
    },
    {
      'name': '해양레저',
      'type': '액티비티',
      'time': '차량 10분',
      'lat': 33.241,
      'lng': 126.425
    },
    {'name': '숙소', 'type': '휴식', 'time': '', 'lat': 33.255, 'lng': 126.410},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
  void _drawRouteOnMap() {
    if (_mapController == null) return;

    List<NLatLng> pathPoints = [];

    for (int i = 0; i < routeSpots.length; i++) {
      final spot = routeSpots[i];
      final position = NLatLng(spot['lat'], spot['lng']);
      pathPoints.add(position);

      // 1. 마커(점) 찍기
      final marker = NMarker(
        id: 'marker_$i',
        position: position,
        caption: NOverlayCaption(text: spot['name']),
      );
      _mapController!.addOverlay(marker);
    }

    // 2. 경로 선(폴리라인) 긋기
    if (pathPoints.length > 1) {
      final polyline = NPolylineOverlay(
        id: 'route_line',
        coords: pathPoints,
        color: const Color(0xFF4A7C59), // 숨트립 초록색
        width: 4, // 선 굵기
      );
      _mapController!.addOverlay(polyline);

      // 3. 모든 경로가 한눈에 보이도록 카메라 줌 자동 조절
      final cameraUpdate = NCameraUpdate.fitBounds(
        NLatLngBounds.from(pathPoints),
        padding: const EdgeInsets.all(50),
      );
      _mapController!.updateCamera(cameraUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // ==========================================
            // 1. 상단: 진짜 네이버 지도 영역 (Flex: 5)
            // ==========================================
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
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
                child: NaverMap(
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
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: routeSpots.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0 || index == routeSpots.length + 1)
                          return const SizedBox(width: 100);
                        return _buildSpotItem(routeSpots[index - 1],
                            isLast: (index == routeSpots.length));
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
        ),
      ),
    );
  }

  // 하단 아이템 렌더링 (기존 동일)[cite: 4]
  Widget _buildSpotItem(Map<String, dynamic> spot, {required bool isLast}) {
    return SizedBox(
      width: 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!isLast)
            Positioned(
              bottom: 72,
              right: -30,
              child: Text(spot['time'],
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'CustomHandwriting')),
            ),
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
                        child: Text(spot['name'],
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
}
