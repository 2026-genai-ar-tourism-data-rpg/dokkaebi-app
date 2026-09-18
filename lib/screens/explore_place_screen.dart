// ============================================================
// [v1] 화면: 가고 싶은 장소 (탐험 마법사 STEP 1/3)
// pipeline: 모바일 클라이언트 / 화면 (나만의 코스 만들기 1단계)
// 구현(요약): 장소 검색(자동완성) + 취향 태그 선택 + 건너뛰기.
//            ⚠️ "지도에서 선택하기"는 실제 지도 SDK 미구현 — 탭하면 준비중 안내만.
// 구현일: 2026-08-05 | 시안: dokkaebi-ai/docs/images/04-wishlist.png
// ------------------------------------------------------------
// [v2] "지도에서 선택하기" 버튼 제거.
// 구현(요약): 위시리스트 항목은 관광공사 데이터(content_id)가 있는 실제 장소여야 해서
//            지도에서 아무 곳이나 찍는 방식과는 안 맞는다. 장소 검색으로 충분해 버튼째 삭제.
// 구현일: 2026-09-09 | 작성: ljs (remove-map-select/ljs/v1)
// ------------------------------------------------------------
// [v3] 마법사 2단계로 이동 + 검색 결과를 고른 반경으로 필터 (QA 1).
// 구현(요약): 반경을 먼저 골라도 장소 검색이 키워드 전용이라 전국 아무 곳이나 골라졌다.
//            이제 조건 화면이 1단계이고, 이 화면은 진입 시 현재 위치를 한 번 읽어
//            검색 결과를 그 반경(ExploreDraft.radiusM) 안으로 걸러낸다.
//            반경 밖은 목록에서 빼고 "N건 숨김"만 알린다 — 반경이 실제로 선택을 제한해야 한다.
//            좌표 없는 후보는 판정할 수 없어 남긴다(숨기면 고를 길이 사라진다).
//            위치를 못 읽으면 필터를 끄고 전체를 보여주며 사유를 알린다(권한이 막혔으면
//            설정 열기) — 장소 선택 자체를 막지는 않는다.
//            검색은 8건 고정이라(서버가 top_n을 쿼리로 노출하지 않음) 반경 밖을 걸렀을 때는
//            반경 안 후보가 그 밖으로 밀렸을 수 있다는 단서도 함께 보여준다.
// 구현일: 2026-09-12 | 작성: ljs (explore-radius-first/ljs/v1)
// ------------------------------------------------------------
// [v4] "검색은 8건까지만 받아와, 반경 안 장소가 더 있을 수 있어요" 문장 삭제.
// 구현(요약): 서버가 top_n=8을 박아 보내던 것을 없애(dokkaebi-server search-top-n/ljs/v1)
//            검색이 AI 설정값(30건)까지 받아오게 됐는데, 앱에 8이 그대로 박혀 있어 틀린 안내가 떴다.
//            게다가 "카페"처럼 22건만 온 경우는 받을 수 있는 걸 다 받은 것이라 "더 있을 수 있다"도
//            거짓이었다. 앱은 서버가 몇 건까지 받아오는지 알 수 없으니 숫자를 박지 않고,
//            반경 밖을 몇 건 숨겼는지만 알린다(_searchLimit 제거).
// 구현일: 2026-09-13 | 작성: ljs (search-hint-fix/ljs/v1)
// ------------------------------------------------------------
// [v5] '선택한 장소' → '위시 리스트' — '내 주변 탐험'의 +로 담은 장소(ScenarioStore 위시리스트)가
//      여기 모이고, 그중 이번 코스에 넣을 곳을 고른다(최대 kMaxWishlistCount곳). 검색으로 담은 장소는
//      이번 코스에만 쓰고 위시리스트엔 남기지 않는다. 반경 밖 위시는 '반경 밖'으로 두고 못 고른다.
// 구현일: 2026-09-19 | 작성: ljs (wishlist-course/ljs/v1)
// ============================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../game/location_service.dart';
import '../models/explore_draft.dart';
import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'create_scenario_screen.dart' show haversineMeters, kMaxWishlistCount;
import 'explore_confirm_screen.dart';

