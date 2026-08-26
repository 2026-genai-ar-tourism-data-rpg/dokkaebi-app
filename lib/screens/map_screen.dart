// ============================================================
// [v3] "현재 위치" 버튼 — GPS로 받은 좌표로 지도 중심 이동 + 내 위치 마커 표시.
// 구현(요약): LocationService(이미 GPS 인증에서 쓰던 것) 재사용 — 권한 거부·서비스
//            꺼짐 등은 result.message로 스낵바 안내, 영구거부면 설정 열기 액션 추가.
//            받은 좌표가 한반도 제약 범위 밖이면 CameraConstraint가 알아서 가장
//            가까운 경계로 붙인다(시뮬레이터 기본 위치가 국외일 때 특히 그렇다).
// 구현일: 2026-08-26 | 작성: ljs
// ------------------------------------------------------------
// [v2] 팔도 지도를 실제 지리 지도로 교체.
// 구현(요약): flutter_map(OSM 타일) + LatLng 마커로 교체. 팬·줌은 한반도 근방으로
//            제한(CameraConstraint).
// 구현일: 2026-08-26 | 작성: ljs
// ------------------------------------------------------------
// [v1] 화면: 팔도 지도 (시안 7)
// pipeline: 모바일 클라이언트 / 화면 (지도 탭)
// 구현(요약): 스타일 지도(그리드 배경 + 지역 핀: 등급색·잠금) + 필터 + 지역 진행 카드.
//            ⚠️ 실제 지리 지도(타일·GPS 핀)는 TODO(정찬희, flutter_map). 지금은 시안 스타일 재현.
// 구현일: 2026-06-19 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  final MapController _mapController = MapController();
  LatLng? _myLocation;
  bool _locating = false;

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

    final here = LatLng(result.lat!, result.lng!);
    setState(() => _myLocation = here);
    // 한반도 제약 범위 밖 좌표(예: 시뮬레이터 기본 위치)는 CameraConstraint가
    // 가장 가까운 경계로 알아서 붙인다. 줌은 maxZoom(10)을 넘기지 않는다.
    _mapController.move(here, 10);
  }

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

  @override
  Widget build(BuildContext context) {
    // 지도(FlutterMap)는 Scrollable 조상 없이 둔다 — ListView 안에 있으면 팬·핀치줌
    // 제스처를 지도 대신 바깥 스크롤이 먼저 채가 버린다. 지도 아래쪽만 별도로 스크롤.
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
        // 지도 영역 — flutter_map(OSM 타일) + 마커.
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
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(36.3, 127.8),
                      initialZoom: 6.4,
                      minZoom: 6.0,
                      maxZoom: 10,
                      // 팬·줌을 한반도 근방으로 제한 — 세계지도로 빠지지 않게.
                      cameraConstraint: CameraConstraint.contain(
                        bounds: LatLngBounds(
                          LatLng(32.8, 124.5), // 남서 — 제주 아래
                          LatLng(38.7, 130.0), // 북동 — 휴전선 위
                        ),
                      ),
                    ),
                    children: [
                      TileLayer(
                        // CartoDB Dark Matter — OSM 데이터 기반, 라벨·색을 줄인 미니멀 다크 타일.
                        // 계정·API 키 불필요(CARTO 무료 기본 사용량 한도 내).
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.dokkaebi.dokkaebiApp',
                        retinaMode: RetinaMode.isHighDensity(context),
                      ),
                      MarkerLayer(markers: _pins.map(_marker).toList()),
                      if (_myLocation != null)
                        MarkerLayer(markers: [_myLocationMarker(_myLocation!)]),
                    ],
                  ),
                  // OSM 필수 저작권 표기 — 작고 은은하게, 단 타일 밝기와 무관하게
                  // 최소한의 대비는 유지(라이선스가 "합리적으로 식별 가능"을 요구).
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('© OpenStreetMap contributors © CARTO',
                          style:
                              TextStyle(color: Color(0xB3F2EAD8), fontSize: 8)),
                    ),
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

  Marker _marker((String, String, double, double, bool) p) {
    final c = p.$5 ? AppColors.textSecondary : tierColor(p.$2);
    return Marker(
      point: LatLng(p.$3, p.$4),
      width: 64,
      height: 64,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: c),
            boxShadow: p.$5
                ? null
                : [BoxShadow(color: c.withOpacity(0.4), blurRadius: 14)],
          ),
          child:
              Icon(p.$5 ? Icons.lock : Icons.location_on, color: c, size: 20),
        ),
        const SizedBox(height: 2),
        Text(p.$1,
            style:
                TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  /// "현재 위치" 버튼으로 받은 내 위치 — 지도 앱들의 익숙한 "정확도 헤일로 + 점"
  /// 구성. 헤딩(방향) 콘은 넣지 않았다 — 단발성 위치 조회라 방향 데이터가
  /// 신뢰할 만큼 안 나온다(그러려면 실시간 위치 스트리밍이 필요, 이번 범위 밖).
  Marker _myLocationMarker(LatLng point) {
    return Marker(
      point: point,
      width: 54,
      height: 54,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.blue.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 5,
                  offset: const Offset(0, 1)),
            ],
          ),
        ),
      ]),
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
