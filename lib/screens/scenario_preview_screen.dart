// ============================================================
// [v1] 화면: 시나리오 상세 (탐험 마법사 결과 미리보기)
// pipeline: 모바일 클라이언트 / 화면 (코스 생성 직후 → 탐험 시작 전 확인)
// 구현(요약): 생성된 시나리오 요약 + 방문 순서 미리보기. "탐험 시작"을 눌러야
//            실제 프롤로그/코스 허브(ScenarioScreen)로 들어간다.
//            예상 시간·난이도는 서버가 안 주는 값이라 draft(사용자가 고른 조건)로 대신 표시.
// 구현일: 2026-08-05 | 작성: Claude · 시안: dokkaebi-ai/docs/images/10-senario-detail.png
// ============================================================
import 'package:flutter/material.dart';

import '../models/explore_draft.dart';
import '../models/scenario.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'prologue_screen.dart';
import 'scenario_screen.dart';

class ScenarioPreviewScreen extends StatelessWidget {
  final Scenario scenario;
  final ExploreDraft draft;
  const ScenarioPreviewScreen({super.key, required this.scenario, required this.draft});

  double get _totalDistM => scenario.nodeSequence
      .map((n) => n.distM ?? 0)
      .fold(0.0, (a, b) => a + b);

  void _startExploring(BuildContext context) {
    final target = Session.prologueSeen
        ? ScenarioScreen(scenario: scenario)
        : PrologueScreen(scenario: scenario);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => route.isFirst,
    );
  }

  void _editConditions(BuildContext context) {
    // 스택: 장소 → 여행조건 → 입력확인 → (이 화면). 두 번 pop하면 여행조건으로 돌아간다.
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stoneTotal = scenario.stoneTotal;
    final km = (_totalDistM / 1000).toStringAsFixed(1);
    return Scaffold(
      appBar: AppBar(title: const Text('시나리오 상세')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    width: double.infinity,
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHi,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(scenario.title,
                          textAlign: TextAlign.center,
                          style: dokkaebiTitle(size: 20, color: AppColors.gold)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('${scenario.region} · 목표 ${draft.duration} · 도보 ${km}km · ${draft.difficulty}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 14),
                  if (stoneTotal > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                          List.generate(stoneTotal, (i) => '${i + 1}').join('  —  '),
                          style: const TextStyle(
                              color: AppColors.gold, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  const SizedBox(height: 20),
                  const Text('방문 순서',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...scenario.nodeSequence.map((n) => _NodePreviewRow(node: n)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _editConditions(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.border),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('내 취향으로 수정', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _startExploring(context),
                    child: const Text('탐험 시작'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodePreviewRow extends StatelessWidget {
  final QuestNode node;
  const _NodePreviewRow({required this.node});

  String get _kindLabel {
    if (node.isFinale) return '피날레';
    if (node.kind == 'cafe') return '카페';
    if (node.kind == 'food') return '맛집';
    return '관광지';
  }

  String get _visitLabel => node.isFood ? '선택 방문' : (node.isFinale ? '기억석 복원' : '주요 퀘스트');

  @override
  Widget build(BuildContext context) {
    final dist = node.distM != null ? ' · 다음 ${node.distM!.toStringAsFixed(0)}m' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlowCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withOpacity(0.16),
              border: Border.all(color: AppColors.gold),
            ),
            child: Text('${node.order + 1}',
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.name ?? node.nodeId,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('$_kindLabel · $_visitLabel$dist',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
