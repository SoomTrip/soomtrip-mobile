import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'gacha_screen.dart'; // 가챠 스크린 연결
import 'preference_service.dart';
import 'recommendation_service.dart';

class RoundItem {
  final String labelA;
  final String wAssetA;
  final String stickerAssetA;
  final Map<String, dynamic> tagA;

  final String labelB;
  final String wAssetB;
  final String stickerAssetB;
  final Map<String, dynamic> tagB;

  RoundItem({
    required this.labelA,
    required this.wAssetA,
    required this.stickerAssetA,
    required this.tagA,
    required this.labelB,
    required this.wAssetB,
    required this.stickerAssetB,
    required this.tagB,
  });
}

class WorldCupScreen extends StatefulWidget {
  const WorldCupScreen({super.key});

  @override
  State<WorldCupScreen> createState() => _WorldCupScreenState();
}

class _WorldCupScreenState extends State<WorldCupScreen> {
  int currentRoundIndex = 0;
  final List<String?> selectedStickers = List.filled(5, null);
  final Map<String, dynamic> finalUserSelection = {};

  double _sliderValue = 50.0;

  // 🌟 진행 상태 및 저장 관련 변수
  bool _isCompleted = false; // 테스트 완료 여부
  bool _showBackgroundEffect = true;
  bool _isSaving = false;
  int? _savedPreferenceId;

  // 🌟 스케치북 이미지 저장을 위한 Key
  final GlobalKey _sketchbookKey = GlobalKey();

  final List<RoundItem> rounds = [
    RoundItem(
        labelA: "바다",
        wAssetA: "assets/images/Wocean.png",
        stickerAssetA: "assets/images/ocean.png",
        tagA: {"theme": "ocean"},
        labelB: "숲",
        wAssetB: "assets/images/Wnature.png",
        stickerAssetB: "assets/images/nature.png",
        tagB: {"theme": "nature"}),
    RoundItem(
        labelA: "뚜벅이",
        wAssetA: "assets/images/Wwalk.png",
        stickerAssetA: "assets/images/walk.png",
        tagA: {"mobility": "walk_transit"},
        labelB: "자차",
        wAssetB: "assets/images/Wcar.png",
        stickerAssetB: "assets/images/car.png",
        tagB: {"mobility": "car"}),
    RoundItem(
        labelA: "혼자 여행",
        wAssetA: "assets/images/Wsolo.png",
        stickerAssetA: "assets/images/solo.png",
        tagA: {"companion": "solo"},
        labelB: "함께 여행",
        wAssetB: "assets/images/Wgroup.png",
        stickerAssetB: "assets/images/group.png",
        tagB: {"companion": "group"}),
    RoundItem(
        labelA: "휴식",
        wAssetA: "assets/images/Wrest.png",
        stickerAssetA: "assets/images/rest.png",
        tagA: {"activity": "rest"},
        labelB: "액티비티",
        wAssetB: "assets/images/Wactivity.png",
        stickerAssetB: "assets/images/activity.png",
        tagB: {"activity": "dynamic"}),
    RoundItem(
        labelA: "야외",
        wAssetA: "assets/images/Woutdoor.png",
        stickerAssetA: "assets/images/outdoor.png",
        tagA: {"indoor": false},
        labelB: "실내",
        wAssetB: "assets/images/Windoor.png",
        stickerAssetB: "assets/images/indoor.png",
        tagB: {"indoor": true}),
  ];

  void _handleSliderEnd(double value) {
    if (value == 50.0) return;
    final isLastRound = currentRoundIndex == rounds.length - 1;

    setState(() {
      String selectedSticker;
      Map<String, dynamic> selectedTag;
      double score;

      if (value < 50.0) {
        selectedSticker = rounds[currentRoundIndex].stickerAssetA;
        selectedTag = rounds[currentRoundIndex].tagA;
        score = 50.0 - value;
      } else {
        selectedSticker = rounds[currentRoundIndex].stickerAssetB;
        selectedTag = rounds[currentRoundIndex].tagB;
        score = value - 50.0;
      }

      selectedStickers[currentRoundIndex] = selectedSticker;
      finalUserSelection['Round ${currentRoundIndex + 1}'] = {
        'tag': selectedTag,
        'score': score.toInt(),
      };

      if (!isLastRound) {
        currentRoundIndex++;
        _sliderValue = 50.0;
      } else {
        // 마지막 라운드면 완료 처리
        _isCompleted = true;
      }
    });

    if (isLastRound) {
      _savePreferencesInBackground();
    }
  }

