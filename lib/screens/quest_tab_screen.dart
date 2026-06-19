// ============================================================
// [v1] 화면: 퀘스트 일지 (시안 3번)
// pipeline: 모바일 클라이언트 / 화면 (퀘스트 탭)
// 구현(요약): 내가 만든 탐험(ScenarioStore) 목록 + 데모 진행 퀘스트. 탭 → 코스 보기.
//            store 구독(ListenableBuilder)으로 새 탐험 생성 시 자동 반영.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'create_scenario_screen.dart';
import 'scenario_screen.dart';

class QuestTabScreen extends StatelessWidget {
  const QuestTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ScenarioStore.I,
      builder: (context, _) {
        final mine = ScenarioStore.I.scenarios;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('QUEST LOG', '퀘스트 일지'),
            const SizedBox(height: 16),
            Row(children: const [
              Pill('🗡 메인 퀘스트', active: true, color: AppColors.gold),
              SizedBox(width: 8),
              Pill('사이드 퀘스트'),
            ]),
            const SizedBox(height: 16),

            // 내가 만든 탐험
            if (mine.isNotEmpty) ...[
              const Text('내가 만든 탐험', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              ...mine.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MyScenarioCard(s),
                  )),
              const SizedBox(height: 8),
            ],

            // 데모 진행 퀘스트(시안)
            const Text('진행 중 (예시)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            GlowCard(
              glow: AppColors.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Text('서울 · 진행 중', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                    Spacer(),
                    Text('⚡ +450', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  const Text('경복궁의 잊혀진 비밀',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const ProgressBar(0.6, color: AppColors.gold),
                  const SizedBox(height: 12),
                  _step('경복궁 도착 확인', true),
                  _step('기억석 조각 3개 수집', true),
                  _step('청룡 도깨비와 대화', true),
                  _step('근정전 앞 문양 해독', false),
                  _step('기억 복원 의식 완료', false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const CreateScenarioScreen())),
              icon: const Icon(Icons.add),
              label: const Text('새 코스 만들기'),
            ),
          ],
        );
      },
    );
  }

  Widget _step(String label, bool done) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: done ? AppColors.teal : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: done ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13)),
        ]),
      );
}

/// 내가 만든 탐험 카드 (탭 → 코스 상세)
class _MyScenarioCard extends StatelessWidget {
  final Scenario s;
  const _MyScenarioCard(this.s);

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glow: AppColors.teal,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ScenarioScreen(scenario: s))),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.explore, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${s.region} · ${s.nodeSequence.length}조각',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
