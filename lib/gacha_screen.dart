import 'package:flutter/material.dart';
import 'dart:async';
import 'main_screen.dart';
import 'recommendation_service.dart';
import 'saved_region_service.dart';

class GachaScreen extends StatefulWidget {
  final int? preferenceId;

  const GachaScreen({super.key, this.preferenceId});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  // --- 기존 가챠 배경 애니메이션용 변수들 ---
  static const double _capsuleSize = 50;
  static const List<String> _capsuleAssets = [
    'assets/images/gacha_capsule.png',
    'assets/images/gacha_capsule2.png',
    'assets/images/gacha_capsule3.png',
    'assets/images/gacha_capsule4.png',
  ];
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _backgroundController;
  final List<double> _capsuleAngles = List.filled(8, 0);
  final List<Offset> _capsulePositions = [];
  final List<Offset> _capsuleVelocities = [
    const Offset(30, 22),
    const Offset(-24, 32),
    const Offset(28, -26),
    const Offset(-32, -20),
    const Offset(20, 30),
    const Offset(-28, 24),
    const Offset(32, -22),
    const Offset(-22, -30),
  ];
  Duration _lastBackgroundTick = Duration.zero;
  Size _backgroundSize = Size.zero;

  // --- 🌟 연출 흐름을 제어하는 상태 변수들 ---
  double _turns = 0.0;
  bool _isSpinning = false; // 1. 손잡이가 돌아가는 중인가?
  bool _isDropped = false; // 2. 기계 밑으로 캡슐이 떨어졌는가?
  bool _showZoomedCapsule = false; // 3. 중앙에 큰 캡슐(오버레이)을 띄울 것인가?
  bool _isOpened = false; // 4. 캡슐이 열리고 티켓이 나왔는가?
  bool _isSavingRegion = false;
  String? _recommendedDestination;
  Map<String, dynamic>? _recommendedCandidate;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 50));
    _shakeAnimation =
        Tween<double>(begin: -4.0, end: 4.0).animate(_shakeController);
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // --- 배경 캡슐 로직 (기존과 동일) ---
  void _initializeCapsules(Size size) {
    const startingPoints = [
      Offset(0.05, 0.08),
      Offset(0.72, 0.12),
      Offset(0.25, 0.28),
      Offset(0.82, 0.34),
      Offset(0.08, 0.55),
      Offset(0.62, 0.58),
      Offset(0.32, 0.78),
      Offset(0.78, 0.84),
    ];
    final maxX = (size.width - _capsuleSize).clamp(0.0, double.infinity);
    final maxY = (size.height - _capsuleSize).clamp(0.0, double.infinity);
    _capsulePositions
      ..clear()
      ..addAll(startingPoints
          .map((point) => Offset(point.dx * maxX, point.dy * maxY)));
    _backgroundSize = size;
    _lastBackgroundTick = Duration.zero;
  }

  void _moveCapsules(Size size) {
    if (_capsulePositions.isEmpty || size != _backgroundSize)
      _initializeCapsules(size);
    final elapsed = _backgroundController.lastElapsedDuration ?? Duration.zero;
    if (_lastBackgroundTick == Duration.zero) {
      _lastBackgroundTick = elapsed;
      return;
    }
    final seconds = ((elapsed - _lastBackgroundTick).inMicroseconds / 1000000)
        .clamp(0.0, 0.05);
    _lastBackgroundTick = elapsed;
    final maxX = (size.width - _capsuleSize).clamp(0.0, double.infinity);
    final maxY = (size.height - _capsuleSize).clamp(0.0, double.infinity);

    for (var i = 0; i < _capsulePositions.length; i++) {
      var position = _capsulePositions[i] + _capsuleVelocities[i] * seconds;
      var velocity = _capsuleVelocities[i];
      if (position.dx <= 0 || position.dx >= maxX) {
        velocity = Offset(-velocity.dx, velocity.dy);
        position = Offset(position.dx.clamp(0.0, maxX), position.dy);
      }
      if (position.dy <= 0 || position.dy >= maxY) {
        velocity = Offset(velocity.dx, -velocity.dy);
        position = Offset(position.dx, position.dy.clamp(0.0, maxY));
      }
      _capsulePositions[i] = position;
      _capsuleVelocities[i] = velocity;
      _capsuleAngles[i] += 0.18 * seconds;
    }
  }

  Widget _buildCapsuleBackground() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: _backgroundController,
          builder: (context, child) {
            _moveCapsules(size);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: List.generate(8, (index) {
                return Positioned(
                  left: _capsulePositions[index].dx,
                  top: _capsulePositions[index].dy,
                  child: Transform.rotate(
                    angle: _capsuleAngles[index],
                    child: Image.asset(_capsuleAssets[index ~/ 2],
                        width: _capsuleSize, height: _capsuleSize),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  // 🌟 [핵심 로직] 순차적인 애니메이션 흐름
  Future<void> _spinGacha() async {
    if (_isSpinning) return;

    final preferenceId = widget.preferenceId;
    if (preferenceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 월드컵을 완료해 취향을 저장해 주세요.')),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _turns += 1.0;
    });
    _shakeController.repeat(reverse: true);

    try {
      final candidate = await RecommendationService.create(preferenceId);
      if (!mounted) return;
      setState(() {
        _recommendedCandidate = candidate;
        _recommendedDestination = candidate['name'] as String;
      });
    } catch (_) {
      if (!mounted) return;
      _shakeController.stop();
      setState(() => _isSpinning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행지를 추천받지 못했습니다. 다시 시도해 주세요.')),
      );
      return;
    }

    if (!mounted) return;

    // 1. 1초 뒤: 흔들림 멈추고 캡슐이 기계 아래로 툭 떨어짐
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      _shakeController.stop();
      setState(() => _isDropped = true);

      // 2. 캡슐이 떨어진 후 0.8초 뒤: 화면 어두워지며 중앙에 큰 캡슐 등장!
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _showZoomedCapsule = true);

        // 3. 큰 캡슐 등장 후 1.5초 뒤: 스르륵 열리면서 티켓으로 변환!
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          setState(() => _isOpened = true);
        });
      });
    });
  }

  // 🌟 처음 상태로 돌아가는 함수 (다시 뽑기)
  void _resetGacha() {
    setState(() {
      _isSpinning = false;
      _isDropped = false;
      _showZoomedCapsule = false;
      _isOpened = false;
      _recommendedDestination = null;
      _recommendedCandidate = null;
    });
  }

  Future<void> _saveRecommendedRegion() async {
    if (_isSavingRegion) return;

    final candidate = _recommendedCandidate;
    if (candidate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 추천 여행지가 없습니다.')),
      );
      return;
    }

    setState(() => _isSavingRegion = true);
    try {
      await SavedRegionService.save(candidate);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingRegion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('여행지를 저장하지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDECB3),
      appBar: AppBar(
        title:
            const Text("운명의 여행지 뽑기", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          // 1. [맨 뒷배경] 떠다니는 캡슐들
          Positioned.fill(child: _buildCapsuleBackground()),

          // 2. [중간층] 덜덜 떨리는 가챠 기계 본체
          Center(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: SizedBox(
                width: 350,
                height: 500,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Image.asset('assets/images/gacha_machine.png',
                          width: 350),
                    ),
                    // 떨어지는 작은 캡슐
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.bounceOut,
                      top: _isDropped ? 400 : 370,
                      left: 217,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isDropped && !_showZoomedCapsule
                            ? 1.0
                            : 0.0, // 오버레이 뜰 때는 숨김
                        child: Image.asset('assets/images/gacha_capsule.png',
                            width: 60),
                      ),
                    ),
                    // 손잡이
                    Positioned(
                      top: 280,
                      left: 113,
                      child: GestureDetector(
                        onTap: _isSpinning ? null : _spinGacha,
                        child: AnimatedRotation(
                          turns: _turns,
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          child: Image.asset('assets/images/gacha_handle.png',
                              width: 104),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🌟 3. [맨 앞층 - 오버레이] 화면이 어두워지며 캡슐 -> 티켓 등장!
          if (_showZoomedCapsule)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6), // 배경을 어둡게 눌러줌
                child: Center(
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 800), // 스르륵 변하는 속도
                    crossFadeState: _isOpened
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,

                    // [상태 1] 🌟 크기를 약 2배로 확 키운 중앙 캡슐 (200 -> 380)
                    firstChild: Image.asset('assets/images/gacha_capsule.png',
                        width: 380),

                    // [상태 2] 🌟 동그랗고 하얀 후광이 퍼지는 티켓
                    secondChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 티켓과 동그란 빛 영역
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. 네모로 잘리지 않는 완벽한 둥근 하얀 빛 (Radial Gradient)
                            Container(
                              width: 450, // 빛이 퍼질 충분히 넒은 공간
                              height: 450,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.9), // 중심은 밝은 하얀색
                                    Colors.white
                                        .withOpacity(0.0), // 바깥쪽은 완전 투명하게
                                  ],
                                  stops: const [0.2, 1.0], // 빛이 부드럽게 퍼지는 비율
                                ),
                              ),
                            ),
                            // 2. 빛 바로 위에 얹어지는 티켓
                            _buildTicket(
                                destination: _recommendedDestination ?? "",
                                memo: "파도 소리와 함께하는 완벽한 힐링 파도 소리와 함께하는 완벽한 힐링"),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 하단 버튼들
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 15),
                              ),
                              onPressed:
                                  _resetGacha, // 다시 뽑기 누르면 오버레이 꺼지고 처음으로!
                              child: const Text("다시 뽑기",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE500),
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 15),
                              ),
                              onPressed: _isSavingRegion
                                  ? null
                                  : _saveRecommendedRegion,
                              child: _isSavingRegion
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black87,
                                      ),
                                    )
                                  : const Text("저장하기",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🎫 어떤 폰에서도 절대 깨지지 않는 티켓 UI
  Widget _buildTicket({
    required String destination,
    required String memo,
  }) {
    return FittedBox(
      fit: BoxFit.contain, // 🌟 핵심: 화면 크기에 맞춰 이 안의 모든 것을 '비율 그대로' 축소/확대해 줌
      child: SizedBox(
        // 🚨 중요: 가지고 계신 기차표 원본 이미지의 비율에 맞춰서 width와 height를 정해주세요!
        // (예: 가로가 길고 세로가 짧은 비율)
        width: 400,
        height: 250,
        child: Stack(
          children: [
            // 1. 빈 바탕의 기차표 이미지 (빈 공간 없이 도화지에 꽉 채움)
            Positioned.fill(
              child: Image.asset(
                'assets/images/ticket_bg.png',
                fit: BoxFit.fill, // 도화지 크기에 딱 맞게 늘림
              ),
            ),

            // 2. 티켓 위 글자들
            // (이제 400x200 도화지 기준으로 맞추면, 화면이 작아져도 위치가 같이 줄어들어서 절대 안 어긋납니다!)
            Positioned(
              top: 85,
              left: 0,
              right: 25,
              child: Text(
                destination,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),

            Positioned(
              top: 150,
              left: 120,
              child: SizedBox(
                width: 140, // 글자가 밖으로 튀어나가지 않게 제한
                child: Text(
                  " $memo",
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