  void _onSelectOption(double extremeValue) {
    _handleSliderEnd(extremeValue);
  }

  Map<String, dynamic> _buildPreferencePayload() {
    final payload = <String, dynamic>{
      'ocean_score': 0,
      'nature_score': 0,
      'theme_choice': null,
      'walk_transit_score': 0,
      'car_score': 0,
      'mobility_choice': null,
      'solo_score': 0,
      'group_score': 0,
      'companion_choice': null,
      'rest_score': 0,
      'dynamic_score': 0,
      'activity_choice': null,
      'outdoor_score': 0,
      'indoor_score': 0,
      'indoor_choice': null,
    };

    for (final selection in finalUserSelection.values) {
      if (selection is! Map<String, dynamic>) continue;
      final tag = selection['tag'];
      final score = selection['score'];
      if (tag is! Map<String, dynamic> || score is! int) continue;

      switch (tag.entries.firstOrNull) {
        case MapEntry(key: 'theme', value: 'ocean'):
          payload['ocean_score'] = score;
          payload['theme_choice'] = 'ocean';
          break;
        case MapEntry(key: 'theme', value: 'nature'):
          payload['nature_score'] = score;
          payload['theme_choice'] = 'nature';
          break;
        case MapEntry(key: 'mobility', value: 'car'):
          payload['car_score'] = score;
          payload['mobility_choice'] = 'car';
          break;
        case MapEntry(key: 'mobility', value: 'walk_transit'):
          payload['walk_transit_score'] = score;
          payload['mobility_choice'] = 'walk_transit';
          break;
        case MapEntry(key: 'companion', value: 'solo'):
          payload['solo_score'] = score;
          payload['companion_choice'] = 'solo';
          break;
        case MapEntry(key: 'companion', value: 'group'):
          payload['group_score'] = score;
          payload['companion_choice'] = 'group';
          break;
        case MapEntry(key: 'activity', value: 'rest'):
          payload['rest_score'] = score;
          payload['activity_choice'] = 'rest';
          break;
        case MapEntry(key: 'activity', value: 'dynamic'):
          payload['dynamic_score'] = score;
          payload['activity_choice'] = 'dynamic';
          break;
        case MapEntry(key: 'indoor', value: false):
          payload['outdoor_score'] = score;
          payload['indoor_choice'] = false;
          break;
        case MapEntry(key: 'indoor', value: true):
          payload['indoor_score'] = score;
          payload['indoor_choice'] = true;
          break;
      }
    }
    return payload;
  }

