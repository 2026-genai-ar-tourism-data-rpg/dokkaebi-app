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
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../api/api_client.dart';
import '../game/location_service.dart';
import '../models/scenario.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'ar_search_screen.dart';
import 'create_scenario_screen.dart' show haversineMeters;
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

            // 새 퀘스트 시작하기 — 종로의 기억석 플레이 여정(setup→…→엔딩).
            // 내가 만든 코스가 하나도 없으면 "새로 시작할 것"이 없으므로 숨긴다.
            if (mine.isNotEmpty) ...[
              _StartJourneyButton(scenario: mine.first),
              const SizedBox(height: 20),
            ],

            _SectionToggle(section: _section, onChanged: (i) => setState(() => _section = i)),
            const SizedBox(height: 16),

            if (_section == 0)
              const _NearbySection()
            else ...[
              Row(children: [
                Pill('최신순', active: _sort == _Sort.latest,
                    onTap: () => setState(() => _sort = _Sort.latest)),
                const SizedBox(width: 8),
                Pill('완주율순', active: _sort == _Sort.completion,
                    onTap: () => setState(() => _sort = _Sort.completion)),
              ]),
              const SizedBox(height: 12),
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

/// "내 주변 탐험" — 현재 GPS 반경 내 실제 POI를 목록/지도로 보여준다.
///
/// 코스 생성(LLM 15초+)을 거치지 않고 지금 서 있는 자리에서 바로 AR 탐색으로 들어가는
/// 짧은 경로다. 목록의 출처는 서버 /v1/scenarios/nearby(→ AI → TourAPI 또는 OSM 실데이터).
/// 여기서 찾은 조각도 코스 플레이와 똑같이 서버(run)에 기록된다.
class _NearbySection extends StatefulWidget {
  /// 위치 서비스 주입 지점 — 테스트가 실기기 GPS 없이 좌표를 밀어 넣는다.
  final LocationService locationService;

  /// HTTP 실행기 주입 지점 — 테스트가 실제 서버 없이 응답을 흉내 낸다.
  final http.Client? httpClient;

  const _NearbySection({
    this.locationService = const LocationService(),
    this.httpClient,
  });

  @override
  State<_NearbySection> createState() => _NearbySectionState();
}

/// 반경 기본값(m). 슬라이더 범위는 1~10km — 코스 생성(explore_conditions_screen)과 동일.
const _kDefaultRadiusM = 2000;
const _kRadiusMinM = 1000;
const _kRadiusMaxM = 10000;

/// 이만큼 움직이면 목록을 자동 갱신한다(m). 너무 작으면 GPS 흔들림에 계속 재조회한다.
const _kAutoRefreshMoveM = 300.0;

/// 이 반경 안이면 "그 자리에 있다"로 보고 실제 AR·조각 획득을 연다.
/// 서버 run.module의 기본 trigger_radius(100m)와 같은 값 — 여기서 통과시켜 놓고
/// 서버가 거절하면 사용자만 헷갈린다.
const _kOnSiteRadiusM = 100.0;

class _NearbySectionState extends State<_NearbySection> {
  late final ApiClient _api = ApiClient(client: widget.httpClient);
  List<NearbyPlace>? _places;
  String? _error;
  bool _loading = false;
  bool _mapView = false;
  int _radiusM = _kDefaultRadiusM;
  NearbyCategory? _filter; // null = 전체
  double? _lat, _lng;      // 목록을 만든 시점의 위치(자동 갱신 판정 기준)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool keepFilter = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!keepFilter) _filter = null;
    });
    try {
      final loc = await widget.locationService.current();
      if (!loc.isOk) {
        // 위치를 못 얻으면 목록의 의미가 없다 — 사유를 그대로 보여준다(조용히 빈 목록 금지).
        if (mounted) setState(() => _error = loc.message);
        return;
      }
      final places = await _api.nearbyPlaces(
          lat: loc.lat!, lng: loc.lng!, radiusM: _radiusM);
      if (mounted) {
        setState(() {
          _places = places;
          _lat = loc.lat;
          _lng = loc.lng;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '주변을 살피지 못했느니라. ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 화면으로 돌아왔을 때 많이 움직였으면 목록을 새로 받는다.
  /// 자동 재조회를 거리로 거는 이유 — 매번 부르면 공개 POI API 호출이 낭비되고,
  /// 안 부르면 한참 걸어간 뒤에도 옛 목록이 남는다.
  Future<void> _refreshIfMoved() async {
    if (_lat == null || _lng == null || _loading) return;
    final loc = await widget.locationService.current();
    if (!loc.isOk) return;
    final moved = haversineMeters(_lat!, _lng!, loc.lat!, loc.lng!);
    if (moved >= _kAutoRefreshMoveM) await _load();
  }

  /// 그 자리에서 바로 AR 탐색 — 코스 없이 단일 지점 조우.
  ///
  /// 서버 run을 먼저 열어 두고 AR에서 조각을 찾으면 인증·획득을 서버에 기록한다.
  /// run이 실패해도 AR 자체는 진행한다(서버 없이도 데모는 돌아야 한다).
  Future<void> _explore(NearbyPlace p) async {
    // 그 자리에 있나? 인증 반경(100m) 밖이면 원격 체험으로 돌린다.
    // 예전엔 멀면 조각 획득 단계에서 "아직 멀었느니라"로 막혀 아무것도 못 하고 끝났다 —
    // 집에서도 이야기와 연출은 볼 수 있어야 한다.
    final remote = (p.distM ?? double.infinity) > _kOnSiteRadiusM;
    if (remote && !await _confirmRemote(p)) return;

    if (!mounted) return;
    final found = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ArSearchScreen(
          placeName: p.name ?? '이름 모를 자리',
          order: remote
              ? '멀리서 ${p.name ?? '이곳'}의 기운을 살펴라'
              : '${p.name ?? '이곳'}에 잠든 기억석 조각을 찾아라',
          hints: remote
              ? const ['기운이 흐릿하구나 — 직접 찾아가면 또렷해진다']
              : const ['주변을 천천히 비추어 보거라', '눈높이보다 조금 아래를 살펴라'],
          total: 1,
          remote: remote,
        ),
      ),
    );

    if (found == true) {
      // 주변 탐험은 서버에 저장된 코스가 아니라 기록이 남지 않는다 — 정식 진행은
      // 코스를 만들어 플레이해야 한다(서버 run은 저장된 시나리오에만 열린다, server#8).
      _snack(remote
          ? '기운만 스쳤느니라. 조각은 그 자리에 가야 손에 들어온다.'
          : '기운을 느꼈느니라. 정식 기록은 코스를 만들어 진행하거라.');
    }
    if (mounted) await _refreshIfMoved();
  }

  /// 원격 체험 진입 확인 — 무엇이 되고 무엇이 안 되는지 미리 알린다.
  /// 그냥 들여보내면 조각이 왜 안 들어오는지 몰라 버그로 읽힌다.
  Future<bool> _confirmRemote(NearbyPlace p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('멀리서 살펴보겠느냐?'),
        content: Text(
          '${p.name ?? '이곳'}은 ${p.distLabel} 떨어져 있느니라.\n\n'
          '원격으로도 이야기와 도깨비는 만날 수 있다. 다만 기억석 조각은 '
          '그 자리에 직접 가야 손에 넣을 수 있느니.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('그만두기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('멀리서 보기')),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 필터를 적용한 목록. 필터가 가리키는 갈래가 없으면 전체를 보여준다.
  List<NearbyPlace> get _visible {
    final all = _places ?? const <NearbyPlace>[];
    if (_filter == null) return all;
    return all.where((p) => p.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _places == null) {
      return const GlowCard(
        child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('주변을 살피는 중…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      );
    }
    if (_error != null) {
      return GlowCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.error_outline, color: AppColors.vermilion, size: 18),
            SizedBox(width: 8),
            Text('주변을 살피지 못했어요',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(_error!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('다시 시도'),
          ),
        ]),
      );
    }

    final visible = _visible;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _radiusRow(),
      const SizedBox(height: 10),
      if ((_places ?? const []).isNotEmpty) ...[
        _categoryRow(),
        const SizedBox(height: 10),
      ],
      _headerRow(visible.length),
      const SizedBox(height: 4),
      if (visible.isEmpty)
        _emptyCard()
      else if (_mapView)
        _NearbyMap(places: visible, myLat: _lat, myLng: _lng, onTap: _explore)
      else
        ...visible.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NearbyCard(place: p, onExplore: () => _explore(p)),
            )),
    ]);
  }

  Widget _radiusRow() {
    final km = _radiusM / 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('반경', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('${km.toStringAsFixed(km.truncateToDouble() == km ? 0 : 1)}km',
              style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
        ]),
        Slider(
          value: _radiusM.clamp(_kRadiusMinM, _kRadiusMaxM).toDouble(),
          min: _kRadiusMinM.toDouble(),
          max: _kRadiusMaxM.toDouble(),
          divisions: (_kRadiusMaxM - _kRadiusMinM) ~/ 1000,
          activeColor: AppColors.teal,
          label: '${(_radiusM / 1000).round()}km',
          onChanged: _loading ? null : (v) => setState(() => _radiusM = v.round()),
          onChangeEnd: (_) => _load(),
        ),
      ],
    );
  }

  Widget _categoryRow() {
    // 실제로 결과가 있는 갈래만 칩으로 — 눌러도 빈 화면이 되는 칩은 만들지 않는다.
    final counts = <NearbyCategory, int>{};
    for (final p in _places ?? const <NearbyPlace>[]) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    final cats = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        Pill('전체', active: _filter == null, onTap: () => setState(() => _filter = null)),
        const SizedBox(width: 6),
        ...cats.map((c) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Pill(
                '${c.label} ${counts[c]}',
                active: _filter == c,
                onTap: () => setState(() => _filter = _filter == c ? null : c),
              ),
            )),
      ]),
    );
  }

  Widget _headerRow(int shown) => Row(children: [
        const Icon(Icons.near_me_outlined, color: AppColors.teal, size: 16),
        const SizedBox(width: 6),
        Text('가까운 순 $shown곳',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() => _mapView = !_mapView),
          icon: Icon(_mapView ? Icons.list : Icons.map_outlined,
              size: 18, color: AppColors.teal),
          tooltip: _mapView ? '목록으로' : '지도로',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: _loading ? null : () => _load(),
          icon: const Icon(Icons.refresh, size: 18, color: AppColors.teal),
          tooltip: '새로고침',
          visualDensity: VisualDensity.compact,
        ),
      ]);

  Widget _emptyCard() => GlowCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _filter != null ? '이 갈래는 주변에 없어요' : '주변에 알려진 자리가 없어요',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _filter != null
                ? '"전체"로 돌리거나 다른 갈래를 골라보세요.'
                : '반경을 넓히거나 자리를 옮겨 다시 살펴보세요.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
          ),
        ]),
      );
}

