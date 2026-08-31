// ============================================================
// [v7] 동적 지역 핀 + 실시간 위치 추적.
// 구현(요약): 지역 핀은 ScenarioStore.I.scenarios에서 만들어진 코스마다
//            (앵커 노드 없으면 첫 노드) 좌표를 뽑아 찍는다 — 별도 레이어
//            (_regionLayerId)를 써서 "내 위치" 마커(default 레이어)와
//            섞이지 않게 하고, ScenarioStore 변경 시 clearMarkers 후 다시
//            그린다. 위치는 버튼 탭 시 1회 조회하던 것을
//            Geolocator.getPositionStream()으로 바꿔 계속 갱신 — 단, 카메라는
//            최초 1번만 이동시키고 이후 업데이트는 마커 위치만 갱신한다
//            (매번 재중심하면 사용자가 지도를 못 둘러본다).
// 구현일: 2026-08-26 | 작성: ljs (world-map-live/ljs/v2)
// ------------------------------------------------------------
// [v6] 하드코딩된 지역 핀·범례 제거.
// 구현(요약): _pins(서울·안동 등 6개 고정 지역)와 등급 범례를 제거 — 앞으로는
//            퀘스트 생성 시 만들어지는 지역으로 핀이 동적으로 채워질 예정
//            (이번 커밋 범위 아님, 후속 작업). addMarkerLayer()는 "내 위치"
//            마커가 여전히 그 레이어를 쓰므로 남겨둠.
// 구현일: 2026-08-26 | 작성: ljs (world-map-live/ljs/v2)
// ------------------------------------------------------------
// [v5] v4에서 미확인으로 남겼던 것 패키지 소스 직접 확인 후 정리.
// 구현(요약): kakao_maps_flutter 0.2.2 소스(pub-cache) 기준 —
//   - 팬·줌 범위 제한: 하드 제약 API 없음. onCameraMoveEndStream으로 범위
//     이탈 감지 후 moveCamera로 되돌리는 방식으로 흉내(_snapBackToKorea).
//     제스처 중엔 못 막고 "놓으면 튕겨 돌아오는" 느낌 — flutter_map의
//     CameraConstraint보다는 덜 매끄럽다.
//   - 다크 테마 지도 스타일: 패키지 전체에 MapType/테마 관련 API가 없어서
//     확실히 불가 — 기본(밝은) 스타일 유지가 최종 결론.
//   - 내 위치 커스텀 마커 이미지: registerMarkerStyles()+MarkerStyle로 적용
//     완료(assets/images/my_location.png — 정확도 헤일로 + 흰 테두리 파란 점,
//     기존 flutter_map 버전 디자인 그대로 PNG로 재현).
// 구현일: 2026-08-26 | 작성: ljs (world-map-live/ljs/v2)
// ------------------------------------------------------------
// [v4] 지도 엔진을 카카오맵으로 교체.
// 구현(요약): flutter_map(CARTO 타일) → kakao_maps_flutter. CARTO 무료 타일이
//            상업 배포 약관이 불명확하고(엔터프라이즈 전용이라는 상반된 안내도 있음)
//            래스터 타일 자체가 단계적 폐기 중이라 교체. 카카오는 개발자 계정당
//            첫 앱 기준 지도 SDK 일 30만 건 무료(초과 시 건당 0.1원)로 조건이 명확함.
//            실행하려면 Kakao Developers에서 발급받은 네이티브 앱 키가 필요
//            (config.dart의 AppConfig.kakaoNativeAppKey, --dart-define으로 주입).
// 구현일: 2026-08-26 | 작성: ljs (world-map-live/ljs/v2)
// ------------------------------------------------------------
// [v3] "현재 위치" 버튼 — GPS로 받은 좌표로 지도 중심 이동 + 내 위치 마커 표시.
// [v2] 팔도 지도를 실제 지리 지도로 교체(flutter_map).
// [v1] 화면: 팔도 지도 (시안 7) — 스타일 지도(그리드 배경) + 필터 + 지역 진행 카드.
// 구현일: 2026-06-19~08-26 | 작성: kys, ljs
// ============================================================
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart'
    show Geolocator, LocationAccuracy, LocationSettings, Position;
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../game/location_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'explore_place_screen.dart';
import 'quest_journey_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = const LocationService();
  KakaoMapController? _mapController;
  StreamSubscription<CameraMoveEndEvent>? _cameraSub;
  StreamSubscription<Position>? _positionSub;
  bool _locating = false;
  bool _hasLocationMarker = false;
  static const _myLocationMarkerId = 'my_location';
  static const _myLocationStyleId = 'my_location_style';
  static const _regionPinStyleId = 'region_pin_style';
  static const _regionLayerId = 'region_layer'; // "내 위치" 레이어와 분리 — 코스가
  // 바뀔 때마다 이 레이어만 clearMarkers 하기 위함(내 위치 마커까지 같이 지워지면 안 됨).

  @override
  void initState() {
    super.initState();
    // 코스 생성·삭제·조각 획득 등 스토어 변경 시 지역 핀을 다시 그린다.
    ScenarioStore.I.addListener(_refreshRegionMarkers);
  }

  // 한반도 팬·줌 제한 범위 — 패키지에 flutter_map의 CameraConstraint 같은
  // 하드 제약 API가 없어서, onCameraMoveEndStream으로 감지해 벗어나면
  // moveCamera로 되돌리는 방식으로 흉내낸다("놓으면 튕겨 돌아오는" 느낌).
  static const _swLat = 32.8, _swLng = 124.5; // 남서 — 제주 아래
  static const _neLat = 38.7, _neLng = 130.0; // 북동 — 휴전선 위

  Future<void> _onMapCreated(KakaoMapController controller) async {
    _mapController = controller;
    _cameraSub = controller.onCameraMoveEndStream.listen(_snapBackToKorea);
    // 이 SDK는 마커 레이어를 자동으로 만들어주지 않는다 — 먼저 명시적으로
    // 만들어야 addMarker(s)가 "LabelLayer not found"로 죽지 않는다.
    await controller.addMarkerLayer(
        layerId: KakaoMapController.defaultLabelLayerId); // 내 위치 마커용
    await controller.addMarkerLayer(layerId: _regionLayerId); // 퀘스트 지역 핀용
    await controller.registerMarkerStyles(styles: [
      MarkerStyle(
        styleId: _myLocationStyleId,
        perLevels: [
          MarkerPerLevelStyle.fromBytes(
              bytes: await _loadAssetBytes('assets/images/my_location.png')),
        ],
      ),
      MarkerStyle(
        styleId: _regionPinStyleId,
        perLevels: [
          MarkerPerLevelStyle.fromBytes(
              bytes: await _loadAssetBytes('assets/images/region_pin.png')),
        ],
      ),
    ]);
    await _refreshRegionMarkers(); // 최초 1회 — 이후는 스토어 리스너가 담당.
  }

  Future<Uint8List> _loadAssetBytes(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// ScenarioStore에 있는 코스마다 지역 핀 하나 — 앵커 노드(없으면 첫 노드)
  /// 좌표를 쓴다. 좌표 없는 코스는 건너뛴다.
  List<MarkerOption> _questRegionMarkers() {
    final markers = <MarkerOption>[];
    for (final s in ScenarioStore.I.scenarios) {
      final anchor =
          s.anchorNodeId != null ? s.nodeById(s.anchorNodeId!) : null;
      final node =
          anchor ?? (s.nodeSequence.isNotEmpty ? s.nodeSequence.first : null);
      final lat = node?.mapY, lng = node?.mapX;
      if (lat == null || lng == null) continue;
      markers.add(MarkerOption(
        id: s.scenarioId,
        latLng: LatLng(latitude: lat, longitude: lng),
        text: s.region,
        styleId: _regionPinStyleId,
      ));
    }
    return markers;
  }

  Future<void> _refreshRegionMarkers() async {
    final controller = _mapController;
    if (controller == null) return; // 지도 준비 전 — onMapCreated에서 다시 부름.
    await controller.clearMarkers(layerId: _regionLayerId);
    final markers = _questRegionMarkers();
    if (markers.isNotEmpty) {
      await controller.addMarkers(
          markerOptions: markers, layerId: _regionLayerId);
    }
  }

  void _snapBackToKorea(CameraMoveEndEvent e) {
    final lat = e.latitude.clamp(_swLat, _neLat).toDouble();
    final lng = e.longitude.clamp(_swLng, _neLng).toDouble();
    if (lat == e.latitude && lng == e.longitude) return; // 범위 안 — 그대로 둠
    _mapController?.moveCamera(
      cameraUpdate:
          CameraUpdate(position: LatLng(latitude: lat, longitude: lng)),
      animation: const CameraAnimation(
          duration: 250, autoElevation: false, isConsecutive: false),
    );
  }

  @override
  void dispose() {
    ScenarioStore.I.removeListener(_refreshRegionMarkers);
    _cameraSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await _locationService.current();
    if (!mounted) return;
    setState(() => _locating = false);

    if (!result.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        action: result.needsSettings
            ? SnackBarAction(
                label: '설정 열기', onPressed: _locationService.openSettings)
            : null,
      ));
      return;
    }

    final here = LatLng(latitude: result.lat!, longitude: result.lng!);
    await _placeMyLocationMarker(here);
    await _mapController?.moveCamera(
      cameraUpdate: CameraUpdate(position: here, zoomLevel: 14),
      animation: const CameraAnimation(
          duration: 500, autoElevation: false, isConsecutive: false),
    );

    // 실시간 추적 시작(최초 1번만) — 이후로는 위치가 바뀔 때마다 마커만 갱신하고
    // 카메라는 다시 옮기지 않는다(매번 재중심하면 지도를 못 둘러본다).
    _positionSub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((pos) => _placeMyLocationMarker(
        LatLng(latitude: pos.latitude, longitude: pos.longitude)));
  }

  /// "내 위치" 마커를 옮긴다. 마커는 선언형이 아니라 명령형 API라, 지우고
  /// 새로 찍는다 — 처음이면 지울 마커가 아직 없어서 removeMarker가
  /// "LabelLayer not found" 예외를 던진다, 그럴 때만 건너뛴다.
  Future<void> _placeMyLocationMarker(LatLng point) async {
    final controller = _mapController;
    if (controller == null) return;
    if (_hasLocationMarker) {
      await controller.removeMarker(id: _myLocationMarkerId);
    }
    _hasLocationMarker = true;
    await controller.addMarker(
      markerOption: MarkerOption(
        id: _myLocationMarkerId,
        latLng: point,
        styleId: _myLocationStyleId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 지도는 Scrollable 조상 없이 둔다 — ListView 안에 있으면 팬·핀치줌 제스처를
    // 지도 대신 바깥 스크롤이 먼저 채가 버린다. 지도 아래쪽만 별도로 스크롤.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader('WORLD MAP', '팔도 지도',
                trailing: TextButton.icon(
                  onPressed: _locating ? null : _goToCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.teal),
                        )
                      : const Icon(Icons.my_location,
                          size: 16, color: AppColors.teal),
                  label: const Text('현재 위치',
                      style: TextStyle(color: AppColors.teal, fontSize: 12)),
                )),
            const SizedBox(height: 16),
          ]),
        ),
        // 지도 영역 — 카카오맵.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 0.92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: KakaoMap(
                  onMapCreated: _onMapCreated,
                  initialPosition:
                      const LatLng(latitude: 36.3, longitude: 127.8),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // 퀘스트 탭(quest_tab_screen.dart)과 같은 기준 — ScenarioStore의
            // 최근 코스를 "진행 중인 퀘스트"로 본다. 스토어가 바뀌면(코스 생성·
            // 삭제·조각 획득) 다시 그려지도록 ListenableBuilder로 구독.
            child: ListenableBuilder(
              listenable: ScenarioStore.I,
              builder: (context, _) => _progressCard(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressCard(BuildContext context) {
    final scenarios = ScenarioStore.I.scenarios;
    if (scenarios.isEmpty) {
      return GlowCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('아직 진행 중인 퀘스트가 없어요.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExplorePlaceScreen())),
            child: const Text('이 지역 탐험하기  →'),
          ),
        ]),
      );
    }

    // 최근 코스 = 퀘스트 탭 "새 퀘스트 시작하기"와 같은 기준(scenarios.first).
    final scenario = scenarios.first;
    final done = ScenarioStore.I.stoneProgressOf(scenario);
    final total = scenario.stoneTotal;
    final progress = total == 0 ? 0.0 : done / total;

    return GlowCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(scenario.region,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          // Expanded 필수 — 부제가 길어지면(코스명·조각 수) 320px 기기에서
          // 오른쪽 진행률을 밀어내 넘친다. Spacer는 남는 공간만 먹으므로
          // 정작 넘칠 때는 도움이 안 된다.
          Expanded(
            child: Text('${scenario.title} · $done/$total조각',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).round()}%',
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ProgressBar(progress, color: AppColors.teal),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => QuestJourneyScreen(scenario: scenario))),
          child: const Text('퀘스트 이어하기  →'),
        ),
      ]),
    );
  }
}
