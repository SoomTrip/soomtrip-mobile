import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'worldcup_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  static const _pages = [
    (
      image: 'assets/images/intro1.png',
      title: 'TRAVEL GACHA',
      body: '취향 월드컵을 진행하면서\n나의 여행 스케치북을 완성하고,\n가챠를 통해 나만의 숨겨진 여행지를 뽑아요',
    ),
    (
      image: 'assets/images/intro2.png',
      title: 'ROUTE & DIARY',
      body:
          '가챠로 얻은 여행지를 볼 수 있어요.\n각 여행지별로 여행 경로를 추천받고,\n여행 후 그림일기로 추억을 기억할 수 있어요',
    ),
    (
      image: 'assets/images/intro3.png',
      title: 'STAMP',
      body: '그림일기를 완성하면 도장판에 도장이 찍혀요.\n다양한 여행지에 대한 도장을 모아보세요',
    ),
    (
      image: 'assets/images/intro4.png',
      title: 'FRIENDS',
      body: '친구와 여행지를 공유할 수 있어요.\n함께 여행하는 기쁨을 누려보세요!',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishIntro() async {
    await AuthService.markIntroCompleted();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WorldCupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var index = 0; index < _pages.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color(0xFF5A4538)
                                  : const Color(0xFFC9C9C9),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    itemBuilder: (context, index) => _buildPage(_pages[index]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _currentPage == _pages.length - 1
                        ? OutlinedButton(
                            onPressed: _finishIntro,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDFCF9),
                              foregroundColor: const Color(0xFF202023),
                              side: const BorderSide(
                                  color: Color(0xFF292929), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '시작하기',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(({String image, String title, String body}) page) {
    return LayoutBuilder(builder: (context, constraints) {
      final minimumHeight = 360 + MediaQuery.textScalerOf(context).scale(140);
      final height = constraints.maxHeight < minimumHeight
          ? minimumHeight
          : constraints.maxHeight;
      return SingleChildScrollView(
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    page.title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Color(0xFF202023),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  page.body,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Color(0xFF29292D),
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 941,
                        height: 1060,
                        // The source artwork has large blank top/bottom margins.
                        // Show its illustrated area without cropping the drawing.
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: 1672,
                            maxHeight: 1672,
                            child: Transform.translate(
                              offset: const Offset(0, -370),
                              child: Image.asset(page.image,
                                  width: 941,
                                  height: 1672,
                                  fit: BoxFit.fill,
                                  excludeFromSemantics: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
