// ============================================================
// [v1] 화면: 퀘스트 일지 (시안 3) — 메인 + 내 코스(상태 구분)
// pipeline: 모바일 클라이언트 / 화면 (퀘스트 탭)
// 구현(요약): 지역 메인 퀘스트 + 내가 만든 코스를 상태별(이어하기/시작전/완료)로 그룹.
//            진행 중을 맨 위로 → "하다 멈춘 것 vs 새 것" 구분. store 구독으로 자동 반영.
// 구현일: 2026-06-18 (상태 그룹: 2026-06-19) | 작성: kys (app-scaffold/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'create_scenario_screen.dart';
import 'quest_journey_screen.dart';
import 'scenario_screen.dart';

class QuestTabScreen extends StatelessWidget {
  const QuestTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ScenarioStore.I,
      builder: (context, _) {
        final mine = ScenarioStore.I.scenarios;
        // 진행/완료는 기억석 조각(식음 제외) 기준
        int p(Scenario s) => ScenarioStore.I.stoneProgressOf(s);
        final inProgress = mine.where((s) => p(s) > 0 && p(s) < s.stoneTotal).toList();
        final notStarted = mine.where((s) => p(s) == 0).toList();
        final completed = mine.where((s) => s.stoneTotal > 0 && p(s) >= s.stoneTotal).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('QUEST LOG', '퀘스트 일지'),
            const SizedBox(height: 16),

            // 새 퀘스트 시작하기 — 종로의 기억석 플레이 여정(setup→…→엔딩)
            _StartJourneyButton(scenario: inProgress.isNotEmpty
                ? inProgress.first
                : (notStarted.isNotEmpty ? notStarted.first : (mine.isNotEmpty ? mine.first : null))),
            const SizedBox(height: 20),

            // 지역 메인 퀘스트 (지역 챕터 — 운영 스토리)
            const Text('🗡 지역 메인 퀘스트', style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _mainQuestCard(),
            const SizedBox(height: 20),

            // 내 코스 (맞춤/사이드) — 상태별
            const Text('🧭 내 코스', style: TextStyle(color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            if (mine.isEmpty)
              GlowCard(
                child: const Text('아직 만든 코스가 없어요. "새 코스 만들기"로 시작하세요.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),

            if (inProgress.isNotEmpty) ...[
              _groupLabel('이어하기 · 진행 중', inProgress.length),
              ...inProgress.map((s) => _MyScenarioCard(s, status: _Status.inProgress)),
            ],
            if (notStarted.isNotEmpty) ...[
              _groupLabel('시작 전', notStarted.length),
              ...notStarted.map((s) => _MyScenarioCard(s, status: _Status.notStarted)),
            ],
            if (completed.isNotEmpty) ...[
              _groupLabel('완료', completed.length),
              ...completed.map((s) => _MyScenarioCard(s, status: _Status.completed)),
            ],

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

  Widget _groupLabel(String label, int n) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text('$label  ·  $n',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );

  Widget _mainQuestCard() => GlowCard(
        glow: AppColors.gold,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Text('서울 종로 · 진행 중', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
            Spacer(),
            Text('⚡ +450', style: TextStyle(color: AppColors.gold, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          const Text('잠든 종로의 기억',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('청룡 수호 도깨비 · 랜드마크 5곳', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          const ProgressBar(0.4, color: AppColors.gold),
          const SizedBox(height: 4),
          const Text('기억석 2/5 복원', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      );
}

/// 새 퀘스트 시작하기 — 종로의 기억석 플레이 여정 진입 히어로 버튼.
class _StartJourneyButton extends StatelessWidget {
  final Scenario? scenario;
  const _StartJourneyButton({this.scenario});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuestJourneyScreen(scenario: scenario)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFE8C268), Color(0xFFC89A3A)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFE8C268).withOpacity(0.3), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF17130F).withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF4C860), width: 1.5),
            ),
            child: Text('訓', style: dokkaebiTitle(size: 22, color: const Color(0xFFF4C860))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('새 퀘스트 시작하기',
                  style: dokkaebiTitle(size: 18, color: const Color(0xFF3A2A08))),
              const SizedBox(height: 2),
              Text(scenario != null ? '${scenario!.region} · ${scenario!.title}' : '종로, 잊혀진 글씨의 비밀',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF5A430E), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const Icon(Icons.play_circle_fill, color: Color(0xFF3A2A08), size: 30),
        ]),
      ),
    );
  }
}

enum _Status { inProgress, notStarted, completed }

/// 내 코스 카드 (상태 뱃지 + 지역 + 진행률)
class _MyScenarioCard extends StatelessWidget {
  final Scenario s;
  final _Status status;
  const _MyScenarioCard(this.s, {required this.status});

  @override
  Widget build(BuildContext context) {
    final p = ScenarioStore.I.stoneProgressOf(s);
    final total = s.stoneTotal;
    final (badgeText, badgeColor) = switch (status) {
      _Status.inProgress => ('진행 중 $p/$total', AppColors.gold),
      _Status.notStarted => ('시작 전', AppColors.purple),
      _Status.completed => ('완료 ✓', AppColors.teal),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlowCard(
        glow: status == _Status.inProgress ? AppColors.gold : null,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ScenarioScreen(scenario: s))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(s.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${s.region} · ${total}조각', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (status != _Status.notStarted) ...[
            const SizedBox(height: 8),
            ProgressBar(total == 0 ? 0 : p / total,
                color: status == _Status.completed ? AppColors.teal : AppColors.gold),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                status == _Status.inProgress ? '이어하기 ›'
                    : status == _Status.notStarted ? '시작하기 ›' : '다시 보기 ›',
                style: TextStyle(color: badgeColor, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
