import 'package:flutter/material.dart';
import 'worldcup_screen.dart';
import 'my_page_screen.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'stamp_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 월드컵, 도장, 홈, 친구, 마이 순서이며 처음에는 홈을 표시합니다.
  int _currentIndex = 2;

  // Hot Reload 후에도 탭 구성이 즉시 반영되도록 매번 현재 목록을 반환합니다.
  List<Widget> get _pages => const [
        WorldCupScreen(),
        StampScreen(),
        HomeScreen(),
        FriendsScreen(),
        MyPageScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE), // 앱 기본 배경색

      // 1. 메인 화면 (현재 선택된 탭의 화면을 보여줌)
      body: SafeArea(
        child: _pages[_currentIndex],
      ),

      // 2. 하단 내비게이션 바
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          // 🌟 탭을 누를 때마다 _currentIndex를 바꿔서 화면을 전환하는 마법
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },

          // 디자인 설정
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF6B4E31), // 선택된 탭 색상 (숨트립 테마색)
          unselectedItemColor: Colors.grey.shade400, // 선택 안 된 탭 색상
          selectedFontSize: 12,
          unselectedFontSize: 12,

          // 3. 5개의 탭 버튼들
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_rounded), // 🏆 트로피 모양
              label: '월드컵',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.approval_rounded),
              label: '도장',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), // 🏠 홈 모양
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded), // 👥 사람 두 명 모양
              label: '친구',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), // 👤 사람 한 명 모양
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
