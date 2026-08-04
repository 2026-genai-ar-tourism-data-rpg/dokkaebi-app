// ============================================================
// [v1] 화면: 도깨비·기억석 — 혼불 레이더 (신규 메인 디자인, standalone 시안 1:1)
// pipeline: 모바일 클라이언트 / 메인 셸 (지도·도감·나 + 레이더→AR→발굴 헌트)
// 구현(요약): 밤 지도에서 기억석(혼불) 탐색 → 레이더(나침반+거리계, 근접 진동) →
//            AR 카메라 발굴 → 결과(시대·감정·이야기) → 도감 보관. 3탭 + 바텀시트.
//            얼음빛 시안(#59C4F2)/청록/단청주홍, Gowun Batang + Space Mono.
// 구현일: 2026-07-08 | 작성: kys (honbul/kys/v1) · 시안: 도깨비 기억석 standalone
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart' show MainShell;
import '../store.dart';

// ── 혼불 팔레트 ─────────────────────────────────────────
const _bg = Color(0xFF141418);
const _bg2 = Color(0xFF0D0D10);
const _bg3 = Color(0xFF1B1B1E);
const _ice = Color(0xFF59C4F2); // 얼음빛 시안 — 나·시안 악센트
const _ice2 = Color(0xFF8FE0FF);
const _tealD = Color(0xFF2E7E76); // 청록 — 되찾은 기억
const _teal2 = Color(0xFF3AA89B);
const _teal3 = Color(0xFF9FE0D6);
const _red = Color(0xFFC6493C); // 단청 주홍 — 잠든 혼불·기억석
const _red2 = Color(0xFFD9705F);
const _red3 = Color(0xFFF0A498);
const _cream = Color(0xFFE8E1D4);
const _cream2 = Color(0xFFC9C3B6);
const _muted = Color(0xFF8A8A86);
const _muted2 = Color(0xFF7D7D78);