class ExplorePlaceScreen extends StatefulWidget {
  /// 조건 화면(1단계)에서 이어받은 입력 — 반경 필터의 기준이 여기 들어 있다.
  final ExploreDraft draft;

  /// 위치 서비스 주입 지점 — 테스트가 실기기 GPS 없이 좌표를 밀어 넣는다.
  final LocationService locationService;

  /// HTTP 실행기 주입 지점 — 테스트가 실제 서버 없이 검색 결과를 넣는다.
  final http.Client? httpClient;

  const ExplorePlaceScreen({
    super.key,
    required this.draft,
    this.locationService = const LocationService(),
    this.httpClient,
  });
  @override
  State<ExplorePlaceScreen> createState() => _ExplorePlaceScreenState();
}

class _ExplorePlaceScreenState extends State<ExplorePlaceScreen> {
  ExploreDraft get _draft => widget.draft;
  late final ApiClient _api = ApiClient(client: widget.httpClient);
  final _search = TextEditingController();
  Timer? _debounce;

  bool _searching = false;
  bool _searched = false;
  String? _searchError;
  List<SearchCandidate> _results = [];

  /// 반경 필터의 기준점(현재 위치). null이면 아직 못 읽었거나 실패한 것 — 그때는 필터를 끈다.
  double? _lat, _lng;

  /// 위치를 못 읽은 사유와, 설정에서 고쳐야 하는 문제인지.
  String? _locError;
  bool _locNeedsSettings = false;

  @override
  void initState() {
    super.initState();
    _readOrigin();
  }

  /// 반경 기준점을 한 번 읽는다. 실패해도 검색은 그대로 되게 둔다(필터만 끈다).
  Future<void> _readOrigin() async {
    final loc = await widget.locationService.current();
    if (!mounted) return;
    setState(() {
      if (loc.isOk) {
        _lat = loc.lat;
        _lng = loc.lng;
        _locError = null;
      } else {
        _locError = loc.message;
        _locNeedsSettings = loc.failure == LocationFailure.deniedForever ||
            loc.failure == LocationFailure.serviceDisabled;
      }
    });
  }

