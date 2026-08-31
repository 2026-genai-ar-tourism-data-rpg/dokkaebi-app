// ============================================================
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../game/location_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'explore_place_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _filter = 0;
  static const _filters = ['전체', '전설', '영웅', '희귀'];

  final LocationService _locationService = const LocationService();
  KakaoMapController? _mapController;
  StreamSubscription<CameraMoveEndEvent>? _cameraSub;
  bool _locating = false;
  bool _hasLocationMarker = false;
  static const _myLocationMarkerId = 'my_location';
  static const _myLocationStyleId = 'my_location_style';

  // 한반도 팬·줌 제한 범위 — 패키지에 flutter_map의 CameraConstraint 같은
  // 하드 제약 API가 없어서, onCameraMoveEndStream으로 감지해 벗어나면
  // moveCamera로 되돌리는 방식으로 흉내낸다("놓으면 튕겨 돌아오는" 느낌).
  static const _swLat = 32.8, _swLng = 124.5; // 남서 — 제주 아래
  static const _neLat = 38.7, _neLng = 130.0; // 북동 — 휴전선 위

  // (지역명, 등급, 위도, 경도, 잠금) — 도시 중심 좌표.
  // MVP 시나리오가 서울 종로구뿐이라 서울 외 지역은 전부 잠금(추후 지역 확장 시 false로).
  static const _pins = [
    ('서울', '전설', 37.5665, 126.9780, false),
    ('안동', '영웅', 36.5684, 128.7294, true),
    ('전주', '희귀', 35.8242, 127.1480, true),
    ('경주', '영웅', 35.8562, 129.2247, true),
    ('부산', '일반', 35.1796, 129.0756, true),
    ('제주', '일반', 33.4996, 126.5312, true),
  ];

  Future<void> _onMapCreated(KakaoMapController controller) async {
    _mapController = controller;
    _cameraSub = controller.onCameraMoveEndStream.listen(_snapBackToKorea);
    // 이 SDK는 기본 마커 레이어를 자동으로 만들어주지 않는다 — 먼저 명시적으로
    // 만들어야 addMarker(s)가 "LabelLayer not found"로 죽지 않는다.
    await controller.addMarkerLayer(
        layerId: KakaoMapController.defaultLabelLayerId);
    await controller.addMarkers(
      markerOptions: [for (final p in _pins) _regionMarker(p)],
    );
    final iconData = await rootBundle.load('assets/images/my_location.png');
    final iconBytes = iconData.buffer
        .asUint8List(iconData.offsetInBytes, iconData.lengthInBytes);
    await controller.registerMarkerStyles(styles: [
      MarkerStyle(
        styleId: _myLocationStyleId,
        perLevels: [MarkerPerLevelStyle.fromBytes(bytes: iconBytes)],
      ),
    ]);
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
    _cameraSub?.cancel();
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
    final controller = _mapController;
    if (controller == null) return;

    // 마커는 선언형이 아니라 명령형 API라, 이전 "내 위치" 마커를 지우고 새로 찍는다.
    // 처음 누른 거면 지울 마커가 아직 없어서 removeMarker가
    // "LabelLayer not found" 예외를 던진다 — 그럴 때만 건너뛴다.
    if (_hasLocationMarker) {
      await controller.removeMarker(id: _myLocationMarkerId);
    }
    _hasLocationMarker = true;
    await controller.addMarker(
      markerOption: MarkerOption(
        id: _myLocationMarkerId,
        latLng: here,
        styleId: _myLocationStyleId,
      ),
    );
    await controller.moveCamera(
      cameraUpdate: CameraUpdate(position: here, zoomLevel: 14),
      animation: const CameraAnimation(
          duration: 500, autoElevation: false, isConsecutive: false),
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
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < _filters.length; i++)
                Pill(_filters[i],
                    active: _filter == i,
                    onTap: () => setState(() => _filter = i)),
            ]),
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
                child: Stack(children: [
                  KakaoMap(
                    onMapCreated: _onMapCreated,
                    initialPosition:
                        const LatLng(latitude: 36.3, longitude: 127.8),
                  ),
                  // 범례
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _Legend('전설', AppColors.gold),
                          _Legend('영웅', AppColors.purple),
                          _Legend('희귀', AppColors.blue),
                          _Legend('일반', AppColors.textSecondary),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // 지역 진행 카드
              GlowCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Text('서울',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        // Expanded 필수 — 부제가 길어지면(지역명·퀘스트 수) 320px 기기에서
                        // 오른쪽 진행률(68%)을 밀어내 넘친다. Spacer는 남는 공간만 먹으므로
                        // 정작 넘칠 때는 도움이 안 된다.
                        Expanded(
                          child: Text('Seoul · 퀘스트 12개',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ),
                        SizedBox(width: 8),
                        Text('68%',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 10),
                      const ProgressBar(0.68, color: AppColors.teal),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ExplorePlaceScreen())),
                        child: const Text('이 지역 탐험하기  →'),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  MarkerOption _regionMarker((String, String, double, double, bool) p) {
    return MarkerOption(
      id: p.$1,
      latLng: LatLng(latitude: p.$3, longitude: p.$4),
      text: p.$5 ? '${p.$1} 🔒' : p.$1,
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10)),
        ]),
      );
}
