// ============================================================
// [v1] 화면: AR 탐색 (시안 4) — QUEST_ACTIVE, 기억석 조각 수집
// pipeline: 모바일 클라이언트 / 화면 (대화 힌트 → AR로 찾기)
// 구현(요약): 카메라 위 AR 마커(기억석·도깨비) + 힌트/스캔/NPC 토글 + 조각 진행.
//            스캔 → 마커 등장 → 기억석 탭 → 수집(pop true).
// ------------------------------------------------------------
// [v2] 실제 AR 연결 — ar_flutter_plugin은 안 씀(pub.dev 확인: 3년 방치,
//      정적분석·최신의존성 검사 실패, 원 기반 arkit_flutter_plugin은 pub.dev에서 삭제됨).
//      대신 ARKit을 네이티브(Swift, ios/Runner/DokkaebiArView.swift)로 얇게 직접 감싸
//      PlatformView로 붙였다. 실외 탐험 게임이라 평면(바닥) 인식은 요구하지 않고
//      포켓몬고식으로 세션 시작 시점 카메라 기준 고정 오프셋에 마커를 띄운다.
//      ⚠️ ARKit은 시뮬레이터 미지원 — dokkaebi/ar_support 채널로 실기기 여부를 먼저
//      확인하고, 아니면(시뮬레이터·구형기기·Android) 기존 고정 2D 마커로 폴백한다.
//      네이티브 코드라 이 폴백 분기 밖은 실기기에서 직접 확인 필요(시뮬레이터로 못 봄).
// 구현일: 2026-08-31 | 작성: 정찬희
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/native_ar_view.dart';

class ArSearchScreen extends StatefulWidget {
  final String placeName;
  final String order; // 도깨비 지령
  final List<String> hints; // 단계 힌트(방탈출)
  final int collected; // 진행: 이미 모은 조각 수
  final int total;

  /// 원격 체험 모드 — 그 장소에서 멀리 떨어져 있을 때.
  ///
  /// 카메라 대신 가상 배경을 쓴다. 집에서 켜면 어차피 그 장소의 사물이 없어
  /// 카메라를 띄워도 의미가 없고, 방바닥 위에 조각이 떠 있는 그림만 남는다.
  /// 조각은 여기서도 찾을 수 있지만 실제 방문 인증이 아니므로 서버 기록은 하지 않는다
  /// (호출부가 판단 — 이 화면은 연출만 바꾼다).
  final bool remote;

  const ArSearchScreen(
      {super.key, this.placeName = '', this.order = '', this.hints = const [], this.collected = 0, this.total = 5,
      this.remote = false});
  @override
  State<ArSearchScreen> createState() => _ArSearchScreenState();
}

class _ArSearchScreenState extends State<ArSearchScreen> with SingleTickerProviderStateMixin {
  String _mode = 'scan'; // hint | scan | npc
  bool _scanned = false;
  int _hintShown = 1; // 방탈출: 처음 1개만, "다음 힌트"로 단계 노출
  bool? _arSupported; // null=확인 중, true=실제 ARKit, false=2D 폴백(시뮬레이터 등)
  bool _arError = false;

