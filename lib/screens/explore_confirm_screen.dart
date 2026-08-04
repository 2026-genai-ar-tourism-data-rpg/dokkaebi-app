// ============================================================
// [v1] 화면: 입력 확인 (탐험 마법사 STEP 3/3)
// pipeline: 모바일 클라이언트 / 화면 (나만의 코스 만들기 3단계 — 실제 생성 요청)
// 구현(요약): draft 요약 표시 → "나만의 코스 만들기"로 /v1/scenarios/custom 호출.
//            좌표는 GPS·카카오 연동 전이라 종로 MVP 기본값 고정(화면엔 노출 안 함).
// 구현일: 2026-08-05 | 작성: Claude · 시안: dokkaebi-ai/docs/images/08-confirm-loading.png
// ============================================================
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/explore_draft.dart';
import '../store.dart';
import '../theme.dart';
import 'scenario_preview_screen.dart';

class ExploreConfirmScreen extends StatefulWidget {
  final ExploreDraft draft;
  const ExploreConfirmScreen({super.key, required this.draft});
  @override
  State<ExploreConfirmScreen> createState() => _ExploreConfirmScreenState();
}

class _ExploreConfirmScreenState extends State<ExploreConfirmScreen> {
  final _api = ApiClient();
  bool _loading = false;
  String? _error;

  // 종로 MVP 기본 출발/도착 좌표 — GPS·카카오 지도 연동 전까지 고정값(구 create_scenario_screen과 동일).
  static const _startLat = 37.5703, _startLng = 126.9856;
  static const _endLat = 37.5547, _endLng = 126.9707;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = widget.draft;
    try {
      final scn = await _api.generateScenario(
        startLat: _startLat,
        startLng: _startLng,
        endLat: _endLat,
        endLng: _endLng,
        transport: d.transport,
        wishlist: d.places,
        budget: d.budget,
        noMeals: !d.includeMeals,
      );
      ScenarioStore.I.add(scn);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScenarioPreviewScreen(scenario: scn, draft: d)),
      );
    } catch (e) {
      setState(() => _error = '생성 실패 — 서버가 켜져 있나요? ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Scaffold(
      appBar: AppBar(title: const Text('입력 확인')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text('나만의 탐험 조건',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(children: [
                      _row('장소', d.places.isEmpty
                          ? '현재 위치 기반 추천'
                          : d.places.map((c) => c.name ?? c.contentId).join(', ')),
                      _row('취향', d.tags.isEmpty ? '미선택' : d.tags.join(', ')),
                      _row('시간', d.duration),
                      _row('이동수단', d.transportLabel),
                      _row('동행', d.companion),
                      _row('난이도', d.difficulty),
                      _row('식음 노드', d.includeMeals ? '포함' : '제외'),
                      _row('예산 (경비)', d.budget == null ? '무제한' : _fmtWon(d.budget!), last: true),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('수정하기'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('STEP 3 / 3', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: _loading ? null : _generate,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('나만의 코스 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
        ),
        child: Row(children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  String _fmtWon(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$buf원';
  }
}
