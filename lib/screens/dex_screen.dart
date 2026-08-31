// ============================================================
// [v3] 기억석 도감 추가 — 도깨비/기억석 두 탭.
// 구현(요약): 도깨비 도감만 있던 화면에 "기억석" 탭 추가. ScenarioStore.
//            collectedStones()(신규)로 완료한 기억석 조각을 모아 이름+지역만
//            표시 — QuestNode엔 "훈 — 운현궁" 같은 제목·설명 필드 자체가 없어
//            (그건 quest_journey_screen.dart의 하드코딩 4장, 별도 버그) 도깨비
//            도감과 동일하게 이름+지역만으로 채운다. 도깨비와 달리 같은 이름도
//            서로 다른 조각이라 중복 제거하지 않는다.
// 구현일: 2026-09-01 | 작성: ljs (dex-stones/ljs/v1)
// ------------------------------------------------------------
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

enum _DexTab { dokkaebi, stone }

class DexScreen extends StatefulWidget {
  const DexScreen({super.key});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  _DexTab _tab = _DexTab.dokkaebi;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ScenarioStore.I,
      builder: (context, _) {
        final met = ScenarioStore.I.metDokkaebi();
        final stones = ScenarioStore.I.collectedStones();
        final isDokkaebi = _tab == _DexTab.dokkaebi;
        final items = isDokkaebi ? met : stones;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('ENCYCLOPEDIA', '도감'),
            const SizedBox(height: 12),
            Row(children: [
              Pill('도깨비',
                  active: isDokkaebi, onTap: () => setState(() => _tab = _DexTab.dokkaebi)),
              const SizedBox(width: 8),
              Pill('기억석',
                  active: !isDokkaebi,
                  color: AppColors.teal,
                  onTap: () => setState(() => _tab = _DexTab.stone)),
            ]),
            const SizedBox(height: 12),
            Text(isDokkaebi ? '${met.length}마리 발견' : '${stones.length}개 수집',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            if (items.isEmpty)
              GlowCard(
                child: Text(
                    isDokkaebi
                        ? '아직 만난 도깨비가 없어요. 퀘스트를 진행하면 여기에 채워져요.'
                        : '아직 모은 기억석이 없어요. 퀘스트를 진행하면 여기에 채워져요.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                  for (final item in items)
                    isDokkaebi
                        ? _card(item.name, item.region,
                            icon: Icons.local_fire_department, color: AppColors.gold)
                        : _card(item.name, item.region,
                            icon: Icons.diamond_outlined, color: AppColors.teal),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _card(String name, String region, {required IconData icon, required Color color}) {
    return GlowCard(
      glow: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration:
                BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          // 좁은 셀(320px 기기에서 내부 폭 ~104px)에서 지역·이름이 여러 줄로
          // 접히면 카드 높이를 넘겨 오버플로가 난다 → 한 줄 + 말줄임으로 고정.
          Text(region,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
