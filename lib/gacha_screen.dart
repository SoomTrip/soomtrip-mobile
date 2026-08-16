import 'package:flutter/material.dart';
import 'dart:async';

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

// 💡 덜덜 떨리는 애니메이션을 쓰려면 with SingleTickerProviderStateMixin 이 꼭 필요합니다!
class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  static const double _capsuleSize = 50;
  static const List<String> _capsuleAssets = [
    'assets/images/gacha_capsule.png',
    'assets/images/gacha_capsule2.png',
    'assets/images/gacha_capsule3.png',
    'assets/images/gacha_capsule4.png',
  ];

  double _turns = 0.0;
  bool _isDropped = false;
  bool _isSpinning = false;

  // 진동 애니메이션을 제어할 컨트롤러
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

  @override
  void initState() {
    super.initState();
    // 0.05초(50밀리초)마다 아주 빠르게 움직이는 컨트롤러 생성
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    // 좌우로 -4픽셀 ~ 4픽셀 사이를 왔다갔다 하도록 설정
    _shakeAnimation =
        Tween<double>(begin: -4.0, end: 4.0).animate(_shakeController);
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _shakeController.dispose(); // 화면이 꺼질 때 메모리 정리
    _backgroundController.dispose();
    super.dispose();
  }

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
      ..addAll(
        startingPoints.map((point) => Offset(point.dx * maxX, point.dy * maxY)),
      );
    _backgroundSize = size;
    _lastBackgroundTick = Duration.zero;
  }

  void _moveCapsules(Size size) {
    if (_capsulePositions.isEmpty || size != _backgroundSize) {
      _initializeCapsules(size);
    }

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
                    child: Image.asset(
                      _capsuleAssets[index ~/ 2],
                      width: _capsuleSize,
                      height: _capsuleSize,
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  void _spinGacha() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _turns += 1.0; // 손잡이 1바퀴 회전
    });

    // 1. 손잡이가 돌아가는 즉시 기계를 좌우로 덜덜 흔듭니다.
    _shakeController.repeat(reverse: true);

    // 2. 1초 뒤 (손잡이 회전 완료)
    Future.delayed(const Duration(seconds: 1), () {
      _shakeController.stop(); // 기계 흔들림 멈춤

      setState(() {
        _isDropped = true; // 캡슐 떨어뜨리기!
      });
    });
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
      // 🌟 화면 전체를 Stack으로 묶어서 배경과 기계를 분리합니다.
      body: Stack(
        children: [
          // ==========================================
          // 1. [맨 뒷배경] 떠다니는 캡슐들 (bouncy_background)
          // ==========================================
          Positioned.fill(
            child: _buildCapsuleBackground(),
          ),

          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Image.asset(
                  'assets/images/soomtrip.png',
                  width: 260,
                ),
              ),
            ),
          ),

          // ==========================================
          // 2. [앞면] 우리가 방금 만든 덜덜 떨리는 가챠 기계
          // ==========================================
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
                    // 기존 가챠 본체 코드
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Image.asset('assets/images/gacha_machine.png',
                          width: 350),
                    ),
                    // 떨어지는 캡슐
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.bounceOut,
                      top: _isDropped ? 400 : 370,
                      left: 217,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isDropped ? 1.0 : 0.0,
                        child: Image.asset('assets/images/gacha_capsule.png',
                            width: 60),
                      ),
                    ),
                    // 돌아가는 손잡이
                    Positioned(
                      top: 280,
                      left: 113,
                      child: GestureDetector(
                        onTap: _spinGacha,
                        child: AnimatedRotation(
                          turns: _turns,
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          child: Image.asset(
                            'assets/images/gacha_handle.png',
                            width: 104,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