  // 🌟 팝업 없이 백그라운드에서 조용히 저장
  Future<void> _savePreferencesInBackground() async {
    setState(() => _isSaving = true);
    try {
      _savedPreferenceId =
          await PreferenceService.save(_buildPreferencePayload());
    } catch (error) {
      _savedPreferenceId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('취향 저장 실패')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 🌟 스케치북 이미지 저장 로직
  Future<void> _saveSketchbookImage() async {
    try {
      RenderRepaintBoundary boundary = _sketchbookKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // TODO: 실제 기기 저장을 원하시면 터미널에 `flutter pub add image_gallery_saver` 입력 후 아래 주석을 풀어주세요.
      // await ImageGallerySaver.saveImage(pngBytes, name: "soomtrip_sketchbook");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("스케치북이 갤러리에 저장되었습니다! 🌱",
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF4A7C59),
        ),
      );
    } catch (e) {
      print("이미지 저장 실패: $e");
    }
  }

  void _resetWorldCup() {
    setState(() {
      currentRoundIndex = 0;
      selectedStickers.fillRange(0, 5, null);
      finalUserSelection.clear();
      _sliderValue = 50.0;
      _isCompleted = false;
      _showBackgroundEffect = true;
      _savedPreferenceId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: Column(
          children: [
            // ===================================
            // 1. 상단 스케치북 영역
            // ===================================
            Expanded(
              flex: 6,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                // 🌟 여기서부터 이미지를 캡처할 수 있도록 RepaintBoundary로 감쌉니다.
                child: RepaintBoundary(
                  key: _sketchbookKey,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        // 🌟 기존 코드의 수치를 완벽하게 유지합니다!
                        width: 550,
                        height: 580,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.asset("assets/images/sketchbook.png",
                                  fit: BoxFit.fill),
                            ),
                            if (_isCompleted && _showBackgroundEffect)
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/effect.png',
                                  fit: BoxFit.fill,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.only(top: 60.0),
                                child: SizedBox(
                                  width: 230,
                                  height: 68,
                                  child: Image(
                                    image: AssetImage('assets/images/logo.png'),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),

                            // 🌟 요청하신 스티커 위치/크기 수치 그대로 유지
                            if (selectedStickers[3] != null)
                              Positioned(
                                left: selectedStickers[3] ==
                                        "assets/images/rest.png"
                                    ? 36
                                    : -18,
                                top: selectedStickers[3] ==
                                        "assets/images/rest.png"
                                    ? 110
                                    : 76,
                                child: _buildStickerOnly(
                                  assetPath: selectedStickers[3]!,
                                  width: selectedStickers[3] ==
                                          "assets/images/rest.png"
                                      ? 200
                                      : 292,
                                  height: selectedStickers[3] ==
                                          "assets/images/rest.png"
                                      ? 150
                                      : 221,
                                  rotation: -0.18,
                                ),
                              ),
                            if (selectedStickers[4] != null)
                              Positioned(
                                right: 50,
                                top: 90,
                                child: _buildStickerOnly(
                                  assetPath: selectedStickers[4]!,
                                  width: 175,
                                  height: 150,
                                  rotation: 0.14,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            if (selectedStickers[2] != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 198,
                                child: Center(
                                  child: _buildStickerOnly(
                                    assetPath: selectedStickers[2]!,
                                    width: 450,
                                    height: 225,
                                    rotation: 0.0,
                                  ),
                                ),
                              ),
                            if (selectedStickers[0] != null)
                              Positioned(
                                left: 14,
                                right: 14,
                                bottom: 20,
                                child: Center(
                                  child: _buildStickerOnly(
                                    assetPath: selectedStickers[0]!,
                                    width: 570,
                                    height: 180,
                                    rotation: 0.0,
                                  ),
                                ),
                              ),
                            if (selectedStickers[1] != null)
                              Positioned(
                                right: 2,
                                top: 345,
                                child: _buildStickerOnly(
                                  assetPath: selectedStickers[1]!,
                                  width: 300,
                                  height: 210,
                                  rotation: 0.0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                _isCompleted ? "취향 분석완료✨" : "손잡이를 더 끌리는 쪽으로 밀어봐! 👆",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isCompleted ? const Color(0xFF4A7C59) : Colors.grey,
                ),
              ),
            ),

            // ===================================
            // 2. 하단 영역 분기 (진행 중: 슬라이더 / 완료: 버튼 UI)
            // ===================================
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  if (_isCompleted)
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _showBackgroundEffect = !_showBackgroundEffect,
                      ),
                      icon: _showBackgroundEffect
                          ? const Icon(Icons.toggle_on_rounded,
                              size: 22, color: Color(0xFF4A7C59))
                          // Material 아이콘은 단색이라 꺼짐 상태에서 흰색으로 채우면
                          // 테두리까지 같이 흰색이 되어 배경에 묻힘.
                          // 테두리는 초록색을 유지하도록 직접 그린 스위치 모양으로 대체.
                          : Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              child: Container(
                                width: 20,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFF4A7C59),
                                      width: 1.5),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.all(1),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4A7C59),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      label:
                          Text('배경 효과 ${_showBackgroundEffect ? "ON" : "OFF"}'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A7C59),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'CustomFont',
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: _isCompleted
                        ? _buildResultButtons() // 완료되면 버튼 등장
                        : _buildSliderArea(), // 아니면 기존 슬라이더
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 팝업을 대체할 새로운 하단 버튼 영역
  Widget _buildResultButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. 운명의 여행지 뽑기 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _isSaving
                ? null
                : () {
                    if (_savedPreferenceId != null) {
                      final recommendationFuture =
                          RecommendationService.create(_savedPreferenceId!);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GachaScreen(
                            preferenceId: _savedPreferenceId!,
                            recommendationFuture: recommendationFuture,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("저장에 실패했어요. 다시 시도해주세요.")));
                    }
                  },
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("여행지 뽑으러 가기",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
          ),
        ),
        const SizedBox(height: 12),

        // 2. 이미지 저장 버튼
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4A7C59), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _saveSketchbookImage,
            child: const Text("스케치북 이미지 저장하기",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A7C59))),
          ),
        ),
        const Spacer(),

        // 3. 다시하기 버튼
        TextButton(
          onPressed: _resetWorldCup,
          child: const Text("처음부터 다시 테스트하기 🔄",
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // 기존 슬라이더 영역을 분리한 위젯
  Widget _buildSliderArea() {
    final currentRound = rounds[currentRoundIndex];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onSelectOption(0.0),
                        child: _buildChoiceCard(
                            currentRound.wAssetA, currentRound.labelA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onSelectOption(100.0),
                        child: _buildChoiceCard(
                            currentRound.wAssetB, currentRound.labelB),
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Align(
                    alignment: const Alignment(0, -0.15),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFF4A7C59), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Text("VS",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A7C59))),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 기존의 커스텀 슬라이더 로직 (CenterFillTrackPainter) 완벽 유지!
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CenterFillTrackPainter(value: _sliderValue),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8.0,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbShape: const _EmojiThumbShape(thumbRadius: 20.0),
                  ),
                  child: Slider(
                    value: _sliderValue,
                    min: 0.0,
                    max: 100.0,
                    onChanged: (value) => setState(() => _sliderValue = value),
                    onChangeEnd: _handleSliderEnd,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerOnly(
      {required String assetPath,
      required double width,
      required double height,
      required double rotation,
      BoxFit fit = BoxFit.contain}) {
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(assetPath, fit: fit)),
    );
  }

  Widget _buildChoiceCard(String assetPath, String label) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEBE6D9), width: 2),
              image: DecorationImage(
                  image: AssetImage(assetPath), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333)),
        ),
      ],
    );
  }
}

// 🌟 예원님이 작성하신 커스텀 페인터 클래스 유지
class _CenterFillTrackPainter extends CustomPainter {
  final double value;

  const _CenterFillTrackPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    const thumbRadius = 20.0;
    const trackHeight = 8.0;
    const left = thumbRadius;
    final right = size.width - thumbRadius;
    final centerX = (left + right) / 2;
    final thumbX = left + (right - left) * (value / 100);
    final y = size.height / 2;

    final backgroundPaint = Paint()
      ..color = const Color(0xFFEBE6D9)
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(left, y), Offset(right, y), backgroundPaint);
    canvas.drawLine(Offset(centerX, y), Offset(thumbX, y), fillPaint);
  }

  @override
  bool shouldRepaint(covariant _CenterFillTrackPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _EmojiThumbShape extends SliderComponentShape {
  final double thumbRadius;
  const _EmojiThumbShape({this.thumbRadius = 18.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: "🌱",
      style: TextStyle(fontSize: thumbRadius * 1.5),
    );
    textPainter.layout();
    textPainter.paint(context.canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2));
  }
}
