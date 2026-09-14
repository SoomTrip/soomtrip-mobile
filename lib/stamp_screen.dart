import 'package:flutter/material.dart';

import 'diary_entry_service.dart';
import 'home_logo_button.dart';
import 'my_destination_screen.dart';
import 'picture_diary_screen.dart';
import 'saved_region_service.dart';

class StampData {
  final String name;
  final String assetPath; // 각각 다른 도장 이미지 경로
  final int savedRegionId;

  const StampData({
    required this.name,
    required this.assetPath,
    required this.savedRegionId,
  });
}

class StampScreen extends StatefulWidget {
  const StampScreen({super.key});

  @override
  State<StampScreen> createState() => _StampScreenState();
}

class _StampScreenState extends State<StampScreen> {
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
            for (final stamp in stamps.reversed)
              StampData(
                name: stamp.regionName,
                assetPath: _assetPathFor(stamp.assetKey),
                savedRegionId: stamp.savedRegionId,
              ),
          ]);
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '도장 불러오기 실패';
        _isLoading = false;
      });
    }
  }

  String _assetPathFor(String assetKey) {
    final normalizedKey =
        assetKey.startsWith('stamp') ? assetKey : 'stamp$assetKey';
    final stampNumber = int.tryParse(normalizedKey.replaceFirst('stamp', ''));
    if (stampNumber == null || stampNumber < 1 || stampNumber > 6) {
      return 'assets/images/stamp1.png';
    }
    return 'assets/images/$normalizedKey.png';
  }

  // 🌟 도장을 탭하면 해당 여행지의 그림일기를 실제 다이어리 모양 그대로 팝업에 보여줌
  void _onStampTapped(StampData stamp) {
    final entryFuture = DiaryEntryService.getBySavedRegion(stamp.savedRegionId);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return FutureBuilder<DiaryEntry?>(
          future: entryFuture,
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState != ConnectionState.done;
            final hasError = snapshot.hasError;
            final entry = snapshot.data;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
              child: isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                    )
                  : hasError
                      ? _buildDiaryMessageCard(
                          dialogContext,
                          snapshot.error
                              .toString()
                              .replaceFirst('Exception: ', ''),
                        )
                      : entry == null
                          ? _buildDiaryMessageCard(
                              dialogContext,
                              '아직 작성한 일기가 없어요. 🥲',
                              actionLabel: '일기 쓰기',
                              onAction: () {
                                Navigator.pop(dialogContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PictureDiaryScreen(
                                      savedRegionId: stamp.savedRegionId,
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildDiaryCard(dialogContext, stamp, entry),
            );
          },
        );
      },
    );
  }

  // 🌟 picture_diary_screen.dart와 동일한 패딩/비율로 다이어리 배경(diary.png)을 재사용한 미리보기 카드
  // (diary.png 자체에는 제목 자리가 없어서 picture_diary_screen.dart처럼 제목은 카드 바깥 헤더에 둠)
  Widget _buildDiaryCard(
      BuildContext dialogContext, StampData stamp, DiaryEntry entry) {
    final imageUrl = entry.signedImageUrl ?? entry.imageUrl;
    final message = entry.message?.trim();
    final title = entry.title?.trim().isNotEmpty == true
        ? entry.title!.trim()
        : stamp.name;

    void goToEdit() {
      Navigator.pop(dialogContext);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PictureDiaryScreen(
            savedRegionId: stamp.savedRegionId,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 일기 내부를 탭하면 바로 수정 화면으로 이동 (바깥 회색 영역을 탭하면 다이얼로그가 닫힘)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: goToEdit,
          child: AspectRatio(
            aspectRatio: 828 / 1141, // diary.png 원본 비율
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      Image.asset('assets/images/diary.png', fit: BoxFit.fill),
                ),
                // diary.png 원본 픽셀(828x1141)을 직접 분석해서 얻은 흰 종이 영역 비율.
                // (picture_diary_screen.dart는 화면 크기에 맞춰 이미지를 늘려서 쓰기 때문에
                //  그 화면의 고정 padding/flex 값을 그대로 쓰면 원본 비율을 유지하는
                //  이 팝업에서는 어긋난다 — 그래서 원본 이미지 좌표 기준으로 다시 계산함)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 실측값(48/828, 46/828, 48/1141)에 여유 버퍼를 더해
                      // 제목·날짜·날씨가 흰 종이 경계에 더 안쪽으로 들어오게 함
                      final bodyFontSize =
                          (constraints.maxHeight * (74.4 / 1141) / 2.2)
                              .clamp(10.0, 20.0);
                      return Padding(
                        padding: EdgeInsets.only(
                          top: constraints.maxHeight * (52 / 1141),
                          bottom: constraints.maxHeight * (56 / 1141),
                          left: constraints.maxWidth * (64 / 828),
                          right: constraints.maxWidth * (60 / 828),
                        ),
                        child: Column(
                          children: [
                            // [상단 영역] 왼쪽엔 제목, 오른쪽엔 날짜 + 날씨 (실측 헤더 띠 93/1141)
                            Expanded(
                              flex: 93,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'CustomFont'),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 7,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                              width: constraints.maxWidth *
                                                  (64 / 828)),
                                          Text(_formatDiaryDate(entry.date),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'CustomFont')),
                                          const SizedBox(width: 10),
                                          Icon(_weatherIconFor(entry.weather),
                                              size: 20, color: Colors.black87),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // [중단 영역] 그림 (실측 캔버스 영역 583/1141)
                            Expanded(
                              flex: 583,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: imageUrl != null
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                                child: Text('그림을 불러오지 못했어요.',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.black38))),
                                      )
                                    : const Center(
                                        child: Text('그려진 그림이 없어요.',
                                            style: TextStyle(
                                                color: Colors.black38))),
                              ),
                            ),
                            // [하단 영역] 글 — 실측 줄 간격(74.4/1141)에 맞춰
                            // 글자 크기(height:2.2 기준)를 역산해서 인쇄된 줄과 겹치지 않게 함
                            Expanded(
                              flex: 369,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0, vertical: 2.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: SingleChildScrollView(
                                    child: Text(
                                      message?.isNotEmpty == true
                                          ? message!
                                          : '작성된 글이 없어요.',
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                          fontSize: bodyFontSize,
                                          height: 2.2,
                                          fontFamily: 'CustomFont',
                                          color: const Color(0xFF333333)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiaryMessageCard(
    BuildContext dialogContext,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87, fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('닫기',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel,
                      style: const TextStyle(
                          color: Color(0xFF4A7C59),
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _weatherIconFor(String? weather) => switch (weather) {
        'cloudy' => Icons.cloud_queue_rounded,
        'rainy' => Icons.water_drop_outlined,
        'snowy' => Icons.ac_unit_rounded,
        _ => Icons.wb_sunny_outlined,
      };

  String _formatDiaryDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
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
        actions: const [HomeLogoButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text("여행 추억을 남겨볼까요? 🌱",
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
                    // PageView로 좌우 스와이프 기능 추가.
                    // 도화지 배경을 페이지별로 각각 넣어서, 스탬프뿐 아니라
                    // 도장판 자체도 새 판처럼 같이 넘어가게 한다.
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
                              children: [
                                Positioned.fill(
                                  child: Image.asset('assets/images/stamp_bg.png',
                                      fit: BoxFit.fill),
                                ),
                                ...List.generate(_stampsPerPage, (slotIndex) {
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
                                      child: GestureDetector(
                                        onTap: stampData == null
                                            ? null
                                            : () => _onStampTapped(stampData),
                                        child: _buildStampItem(stampData),
                                      ),
                                    ),
                                  );
                                }),
                              ],
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
            Text("도장을 클릭하면 그림일기를 확인할 수 있어요!",
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
              label: const Text("일기 쓰고 도장 받기",
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
          // top과 bottom을 함께 고정해 라벨 칸 높이 자체를 고정시킴.
          // (bottom만 고정하면 이름이 길어져 FittedBox가 줄어들 때 박스 높이도
          //  같이 줄어들어서 아래로 내려간 것처럼 보였음)
          Positioned(
            left: 23,
            right: 23,
            top: 67,
            bottom: 39,
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
