// ============================================================
// [v2] 필터 칩 제거 + 실제로 만난 도깨비로 카드 동적 연결.
// 구현(요약): 지역 필터 칩(전체/서울/경주/전주)은 onTap조차 없는 순수 장식이라
//            제거. 도깨비 카드 2장(청룡·화룡) 하드코딩도 제거하고,
//            ScenarioStore의 완료 노드 중 npcName이 있는 것들을 "만난 도깨비"로
//            모아 채운다(이름 기준 중복 제거). ⚠️ 등급(전설/영웅)과 개별
//            친밀도는 지금 데이터에 없어서 카드에서 뺐다 — AI가 NPC별 등급을
//            안 내려주고, 친밀도(PlayerState.affinity)는 시나리오당 전역
//            누적치 하나뿐이라 도깨비별로 못 나눈다.
// 구현일: 2026-08-26 | 작성: ljs (world-map-live/ljs/v2)
// ------------------------------------------------------------
// [v1] 화면: 도깨비 도감 (시안 1번) — 탭 골격
// pipeline: 모바일 클라이언트 / 화면 (도감 탭)
// 구현(요약): 헤더 + 등급 칩 + placeholder. 도깨비 카드 그리드·친밀도는 TODO(이지선 데이터).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class DexScreen extends StatelessWidget {
  const DexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ScenarioStore.I,
      builder: (context, _) {
        final met = ScenarioStore.I.metDokkaebi();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('ENCYCLOPEDIA', '도깨비 도감'),
            const SizedBox(height: 8),
            Text('${met.length}마리 발견',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            if (met.isEmpty)
              GlowCard(
                child: const Text('아직 만난 도깨비가 없어요. 퀘스트를 진행하면 여기에 채워져요.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // 0.85였으나 좁은 기기에서 3.6px 모자랐다 — 텍스트 한 줄 고정 후에도
                // 여유가 필요해 셀을 조금 더 높게 잡는다.
                childAspectRatio: 0.78,
                children: [
                  for (final d in met) _dokkaebi(d.name, d.region),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _dokkaebi(String name, String region) {
    const c = AppColors.gold; // 등급 데이터가 없어 고정 색.
    return GlowCard(
      glow: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
                color: c.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.local_fire_department, color: c),
          ),
          const Spacer(),
          // 좁은 셀(320px 기기에서 내부 폭 ~104px)에서 지역·이름이 여러 줄로
          // 접히면 카드 높이를 넘겨 오버플로가 난다 → 한 줄 + 말줄임으로 고정.
          Text(region,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
