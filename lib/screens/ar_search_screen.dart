// ============================================================
// [v1] 화면: AR 탐색 (시안 4) — QUEST_ACTIVE, 기억석 조각 수집
// pipeline: 모바일 클라이언트 / 화면 (대화 힌트 → AR로 찾기)
// 구현(요약): 카메라 위 AR 마커(기억석·도깨비) + 힌트/스캔/NPC 토글 + 조각 진행.
//            스캔 → 마커 등장 → 기억석 탭 → 수집(pop true).
//            ⚠️ 실제 AR(카메라·평면인식·3D)은 TODO(정찬희, ar_flutter_plugin + 실기기).
// 구현일: 2026-06-19 | 작성: kys (rpg-dialogue/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';

class ArSearchScreen extends StatefulWidget {
  final String placeName;
  final String order; // 도깨비 지령
  final List<String> hints; // 단계 힌트(방탈출)
  final int collected; // 진행: 이미 모은 조각 수
  final int total;
  const ArSearchScreen(
      {super.key, this.placeName = '', this.order = '', this.hints = const [], this.collected = 0, this.total = 5});
  @override
  State<ArSearchScreen> createState() => _ArSearchScreenState();
}

class _ArSearchScreenState extends State<ArSearchScreen> with SingleTickerProviderStateMixin {
  String _mode = 'scan'; // hint | scan | npc
  bool _scanned = false;
  int _hintShown = 1; // 방탈출: 처음 1개만, "다음 힌트"로 단계 노출
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

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
        // 카메라 placeholder
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

        // 스캔 모드: 마커
        if (_mode == 'scan' && _scanned) ...[
          _marker(0.30, 0.40, AppColors.teal, Icons.diamond, '기억석 조각', onTap: () => Navigator.pop(context, true)),
          _marker(0.68, 0.55, AppColors.purple, Icons.local_fire_department, '도깨비', onTap: () => setState(() => _mode = 'npc')),
        ],
        if (_mode == 'scan' && !_scanned)
          const Center(child: Text('아래 "스캔"으로 주변을 살펴보세요',
              style: TextStyle(color: Colors.white54))),

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