TextStyle _serif(double size, Color color, {double spacing = 0, double? height, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.gowunBatang(fontSize: size, color: color, letterSpacing: spacing, height: height, fontWeight: w);

TextStyle _mono(double size, Color color, {double spacing = 0, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.spaceMono(fontSize: size, color: color, letterSpacing: spacing, fontWeight: w);

/// 기억석(혼불) 한 점.
class Memory {
  final String id, name, era, emotion, story;
  final int dist; // m
  final double mx, my; // 지도 % 위치
  bool collected;
  Memory(this.id, this.name, this.era, this.emotion, this.dist, this.mx, this.my, this.story, {this.collected = false});
}

class HonbulHomeScreen extends StatefulWidget {
  const HonbulHomeScreen({super.key});
  @override
  State<HonbulHomeScreen> createState() => _HonbulHomeScreenState();
}

class _HonbulHomeScreenState extends State<HonbulHomeScreen> with SingleTickerProviderStateMixin {
  static const _maxRange = 120; // m
  static const _nearThreshold = 15;
  static const _sMin = 3;

  late final List<Memory> memories = _seedMemories();

  String screen = 'home'; // home | codex | profile | radar | camera | result
  int dist = 62;
  String targetId = 'well';
  bool revealed = false;
  final Set<String> collectedIds = {'firstsnow', 'lullaby'};
  String? sheetId;
  bool notif = true, haptic = true;

  // 연속 애니메이션용 마스터 클록 (초 단위 시간 = value*period)
  static const _period = 60.0;
  // ⚠️ initState에서 생성 — `late final = AnimationController(...)`는 지연 생성이라
  //    build가 이 컨트롤러를 안 쓰는 분기로 지나가면 dispose()가 최초 접근이 되어
  //    비활성 element에서 TickerMode를 조회하다 터진다.
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }
  double get _time => _clock.value * _period;

  List<Memory> _seedMemories() {
    final base = [
      Memory('well', '옛 우물가의 노래', '조선', '그리움', 62, 36, 34,
          '달빛이 우물에 내려앉으면, 두레박을 긷던 이의 노랫가락이 물결처럼 번졌다. 그 소리를 그리워한 혼불이 이 돌에 스몄다.'),
      Memory('market', '장터의 왁자한 웃음', '근대', '즐거움', 88, 68, 30,
          '엽전 부딪는 소리와 국밥 냄새, 흥정하던 목소리들이 한데 엉켜 웃음이 되었다. 그 흥이 채 식지 못해 여태 이 자리를 맴돈다.'),
      Memory('nightroad', '홀로 걷던 밤길', '일제강점기', '두려움', 110, 24, 66,
          '호롱불 하나 없는 밤, 제 발소리가 제 그림자를 쫓던 길. 그 두려움마저 서러워 작은 돌 속에 웅크렸다.'),
      Memory('firstsnow', '첫 눈 오던 마당', '1970년대', '설렘', 40, 74, 62,
          '첫 눈이 마당을 덮던 아침, 아이의 발자국이 세상에서 제일 먼저 찍혔다. 그 설렘이 눈처럼 소복이 쌓여 있다.'),
      Memory('lullaby', '이름 모를 자장가', '고려', '평안', 90, 52, 74,
          '누구의 것인지 모를 자장가가 처마 밑을 나직이 맴돌았다. 잠든 이를 지키던 그 평안이 돌에 고요히 깃들었다.'),
    ];
    // 데이터 연동(있으면): 내 코스의 기억석 노드 이름을 앞에서부터 덧입힘.
    try {
      final nodes = ScenarioStore.I.scenarios.expand((s) => s.stoneNodes).toList();
      for (var i = 0; i < base.length && i < nodes.length; i++) {
        final nm = nodes[i].name;
        if (nm != null && nm.trim().isNotEmpty) {
          final m = base[i];
          base[i] = Memory(m.id, nm, m.era, m.emotion, m.dist, m.mx, m.my,
              nodes[i].npcDialogue.trim().isNotEmpty ? nodes[i].npcDialogue.trim() : m.story);
        }
      }
    } catch (_) {}
    return base;
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  // ── 파생 상태 ──
  Memory get _target => memories.firstWhere((m) => m.id == targetId, orElse: () => memories.first);
  List<Memory> get _uncollected {
    final u = memories.where((m) => !collectedIds.contains(m.id)).toList();
    u.sort((a, b) => a.dist.compareTo(b.dist));
    return u;
  }

  bool get _isTabScreen => screen == 'home' || screen == 'codex' || screen == 'profile';
  bool _collected(Memory m) => collectedIds.contains(m.id);

  void _hunt(String id) {
    final m = memories.firstWhere((x) => x.id == id);
    setState(() {
      targetId = id;
      screen = 'radar';
      dist = math.min(m.dist, _maxRange - 2);
      revealed = false;
      sheetId = null;
    });
  }

  void _goResult() {
    setState(() { screen = 'result'; revealed = false; });
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted && screen == 'result') setState(() => revealed = true);
    });
  }

  void _keepMemory() {
    setState(() {
      collectedIds.add(targetId);
      for (final m in memories) {
        m.collected = collectedIds.contains(m.id);
      }
      screen = 'codex';
      sheetId = null;
    });
  }

  // ── 레이더 수학(시안 renderVals 이식) ──
  _RadarVals _radar() {
    final d = math.min(_maxRange.toDouble(), math.max(_sMin.toDouble(), dist.toDouble()));
    final t = math.min(1.0, d / _maxRange);
    final prox = 1 - t;
    final near = d <= _nearThreshold;
    final tick = _time / 0.09;
    final wob = math.sin(tick / 6) * 3.2 + math.sin(tick / 2.15) * 1.3;
    final angle = -50 + prox * 44 + wob; // deg, 0 = 북(위)
    final rad = angle * math.pi / 180;
    const r = 132.0;
    final dotR = t * r;
    final dx = dotR * math.sin(rad), dy = -dotR * math.cos(rad);
    final cardinals = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
    final bearing = '${cardinals[(((angle % 360) + 360) % 360 / 45).round() % 8]}쪽';
    final chip = near ? '지척' : (d < _maxRange * 0.45 ? '접근 중' : '탐지 중');
    return _RadarVals(d, t, prox, near, angle, dx, dy, bearing, chip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(fit: StackFit.expand, children: [
        // 탭 화면(페이드)
        _fadeLayer('home', _homeLayer()),
        _fadeLayer('codex', _codexLayer()),
        _fadeLayer('profile', _profileLayer()),
        // 탭바
        _tabBar(),
        // 푸시 화면(아래→위)
        _pushLayer('radar', _bg3, _radarLayer()),
        _pushLayer('camera', _bg2, _cameraLayer()),
        _pushLayer('result', _bg3, _resultLayer()),
        // 도감 상세 시트
        _sheet(),
      ]),
    );
  }

  // ── 레이어 전환 헬퍼 ──
  Widget _fadeLayer(String name, Widget child) {
    final on = screen == name;
    return IgnorePointer(
      ignoring: !on,
      child: AnimatedOpacity(
        opacity: on ? 1 : 0,
        duration: const Duration(milliseconds: 450),
        child: AnimatedScale(scale: on ? 1 : 0.985, duration: const Duration(milliseconds: 450), child: child),
      ),
    );
  }

  Widget _pushLayer(String name, Color bg, Widget child) {
    final on = screen == name;
    return IgnorePointer(
      ignoring: !on,
      child: AnimatedSlide(
        offset: Offset(0, on ? 0 : 1.02),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        child: Container(color: bg, child: child),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  // HOME (지도)
  // ════════════════════════════════════════════════════
  Widget _homeLayer() {
    final nearest = _uncollected.isNotEmpty ? _uncollected.first : null;
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.5), radius: 1.1, colors: [Color(0xFF1E1E24), _bg], stops: [0, 0.72]))),
      const Positioned.fill(child: CustomPaint(painter: _MapPathPainter())),
      // 핀 + 나(self)
      LayoutBuilder(builder: (ctx, box) => Stack(children: [
        for (final m in memories) _mapPin(box, m, isTarget: nearest != null && m.id == nearest.id, codex: false),
        Positioned(left: box.maxWidth * .5, top: box.maxHeight * .56, child: _selfWisp(label: '나')),
      ])),
      // 헤더
      _pageHeader('혼불 지도 · 오늘 밤', '주변의 기억석',
          sub: nearest != null ? '${_uncollected.length}점의 혼불이 당신을 기다립니다' : '오늘 밤의 혼불을 모두 되찾았습니다'),
      // 가장 가까운 혼불 CTA
      if (nearest != null)
        Positioned(left: 16, right: 16, bottom: 104, child: _nearestCard(nearest)),
    ]);
  }

  Widget _nearestCard(Memory m) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C21).withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _tealD.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: Row(children: [
          SizedBox(width: 40, height: 40, child: Stack(alignment: Alignment.center, children: [
            Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_red.withOpacity(0.5), _red.withOpacity(0)], stops: const [0, 0.68]))),
            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [_red3, _red]), boxShadow: [BoxShadow(color: _red.withOpacity(0.9), blurRadius: 12)])),
          ])),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('가장 가까운 혼불 · ${m.dist}m', style: _mono(10, _teal2, spacing: 1.5)),
            const SizedBox(height: 2),
            Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(17, _cream)),
            const SizedBox(height: 1),
            Text('${m.era} · ${m.emotion}', style: TextStyle(fontSize: 12, color: _muted.withOpacity(0.95))),
          ])),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _hunt(m.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD15848), _red]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _red.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))]),
              child: Text('쫓기 ▶', style: _serif(15, const Color(0xFFFFF8F2))),
            ),
          ),
        ]),
      );

  // ════════════════════════════════════════════════════
  // CODEX (도감)
  // ════════════════════════════════════════════════════
  Widget _codexLayer() {
    final collectedCount = memories.where(_collected).length;
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.4), radius: 1.1, colors: [Color(0xFF1B1E20), Color(0xFF121417)], stops: [0, 0.72]))),
      const Positioned.fill(child: CustomPaint(painter: _MapPathPainter(codex: true))),
      LayoutBuilder(builder: (ctx, box) => Stack(children: [
        for (final m in memories) _mapPin(box, m, isTarget: false, codex: true),
        Positioned(left: box.maxWidth * .5, top: box.maxHeight * .56, child: _selfWisp(small: true)),
      ])),
      // 헤더
      Positioned(top: 0, left: 0, right: 0, child: Container(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 26),
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xEE121417), Color(0x00121417)], stops: [0.45, 1])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('기억 도감', style: _mono(10, _teal2, spacing: 3.5)),
          const SizedBox(height: 5),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('모아온 기억들', style: _serif(27, _cream, spacing: 0.5)),
            const Spacer(),
            Text('$collectedCount / ${memories.length}', style: _mono(13, _ice)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _legend(_tealD, '되찾은 기억', fill: true),
            const SizedBox(width: 16),
            _legend(_cream.withOpacity(0.3), '아직 잠든 혼불', fill: false),
          ]),
        ]),
      )),
    ]);
  }

  Widget _legend(Color c, String label, {required bool fill}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: fill ? c : null, border: fill ? null : Border.all(color: c), boxShadow: fill ? [BoxShadow(color: c.withOpacity(0.8), blurRadius: 6)] : null)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
      ]);

  // ════════════════════════════════════════════════════
  // PROFILE (나)
  // ════════════════════════════════════════════════════
  Widget _profileLayer() {
    final collectedCount = memories.where(_collected).length;
    final uncollectedCount = memories.length - collectedCount;
    return Container(
      decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.76), radius: 1.0, colors: [Color(0xFF22222A), _bg], stops: [0, 0.6])),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 120),
          child: Column(children: [
            SizedBox(width: 96, height: 96, child: Stack(alignment: Alignment.center, children: [
              Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_ice.withOpacity(0.4), _ice.withOpacity(0)], stops: const [0, 0.68]))),
              AnimatedBuilder(animation: _clock, builder: (_, __) {
                final w = (math.sin(_time / 3 * math.pi * 2) + 1) / 2;
                return Container(width: 40 + 8 * w, height: 40 + 8 * w, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _ice.withOpacity(0.45 * (1 - w)), width: 1.5)));
              }),
              Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFEAFFFF), _ice], stops: [0, 0.6]), boxShadow: [BoxShadow(color: _ice.withOpacity(0.9), blurRadius: 20)])),
            ])),
            const SizedBox(height: 14),
            Text('떠도는 도깨비', style: _serif(22, _cream, spacing: 0.5)),
            const SizedBox(height: 4),
            Text('@dokkaebi_honbul', style: _mono(11, _muted2)),
            const SizedBox(height: 26),
            Row(children: [
              _stat('$collectedCount', '되찾은 기억', _ice),
              const SizedBox(width: 10),
              _stat('$uncollectedCount', '잠든 혼불', _red2),
              const SizedBox(width: 10),
              _stat('3.4', '걸은 밤길 (km)', _teal2),
            ]),
            const SizedBox(height: 28),
            Align(alignment: Alignment.centerLeft, child: Text('설정', style: _mono(10, _muted2, spacing: 2))),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Column(children: [
                _toggleRow('혼불 알림', notif, () => setState(() => notif = !notif)),
                _divider(),
                _toggleRow('소리 · 진동', haptic, () => setState(() => haptic = !haptic)),
                _divider(),
                _linkRow('지도 테마', '먹빛 밤 ›'),
                _divider(),
                _linkRow('앱 정보', 'v1.0 ›'),
              ]),
            ),
            const SizedBox(height: 14),
            // 구버전(퀘스트/시나리오) 진입 — 기존 기능 보존
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MainShell())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _tealD.withOpacity(0.35)), color: _tealD.withOpacity(0.08)),
                child: Text('퀘스트 · 코스 모드 (구버전) ›', style: _serif(14, _teal3)),
              ),
            ),
            const SizedBox(height: 26),
            Text('도깨비 · 기억석\n잊혀진 혼불을 되찾는 밤', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF55554F), height: 1.7)),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
          child: Column(children: [
            Text(value, style: _mono(24, c)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: _muted), textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _divider() => Container(height: 1, color: Colors.white.withOpacity(0.05));

  Widget _toggleRow(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: _cream))),
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46, height: 27,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: on ? _tealD : Colors.white.withOpacity(0.14)),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 21, height: 21, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))])),
              ),
            ),
          ),
        ]),
      );

  Widget _linkRow(String label, String value) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15, color: _cream))),
          Text(value, style: const TextStyle(fontSize: 13, color: _muted2)),
        ]),
      );

  // ════════════════════════════════════════════════════
  // RADAR (혼불 레이더)
  // ════════════════════════════════════════════════════
  Widget _radarLayer() {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final rv = _radar();
          return Column(children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Row(children: [
                _circleBtn(child: const Icon(Icons.chevron_left, color: _ice, size: 22), onTap: () => setState(() => screen = 'home')),
                Expanded(child: Column(children: [
                  Text('혼불 레이더', style: _mono(10, _teal2, spacing: 3.5)),
                  const SizedBox(height: 3),
                  Text(_target.name, style: _serif(15, _cream, spacing: 0.6)),
                ])),
                _circleBtn(child: Text('?', style: _mono(15, _cream.withOpacity(0.55)))),
              ]),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _tealD, borderRadius: BorderRadius.circular(999)), child: Text(rv.chip, style: _mono(10, _bg2, spacing: 2))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: _red.withOpacity(0.45))), child: Text(rv.bearing, style: _mono(10, _red2, spacing: 2))),
            ]),
            // 레이더 원
            Expanded(child: Center(child: _radarDial(rv))),
            // 거리 리드아웃
            Column(children: [
              Text('남은 거리', style: _mono(10, _muted2, spacing: 2.5)),
              SizedBox(height: 72, child: Center(child: rv.near
                  ? Text('매우 가까움', style: _serif(36, _cream, spacing: 1))
                  : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      Text('${rv.dist.round()}', style: _mono(62, _cream, w: FontWeight.w700)),
                      const SizedBox(width: 5),
                      Text('m', style: _mono(22, _ice)),
                    ]))),
              SizedBox(height: 20, child: Center(child: Text(rv.near ? '기억석이 지척에 잠들어 있습니다' : '${rv.bearing} · 희미한 온기가 번져옵니다', style: TextStyle(fontSize: 13, color: rv.near ? _red3 : _muted)))),
            ]),
            // 슬라이더 + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 14, 26, 30),
              child: Column(children: [
                Row(children: [
                  Text('멀리', style: _mono(9, _muted2, spacing: 1)),
                  Expanded(child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 5,
                      activeTrackColor: _ice,
                      inactiveTrackColor: _tealD.withOpacity(0.2),
                      thumbColor: _ice,
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                    ),
                    child: Slider(min: _sMin.toDouble(), max: _maxRange.toDouble(), value: rv.dist, onChanged: (v) => setState(() => dist = v.round())),
                  )),
                  Text('가까이', style: _mono(9, _muted2, spacing: 1)),
                ]),
                const SizedBox(height: 12),
                SizedBox(height: 56, child: rv.near
                    ? _AnimatedGlowButton(onTap: () => setState(() => screen = 'camera'), clock: _clock, time: _time)
                    : Center(child: Text('혼불이 이끄는 곳으로 발걸음을 옮기세요', style: TextStyle(fontSize: 13, color: _muted.withOpacity(0.95))))),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _circleBtn({required Widget child, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: _tealD.withOpacity(0.13), border: Border.all(color: _tealD.withOpacity(0.32))), child: child),
      );

  Widget _radarDial(_RadarVals rv) {
    final shake = rv.near && haptic;
    final shakeOff = shake
        ? Offset(math.sin(_time * 40) * 2, math.cos(_time * 33) * 2)
        : Offset.zero;
    Widget dial = SizedBox(
      width: 300, height: 300,
      child: Stack(children: [
        // 십자선
        Positioned(left: 150, top: 30, bottom: 30, child: Container(width: 1, color: _tealD.withOpacity(0.13))),
        Positioned(top: 150, left: 30, right: 30, child: Container(height: 1, color: _tealD.withOpacity(0.13))),
        Positioned(left: 150 - 6, top: 4, child: Text('N', style: _mono(11, _cream.withOpacity(0.4)))),
        Positioned(left: 150 - 5, bottom: 4, child: Text('S', style: _mono(11, _cream.withOpacity(0.28)))),
        Positioned(top: 150 - 8, right: 4, child: Text('E', style: _mono(11, _cream.withOpacity(0.28)))),
        Positioned(top: 150 - 8, left: 4, child: Text('W', style: _mono(11, _cream.withOpacity(0.28)))),
        // 펄스 링 2개
        _pulseRing(0), _pulseRing(0.5),
        // 스윕
        _sweep(rv.t),
        // 링 그룹
        _ringGroup(rv.t),
        // 정지 노이즈 점
        Positioned(left: 212, top: 92, child: _dot(5, _red.withOpacity(0.32))),
        Positioned(left: 96, top: 118, child: _dot(4, _red.withOpacity(0.26))),
        Positioned(left: 172, top: 224, child: _dot(4, _red.withOpacity(0.22))),
        // 방향 화살표(중심 기준 회전)
        Positioned(left: 150, top: 150, child: Transform.rotate(
          angle: rv.angle * math.pi / 180,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: 0.42 + 0.58 * rv.t,
            alignment: Alignment.bottomCenter,
            child: _arrow(),
          ),
        )),
        // 기억석 점(극좌표)
        Positioned(left: 150 + rv.dx, top: 150 + rv.dy, child: _stoneDot(rv)),
        // 나(중심)
        Positioned(left: 150, top: 150, child: _selfWisp(center: true)),
      ]),
    );
    // 화면 폭에 맞게 축소
    return Transform.translate(
      offset: shakeOff,
      child: LayoutBuilder(builder: (ctx, box) {
        final s = math.min(1.0, (box.maxWidth - 24) / 300);
        return Transform.scale(scale: s, child: dial);
      }),
    );
  }

  Widget _pulseRing(double delay) => AnimatedBuilder(animation: _clock, builder: (_, __) {
        final period = 2.4;
        final p = ((_time / period) + delay) % 1.0;
        final scale = 0.14 + 0.86 * p;
        final opacity = (0.5 * (1 - p)).clamp(0.0, 0.5);
        return Positioned(
          left: 150, top: 150,
          child: Transform.translate(
            offset: const Offset(-132, -132),
            child: Transform.scale(
              scale: scale,
              child: Opacity(opacity: opacity, child: Container(width: 264, height: 264, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: (delay == 0 ? _tealD : _ice).withOpacity(0.5), width: 1.5)))),
            ),
          ),
        );
      });

  Widget _sweep(double t) => AnimatedBuilder(animation: _clock, builder: (_, __) {
        final dur = 3.2 + 2.6 * t;
        final ang = (_time / dur % 1.0) * 2 * math.pi;
        return Positioned(
          left: 150 - 132, top: 150 - 132,
          child: Transform.rotate(
            angle: ang,
            child: ClipOval(
              child: SizedBox(width: 264, height: 264, child: CustomPaint(painter: _SweepPainter())),
            ),
          ),
        );
      });

  Widget _ringGroup(double t) => Transform.translate(
        offset: const Offset(150, 150),
        child: Transform.scale(
          scale: 0.6 + 0.4 * t,
          child: Stack(clipBehavior: Clip.none, children: [
            _ring(92, _tealD.withOpacity(0.18), 1),
            _ring(150, _tealD.withOpacity(0.24), 1),
            _ring(208, _tealD.withOpacity(0.32), 1),
            _ring(264, _tealD.withOpacity(0.44), 1.5),
          ]),
        ),
      );

  Widget _ring(double d, Color c, double w) => Positioned(left: -d / 2, top: -d / 2, child: Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: w))));

  Widget _arrow() => SizedBox(
        width: 16, height: 118,
        child: Stack(alignment: Alignment.topCenter, children: [
          Positioned(bottom: 0, child: Container(width: 2, height: 106, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x0059C4F2), Color(0x2E59C4F2), _ice], stops: [0, 0.32, 1]), borderRadius: BorderRadius.all(Radius.circular(2))))),
          Positioned(top: 0, child: CustomPaint(size: const Size(14, 12), painter: _ArrowHeadPainter())),
        ]),
      );

  Widget _stoneDot(_RadarVals rv) => SizedBox(
        width: 0, height: 0,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          Container(width: 66, height: 66, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_red.withOpacity(0.55 * (0.5 + rv.prox * 0.5)), _red.withOpacity(0)], stops: const [0, 0.68]))),
          AnimatedBuilder(animation: _clock, builder: (_, __) {
            final p = (_time / 2.4) % 1.0;
            return Container(width: 26 * (1 + p * 0.35), height: 26 * (1 + p * 0.35), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _red.withOpacity(0.7 * (1 - p * 0.7)), width: 1.5)));
          }),
          Container(width: 13, height: 13, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [_red3, _red]), boxShadow: [BoxShadow(color: _red.withOpacity(0.9), blurRadius: 12)])),
          if (!rv.near) Positioned(top: 22, child: Text('기억석', style: TextStyle(fontSize: 11, color: _red3.withOpacity(0.95)))),
        ]),
      );

  // ════════════════════════════════════════════════════
  // CAMERA (AR 발굴)
  // ════════════════════════════════════════════════════
  Widget _cameraLayer() {
    final camDist = math.max(0.6, _radar().dist * 0.18);
    return Stack(fit: StackFit.expand, children: [
      // 카메라 플레이스홀더
      Container(color: const Color(0xFF0A0A0C), child: Center(child: Icon(Icons.videocam_outlined, color: Colors.white.withOpacity(0.06), size: 90))),
      IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.16), radius: 1.1, colors: [const Color(0x000B0B0E), const Color(0xB80B0B0E)], stops: const [0.26, 1])))),
      // 상단 REC
      Positioned(top: 56, left: 22, right: 22, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: _red, boxShadow: [BoxShadow(color: _red, blurRadius: 8)])), const SizedBox(width: 7), Text('REC · 기억 탐지', style: _mono(10, _cream, spacing: 2))]),
        Text('${camDist.toStringAsFixed(1)}m', style: _mono(10, _cream.withOpacity(0.7))),
      ])),
      // 레티클
      Center(child: AnimatedBuilder(animation: _clock, builder: (_, __) => SizedBox(
        width: 222, height: 222,
        child: Stack(alignment: Alignment.center, children: [
          Transform.rotate(angle: (_time / 14 % 1) * 2 * math.pi, child: CustomPaint(size: const Size(222, 222), painter: _ReticlePainter())),
          Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_red.withOpacity(0.5), _red.withOpacity(0)], stops: const [0, 0.7]))),
          Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFF4B3A7), _red]), boxShadow: [BoxShadow(color: _red.withOpacity(0.9), blurRadius: 22), BoxShadow(color: _red.withOpacity(0.5), blurRadius: 46)])),
        ]),
      ))),
      Positioned(left: 34, right: 34, bottom: 158, child: Column(children: [
        Text('이 자리에 기억석이 잠들어 있습니다', textAlign: TextAlign.center, style: _serif(19, _cream, spacing: 0.5)),
        const SizedBox(height: 8),
        Text('화면 중앙에 겹쳐 보세요', style: _mono(10, _cream.withOpacity(0.6), spacing: 1.5)),
      ])),
      Positioned(left: 30, right: 30, bottom: 44, child: Column(children: [
        GestureDetector(onTap: _goResult, child: Container(
          width: double.infinity, padding: const EdgeInsets.all(15), alignment: Alignment.center,
          decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD15848), _red]), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: _red.withOpacity(0.4), blurRadius: 26, offset: const Offset(0, 8))]),
          child: Text('기억석 발굴하기', style: _serif(16, const Color(0xFFFFF8F2), spacing: 1)),
        )),
        const SizedBox(height: 13),
        GestureDetector(onTap: () => setState(() => screen = 'radar'), child: Text('← 레이더로 돌아가기', style: _serif(14, _cream.withOpacity(0.65), spacing: 0.5))),
      ])),
    ]);
  }

  // ════════════════════════════════════════════════════
  // RESULT (발굴 결과)
  // ════════════════════════════════════════════════════
  Widget _resultLayer() {
    final m = _target;
    Widget rvItem(double delay, Widget child) => AnimatedSlide(
          offset: revealed ? Offset.zero : const Offset(0, 0.12),
          duration: Duration(milliseconds: 600 + (delay * 1000).round()),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(opacity: revealed ? 1 : 0, duration: Duration(milliseconds: 500 + (delay * 1000).round()), child: child),
        );
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 0.9, colors: [_red.withOpacity(0.22), const Color(0x001B1B1E)], stops: const [0, 0.68]))),
      SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 30, 36, 150),
        // 결과 연출은 조각(150) + 제목 + 태그 + 본문으로 세로가 길다. 320x568 기기에선
        // 남는 높이(388)를 109px 넘겨 오버플로가 났다 → 넘칠 때만 스크롤되게 한다.
        // ConstrainedBox(minHeight)가 있어 여유가 있는 기기에선 기존처럼 중앙 정렬 유지.
        child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          rvItem(0.05, Text('기억을 되찾았습니다', style: _mono(10, _teal2, spacing: 3.5))),
          const SizedBox(height: 22),
          // 조각
          SizedBox(width: 150, height: 150, child: AnimatedScale(
            scale: revealed ? 1 : 0.6,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(opacity: revealed ? 1 : 0, duration: const Duration(milliseconds: 700), child: AnimatedBuilder(animation: _clock, builder: (_, __) => Stack(alignment: Alignment.center, children: [
              Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_red.withOpacity(0.4), _red.withOpacity(0)], stops: const [0, 0.68]))),
              Transform.rotate(angle: (_time / 16 % 1) * 2 * math.pi, child: Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _red.withOpacity(0.35))))),
              Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFF6C3B8), _red]), boxShadow: [BoxShadow(color: _red.withOpacity(0.85), blurRadius: 30), BoxShadow(color: _red.withOpacity(0.4), blurRadius: 60)])),
            ]))),
          )),
          const SizedBox(height: 26),
          rvItem(0.25, Text(m.name, textAlign: TextAlign.center, style: _serif(28, _cream, spacing: 0.5))),
          const SizedBox(height: 14),
          rvItem(0.38, Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _resultTag(m.era, _teal3, _tealD),
            const SizedBox(width: 8),
            _resultTag(m.emotion, _red3, _red),
          ])),
          const SizedBox(height: 20),
          rvItem(0.5, ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: Text(m.story, textAlign: TextAlign.center, style: _serif(15, _cream2, height: 1.9)))),
            ]),
          ),
        )),
      )),
      Positioned(left: 30, right: 30, bottom: 44, child: Column(children: [
        rvItem(0.65, GestureDetector(onTap: _keepMemory, child: Container(
          width: double.infinity, padding: const EdgeInsets.all(15), alignment: Alignment.center,
          decoration: BoxDecoration(color: _tealD.withOpacity(0.18), borderRadius: BorderRadius.circular(15), border: Border.all(color: _tealD.withOpacity(0.5))),
          child: Text('도감에 보관하기', style: _serif(16, const Color(0xFFBFF0E7), spacing: 1)),
        ))),
        const SizedBox(height: 13),
        GestureDetector(onTap: () => setState(() => screen = 'home'), child: Text('계속 탐색하기', style: _serif(14, _cream.withOpacity(0.6)))),
      ])),
    ]);
  }

  Widget _resultTag(String text, Color fg, Color base) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(color: base.withOpacity(0.16), borderRadius: BorderRadius.circular(999), border: Border.all(color: base.withOpacity(0.35))),
        child: Text(text, style: _mono(11, fg, spacing: 1)),
      );

  // ════════════════════════════════════════════════════
  // TAB BAR (지도 / 도감 / 나)
  // ════════════════════════════════════════════════════
  Widget _tabBar() {
    return AnimatedSlide(
      offset: Offset(0, _isTabScreen ? 0 : 1.3),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          ignoring: !_isTabScreen,
          child: Container(
            padding: const EdgeInsets.only(top: 10, bottom: 26),
            decoration: BoxDecoration(color: const Color(0xFF101013).withOpacity(0.92), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
            child: Row(children: [
              _tabItem('home', Icons.place_outlined, '지도'),
              _tabItem('codex', Icons.menu_book_outlined, '도감'),
              _tabItem('profile', Icons.person_outline, '나'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tabItem(String name, IconData icon, String label) {
    final on = screen == name;
    final c = on ? _ice : _cream.withOpacity(0.5);
    return Expanded(child: GestureDetector(
      onTap: () => setState(() { screen = name; sheetId = null; revealed = false; }),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: c, size: 22),
        const SizedBox(height: 4),
        Text(label, style: _serif(10, c, spacing: 0.5)),
      ]),
    ));
  }

  // ════════════════════════════════════════════════════
  // 지도 핀 / 나 / 상세 시트 / 공통
  // ════════════════════════════════════════════════════
  Widget _mapPin(BoxConstraints box, Memory m, {required bool isTarget, required bool codex}) {
    final got = _collected(m);
    if (codex && !got && !isTarget) {
      // 도감 미수집: 빈 원
      final size = 9.0;
      return Positioned(
        left: box.maxWidth * m.mx / 100 - 23, top: box.maxHeight * m.my / 100 - 23,
        child: SizedBox(width: 46, height: 46, child: Center(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _cream.withOpacity(0.28)))))),
      );
    }
    final size = isTarget ? 15.0 : (got ? (codex ? 14.0 : 11.0) : 13.0);
    final haloC = got ? _tealD : _red;
    final coreGrad = got
        ? const RadialGradient(center: Alignment(-0.3, -0.4), colors: [_teal3, _tealD])
        : const RadialGradient(center: Alignment(-0.3, -0.4), colors: [_red3, _red]);
    return Positioned(
      left: box.maxWidth * m.mx / 100 - 30,
      top: box.maxHeight * m.my / 100 - 30,
      child: GestureDetector(
        onTap: () {
          if (got) {
            setState(() => sheetId = m.id);
          } else if (!codex) {
            _hunt(m.id);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(width: 60, height: 60, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          Container(width: size * 4.6, height: size * 4.6, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [haloC.withOpacity(got ? 0.35 : 0.5), haloC.withOpacity(0)], stops: const [0, 0.68]))),
          if (isTarget) AnimatedBuilder(animation: _clock, builder: (_, __) {
            final p = (_time / 2.2) % 1.0;
            return Container(width: size * 2.3 * (1 + p * 0.35), height: size * 2.3 * (1 + p * 0.35), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _red.withOpacity(0.6 * (1 - p * 0.7)), width: 1.5)));
          }),
          Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: coreGrad, boxShadow: [BoxShadow(color: haloC.withOpacity(got ? 0.6 : 0.9), blurRadius: got && codex ? 14 : 12)])),
          if (isTarget || (codex && got)) Positioned(top: 3, child: Text(m.name, style: TextStyle(fontSize: isTarget ? 12 : 11, color: isTarget ? _red3 : _teal3, shadows: const [Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1))]))),
        ])),
      ),
    );
  }

  Widget _selfWisp({String? label, bool small = false, bool center = false}) {
    final core = small ? 10.0 : 12.0;
    return SizedBox(width: 0, height: 0, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      if (!small && !center) AnimatedBuilder(animation: _clock, builder: (_, __) {
        final w = (math.sin(_time / 2.6 * math.pi * 2) + 1) / 2;
        return Container(width: 44 * (1 + w * 0.3), height: 44 * (1 + w * 0.3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _ice.withOpacity(0.5 * (1 - w)), width: 1.5)));
      }),
      Container(width: small ? 34 : 40, height: small ? 34 : 40, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_ice.withOpacity(small ? 0.32 : 0.4), _ice.withOpacity(0)], stops: const [0, 0.7]))),
      if (center) ..._floatParticles(),
      Container(width: core, height: core, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFEAFFFF), _ice], stops: [0, 0.62]), boxShadow: [BoxShadow(color: _ice.withOpacity(0.95), blurRadius: 14), if (center) BoxShadow(color: _ice.withOpacity(0.5), blurRadius: 30)])),
      if (label != null) Positioned(top: 14, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8FD6F5)))),
    ]));
  }

  List<Widget> _floatParticles() {
    final defs = [
      (const Offset(16, -22), _ice, 3.2, 0.0, 5.0),
      (const Offset(-20, -14), _ice2, 3.8, -1.2, 4.0),
      (const Offset(22, 10), _ice, 4.2, -2.4, 3.0),
      (const Offset(-12, 20), const Color(0xFFBFEFFF), 3.5, -0.7, 4.0),
    ];
    return [
      for (final d in defs)
        AnimatedBuilder(animation: _clock, builder: (_, __) {
          final p = ((_time + d.$4) / d.$3) % 1.0;
          final op = p < 0.2 ? p / 0.2 * 0.9 : (p > 0.8 ? (1 - p) / 0.2 * 0.5 : 0.9 - (p - 0.2) * 0.5);
          return Transform.translate(offset: Offset(d.$1.dx * p, d.$1.dy * p), child: Opacity(opacity: op.clamp(0.0, 1.0), child: Container(width: d.$5, height: d.$5, decoration: BoxDecoration(shape: BoxShape.circle, color: d.$2))));
        }),
    ];
  }

  Widget _pageHeader(String eyebrow, String title, {required String sub}) => Positioned(
        top: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xEB141418), Color(0x00141418)], stops: [0.4, 1])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eyebrow, style: _mono(10, _teal2, spacing: 3.5)),
            const SizedBox(height: 5),
            Text(title, style: _serif(27, _cream, spacing: 0.5)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 13, color: Color(0xFF9A9A94))),
          ]),
        ),
      );

  Widget _dot(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _sheet() {
    final m = sheetId == null ? null : memories.firstWhere((x) => x.id == sheetId, orElse: () => memories.first);
    final open = m != null;
    return Stack(children: [
      IgnorePointer(
        ignoring: !open,
        child: GestureDetector(
          onTap: () => setState(() => sheetId = null),
          child: AnimatedOpacity(opacity: open ? 1 : 0, duration: const Duration(milliseconds: 350), child: Container(color: const Color(0x99080810))),
        ),
      ),
      AnimatedSlide(
        offset: Offset(0, open ? 0 : 1.1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
            decoration: const BoxDecoration(color: Color(0xFF1C1C22), borderRadius: BorderRadius.vertical(top: Radius.circular(26)), border: Border(top: BorderSide(color: Color(0x4D2E7E76))), boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, -14))]),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 20),
              Text(m == null ? '' : '${m.era} · ${m.emotion}', style: _mono(10, _teal2, spacing: 2)),
              const SizedBox(height: 8),
              Text(m?.name ?? '', style: _serif(26, _cream)),
              const SizedBox(height: 16),
              Text(m?.story ?? '', style: _serif(15, _cream2, height: 1.9)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.all(13), alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: _tealD.withOpacity(0.4)), color: _tealD.withOpacity(0.14)),
                  child: Text('▶ 다시 듣기', style: _serif(15, _teal3)),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => sheetId = null),
                  child: Container(
                    padding: const EdgeInsets.all(13), alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), color: Colors.white.withOpacity(0.06)),
                    child: Text('닫기', style: _serif(15, _cream)),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ── 레이더 파생값 묶음 ──
