// ============================================================
// [v1] 화면: 온보딩 (시안 9·10) — Forgotten Legends Awaken
// pipeline: 모바일 클라이언트 / 화면 (첫 진입)
// 구현(요약): 기억석 글로우 + 스토리 페이지(PageView) + 다음/건너뛰기 → MainShell.
//            텍스트는 시안 그대로. 3D 기억석 에셋은 추후(이지선) — 지금은 다이아 글로우.
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    (
      'FORGOTTEN LEGENDS',
      'Forgotten Legends Awaken',
      '오래된 저주가 팔도의 정령들을 잠재웠다. 여덟 지역에 흩어진 기억석 조각을 모아라 — 각 조각은 잃어버린 전설의 한 조각이다.',
    ),
    (
      'YOUR JOURNEY',
      '발로 떠나는 탐사',
      '실제 관광지를 찾아가 GPS로 도착을 인증하고, AR로 숨은 기억석 조각을 수집한다. 도깨비 NPC가 그곳의 진짜 이야기를 들려준다.',
    ),
    (
      'BEGIN',
      '당신의 탐사가 시작된다',
      '가고 싶은 곳을 고르면 도깨비가 숨은 명소를 잇는 코스를 짜준다. 떠날 준비가 됐는가, 용사여?',
    ),
  ];

  void _finish() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const LoginScreen()));

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('건너뛰기', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageView(data: _pages[i]),
              ),
            ),
            // 페이지 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.teal : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: last
                    ? _finish
                    : () => _pc.nextPage(
                        duration: const Duration(milliseconds: 300), curve: Curves.ease),
                child: Text(last ? '시작하기' : '다음  ›'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  final (String, String, String) data;
  const _PageView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기억석 글로우 (다이아)
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 48),
              width: 120,
              height: 120,
              child: Transform.rotate(
                angle: 0.785, // 45°
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.teal, AppColors.blue]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppColors.teal.withOpacity(0.5), blurRadius: 40, spreadRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text(data.$1,
              style: const TextStyle(color: AppColors.teal, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(data.$2,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 16),
          Text(data.$3,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}
