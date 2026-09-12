// ============================================================
// [v1] 화면: 여행 조건 (탐험 마법사 STEP 2/3)
// pipeline: 모바일 클라이언트 / 화면 (나만의 코스 만들기 2단계)
// 구현(요약): 시간·이동수단·동행·난이도·식음노드·예산 선택.
//            ⚠️ 시간·동행·난이도는 서버 미지원 필드 — draft에만 저장, 생성 요청엔 미포함.
// 구현일: 2026-08-05 | 작성: Claude · 시안: dokkaebi-ai/docs/images/07-travel-conditions.png
// ------------------------------------------------------------
// [v2] 식음·예산 입력 숨김 — 결과에 반영되지 않는 선택지를 걷어낸다.
// 구현(요약): '식음 노드 포함/제외'와 예산 슬라이더가 UI엔 있는데, AI의 식음 삽입 스위치
//            (scenario_food_per_route=0)와 가격대 미상 후보 배제 정책 때문에 어떤 값을
//            넣어도 식음 노드가 0개로 나왔다(4개 지역 실측). 사용자가 "식사 포함"을 켜고
//            예산을 맞춰도 결과가 같으면 그건 기만이다 → 기능을 켤 때까지 입력을 감춘다.
//            draft 필드는 그대로 두고(includeMeals=false·budget=null 고정) 화면만 숨겨서
//            스위치를 켜는 날 이 블록만 되살리면 되게 한다.
// 구현일: 2026-08-22 | 작성: kys (play-path-unify/kys/v1)
// ------------------------------------------------------------
// [v3] 마법사 1단계로 승격 — 반경을 먼저 고르고 그다음 장소를 고른다 (QA 1).
// 구현(요약): 장소를 먼저 고르는 순서라 반경을 나중에 바꿔도 이미 고른 장소에 아무 영향이
//            없었다(반경이 사실상 장식). 이 화면이 1단계가 되어 입력(ExploreDraft)을 만들고,
//            다음 단계인 장소 화면이 그 반경으로 검색 결과를 걸러낸다.
// 구현일: 2026-09-12 | 작성: ljs (explore-radius-first/ljs/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../models/explore_draft.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'explore_place_screen.dart';

class ExploreConditionsScreen extends StatefulWidget {
  /// 이어받을 입력. 마법사 1단계라 보통 null이고, 그때 이 화면이 새로 만든다.
  final ExploreDraft? draft;
  const ExploreConditionsScreen({super.key, this.draft});
  @override
  State<ExploreConditionsScreen> createState() => _ExploreConditionsScreenState();
}

class _ExploreConditionsScreenState extends State<ExploreConditionsScreen> {
  /// 마법사 3화면이 함께 쓰는 입력 — 1단계인 이 화면이 만들어 다음 화면에 넘긴다.
  late final ExploreDraft _d = widget.draft ?? ExploreDraft();

  static const _durations = ['2시간', '반나절', '하루'];
  static const _transports = ['도보', '대중교통'];
  static const _companions = ['혼자', '친구', '가족', '연인'];
  static const _difficulties = ['쉬움', '보통', '어려움'];
  static const _budgetLabels = ['0원', '10,000', '50,000', '100,000', '무제한'];

  late double _budgetIndex = _d.budget == null
      ? 11
      : (_d.budget! / 10000).clamp(0, 11).toDouble();

  String _fmtWon(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$buf원';
  }

  void _next() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExplorePlaceScreen(draft: _d)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: const Text('여행 조건')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text('어떤 탐험을 원하나요?',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _section('시간', _durations, d.duration, (v) => setState(() => d.duration = v)),
                  _section('이동수단', _transports, d.transportLabel,
                      (v) => setState(() => d.transportLabel = v)),
                  _section('동행', _companions, d.companion, (v) => setState(() => d.companion = v)),
                  _section('난이도', _difficulties, d.difficulty, (v) => setState(() => d.difficulty = v)),
                  _radiusSection(d),
                  // [v2] 식음·예산 입력은 기능이 꺼져 있는 동안 숨긴다(위 헤더 참조).
                  //      되살릴 때: 아래 주석을 풀고 ExploreDraft의 고정값을 되돌린다.
                  // _section('식음 노드', const ['포함', '제외'], d.includeMeals ? '포함' : '제외',
                  //     (v) => setState(() => d.includeMeals = v == '포함')),
                  // ...예산 슬라이더(0~10만·무제한)
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('STEP 1 / 3', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(onPressed: _next, child: const Text('다음')),
            ),
          ],
        ),
      ),
    );
  }

  /// 탐색 반경(1~10km) — 현재 위치 기준. 직접 고르면 "시간" 기반 자동 반경 계산 대신
  /// 이 값이 그대로 서버 검색 반경이 된다(ExploreDraft.radiusM 참고).
  Widget _radiusSection(ExploreDraft d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('탐색 반경',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${d.radiusKm}km',
                  style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
            ],
          ),
          Text('현재 위치에서 반경 몇 km 안의 장소로 코스를 만들지 골라주세요. 다음 단계의 장소 검색에도 적용돼요.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Slider(
            value: d.radiusKm.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppColors.teal,
            label: '${d.radiusKm}km',
            onChanged: (v) => setState(() => d.radiusKm = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> options, String current, ValueChanged<String> onSelect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((o) => Pill(o, active: o == current, onTap: () => onSelect(o)))
                .toList(),
          ),
        ],
      ),
    );
  }
}
