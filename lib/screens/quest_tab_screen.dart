// ============================================================
// [v2] 화면: 퀘스트 일지 — 04 Library 시안 기반 재구성
// pipeline: 모바일 클라이언트 / 화면 (퀘스트 탭)
// 구현(요약): 상단 "새 퀘스트 시작하기"(이어하기)는 유지, 그 아래를
//            [내 주변 탐험 / 시나리오 라이브러리] 토글 + 카드 리스트로 재구성.
//            ⚠️ 다른 유저 공개 코스·좌표기반 추천·평점·즐겨찾기는 서버 미지원(DB 없음) —
//            "시나리오 라이브러리"는 기존 지역 메인 퀘스트(공식 추천 1건, 더미)와
//            ScenarioStore의 내가 만든 코스만 보여준다. "내 주변 탐험"은 준비중 안내.
//            평점(★)은 데이터가 없어 카드에서 제외, 완주율은 실제 진행률로 표시.
// 구현일: 2026-08-05 | 작성: Claude · 시안: dokkaebi-ai/docs/images/09-library.png ("04 Library")
// ------------------------------------------------------------
// [v1] 지역 메인 퀘스트 + 내 코스(상태별 그룹) — 2026-06-18/19 kys (app-scaffold/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'explore_place_screen.dart';
import 'quest_journey_screen.dart';
import 'scenario_screen.dart';

enum _Sort { latest, completion }

class QuestTabScreen extends StatefulWidget {
  const QuestTabScreen({super.key});
  @override
  State<QuestTabScreen> createState() => _QuestTabScreenState();
}

class _QuestTabScreenState extends State<QuestTabScreen> {
  int _section = 1; // 0 = 내 주변 탐험, 1 = 시나리오 라이브러리
  _Sort _sort = _Sort.latest;

  double _completion(Scenario s) =>
      s.stoneTotal == 0 ? 0 : ScenarioStore.I.stoneProgressOf(s) / s.stoneTotal;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ScenarioStore.I,
      builder: (context, _) {
        final mine = List<Scenario>.from(ScenarioStore.I.scenarios);
        if (_sort == _Sort.completion) {
          mine.sort((a, b) => _completion(b).compareTo(_completion(a)));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('QUEST LOG', '퀘스트 일지'),
            const SizedBox(height: 16),

            // 새 퀘스트 시작하기 — 종로의 기억석 플레이 여정(setup→…→엔딩)
            _StartJourneyButton(scenario: mine.isNotEmpty ? mine.first : null),
            const SizedBox(height: 20),

            _SectionToggle(section: _section, onChanged: (i) => setState(() => _section = i)),
            const SizedBox(height: 16),

            if (_section == 0)
              const _NearbyPlaceholder()
            else ...[
              Row(children: [
                Pill('최신순', active: _sort == _Sort.latest,
                    onTap: () => setState(() => _sort = _Sort.latest)),
                const SizedBox(width: 8),
                Pill('완주율순', active: _sort == _Sort.completion,
                    onTap: () => setState(() => _sort = _Sort.completion)),
              ]),
              const SizedBox(height: 12),
              const _LibraryCard.official(),
              const SizedBox(height: 10),
              if (mine.isEmpty)
                GlowCard(
                  child: const Text('아직 만든 코스가 없어요. "새 코스 만들기"로 시작하세요.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                )
              else
                ...mine.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LibraryCard.mine(s),
                    )),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const ExplorePlaceScreen())),
                icon: const Icon(Icons.add),
                label: const Text('새 코스 만들기'),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// [내 주변 탐험 / 시나리오 라이브러리] 두 칸 토글 — 활성 칸만 채움.
class _SectionToggle extends StatelessWidget {
  final int section;
  final ValueChanged<int> onChanged;
  const _SectionToggle({required this.section, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        _cell('내 주변 탐험', 0),
        _cell('시나리오 라이브러리', 1),
      ]),
    );
  }

