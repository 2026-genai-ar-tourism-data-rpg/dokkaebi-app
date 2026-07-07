// ============================================================
// [v1] 화면: 홈 대시보드 (시안 8번)
// pipeline: 모바일 클라이언트 / 화면 (홈 탭 — 허브)
// 구현(요약): 인사·스탯·기억석 진행도·활성 퀘스트·새 탐험 시작(코스 생성 진입)·추천 장소.
//            데이터는 시안 기준 더미(서버 유저/진행 API 붙으면 교체 — 이지선/정찬희).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'create_scenario_screen.dart';
import 'place_detail_screen.dart';
import 'quest_play_screen.dart';

/// 홈의 "활성 퀘스트" 탭 시 이어할 샘플 노드 (서버 진행 API 붙으면 교체).
final QuestNode _activeQuestNode = QuestNode(
  order: 0,
  nodeId: 'jongno_gyeongbok',
  name: '경복궁',
  mapX: 126.9770,
  mapY: 37.5796,
  distM: 1200,
  triggerRadiusM: 100,
  fragmentId: '서울_stone_3of5',
  npcDialogue: '허허, 경복궁에 깃든 기억의 조각이 근정전 어딘가에 숨었느니라. 눈을 크게 뜨고 찾아보거라.',
  isFinale: false,
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // 인사 + 등급 배지
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('탐사도 탐험가',
                      style: TextStyle(color: AppColors.teal, fontSize: 11, letterSpacing: 2)),
                  SizedBox(height: 2),
                  Text('안녕하세요, 용사님',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.teal.withOpacity(0.18),
              child: const Text('17', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 스탯 3종
        Row(children: const [
          StatTile(Icons.shield_outlined, '17', '탐사 등급', AppColors.teal),
          SizedBox(width: 10),
          StatTile(Icons.diamond_outlined, '43/100', '기억석', AppColors.purple),
          SizedBox(width: 10),
          StatTile(Icons.auto_awesome_outlined, '12', '유물', AppColors.gold),
        ]),
        const SizedBox(height: 16),
        // 기억석 진행도
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('기억석 진행도', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text('43%', style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              const ProgressBar(0.43, color: AppColors.purple),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 활성 퀘스트
        const Text('활성 퀘스트', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        GlowCard(
          glow: AppColors.gold,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuestPlayScreen(node: _activeQuestNode)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Text('서울 · 진행 중',
                    style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                Spacer(),
                Text('⚡ +450', style: TextStyle(color: AppColors.gold, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              const Text('경복궁의 잊혀진 비밀',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const ProgressBar(0.6, color: AppColors.gold),
              const SizedBox(height: 6),
              Row(children: const [
                Text('3/5 단계 완료', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Spacer(),
                Text('이어하기 ›', style: TextStyle(color: AppColors.gold, fontSize: 12)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 새 탐험 시작 (코스 생성 진입)
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateScenarioScreen()),
          ),
          icon: const Icon(Icons.explore),
          label: const Text('새 탐험 시작'),
        ),
        const SizedBox(height: 20),
        // 오늘 추천 장소
        const Text('오늘 추천 장소', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        GlowCard(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PlaceDetailScreen())),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('경복궁', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('서울 · 1.2km · ⚡+50 XP', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
