import 'package:flutter/material.dart';
import 'gacha_screen.dart'; // 가챠 스크린 연결

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '숨트립',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFFDECB3),
        fontFamily: 'CustomFont',
      ),
      home: const WorldCupScreen(),
    );
  }
}

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

  // 🌟 슬라이더의 현재 위치값 (0.0 ~ 100.0 / 기본값은 정중앙 50.0)
  double _sliderValue = 50.0;

  final List<RoundItem> rounds = [
    RoundItem(
      labelA: "바다",
      wAssetA: "assets/images/Wocean.png",
      stickerAssetA: "assets/images/ocean.png",
      tagA: {"theme": "ocean"},
      labelB: "숲",
      wAssetB: "assets/images/Wnature.png",
      stickerAssetB: "assets/images/nature.png",
      tagB: {"theme": "nature"},
    ),
    RoundItem(
      labelA: "뚜벅이",
      wAssetA: "assets/images/Wwalk.png",
      stickerAssetA: "assets/images/walk.png",
      tagA: {"mobility": "walk_transit"},
      labelB: "자차",
      wAssetB: "assets/images/Wcar.png",
      stickerAssetB: "assets/images/car.png",
      tagB: {"mobility": "car"},
    ),
    RoundItem(
      labelA: "혼자 여행",
      wAssetA: "assets/images/Wsolo.png",
      stickerAssetA: "assets/images/solo.png",
      tagA: {"companion": "solo"},
      labelB: "함께 여행",
      wAssetB: "assets/images/Wgroup.png",
      stickerAssetB: "assets/images/group.png",
      tagB: {"companion": "group"},
    ),
    RoundItem(
      labelA: "휴식",
      wAssetA: "assets/images/Wrest.png",
      stickerAssetA: "assets/images/rest.png",
      tagA: {"activity": "rest"},
      labelB: "액티비티",
      wAssetB: "assets/images/Wactivity.png",
      stickerAssetB: "assets/images/activity.png",
      tagB: {"activity": "dynamic"},
    ),
    RoundItem(
      labelA: "야외",
      wAssetA: "assets/images/Woutdoor.png",
      stickerAssetA: "assets/images/outdoor.png",
      tagA: {"indoor": false},
      labelB: "실내",
      wAssetB: "assets/images/Windoor.png",
      stickerAssetB: "assets/images/indoor.png",
      tagB: {"indoor": true},
    ),
  ];

  // 🌟 슬라이더 조작이 끝났을 때(손을 뗐을 때) 실행되는 함수
  void _handleSliderEnd(double value) {
    // 중앙에 그대로 두고 터치만 한 경우 넘어가지 않도록 방지
    if (value == 50.0) return;

    setState(() {
      String selectedSticker;
      Map<String, dynamic> selectedTag;
      double score; // 가중치 점수

      if (value < 50.0) {
        // 왼쪽(A)으로 당긴 경우
        selectedSticker = rounds[currentRoundIndex].stickerAssetA;
        selectedTag = rounds[currentRoundIndex].tagA;
        score = 50.0 - value; // (예: 끝까지 당기면 50점, 살짝 당기면 10점)
      } else {
        // 오른쪽(B)으로 당긴 경우
        selectedSticker = rounds[currentRoundIndex].stickerAssetB;
        selectedTag = rounds[currentRoundIndex].tagB;
        score = value - 50.0;
      }

      // 스티커 및 데이터 저장 (태그와 점수를 함께 기록)
      selectedStickers[currentRoundIndex] = selectedSticker;
      finalUserSelection['Round ${currentRoundIndex + 1}'] = {
        'tag': selectedTag,
        'score': score.toInt(), // 소수점 버리고 정수형 점수로 저장
      };

      // 다음 라운드 진행
      if (currentRoundIndex < rounds.length - 1) {
        currentRoundIndex++;
        _sliderValue = 50.0; // 🌟 슬라이더 위치를 다시 중앙으로 리셋
      } else {
        _showCompletionDialog();
      }
    });
  }

  // 기존 버튼 터치 방식도 유지 (버튼을 누르면 슬라이더를 끝까지 당긴 것과 동일한 효과)
  void _onSelectOption(double extremeValue) {
    _handleSliderEnd(extremeValue);
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("취향 스크랩 완료!"),
        content: Text("수집된 데이터:\n$finalUserSelection"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetWorldCup();
            },
            child: const Text("다시 테스트하기", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GachaScreen()),
              );
            },
            child: const Text("결과 보기",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF8B5A2B))),
          ),
        ],
      ),
    );
  }

  void _resetWorldCup() {
    setState(() {
      currentRoundIndex = 0;
      selectedStickers.fillRange(0, 5, null);
      finalUserSelection.clear();
      _sliderValue = 50.0; // 리셋할 때 슬라이더도 중앙으로
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRound = rounds[currentRoundIndex];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===================================
            // 1. 상단 스케치북 영역 (flex: 6)
            // ===================================
            Expanded(
              flex: 6,
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage("assets/images/sketchbook.png"),
                    fit: BoxFit.fill,
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4))
                  ],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 50.0),
                        child: Text("나의 여행 취향 보드",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8B5A2B))),
                      ),
                    ),
                    if (selectedStickers[3] != null)
                      Positioned(
                        left: selectedStickers[3] == "assets/images/rest.png"
                            ? 26
                            : -28,
                        top: selectedStickers[3] == "assets/images/rest.png"
                            ? 90
                            : 56,
                        child: _buildStickerOnly(
                          assetPath: selectedStickers[3]!,
                          width: selectedStickers[3] == "assets/images/rest.png"
                              ? 170
                              : 242,
                          height:
                              selectedStickers[3] == "assets/images/rest.png"
                                  ? 120
                                  : 171,
                          rotation: -0.18,
                        ),
                      ),
                    if (selectedStickers[4] != null)
                      Positioned(
                        right: 0,
                        top: 80,
                        child: _buildStickerOnly(
                          assetPath: selectedStickers[4]!,
                          width: 176,
                          height: 124,
                          rotation: 0.14,
                        ),
                      ),
                    if (selectedStickers[2] != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 168,
                        child: Center(
                          child: _buildStickerOnly(
                            assetPath: selectedStickers[2]!,
                            width: 370,
                            height: 165,
                            rotation: 0.0,
                          ),
                        ),
                      ),
                    if (selectedStickers[0] != null)
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 10,
                        child: Center(
                          child: _buildStickerOnly(
                            assetPath: selectedStickers[0]!,
                            width: 540,
                            height: 150,
                            rotation: 0.0,
                          ),
                        ),
                      ),
                    if (selectedStickers[1] != null)
                      Positioned(
                        right: 2,
                        top: 290,
                        child: _buildStickerOnly(
                          assetPath: selectedStickers[1]!,
                          width: 250,
                          height: 160,
                          rotation: 0.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text("손잡이를 더 끌리는 쪽으로 밀어봐!",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B8E23))),
            ),

            // ===================================
            // 2. 하단 선택지 & 슬라이더 영역 (flex: 4)
            // ===================================
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(7, 7, 7, 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3DFA8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFD8BE78),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
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
                                            currentRound.wAssetA,
                                            currentRound.labelA,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _onSelectOption(100.0),
                                          child: _buildChoiceCard(
                                            currentRound.wAssetB,
                                            currentRound.labelB,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  IgnorePointer(
                                    child: Align(
                                      alignment: const Alignment(0, -0.15),
                                      child: Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFFFF8E7),
                                          border: Border.all(
                                            color: const Color(0xFFD8BE78),
                                            width: 1.5,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 5,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          "VS",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7A5A36),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 40,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 8.0,
                                  activeTrackColor: const Color(0xFFD6C8A1),
                                  inactiveTrackColor: const Color(0xFFD6C8A1),
                                  thumbShape:
                                      const _EmojiThumbShape(thumbRadius: 20.0),
                                ),
                                child: Slider(
                                  value: _sliderValue,
                                  min: 0.0,
                                  max: 100.0,
                                  onChanged: (value) {
                                    setState(() {
                                      _sliderValue = value;
                                    });
                                  },
                                  onChangeEnd: _handleSliderEnd,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerOnly(
      {required String assetPath,
      required double width,
      required double height,
      required double rotation}) {
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(assetPath, fit: BoxFit.contain)),
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
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 6, offset: Offset(2, 2))
              ],
              image: DecorationImage(
                  image: AssetImage(assetPath), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B4E31))),
      ],
    );
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
      text: "😄",
      style: TextStyle(
        fontSize: thumbRadius * 1.5,
      ),
    );
    textPainter.layout();
    textPainter.paint(context.canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2));
  }
}
