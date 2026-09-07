// ============================================================
// [v1] 화면: 입력 확인 (탐험 마법사 STEP 3/3)
// pipeline: 모바일 클라이언트 / 화면 (나만의 코스 만들기 3단계 — 실제 생성 요청)
// 구현(요약): draft 요약 표시 → "나만의 코스 만들기"로 /v1/scenarios/custom 호출.
//            좌표는 GPS·카카오 연동 전이라 종로 MVP 기본값 고정(화면엔 노출 안 함).
// 구현일: 2026-08-05 | 작성: Claude · 시안: dokkaebi-ai/docs/images/08-confirm-loading.png
// ------------------------------------------------------------
// [v2] 실제 GPS 좌표 + 마법사 입력 전달 — 하드코딩 종로 좌표 제거.
// 구현(요약): 출발 좌표가 종로 고정값이었고 region도 '종로' 기본값이라, 어디서 만들든
//            같은 종로 코스가 나왔다(위치를 바꿔도 결과가 안 변함). LocationService로
//            현재 위치를 읽어 start로 보내고, 취향·시간·동행·난이도도 함께 보낸다.
//            위치를 못 얻으면 종로 기본값으로 폴백하되 그 사실을 화면에 알린다 —
//            조용히 다른 동네 코스를 만들어 주면 사용자가 원인을 알 수 없다.
//            end(집)는 보내지 않는다 — 왕복(시작=끝)이 서버 기본값이고, 종로 고정
//            도착점을 그대로 두면 다른 지역에서 피날레가 엉뚱한 곳으로 잡힌다.
// 구현일: 2026-08-18 | 작성: kys (explore-input-wiring/kys/v1)
// ============================================================
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../game/location_service.dart';
import '../models/explore_draft.dart';
import '../store.dart';
import '../theme.dart';
import 'scenario_preview_screen.dart';

class ExploreConfirmScreen extends StatefulWidget {
  final ExploreDraft draft;

  /// 위치 서비스 주입 지점 — 테스트가 실기기 GPS 없이 좌표를 밀어 넣는다.
  final LocationService locationService;

  /// HTTP 실행기 주입 지점 — 테스트가 실제 서버 없이 요청 본문을 확인한다.
  final http.Client? httpClient;

  const ExploreConfirmScreen({
    super.key,
    required this.draft,
    this.locationService = const LocationService(),
    this.httpClient,
  });
  @override
  State<ExploreConfirmScreen> createState() => _ExploreConfirmScreenState();
}

class _ExploreConfirmScreenState extends State<ExploreConfirmScreen> {
  late final ApiClient _api = ApiClient(client: widget.httpClient);
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 위치를 못 얻었을 때만 쓰는 폴백 좌표(종로 MVP 기준점). 성공 경로에서는 안 쓴다.
  static const _fallbackLat = 37.5703, _fallbackLng = 126.9856;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = widget.draft;
    try {
      // 출발점 = 지금 서 있는 자리. 실패하면 폴백 좌표 + 안내(조용히 넘어가지 않는다).
      final loc = await widget.locationService.current();
      final startLat = loc.isOk ? loc.lat! : _fallbackLat;
      final startLng = loc.isOk ? loc.lng! : _fallbackLng;
      final notice = loc.isOk ? null : '${loc.message} 종로 기준으로 코스를 만들었느니라.';

      final scn = await _api.generateScenario(
        startLat: startLat,
        startLng: startLng,
        transport: d.transport,
        wishlist: d.places,
        budget: d.budget,
        noMeals: !d.includeMeals,
        region: d.region,
        duration: d.durationCode,
        companion: d.companionCode,
        difficulty: d.difficultyCode,
        tags: d.tagList,
        headcount: d.headcount,
        radiusM: d.radiusM,
      );
      final name = _nameController.text.trim();
      final named = name.isEmpty ? scn : scn.copyWith(title: name);
      ScenarioStore.I.add(named);
      if (!mounted) return;
      if (notice != null) {
        // 폴백으로 만들었다는 사실은 결과 화면에서도 보여야 한다(왜 딴 동네인지 알 수 있게).
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScenarioPreviewScreen(scenario: named, draft: d)),
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
                  const Text('코스 이름',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      hintText: '비워두면 도깨비가 지어드려요',
                      counterText: '',
                    ),
                  ),
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
