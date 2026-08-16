import 'package:flutter/material.dart';
import 'gacha_screen.dart'; // 👈 이 줄을 추가하세요

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
    required this.labelA, required this.wAssetA, required this.stickerAssetA, required this.tagA,
    required this.labelB, required this.wAssetB, required this.stickerAssetB, required this.tagB,
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

  final List<RoundItem> rounds = [
    RoundItem(
      labelA: "바다", wAssetA: "assets/images/Wocean.png", stickerAssetA: "assets/images/ocean.png", tagA: {"theme": "ocean"},
      labelB: "숲", wAssetB: "assets/images/Wnature.png", stickerAssetB: "assets/images/nature.png", tagB: {"theme": "nature"},
    ),
    RoundItem(
      labelA: "뚜벅이", wAssetA: "assets/images/Wwalk.png", stickerAssetA: "assets/images/walk.png", tagA: {"mobility": "walk_transit"},
      labelB: "자차", wAssetB: "assets/images/Wcar.png", stickerAssetB: "assets/images/car.png", tagB: {"mobility": "car"},
    ),
    RoundItem(
      labelA: "혼자 여행", wAssetA: "assets/images/Wsolo.png", stickerAssetA: "assets/images/solo.png", tagA: {"companion": "solo"},
      labelB: "친구/연인", wAssetB: "assets/images/Wgroup.png", stickerAssetB: "assets/images/group.png", tagB: {"companion": "group"},
    ),
    RoundItem(
      labelA: "휴식", wAssetA: "assets/images/Wrest.png", stickerAssetA: "assets/images/rest.png", tagA: {"activity": "rest"},
      labelB: "액티비티", wAssetB: "assets/images/Wactivity.png", stickerAssetB: "assets/images/activity.png", tagB: {"activity": "dynamic"},
    ),
    RoundItem(
      labelA: "야외", wAssetA: "assets/images/Woutdoor.png", stickerAssetA: "assets/images/outdoor.png", tagA: {"indoor": false},
      labelB: "실내", wAssetB: "assets/images/Windoor.png", stickerAssetB: "assets/images/indoor.png", tagB: {"indoor": true},
    ),
  ];

  void _onSelectOption(String selectedSticker, Map<String, dynamic> selectedTag) {
    setState(() {
      selectedStickers[currentRoundIndex] = selectedSticker;
      finalUserSelection.addAll(selectedTag);

      if (currentRoundIndex < rounds.length - 1) {
        currentRoundIndex++;
      } else {
        _showCompletionDialog();
      }
    });
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
          // ➡️ 2. 결과 보기 버튼
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 팝업창을 닫고
              // 가챠 화면으로 부드럽게 화면 이동!
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GachaScreen()),
              );
            },
            child: const Text("결과 보기", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5A2B))),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRound = rounds[currentRoundIndex];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage("assets/images/sketchbook.png"),
                    fit: BoxFit.fill,
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 40.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("여행 취향 월드컵", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF8B5A2B))),
                            SizedBox(height: 8),
                            Text("더 끌리는 곳을 골라봐", style: TextStyle(fontSize: 14, color: Color(0xFF6B8E23))),
                          ],
                        ),
                      ),
                    ),
                    
                    if (selectedStickers[3] != null)
                      Positioned(
                        left: selectedStickers[3] == "assets/images/rest.png" ? 26 : -28,
                        top: selectedStickers[3] == "assets/images/rest.png" ? 90 : 56,
                        child: _buildStickerOnly(
                          assetPath: selectedStickers[3]!,
                          width: selectedStickers[3] == "assets/images/rest.png" ? 170 : 242,
                          height: selectedStickers[3] == "assets/images/rest.png" ? 120 : 171,
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
                        top: 270,
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

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFD6C8A1), borderRadius: BorderRadius.circular(20)),
                child: Text("ROUND ${currentRoundIndex + 1} / 5", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),

            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onSelectOption(currentRound.stickerAssetA, currentRound.tagA),
                        child: _buildChoiceCard(currentRound.wAssetA, currentRound.labelA),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                        child: const Text("VS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onSelectOption(currentRound.stickerAssetB, currentRound.tagB),
                        child: _buildChoiceCard(currentRound.wAssetB, currentRound.labelB),
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

  Widget _buildStickerOnly({
    required String assetPath,
    required double width,
    required double height,
    required double rotation,
  }) {
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
        ),
      ),
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
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2))],
              image: DecorationImage(image: AssetImage(assetPath), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B4E31))),
      ],
    );
  }
}