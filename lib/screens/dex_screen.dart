// ============================================================
// [v1] 화면: 도깨비 도감 (시안 1번) — 탭 골격
// pipeline: 모바일 클라이언트 / 화면 (도감 탭)
// 구현(요약): 헤더 + 등급 칩 + placeholder. 도깨비 카드 그리드·친밀도는 TODO(이지선 데이터).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';

class DexScreen extends StatelessWidget {
  const DexScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader('ENCYCLOPEDIA', '도깨비 도감'),
        const SizedBox(height: 8),
        const Text('2/8 발견 완료', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: const [
          Pill('전체', active: true),
          Pill('서울'),
          Pill('경주'),
          Pill('전주'),
        ]),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            _dokkaebi('청룡 도깨비', '전설', '서울', 0.72),
            _dokkaebi('화룡 도깨비', '영웅', '경주', 0.35),
            _locked(),
            _locked(),
          ],
        ),
      ],
    );
  }

  Widget _dokkaebi(String name, String tier, String region, double bond) {
    final c = tierColor(tier);
    return GlowCard(
      glow: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56, width: 56,
            decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.local_fire_department, color: c),
          ),
          const Spacer(),
          Text(tier, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ProgressBar(bond, color: c),
          const SizedBox(height: 4),
          Text('친밀도 ${(bond * 100).round()}/100',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _locked() => GlowCard(
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 28),
            SizedBox(height: 8),
            Text('???', style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}
