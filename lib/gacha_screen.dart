import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'recommendation_service.dart';
import 'saved_region_service.dart';

class GachaScreen extends StatefulWidget {
  final int? preferenceId;
  final Future<Map<String, dynamic>>? recommendationFuture;

  const GachaScreen({
    super.key,
    this.preferenceId,
    this.recommendationFuture,
  });

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // --- 🌟 연출 흐름을 제어하는 상태 변수들 ---
  double _turns = 0.0;
  bool _isSpinning = false; // 1. 손잡이가 돌아가는 중인가?
  bool _isDropped = false; // 2. 기계 밑으로 캡슐이 떨어졌는가?
  bool _showZoomedCapsule = false; // 3. 중앙에 큰 캡슐(오버레이)을 띄울 것인가?
  bool _isOpened = false; // 4. 캡슐이 열리고 티켓이 나왔는가?
  bool _showTicket = false;
  bool _isSavingRegion = false;
  late Future<Map<String, dynamic>> _recommendationFuture;
  Timer? _statusTimer;
  int _statusIndex = 0;
  final List<String> _statusMessages = const [
    '나의 여행 취향 분석 중... 🔍',
    '나만의 여행지 찾는 중... 🗺️',
    '거의 다 왔어요! ✨',
  ];
  String? _recommendedDestination;
  Map<String, dynamic>? _recommendedCandidate;

  String get _recommendedReview {
    final review = _recommendedCandidate?['one_line_review'];
    return review is String && review.trim().isNotEmpty
        ? review.trim()
        : '당신의 취향에 꼭 맞는 특별한 여행지예요.';
  }

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 50));
    _shakeAnimation =
        Tween<double>(begin: -4.0, end: 4.0).animate(_shakeController);
    final preferenceId = widget.preferenceId;
    _recommendationFuture = widget.recommendationFuture ??
        (preferenceId == null
            ? Future<Map<String, dynamic>>.error(
                StateError('취향 분석 결과가 없습니다.'),
              )
            : RecommendationService.create(preferenceId));
    _watchRecommendation(_recommendationFuture);
  }

  void _startStatusMessages() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _statusIndex >= _statusMessages.length - 1) return;
      setState(() => _statusIndex++);
    });
  }

  Future<void> _watchRecommendation(
    Future<Map<String, dynamic>> request,
  ) async {
    try {
      final candidate = await request;
      if (!mounted || !identical(request, _recommendationFuture)) return;
      setState(() {
        _recommendedCandidate = candidate;
        _recommendedDestination = candidate['name'] as String;
      });
    } catch (_) {
      if (!mounted || !identical(request, _recommendationFuture)) return;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
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
      _statusIndex = 0;
    });
    _startStatusMessages();
    _shakeController.repeat(reverse: true);

    try {
      final request = _recommendationFuture;
      await Future.wait([
        request,
        // 각 안내 문구를 최소 2초씩 보여 준다.
        Future<void>.delayed(const Duration(seconds: 6)),
      ]);
    } catch (error) {
      if (!mounted) return;
      _statusTimer?.cancel();
      _shakeController.stop();
      setState(() => _isSpinning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            error.toString().replaceFirst('Exception: ', '')),
      ),
      );
      return;
    }

    if (!mounted) return;
    _statusTimer?.cancel();
    _shakeController.stop();
    setState(() => _isDropped = true);

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _showZoomedCapsule = true);
  }

  Future<void> _openCapsule() async {
    if (_isOpened) return;
    setState(() => _isOpened = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showTicket = true);
  }

  // 🌟 처음 상태로 돌아가는 함수 (다시 뽑기)
  void _resetGacha() {
    final preferenceId = widget.preferenceId;
    if (preferenceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('취향 분석 결과가 없어 다시 뽑을 수 없습니다.')),
      );
      return;
    }

    // 버튼을 누르는 즉시 다음 추천 요청을 시작한다.
    final nextRequest = RecommendationService.create(preferenceId);
    _statusTimer?.cancel();
    _recommendationFuture = nextRequest;

    setState(() {
      _isSpinning = false;
      _isDropped = false;
      _showZoomedCapsule = false;
      _isOpened = false;
      _showTicket = false;
      _recommendedDestination = null;
      _recommendedCandidate = null;
      _statusIndex = 0;
    });
    _watchRecommendation(nextRequest);
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
      backgroundColor: const Color(0xFFFBF9F4),
      appBar: AppBar(
        title:
            const Text("운명의 여행지 뽑기", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/gacha_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // 덜덜 떨리는 가챠 기계 본체
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
                      top: 50,
                      left: 0,
                      right: 0,
                      child: Image.asset('assets/images/gacha_machine.png',
                          width: 350),
                    ),
                    // 떨어지는 작은 캡슐
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.bounceOut,
                      top: _isDropped ? 450 : 420,
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
                      top: 300,
                      left: 101,
                      child: GestureDetector(
                        onTap: _isSpinning ? null : _spinGacha,
                        child: AnimatedRotation(
                          turns: _turns,
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          child: Image.asset('assets/images/gacha_handle.png',
                              width: 116),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isSpinning && !_isDropped && !_showZoomedCapsule)
            Center(
              child: SizedBox(
                width: 350,
                height: 500,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        // Machine top + rendered image height + a small gap.
                        top: 50 + constraints.maxWidth * 1448 / 1086 + 6,
                        left: 0,
                        right: 0,
                        child: Text(
                          _statusMessages[_statusIndex],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3F5948),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 결과 캡슐과 티켓 레이어
          if (_showZoomedCapsule)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 430,
                        height: 480,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: -35,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 500),
                                opacity: _showTicket ? 1 : 0,
                                child: Container(
                                  width: 440,
                                  height: 440,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.95),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                      stops: const [0.2, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 50,
                              child: GestureDetector(
                                onTap: _openCapsule,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 0.96, end: 1)
                                          .animate(animation),
                                      child: child,
                                    ),
                                  ),
                                  child: Image.asset(
                                    _isOpened
                                        ? 'assets/images/gacha_capsule_open.png'
                                        : 'assets/images/gacha_capsule.png',
                                    key: ValueKey(_isOpened),
                                    width: 370,
                                  ),
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutBack,
                              top: _showTicket ? 135 : 225,
                              left: 15,
                              right: 15,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: _showTicket ? 1 : 0,
                                child: _showTicket
                                    ? _buildTicket(
                                        destination:
                                            _recommendedDestination ?? '',
                                        memo: _recommendedReview,
                                      )
                                    : const SizedBox(height: 250),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _showTicket
                            ? Row(
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
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 20),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEBE6D9),
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
                              )
                            : const Text(
                                '캡슐을 터치해주세요!',
                                key: ValueKey('tap-capsule'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Text(
                '출처: ⓒ한국관광공사',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _showZoomedCapsule ? Colors.white70 : Colors.black54,
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
        width: 420,
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
              left: 85,
              right: 125,
              height: 50,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  destination,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
            ),

            Positioned(
              top: 145,
              left: 130,
              child: SizedBox(
                width: 140, // 글자가 밖으로 튀어나가지 않게 제한
                child: AnimatedTextKit(
                  key: ValueKey((destination, memo)),
                  isRepeatingAnimation: false,
                  displayFullTextOnTap: true,
                  animatedTexts: [
                    TyperAnimatedText(
                      memo,
                      speed: const Duration(milliseconds: 110),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
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
}