  /// 목록에 띄울 후보 — 반경 안만. 기준점이 없으면 필터를 적용하지 않는다.
  /// 좌표 없는 후보는 반경을 판정할 수 없어 남긴다(숨기면 고를 길이 사라진다).
  List<SearchCandidate> get _shown {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) return _results;
    return _results.where((c) {
      if (c.lat == null || c.lng == null) return true;
      return haversineMeters(lat, lng, c.lat!, c.lng!) <= _draft.radiusM;
    }).toList();
  }

  /// 반경 밖이라 숨긴 후보 수.
  int get _hiddenCount => _results.length - _shown.length;

  /// 고른 반경 안인가 — 위치를 모르거나 좌표 없는 장소는 판정할 수 없어 안으로 본다(_shown과 같은 규칙).
  bool _inRadius(SearchCandidate c) {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null || c.lat == null || c.lng == null) return true;
    return haversineMeters(lat, lng, c.lat!, c.lng!) <= _draft.radiusM;
  }

  bool _isPicked(SearchCandidate c) => _draft.places.any((s) => s.contentId == c.contentId);

  /// 코스 하나엔 kMaxWishlistCount곳까지 — 넘으면 알리고 false.
  bool _roomForOneMore() {
    if (_draft.places.length < kMaxWishlistCount) return true;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코스 하나엔 최대 $kMaxWishlistCount곳까지 고를 수 있어요.')));
    return false;
  }

  /// 위시리스트 장소를 이번 코스에 넣기/빼기.
  void _toggleWish(SearchCandidate w) {
    if (_isPicked(w)) {
      setState(() => _draft.places.removeWhere((s) => s.contentId == w.contentId));
    } else if (_roomForOneMore()) {
      setState(() => _draft.places.add(w));
    }
  }

  static const _tagOptions = ['고궁', '역사', '한옥', '전통문화', '카페', '맛집', '한적한 곳', '사진 명소'];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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

  void _pick(SearchCandidate c) {
    if (!_isPicked(c) && _roomForOneMore()) {
      setState(() => _draft.places.add(c));
    }
    setState(() {
      _results = [];
      _searched = false;
      _search.clear();
    });
  }

  /// 위시 리스트 — 위시리스트 장소(골라 넣기) + 검색으로 이번 코스에만 담은 장소(빼기).
  Widget _wishlistBlock() {
    return ListenableBuilder(
      listenable: ScenarioStore.I,
      builder: (context, _) {
        final wishes = ScenarioStore.I.wishlist;
        final searchPicks =
            _draft.places.where((c) => !wishes.any((w) => w.contentId == c.contentId)).toList();
        if (wishes.isEmpty && searchPicks.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('장소를 검색하거나 "내 주변 탐험"에서 + 로 담아 주세요',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          );
        }
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (final w in wishes)
            FilterChip(
              key: ValueKey('wizard-wish-${w.contentId}'),
              label: Text(_inRadius(w) ? (w.name ?? w.contentId) : '${w.name ?? w.contentId} · 반경 밖'),
              selected: _isPicked(w),
              // 반경 밖은 새로 고를 수 없다(이미 골라 둔 건 뺄 수 있게).
              onSelected: _inRadius(w) || _isPicked(w) ? (_) => _toggleWish(w) : null,
            ),
          for (final c in searchPicks)
            Chip(
              label: Text(c.name ?? c.contentId),
              onDeleted: () => setState(() => _draft.places.remove(c)),
            ),
        ]);
      },
    );
  }

  Future<void> _skip() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('장소 입력을 건너뛸까요?'),
        content: const Text('현재 위치와 여행 조건을 기반으로 시스템 추천 코스를 만들어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('건너뛰기')),
        ],
      ),
    );
    if (ok == true) _next();
  }

  void _next() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExploreConfirmScreen(draft: _draft)),
    );
  }

  /// 반경 필터가 걸려 있는지 한 줄로 알린다 — 못 읽었으면 사유와 다음 행동(설정 열기)까지.
  Widget _radiusNotice() {
    final err = _locError;
    if (err != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$err 반경을 적용하지 못해 전체 결과를 보여줘요.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
          if (_locNeedsSettings)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.locationService.openSettings,
                child: const Text('설정 열기'),
              ),
            ),
        ]),
      );
    }
    final ready = _lat != null && _lng != null;
    return Row(children: [
      Icon(ready ? Icons.my_location : Icons.location_searching,
          size: 14, color: AppColors.textMuted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          ready
              ? '현재 위치에서 반경 ${_draft.radiusKm}km 안의 장소만 보여줘요.'
              : '현재 위치를 확인하고 있어요…',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가고 싶은 장소')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text('어디를 꼭 가보고 싶나요?',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('선택한 장소 주변의 숨은 명소와 도깨비 이야기를 연결해 드려요.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  _radiusNotice(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '장소 검색',
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
                  if (_searchError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_searched && _shown.isEmpty && _searchError == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _hiddenCount > 0
                            ? '반경 ${_draft.radiusKm}km 안에는 결과가 없어요 — 반경을 넓혀 보세요.'
                            : '검색 결과 없음',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ..._shown.map((c) => Card(
                        margin: const EdgeInsets.only(top: 6),
                        color: AppColors.surface,
                        elevation: 0,
                        shape: dokkaebiCardShape,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(c.name ?? c.contentId),
                          subtitle: Text(c.addr ?? ''),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _pick(c),
                        ),
                      )),
                  // 반경 밖을 몇 건 걸렀는지 알린다. 검색 건수 한계는 말하지 않는다 —
                  // 앱은 서버가 몇 건까지 받아오는지 몰라 숫자를 박으면 틀린 안내가 된다.
                  if (_hiddenCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '반경 밖 $_hiddenCount건은 숨겼어요.',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text('위시 리스트',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('이번 코스에 넣을 곳을 골라 주세요 (최대 $kMaxWishlistCount곳)',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  _wishlistBlock(),
                  const SizedBox(height: 20),
                  const Text('추천 취향',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tagOptions
                        .map((t) => Pill('#$t',
                            active: _draft.tags.contains(t),
                            onTap: () => setState(() =>
                                _draft.tags.contains(t) ? _draft.tags.remove(t) : _draft.tags.add(t))))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _skip,
                      child: const Text('건너뛰기', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('STEP 2 / 3',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
}