  static const _fragmentMarker = ArMarkerDef(
    id: 'fragment', label: '기억석 조각', color: AppColors.teal,
    forward: 1.8, right: -0.4, down: 0.15,
  );
  static const _dokkaebiMarker = ArMarkerDef(
    id: 'dokkaebi', label: '도깨비', color: AppColors.purple,
    forward: 2.1, right: 0.5, down: 0.05,
  );
  // ⚠️ initState에서 생성한다. `late final _ac = AnimationController(...)` 형태로 두면
  //    지연 생성이라, build가 이 컨트롤러를 안 쓰는 분기(_mode='scan' 등)로만 지나가면
  //    dispose()의 _ac.dispose()가 '최초 접근'이 되어 dispose 도중에 컨트롤러를 만든다.
  //    그 시점엔 element가 비활성이라 TickerMode 조회가 터진다
  //    ("Looking up a deactivated widget's ancestor is unsafe").
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    if (widget.remote) {
      // 원격 체험은 카메라를 아예 켜지 않는다 — 권한 팝업도 띄우지 않는다.
      _arSupported = false;
    } else {
      isArSupported().then((ok) {
        if (mounted) setState(() => _arSupported = ok);
      });
    }
  }

  void _onNativeMarkerTapped(String id) {
    if (id == 'fragment') {
      Navigator.pop(context, true);
    } else if (id == 'dokkaebi') {
      setState(() => _mode = 'npc');
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 배경: 실기기(ARKit 지원)면 실제 카메라+3D 마커, 아니면(시뮬레이터·구형·Android·
        // 확인 중) 검은 placeholder + 아래 2D 고정 마커로 폴백.
        if (_arSupported == true && _mode == 'scan' && !_arError)
          NativeArView(
            markers: const [_fragmentMarker, _dokkaebiMarker],
            onMarkerTapped: _onNativeMarkerTapped,
            onError: () => setState(() => _arError = true),
          )
        else if (widget.remote)
          // 원격 체험 배경 — 그 자리에 없으니 카메라 대신 도깨비 기운이 도는 밤 풍경.
          _RemoteBackdrop(anim: _ac)
        else
          Container(
            color: const Color(0xFF0A0E16),
            child: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white10, size: 90)),
          ),

        // 상단: 장소 + 진행 + 닫기
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _chip(Icons.place, widget.placeName.isEmpty ? 'AR 탐색' : widget.placeName),
              const Spacer(),
              _chip(Icons.diamond, '${widget.collected}/${widget.total}', color: AppColors.teal),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ]),
          ),
        ),

        // 힌트 모드 (방탈출: 지령 + 단계 힌트)
        if (_mode == 'hint')
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.assignment_outlined, color: AppColors.gold, size: 28),
                const SizedBox(height: 10),
                if (widget.order.isNotEmpty)
                  Text('🧙 "${widget.order}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, height: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...List.generate(
                  widget.hints.take(_hintShown).length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('힌트 ${i + 1}. ${widget.hints[i]}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.gold, fontSize: 13, height: 1.4)),
                  ),
                ),
                if (_hintShown < widget.hints.length) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _hintShown++),
                    child: const Text('다음 힌트 보기', style: TextStyle(color: AppColors.gold)),
                  ),
                ],
              ]),
            ),
          ),

        // NPC 모드
        if (_mode == 'npc')
          Center(child: _panel(Icons.local_fire_department, AppColors.purple,
              '이 곳의 도깨비가 지켜보고 있다. 대화로 받은 단서를 떠올려 보자.')),

        // 스캔 모드 2D 폴백 마커 — 실제 AR(NativeArView) 사용 중이면 안 그림(중복 방지).
        if (!(_arSupported == true && !_arError)) ...[
          if (_mode == 'scan' && _scanned) ...[
            _marker(0.30, 0.40, AppColors.teal, Icons.diamond, '기억석 조각', onTap: () => Navigator.pop(context, true)),
            _marker(0.68, 0.55, AppColors.purple, Icons.local_fire_department, '도깨비', onTap: () => setState(() => _mode = 'npc')),
          ],
          if (_mode == 'scan' && !_scanned)
            const Center(child: Text('아래 "스캔"으로 주변을 살펴보세요',
                style: TextStyle(color: Colors.white54))),
        ],
        // 실제 AR 로딩 중 안내(마커가 뜨기 전 잠깐 표시).
        if (_arSupported == true && _mode == 'scan' && !_arError)
          const Positioned(
            bottom: 120, left: 0, right: 0,
            child: Center(child: Text('천천히 주변을 비춰 보세요 — 도깨비가 나타납니다',
                style: TextStyle(color: Colors.white54, fontSize: 12))),
          ),

        // 하단 토글 (힌트 / 스캔 / NPC)
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28, left: 16, right: 16),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                _tab('hint', Icons.lightbulb_outline, '힌트'),
                _tab('scan', Icons.radar, '스캔'),
                _tab('npc', Icons.face_retouching_natural, 'NPC'),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tab(String mode, IconData icon, String label) {
    final on = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _mode = mode;
          if (mode == 'scan') _scanned = true; // 스캔 누르면 마커 등장
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.teal.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: on ? AppColors.teal : Colors.white60, size: 20),
            Text(label, style: TextStyle(color: on ? AppColors.teal : Colors.white60, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _marker(double x, double y, Color c, IconData icon, String label, {VoidCallback? onTap}) {
    return LayoutBuilder(builder: (context, _) {
      final size = MediaQuery.of(context).size;
      return Positioned(
        left: size.width * x - 36,
        top: size.height * y - 36,
        child: GestureDetector(
          onTap: onTap,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.1).animate(_ac),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: c, width: 2),
                  boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 24, spreadRadius: 2)],
                ),
                child: Icon(icon, color: c, size: 28),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text(label, style: TextStyle(color: c, fontSize: 11)),
              ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _chip(IconData icon, String text, {Color color = Colors.white}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _panel(IconData icon, Color color, String text) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.5)),
        ]),
      );
}

/// 원격 체험 배경 — 카메라를 못 쓰는(또는 쓸 이유가 없는) 자리에서의 대체 화면.
///
/// 사진을 깔지 않고 그라데이션·별·안개로만 그린다. 실제 그 장소의 사진을 쓰면
/// "지금 눈앞"이라고 오해할 수 있는데, 원격 체험은 그 반대를 분명히 해야 한다.
class _RemoteBackdrop extends StatelessWidget {
  final Animation<double> anim;
  const _RemoteBackdrop({required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1020), Color(0xFF161226), Color(0xFF241B24)],
          ),
        ),
        child: Stack(children: [
          // 도깨비불 — 숨쉬듯 밝기가 오르내린다.
          Positioned(
            left: 60, top: 180,
            child: _Glow(color: AppColors.teal, size: 120, opacity: 0.10 + 0.06 * anim.value),
          ),
          Positioned(
            right: 40, top: 300,
            child: _Glow(color: AppColors.purple, size: 160, opacity: 0.08 + 0.05 * (1 - anim.value)),
          ),
          Positioned(
            left: 120, bottom: 220,
            child: _Glow(color: AppColors.gold, size: 100, opacity: 0.06 + 0.04 * anim.value),
          ),
          // 먼 능선 — 바깥 어딘가라는 감만 준다.
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _RidgeClipper(),
              child: Container(height: 170, color: const Color(0xFF0A0A12)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ),
        ),
      );
}

/// 배경 아래쪽 능선 실루엣.
class _RidgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()..moveTo(0, size.height);
    p.lineTo(0, size.height * 0.55);
    p.lineTo(size.width * 0.18, size.height * 0.18);
    p.lineTo(size.width * 0.34, size.height * 0.50);
    p.lineTo(size.width * 0.52, size.height * 0.10);
    p.lineTo(size.width * 0.70, size.height * 0.46);
    p.lineTo(size.width * 0.86, size.height * 0.22);
    p.lineTo(size.width, size.height * 0.52);
    p.lineTo(size.width, size.height);
    return p..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
