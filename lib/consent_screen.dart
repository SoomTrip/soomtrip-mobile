import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';
import 'splash_screen.dart';

// 카카오 로그인 직후, 이용약관·개인정보 수집·이용 동의가 아직 안 된 계정에게
// 보여주는 필수 동의 화면. 동의해야만 다음(인트로/홈)으로 넘어간다.
class ConsentScreen extends StatefulWidget {
  // 동의 완료 후 이동할 화면. 온보딩 완료 여부에 따라 호출부에서 미리 정해서 넘겨준다.
  final Widget nextScreen;

  const ConsentScreen({super.key, required this.nextScreen});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreePrivacy = false;
  bool _agreeTerms = false;
  bool _isSaving = false;

  bool get _allAgreed => _agreePrivacy && _agreeTerms;

  Future<void> _openInAppBrowser(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
    } catch (_) {
      // 열지 못해도 동의 화면 자체는 계속 진행 가능하게 둔다.
    }
  }

  Future<void> _onSubmit() async {
    if (!_allAgreed || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await AuthService.agreeToRequiredTerms();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('동의 처리에 실패했어요. 다시 시도해 주세요.')),
      );
    }
  }

  // 동의를 거부하면 이 서비스를 이용할 수 없다 (카카오 로그인 기반이라
  // 개인정보 수집 없이는 회원 식별 자체가 안 됨). 로그아웃 후 로그인 화면으로.
  Future<void> _onDecline() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await AuthService.logout();
    } catch (_) {
      // 로그아웃 API 실패해도 로컬 세션은 정리하고 로그인 화면으로 보낸다.
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('시작하기 전에\n확인 및 동의가 필요해요',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                      color: Color(0xFF333333))),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      _buildAllAgreeRow(),
                      const Divider(height: 24),
                      _buildAgreeRow(
                        label: '[필수] 개인정보 수집 및 이용 동의',
                        value: _agreePrivacy,
                        onChanged: (v) =>
                            setState(() => _agreePrivacy = v ?? false),
                        onViewDetail: () => _openInAppBrowser(
                            'https://soomtrip.cspc.me/privacy'),
                      ),
                      const SizedBox(height: 4),
                      _buildAgreeRow(
                        label: '[필수] 이용약관 동의',
                        value: _agreeTerms,
                        onChanged: (v) =>
                            setState(() => _agreeTerms = v ?? false),
                        onViewDetail: () =>
                            _openInAppBrowser('https://soomtrip.cspc.me/terms'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _allAgreed && !_isSaving ? _onSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A7C59),
                    disabledBackgroundColor: const Color(0xFFCBD5C9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('동의하고 시작하기',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
              TextButton(
                onPressed: _isSaving ? null : _onDecline,
                child: const Text('동의하지 않음 (로그아웃)',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE6D9)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('개인정보 수집·이용 안내',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 10),
          _InfoRow(label: '수집 항목', value: '카카오 식별자, 닉네임, 프로필 이미지'),
          _InfoRow(label: '이용 목적', value: '회원 식별, 로그인 유지, 여행지 추천 서비스 제공'),
          _InfoRow(label: '보유 기간', value: '회원탈퇴 시까지'),
          _InfoRow(
              label: '동의 거부 권리', value: '동의를 거부할 수 있으며, 이 경우 서비스 이용이 제한돼요.'),
        ],
      ),
    );
  }

  Widget _buildAllAgreeRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        final next = !_allAgreed;
        _agreePrivacy = next;
        _agreeTerms = next;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: _allAgreed,
              activeColor: const Color(0xFF4A7C59),
              onChanged: (v) => setState(() {
                _agreePrivacy = v ?? false;
                _agreeTerms = v ?? false;
              }),
            ),
            const Text('전체 동의합니다',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreeRow({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onViewDetail,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: const Color(0xFF4A7C59),
          onChanged: onChanged,
        ),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        TextButton(
          onPressed: onViewDetail,
          child: const Text('보기',
              style:
                  TextStyle(color: Color(0xFF6B4E31), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
          children: [
            TextSpan(
                text: '$label  ',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
