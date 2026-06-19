// ============================================================
// [v1] 화면: AR 탐색 (시안 4) — QUEST_ACTIVE, 기억석 조각 수집
// pipeline: 모바일 클라이언트 / 화면 (대화 힌트 → AR로 찾기)
// 구현(요약): 카메라(placeholder) 위 숨은 기억석 오브젝트를 스캔→탭하여 수집(FIND_OBJECT).
//            ⚠️ 실제 AR(카메라·평면인식·3D)은 TODO(정찬희, ar_flutter_plugin + 실기기).
//            지금은 흐름·연출 stub: 스캔 → 오브젝트 등장 → 탭 → 수집(pop true).
// 구현일: 2026-06-19 | 작성: kys (rpg-dialogue/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';

class ArSearchScreen extends StatefulWidget {
  final String placeName;
  final String hint;
  const ArSearchScreen({super.key, this.placeName = '', this.hint = ''});
  @override
  State<ArSearchScreen> createState() => _ArSearchScreenState();
}

class _ArSearchScreenState extends State<ArSearchScreen> with SingleTickerProviderStateMixin {
  bool _scanned = false; // 스캔 후 오브젝트 등장
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
      body: Stack(
        children: [
          // 카메라 placeholder (실제 카메라 = 정찬희)
          Container(
            color: const Color(0xFF0A0E16),
            child: const Center(
              child: Icon(Icons.camera_alt_outlined, color: Colors.white12, size: 80),
            ),
          ),
          // 상단 힌트
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.hint.isEmpty ? '도깨비의 힌트를 떠올리며 주변을 살펴보세요.' : widget.hint,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
          // 스캔 후 등장하는 기억석 오브젝트 (탭하여 수집)
          if (_scanned)
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.1).animate(_ac),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.teal, AppColors.blue]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.6), blurRadius: 36, spreadRadius: 6)],
                      ),
                      child: Transform.rotate(angle: 0.785, child: const SizedBox()),
                    ),
                    const SizedBox(height: 16),
                    const Text('탭하여 기억석 조각 수집',
                        style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
          // 하단 스캔 버튼
          if (!_scanned)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: FilledButton.icon(
                  onPressed: () => setState(() => _scanned = true),
                  icon: const Icon(Icons.radar),
                  label: const Text('주변 스캔'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