  Widget _cell(String label, int i) {
    final active = section == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.teal.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? AppColors.teal : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// "내 주변 탐험" 빈 상태 — 좌표 기반 추천 API가 아직 없다.
class _NearbyPlaceholder extends StatelessWidget {
  const _NearbyPlaceholder();
  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.near_me_outlined, color: AppColors.textMuted, size: 18),
          SizedBox(width: 8),
          Text('내 주변 탐험은 준비 중이에요',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        const Text('위치 기반 추천은 GPS 연동 후 제공될 예정입니다. 그동안 시나리오 라이브러리를 둘러보세요.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
      ]),
    );
  }
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

/// 라이브러리 카드 — 대표이미지 자리 + 배지(공식추천/내가 만든 코스) + 실제 완주율.
/// 평점(★)은 데이터가 없어 표시하지 않는다.
class _LibraryCard extends StatelessWidget {
  final bool official;
  final Scenario? scenario;
  const _LibraryCard.official() : official = true, scenario = null;
  const _LibraryCard.mine(Scenario s) : official = false, scenario = s;

  @override
  Widget build(BuildContext context) {
    if (official) return _build(context, _officialData());
    return _build(context, _mineData(context, scenario!));
  }

  ({String badge, Color badgeColor, String title, String subtitle1, String subtitle2,
      double completion, String statusText, Color statusColor, VoidCallback? onTap})
      _officialData() => (
        badge: '공식 추천',
        badgeColor: AppColors.gold,
        title: '잠든 종로의 기억',
        subtitle1: '서울 종로 · 랜드마크 5곳',
        subtitle2: '청룡 수호 도깨비',
        completion: 0.4,
        statusText: '진행 중',
        statusColor: AppColors.gold,
        onTap: null,
      );

  ({String badge, Color badgeColor, String title, String subtitle1, String subtitle2,
      double completion, String statusText, Color statusColor, VoidCallback? onTap})
      _mineData(BuildContext context, Scenario s) {
    final p = ScenarioStore.I.stoneProgressOf(s);
    final total = s.stoneTotal;
    final status = p == 0
        ? _Status.notStarted
        : (p >= total ? _Status.completed : _Status.inProgress);
    final (statusText, statusColor) = switch (status) {
      _Status.inProgress => ('진행 중 $p/$total', AppColors.gold),
      _Status.notStarted => ('시작 전', AppColors.purple),
      _Status.completed => ('완료 ✓', AppColors.teal),
    };
    return (
      badge: '내가 만든 코스',
      badgeColor: AppColors.teal,
      title: s.title,
      subtitle1: '${s.region} · ${_composition(s)}',
      subtitle2: '도보 ${_totalKm(s).toStringAsFixed(1)}km · $total조각',
      completion: total == 0 ? 0 : p / total,
      statusText: statusText,
      statusColor: statusColor,
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ScenarioScreen(scenario: s))),
    );
  }

  static String _composition(Scenario s) {
    var attraction = 0, cafe = 0, food = 0;
    for (final n in s.nodeSequence) {
      if (n.kind == 'cafe') {
        cafe++;
      } else if (n.kind == 'food') {
        food++;
      } else {
        attraction++;
      }
    }
    final parts = <String>[
      if (attraction > 0) '관광지 $attraction',
      if (cafe > 0) '카페 $cafe',
      if (food > 0) '맛집 $food',
    ];
    return parts.isEmpty ? '구성 정보 없음' : parts.join(' · ');
  }

  static double _totalKm(Scenario s) =>
      s.nodeSequence.map((n) => n.distM ?? 0).fold(0.0, (a, b) => a + b) / 1000;

  Widget _build(
    BuildContext context,
    ({String badge, Color badgeColor, String title, String subtitle1, String subtitle2,
        double completion, String statusText, Color statusColor, VoidCallback? onTap}) d,
  ) {
    return GlowCard(
      padding: EdgeInsets.zero,
      onTap: d.onTap,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 84,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHi,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.terrain_outlined, color: AppColors.textMuted, size: 28),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: d.badgeColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(d.badge,
                        style: TextStyle(color: d.badgeColor, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(d.statusText, style: TextStyle(color: d.statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(d.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(d.subtitle1,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                Text(d.subtitle2,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ProgressBar(d.completion, color: d.badgeColor)),
                  const SizedBox(width: 8),
                  Text('완주율 ${(d.completion * 100).round()}%',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
