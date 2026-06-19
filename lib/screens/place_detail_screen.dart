// ============================================================
// [v1] 화면: 관광지 상세 (시안 6)
// pipeline: 모바일 클라이언트 / 화면 (장소 상세 → 방문 인증)
// 구현(요약): 이미지 헤더·거리·설명·등장 도깨비·탐방 보상·방문 인증 CTA.
//            데이터는 파라미터(없으면 샘플). 이미지/도깨비 에셋은 추후(이지선).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';
import 'location_verify_screen.dart';

class PlaceDetailScreen extends StatelessWidget {
  final String name;
  final String region;
  final String overview;
  final double distanceKm;
  const PlaceDetailScreen({
    super.key,
    this.name = '경복궁',
    this.region = '서울 · 고궁',
    this.overview =
        '조선 왕조의 정궁. 1395년 창건되어 광화문과 근정전을 중심으로 왕실의 위엄을 보여준다. 잊혀진 기억의 조각이 이곳 어딘가에 잠들어 있다.',
    this.distanceKm = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 이미지 헤더 (에셋 전 그라데이션 placeholder)
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B2438), Color(0xFF243049)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: const Center(child: Icon(Icons.account_balance, color: AppColors.gold, size: 48)),
            ),
            const SizedBox(height: 14),
            Text(region, style: const TextStyle(color: AppColors.teal, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${distanceKm}km', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              const Text('244명 방문', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 16),
            const Text('약속의 전설', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(overview, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6)),
            const SizedBox(height: 16),
            // 만날 수 있는 도깨비
            const Text('만날 수 있는 도깨비', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            GlowCard(
              glow: AppColors.purple,
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.purple.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_fire_department, color: AppColors.purple),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('청룡 도깨비', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  Text('영웅 · 서울 보물', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            // 탐방 보상
            const Text('탐방 보상', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: const [
              _Reward(Icons.diamond_outlined, '기억석 x3', AppColors.purple),
              SizedBox(width: 10),
              _Reward(Icons.bolt, '+450 XP', AppColors.gold),
              SizedBox(width: 10),
              _Reward(Icons.menu_book_outlined, '도깨비 기록', AppColors.teal),
            ]),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => LocationVerifyScreen(placeName: name))),
              icon: const Icon(Icons.my_location),
              label: const Text('방문 인증'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reward extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Reward(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlowCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11)),
        ]),
      ),
    );
  }
}
