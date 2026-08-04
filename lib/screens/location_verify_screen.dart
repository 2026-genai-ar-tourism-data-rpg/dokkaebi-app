// ============================================================
// [v2] 화면: 위치 확인 — 실제 GPS + 서버 반경 판정
// pipeline: 모바일 클라이언트 / 화면 (GPS 인증)
// 구현(요약): 단말 GPS로 좌표·정확도를 읽어 서버 verify-location에 보내고 결과로 분기.
//            v1은 1.8초 뒤 무조건 성공으로 pop하는 연출이었다 — 어디서든 통과됐다.
//            거절 사유(반경 밖/신호 흐림/순간이동)마다 안내와 다음 행동이 다르다.
// 구현일: 2026-06-18 (실 GPS·서버 판정: 2026-08-04) | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../game/location_service.dart';
import '../game/run_session.dart';
import '../theme.dart';

/// 인증 단계 — 화면이 그릴 상태.
enum _Phase { locating, verifying, success, failure }

class LocationVerifyScreen extends StatefulWidget {
  final String placeName;

  /// 인증할 노드. null이면(데모·미리보기) 서버를 타지 않고 좌표만 확인한다.
  final String? nodeId;

  /// 테스트에서 갈아끼우는 지점 — 실기기 없이 화면 분기를 검증할 수 있게.
  final LocationService locationService;

  const LocationVerifyScreen({
    super.key,
    this.placeName = '경복궁',
    this.nodeId,
    this.locationService = const LocationService(),
  });

  @override
  State<LocationVerifyScreen> createState() => _LocationVerifyScreenState();
}

class _LocationVerifyScreenState extends State<LocationVerifyScreen>
    with SingleTickerProviderStateMixin {
  // ⚠️ initState에서 생성 — 지연 생성이면 dispose가 최초 접근이 되어 터질 수 있다.
  late final AnimationController _ac;

  _Phase _phase = _Phase.locating;
  String _detail = '';         // 실패 안내
  bool _needsSettings = false; // 앱 설정으로 보내야 하는 실패인지
  int? _distanceM;
  int? _requiredM;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _verify();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  /// GPS → 서버 판정. 실패해도 화면을 닫지 않는다 — 재시도할 수 있어야 한다.
  Future<void> _verify() async {
    setState(() {
      _phase = _Phase.locating;
      _detail = '';
      _needsSettings = false;
      _distanceM = null;
      _requiredM = null;
    });

    final loc = await widget.locationService.current();
    if (!mounted) return;

    if (!loc.isOk) {
      setState(() {
        _phase = _Phase.failure;
        _detail = loc.message;
        _needsSettings = loc.needsSettings;
      });
      return;
    }

    // 서버 판정 대상이 아니면(데모) 좌표 확인만으로 통과.
    final nodeId = widget.nodeId;
    if (nodeId == null) {
      setState(() => _phase = _Phase.success);
      _popAfterCelebration();
      return;
    }

    setState(() => _phase = _Phase.verifying);
    final verdict = await RunSession.I.verify(
      nodeId: nodeId, lat: loc.lat!, lng: loc.lng!, accuracyM: loc.accuracyM,
    );
    if (!mounted) return;

    if (verdict == null) {
      // 통신 자체가 실패 — 세션이 담아 둔 메시지를 그대로 보여준다.
      setState(() {
        _phase = _Phase.failure;
        _detail = RunSession.I.error ?? '서버와 통신하지 못했느니라.';
      });
      return;
    }

    if (!verdict.verified) {
      setState(() {
        _phase = _Phase.failure;
        _detail = verdict.message; // 사유별 문구는 모델이 만든다
        _distanceM = verdict.distanceM;
        _requiredM = verdict.requiredRadiusM;
      });
      return;
    }

    setState(() => _phase = _Phase.success);
    _popAfterCelebration();
  }

  /// 성공 연출을 잠깐 보여주고 닫는다.
  /// Timer 대신 await — 화면이 사라지면 mounted 검사로 걸러진다(취소 누락 위험 없음).
  Future<void> _popAfterCelebration() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final failed = _phase == _Phase.failure;
    final ok = _phase == _Phase.success;
    final color = failed ? Colors.redAccent : AppColors.teal;

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.15).animate(
                        CurvedAnimation(parent: _ac, curve: Curves.easeInOut)),
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.15),
                        border: Border.all(color: color),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.4), blurRadius: 30, spreadRadius: 4),
                        ],
                      ),
                      child: Icon(failed ? Icons.location_off : Icons.my_location,
                          color: color, size: 36),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    switch (_phase) {
                      _Phase.locating => '위치를 찾는 중...',
                      _Phase.verifying => '도착을 확인하는 중...',
                      _Phase.success => '위치 확인 완료!',
                      _Phase.failure => '아직 도착하지 않았느니라',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (ok)
                    Text('${widget.placeName} 근처에 있습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  if (failed) ...[
                    Text(_detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                    if (_distanceM != null && _requiredM != null) ...[
                      const SizedBox(height: 10),
                      Text('현재 ${_distanceM}m · 필요 ${_requiredM}m 이내',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                    const SizedBox(height: 24),
                    // Wrap — 좁은 기기에서 버튼 두 개가 한 줄에 안 들어가면 접힌다.
                    // (Row는 넘칠 때 잘리고, 여기서는 버튼이 잘리면 복구 수단이 사라진다)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (_needsSettings)
                          OutlinedButton(
                            onPressed: widget.locationService.openSettings,
                            child: const Text('설정 열기'),
                          ),
                        FilledButton(onPressed: _verify, child: const Text('다시 확인')),
                      ],
                    ),
                  ],
                  if (!failed && !ok)
                    const Text('잠시만 기다려다오...',
                        style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          // 실패해도 빠져나갈 수 있어야 한다 — 갇히면 앱을 껐다 켜야 한다.
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.place, size: 14, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(widget.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