class _RadarVals {
  final double dist, t, prox;
  final bool near;
  final double angle, dx, dy;
  final String bearing, chip;
  _RadarVals(this.dist, this.t, this.prox, this.near, this.angle, this.dx, this.dy, this.bearing, this.chip);
}

/// 근접 시 붉게 맥동하는 CTA 버튼.
class _AnimatedGlowButton extends StatelessWidget {
  final VoidCallback onTap;
  final Animation<double> clock;
  final double time;
  const _AnimatedGlowButton({required this.onTap, required this.clock, required this.time});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (_, __) {
        final g = (math.sin(time / 1.9 * math.pi * 2) + 1) / 2;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(15), alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD15848), _red]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: _red.withOpacity(0.25 + 0.45 * g), blurRadius: 22 + 12 * g, offset: const Offset(0, 6))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('카메라를 들어보세요', style: _serif(16, const Color(0xFFFFF8F2), spacing: 1)),
            ]),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════
// CustomPainters
// ════════════════════════════════════════════════════════

/// 밤 지도 안개길 + 혼불 길.
class _MapPathPainter extends CustomPainter {
  final bool codex;
  const _MapPathPainter({this.codex = false});
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    double x(double p) => w * p / 400;
    double y(double p) => h * p / 800;
    void curve(List<Offset> pts, Color color, double sw) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i + 2 < pts.length; i += 3) {
        path.cubicTo(pts[i].dx, pts[i].dy, pts[i + 1].dx, pts[i + 1].dy, pts[i + 2].dx, pts[i + 2].dy);
      }
      final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round;
      c.drawPath(path, paint);
    }

    // 안개 등고선
    curve([Offset(x(-20), y(210)), Offset(x(90), y(170)), Offset(x(150), y(250)), Offset(x(250), y(210)), Offset(x(350), y(190)), Offset(x(430), y(240)), Offset(x(440), y(200))], _tealD.withOpacity(0.14), 1);
    curve([Offset(x(-20), y(300)), Offset(x(110), y(260)), Offset(x(170), y(330)), Offset(x(260), y(290)), Offset(x(350), y(270)), Offset(x(430), y(320)), Offset(x(440), y(280))], _tealD.withOpacity(0.10), 1);
    curve([Offset(x(-20), y(470)), Offset(x(90), y(440)), Offset(x(200), y(500)), Offset(x(300), y(460)), Offset(x(380), y(440)), Offset(x(430), y(480)), Offset(x(440), y(450))], _tealD.withOpacity(0.09), 1);
    // 혼불 길(두꺼운 청록 + 얇은 시안)
    final road = [Offset(x(70), y(-20)), Offset(x(110), y(140)), Offset(x(40), y(260)), Offset(x(130), y(380)), Offset(x(180), y(500)), Offset(x(210), y(560)), Offset(x(150), y(820))];
    curve(road, _tealD.withOpacity(codex ? 0.2 : 0.22), 7);
    if (!codex) curve(road, _ice.withOpacity(0.10), 2.5);
  }

  @override
  bool shouldRepaint(covariant _MapPathPainter old) => old.codex != codex;
}