/// 주변 POI를 지도 핀으로 — 어느 방향인지 감을 준다.
///
/// 지도는 팀 표준인 카카오맵(map_screen과 동일)을 쓴다. flutter_map으로 먼저
/// 만들었다가 dev가 카카오맵으로 갈아타며 그 의존성이 빠져 포팅했다.
/// 핀 이미지는 기존 region_pin 하나를 재사용한다 — 갈래 구분은 목록 아이콘이
/// 이미 하고 있어서, 지도에까지 갈래별 PNG 6종을 새로 만들 이유가 없다.
class _NearbyMap extends StatefulWidget {
  final List<NearbyPlace> places;
  final double? myLat, myLng;
  final ValueChanged<NearbyPlace> onTap;
  const _NearbyMap({
    required this.places,
    required this.myLat,
    required this.myLng,
    required this.onTap,
  });

  @override
  State<_NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<_NearbyMap> {
  static const _pinStyleId = 'nearby_pin';
  static const _layerId = 'nearby_layer';
  KakaoMapController? _controller;

  @override
  void didUpdateWidget(covariant _NearbyMap old) {
    super.didUpdateWidget(old);
    // 필터·반경이 바뀌면 목록이 바뀐다 → 핀도 다시 그린다.
    if (old.places != widget.places) _drawPins();
  }

  Future<void> _onMapCreated(KakaoMapController controller) async {
    _controller = controller;
    // 레이어를 먼저 만들어야 addMarkers가 "LabelLayer not found"로 죽지 않는다.
    await controller.addMarkerLayer(layerId: _layerId);
    final bytes = await rootBundle.load('assets/images/region_pin.png');
    final pin = bytes.buffer.asUint8List();
    await controller.registerMarkerStyles(styles: [
      MarkerStyle(
        styleId: _pinStyleId,
        // 레벨을 하나만 등록하면 그 레벨에서만 보인다 — 축소·확대 양 끝을 등록.
        perLevels: [
          MarkerPerLevelStyle.fromBytes(bytes: pin, level: 1),
          MarkerPerLevelStyle.fromBytes(bytes: pin, level: 21),
        ],
      ),
    ]);
    await _drawPins();
  }

  Future<void> _drawPins() async {
    final c = _controller;
    if (c == null) return; // 지도 준비 전 — onMapCreated에서 다시 부른다.
    await c.clearMarkers(layerId: _layerId);
    final markers = [
      for (final p in widget.places)
        if (p.lat != null && p.lng != null)
          MarkerOption(
            id: p.nodeId,
            latLng: LatLng(latitude: p.lat!, longitude: p.lng!),
            text: p.name ?? '',
            styleId: _pinStyleId,
          ),
    ];
    if (markers.isNotEmpty) {
      await c.addMarkers(markerOptions: markers, layerId: _layerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 카메라 중심 — 내 위치가 있으면 그곳, 없으면 가장 가까운 장소.
    final center = (widget.myLat != null && widget.myLng != null)
        ? LatLng(latitude: widget.myLat!, longitude: widget.myLng!)
        : (widget.places.isNotEmpty &&
                widget.places.first.lat != null &&
                widget.places.first.lng != null
            ? LatLng(
                latitude: widget.places.first.lat!,
                longitude: widget.places.first.lng!)
            : null);
    if (center == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 320,
          child: KakaoMap(onMapCreated: _onMapCreated, initialPosition: center),
        ),
      ),
      const SizedBox(height: 6),
      // 카카오맵 마커는 탭 콜백을 붙이기 번거로워(스타일·레이어 단위) 지도에서는
      // 위치만 보여주고, 실제 진입은 목록에서 하도록 안내한다.
      const Text('핀 위치를 확인하고, 목록에서 골라 탐색을 시작하세요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]);
  }
}

/// 갈래별 아이콘 — 목록·지도 핀이 같은 기호를 쓴다.
IconData _iconOf(NearbyCategory c) => switch (c) {
      NearbyCategory.historic => Icons.account_balance_outlined,
      NearbyCategory.museum => Icons.museum_outlined,
      NearbyCategory.artwork => Icons.palette_outlined,
      NearbyCategory.viewpoint => Icons.landscape_outlined,
      NearbyCategory.park => Icons.park_outlined,
      NearbyCategory.attraction => Icons.star_outline,
      NearbyCategory.other => Icons.place_outlined,
    };

/// 주변 POI 카드 — 갈래 아이콘·이름·거리·주소 + "AR로 탐색" 진입.
class _NearbyCard extends StatelessWidget {
  final NearbyPlace place;
  final VoidCallback onExplore;
  const _NearbyCard({required this.place, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      onTap: onExplore,
      child: Row(children: [
        Container(
          width: 44, height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceHi,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.teal.withOpacity(0.4)),
          ),
          child: Icon(_iconOf(place.category), color: AppColors.teal, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.name ?? '이름 모를 자리',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              [place.category.label, place.distLabel]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
            if (place.summary != null && place.summary!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(place.summary!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.camera_alt_outlined, color: AppColors.teal, size: 20),
      ]),
    );
  }
}

/// 새 퀘스트 시작하기 — 종로의 기억석 플레이 여정 진입 히어로 버튼.
class _StartJourneyButton extends StatelessWidget {
  final Scenario scenario;
  const _StartJourneyButton({required this.scenario});

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
              Text('${scenario.region} · ${scenario.title}',
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

/// 라이브러리 카드 — 대표이미지 자리 + 배지(내가 만든 코스) + 실제 완주율.
/// 평점(★)은 데이터가 없어 표시하지 않는다.
class _LibraryCard extends StatelessWidget {
  final Scenario scenario;
  const _LibraryCard.mine(this.scenario);

  @override
  Widget build(BuildContext context) => _build(context, _mineData(context, scenario));

  ({String badge, Color badgeColor, String title, String subtitle1, String subtitle2,
      double completion, String statusText, Color statusColor, VoidCallback? onTap,
      VoidCallback onDelete})
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
      onDelete: () => _confirmDelete(context, s),
    );
  }

  static Future<void> _confirmDelete(BuildContext context, Scenario s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('코스를 삭제할까요?'),
        content: Text('"${s.title}" 코스와 진행 상황이 함께 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) await ScenarioStore.I.remove(s.scenarioId);
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
        double completion, String statusText, Color statusColor, VoidCallback? onTap,
        VoidCallback onDelete}) d,
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
                  IconButton(
                    onPressed: d.onDelete,
                    icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
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
