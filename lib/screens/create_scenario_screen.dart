// ============================================================
// [v1] 화면: 시나리오 만들기 (입력 contract 수집)
// pipeline: 모바일 클라이언트 / 화면 (1단계 사용자 입력)
// 구현(요약): 현재위치·끝점·이동수단·위시리스트(이름 자동완성→선택)·예산 → 서버 호출.
//            위시리스트: 타이핑하면(디바운스) 자동 검색 → 후보 탭 → content_id 확정(칩).
//            ⚠️ GPS·카카오는 TODO(정찬희) — 지금은 좌표 직접 입력.
// 구현일: 2026-06-18 | 작성: kys (app-scaffold/kys/v1)
// ------------------------------------------------------------
// [v1.1] 위시 상한 5개 + 반경 밖 사전 경고(선택 전 후보·칩에 표시) 배선.
//        서버 앵커 캡 제거(dokkaebi-ai 5c4a978)로 위시 수만큼 경로·LLM 호출이
//        비례 증가해 클라이언트에서 제한. 반경 상수는 서버 config.py와 동기화 필요.
// 구현일: 2026-07-30 | 작성: 정찬희 (app-v3-front/jch/v1)
// ============================================================
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'scenario_screen.dart';

/// 위시 선택 상한 — 서버 앵커 캡 제거(dokkaebi-ai `5c4a978`)로 위시 수만큼
/// 경로 계산·LLM 호출이 비례 증가하므로 클라이언트에서 제한한다.
const int kMaxWishlistCount = 5;

/// 반경 사전 경고 기준(m). 서버 `app/config.py`의
/// `scenario_radius_walk_m`(2000)·`scenario_radius_car_m`(8000)과 값을 동일하게 유지할 것
/// — 어긋나면 사전 경고와 실제 생성 결과(out_of_radius)가 불일치할 수 있음.
const int kRadiusWalkM = 2000;
const int kRadiusCarM = 8000;

const double _kEarthRadiusM = 6371000.0;

/// 두 좌표 간 대권거리(m). 서버 `density.py`의 `_haversine_m`과 동일한 공식.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final double dLat = (lat2 - lat1) * math.pi / 180;
  final double dLng = (lng2 - lng1) * math.pi / 180;
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _kEarthRadiusM * math.asin(math.sqrt(a));
}

/// 위시 후보 하나에 대한 사전 경고 상태.
enum WishWarning {
  /// 경고 없음(반경 안, 좌표 있음).
  none,

  /// 좌표가 없는 후보 — 서버가 합성 앵커 배치 불가로 조용히 드롭할 수 있음.
  missingCoords,

  /// 현재 이동수단 기준 반경 밖 — 서버가 받아들이되 위치가 부정확할 수 있음.
  outOfRadius,
}

/// [WishWarning]에 대응하는 사용자용 안내 문구.
String wishWarningLabel(WishWarning w) {
  switch (w) {
    case WishWarning.missingCoords:
      return '좌표 없음 — 경로에 반영되지 않을 수 있음';
    case WishWarning.outOfRadius:
      return '반경 밖 — 위치가 부정확할 수 있음';
    case WishWarning.none:
      return '';
  }
}

class CreateScenarioScreen extends StatefulWidget {
  const CreateScenarioScreen({super.key});
  @override
  State<CreateScenarioScreen> createState() => _CreateScenarioScreenState();
}

class _CreateScenarioScreenState extends State<CreateScenarioScreen> {
  final _api = ApiClient();
  final _startLat = TextEditingController(text: '37.5703');
  final _startLng = TextEditingController(text: '126.9856');
  final _endLat = TextEditingController(text: '37.5547');
  final _endLng = TextEditingController(text: '126.9707');
  final _budget = TextEditingController(text: '30000');
  final _search = TextEditingController();
  String _transport = 'walk';
  bool _withDialogue = true;
  bool _noMeals = false;
  bool _loading = false;
  bool _searching = false;
  bool _searched = false; // 검색 1회 이상 수행(결과없음 안내용)
  String? _error;
  String? _searchError;
  Timer? _debounce;

