// ============================================================
// [v1] 화면: 프로필 — 탭 골격
// pipeline: 모바일 클라이언트 / 화면 (프로필 탭)
// 구현(요약): 헤더 + 유저 요약 placeholder. 인증·도감률·방문률은 TODO(이지선/정찬희).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('PROFILE', '내 정보'),
        const SizedBox(height: 16),
        GlowCard(
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.teal.withOpacity(0.18),
              child: const Icon(Icons.person, color: AppColors.teal),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('용사님', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('탐사 등급 17 · 종로의 기억 복원자', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: const [
          StatTile(Icons.place_outlined, '43%', '방문률', AppColors.teal),
          SizedBox(width: 10),
          StatTile(Icons.menu_book_outlined, '2/8', '도감', AppColors.purple),
          SizedBox(width: 10),
          StatTile(Icons.emoji_events_outlined, '5', '칭호', AppColors.gold),
        ]),
        const SizedBox(height: 12),
        const GlowCard(
          child: Text('설정·로그인·도감/칭호 (준비 중)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }
}
