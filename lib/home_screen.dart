import 'package:flutter/material.dart';

import 'diary_entry_service.dart';
import 'my_destination_screen.dart';
import 'saved_region_service.dart';

class StampData {
  final String name;
  final String assetPath; // 각각 다른 도장 이미지 경로

  const StampData({required this.name, required this.assetPath});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _stampsPerPage = 5;
  static const double _stampSize = 130.0;

  final PageController _pageController = PageController();
  int _currentPage = 0;
    final List<StampData> myStamps = [];
    bool _isLoading = true;
    String? _errorMessage;

  // 🌟 위쪽 두 줄에 2개씩, 마지막 도장은 3행 중앙에 배치
  List<Map<String, double>> get pageSlots => [
    {'dx': 0.15, 'dy': 0.12, 'angle': -0.05}, // 1행 1열
    {'dx': 0.53, 'dy': 0.18, 'angle': 0.07}, // 1행 2열
    {'dx': 0.11, 'dy': 0.40, 'angle': 0.06}, // 2행 1열
    {'dx': 0.48, 'dy': 0.44, 'angle': -0.03}, // 2행 2열
    {'dx': 0.27, 'dy': 0.66, 'angle': -0.08}, // 3행 중앙
  ];

  @override
  void dispose() {
    DiaryEntryService.entriesChanged.removeListener(_loadStamps);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    DiaryEntryService.entriesChanged.addListener(_loadStamps);
    _loadStamps();
  }

  Future<void> _loadStamps() async {
    try {
      final stamps = await StampService.getStamps();
      if (!mounted) return;
      setState(() {
        myStamps
          ..clear()
          ..addAll([
            for (final stamp in stamps)
              StampData(
                name: stamp.regionName,
                assetPath: _assetPathFor(stamp.assetKey),
              ),
          ]);
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _assetPathFor(String assetKey) {
    final normalizedKey = assetKey.startsWith('stamp')
        ? assetKey
        : 'stamp$assetKey';
    final stampNumber = int.tryParse(normalizedKey.replaceFirst('stamp', ''));
    if (stampNumber == null || stampNumber < 1 || stampNumber > 6) {
      return 'assets/images/stamp1.png';
    }
    return 'assets/images/$normalizedKey.png';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadStamps, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    // 총 필요한 페이지 수 계산 (최소 1페이지)
    int totalPages = (myStamps.length / _stampsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("숨트립 🌱",
            style: TextStyle(
                color: Color(0xFF4A7C59),
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text("이번 여행도 한 장 남겨볼까요? 🌱",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555))),
            const SizedBox(height: 16),

            // ==========================================
            // 1. 도화지 및 페이징 도장판 영역
            // ==========================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  children: [
                    // 배경 도화지 이미지 고정
                    Positioned.fill(
                      child: Image.asset('assets/images/stamp_bg.png',
                          fit: BoxFit.fill),
                    ),

                    // PageView로 좌우 스와이프 기능 추가
                    PageView.builder(
                      controller: _pageController,
                      itemCount: totalPages,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                      },
                      itemBuilder: (context, pageIndex) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children:
                                  List.generate(_stampsPerPage, (slotIndex) {
                                int stampIndex =
                                    (pageIndex * _stampsPerPage) + slotIndex;
                                StampData? stampData =
                                    stampIndex < myStamps.length
                                        ? myStamps[stampIndex]
                                        : null;
                                var slot = pageSlots[slotIndex];

                                return Positioned(
                                  left: constraints.maxWidth * slot['dx']!,
                                  top: constraints.maxHeight * slot['dy']!,
                                  child: Transform.rotate(
                                    angle: slot['angle']!,
                                    child: _buildStampItem(stampData),
                                  ),
                                );
                              }),
                            );
                          },
                        );
                      },
                    ),

                    // 좌우 이동 화살표 가이드 (선택 사항)
                    Positioned(
                      left: 5,
                      top: 0,
                      bottom: 0,
                      child: Center(
                          child: Icon(Icons.chevron_left,
                              color: Colors.black.withOpacity(0.2), size: 30)),
                    ),
                    Positioned(
                      right: 5,
                      top: 0,
                      bottom: 0,
                      child: Center(
                          child: Icon(Icons.chevron_right,
                              color: Colors.black.withOpacity(0.2), size: 30)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                final isCurrentPage = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentPage
                        ? const Color(0xFF4A7C59)
                        : const Color(0xFFD5DED2),
                  ),
                );
              }),
            ),

            // ==========================================
            // 2. 하단 진행도 및 버튼
            // ==========================================
            const SizedBox(height: 12),
            Text("여행 도장 ${myStamps.length}개 획득!",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MyDestinationsScreen()),
                );
              },
              icon: const Icon(Icons.approval, color: Colors.white),
              label: const Text("일기 쓰고 도장 받기 🌱",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF86B971),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 🌟 도장 이미지 위에 텍스트를 오버레이하는 위젯
  Widget _buildStampItem(StampData? data) {
    if (data == null) {
      return const SizedBox(width: _stampSize, height: _stampSize);
    }

    return SizedBox(
      width: _stampSize,
      height: _stampSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            data.assetPath,
            width: _stampSize,
            height: _stampSize,
            fit: BoxFit.contain,
          ),

          Positioned(
            left: 23,
            right: 23,
            bottom: 41,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.name,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