  List<SearchCandidate> _results = [];
  final List<SearchCandidate> _selected = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// 타이핑할 때마다 디바운스(400ms) 후 자동 검색.
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    final kw = v.trim();
    if (kw.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(kw));
  }

  Future<void> _runSearch(String kw) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await _api.searchAttractions(kw);
      setState(() {
        _results = r;
        _searched = true;
      });
    } catch (e) {
      setState(() => _searchError = '검색 실패 — 서버가 켜져 있나요? ($e)');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// 검색 결과에서 후보를 선택. 상한([kMaxWishlistCount]) 도달 시 신규 추가는 막고 안내한다.
  void _pick(SearchCandidate c) {
    final bool alreadyPicked = _selected.any((s) => s.contentId == c.contentId);
    if (!alreadyPicked && _selected.length >= kMaxWishlistCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위시는 최대 $kMaxWishlistCount개까지 담을 수 있어요.')),
      );
      return;
    }
    if (!alreadyPicked) {
      _selected.add(c);
    }
    setState(() {
      _results = [];
      _searched = false;
      _search.clear();
    });
  }

  /// 후보 [c]의 사전 경고 상태 — 시작 좌표·이동수단 기준으로 판정.
  /// 시작 좌표를 파싱할 수 없으면(입력 중 등) 판정을 보류하고 [WishWarning.none]을 반환한다.
  WishWarning _wishWarning(SearchCandidate c) {
    if (c.lat == null || c.lng == null) return WishWarning.missingCoords;
    final double? startLat = double.tryParse(_startLat.text);
    final double? startLng = double.tryParse(_startLng.text);
    if (startLat == null || startLng == null) return WishWarning.none;
    final int radiusM = _transport == 'car' ? kRadiusCarM : kRadiusWalkM;
    final double distM = haversineMeters(startLat, startLng, c.lat!, c.lng!);
    return distM > radiusM ? WishWarning.outOfRadius : WishWarning.none;
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scn = await _api.generateScenario(
        startLat: double.parse(_startLat.text),
        startLng: double.parse(_startLng.text),
        endLat: double.tryParse(_endLat.text),
        endLng: double.tryParse(_endLng.text),
        transport: _transport,
        wishlist: _selected, // content_id + 좌표·이름 함께 전달(합성 앵커 배치용)
        budget: int.tryParse(_budget.text),
        noMeals: _noMeals,
        withDialogue: _withDialogue,
      );
      ScenarioStore.I.add(scn); // 퀘스트 일지에 남김
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ScenarioScreen(scenario: scn)));
    } catch (e) {
      setState(() => _error = '생성 실패 — 서버가 켜져 있나요? ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('도깨비 — 시나리오 만들기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('현재 위치 (GPS — 지금은 직접 입력)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            // onChanged: 위시 반경 사전 경고가 시작 좌표에 의존하므로 값이 바뀌면 다시 계산한다.
            Expanded(child: _num(_startLat, '위도', onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: _num(_startLng, '경도', onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 12),
          const Text('끝 위치 (집 — 없으면 비워서 왕복)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Expanded(child: _num(_endLat, '위도')),
            const SizedBox(width: 8),
            Expanded(child: _num(_endLng, '경도')),
          ]),
          const SizedBox(height: 16),

          // --- 꼭 가고싶은 관광지: 이름 입력 → 자동 검색 → 후보 선택 ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('꼭 가고싶은 관광지 (이름 검색)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${_selected.length}/$kMaxWishlistCount',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _selected.length >= kMaxWishlistCount
                      ? AppColors.vermilion
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '예: 경복궁 — 입력하면 자동 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          // 선택된 앵커 칩 — 경고 상태(반경 밖·좌표 없음)면 주홍 테두리로 표시
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selected.map((c) {
                  final WishWarning warning = _wishWarning(c);
                  final Color warnColor =
                      warning == WishWarning.none ? AppColors.teal : AppColors.vermilion;
                  return Tooltip(
                    message: wishWarningLabel(warning),
                    child: Chip(
                      avatar: warning == WishWarning.none
                          ? null
                          : const Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.vermilion),
                      label: Text(c.name ?? c.contentId),
                      backgroundColor: AppColors.surfaceHi,
                      side: BorderSide(color: warnColor.withOpacity(0.6)),
                      labelStyle: const TextStyle(color: AppColors.textPrimary),
                      deleteIconColor: AppColors.textSecondary,
                      onDeleted: () => setState(() => _selected.remove(c)),
                    ),
                  );
                }).toList(),
              ),
            ),
          // 검색 상태/결과
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
            ),
          if (_searched && _results.isEmpty && _searchError == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('검색 결과 없음', style: TextStyle(color: Colors.grey)),
            ),
          ..._results.map((c) {
            final WishWarning warning = _wishWarning(c);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GlowCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                glow: warning == WishWarning.none ? null : AppColors.vermilion,
                onTap: () => _pick(c),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.name ?? c.contentId,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          if ((c.addr ?? '').isNotEmpty)
                            Text(c.addr!,
                                style:
                                    const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          if (warning != WishWarning.none)
                            Text(wishWarningLabel(warning),
                                style: const TextStyle(
                                    color: AppColors.vermilion,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.add_circle_outline, color: AppColors.teal),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          Row(children: [
            const Text('이동수단  '),
            DropdownButton<String>(
              value: _transport,
              items: const [
                DropdownMenuItem(value: 'walk', child: Text('🚶 도보')),
                DropdownMenuItem(value: 'car', child: Text('🚗 차')),
              ],
              onChanged: (v) => setState(() => _transport = v ?? 'walk'),
            ),
          ]),
          _num(_budget, '예산(원, 선택)'),
          SwitchListTile(
            title: const Text('밥 안 먹음'),
            subtitle: const Text('켜면 식음(카페·식당) 노드 제외'),
            value: _noMeals,
            onChanged: (v) => setState(() => _noMeals = v),
          ),
          SwitchListTile(
            title: const Text('NPC 대사 LLM 생성'),
            subtitle: const Text('끄면 빠름(고정 대사)'),
            value: _withDialogue,
            onChanged: (v) => setState(() => _withDialogue = v),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          FilledButton(
            onPressed: _loading ? null : _generate,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('코스 생성'),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label, {ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      );
}