/// 레이더 스윕(원뿔형 그라디언트).
class _SweepPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    final shader = SweepGradient(
      startAngle: 0, endAngle: 2 * math.pi,
      colors: [_tealD.withOpacity(0), _tealD.withOpacity(0), _tealD.withOpacity(0.22), _ice.withOpacity(0.5)],
      stops: const [0, 0.82, 0.978, 1.0],
    ).createShader(rect);
    c.drawCircle(s.center(Offset.zero), s.width / 2, Paint()..shader = shader);
  }
  @override
  bool shouldRepaint(_) => false;
}

/// 화살촉.
class _ArrowHeadPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFFBFEFFF)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);
    c.drawPath(Path()..moveTo(s.width / 2, 0)..lineTo(0, s.height)..lineTo(s.width, s.height)..close(), p);
  }
  @override
  bool shouldRepaint(_) => false;
}

/// AR 레티클(모서리 4개).
class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = _ice.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 2;
    const l = 30.0;
    // 좌상
    c.drawLine(const Offset(0, 0), const Offset(l, 0), p);
    c.drawLine(const Offset(0, 0), const Offset(0, l), p);
    // 우상
    c.drawLine(Offset(s.width, 0), Offset(s.width - l, 0), p);
    c.drawLine(Offset(s.width, 0), Offset(s.width, l), p);
    // 좌하
    c.drawLine(Offset(0, s.height), Offset(l, s.height), p);
    c.drawLine(Offset(0, s.height), Offset(0, s.height - l), p);
    // 우하
    c.drawLine(Offset(s.width, s.height), Offset(s.width - l, s.height), p);
    c.drawLine(Offset(s.width, s.height), Offset(s.width, s.height - l), p);
  }
  @override
  bool shouldRepaint(_) => false;
}
