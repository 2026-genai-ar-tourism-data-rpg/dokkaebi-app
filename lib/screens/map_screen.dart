// ============================================================
// [v1] 화면: 팔도 지도 (시안 7)
// pipeline: 모바일 클라이언트 / 화면 (지도 탭)
// 구현(요약): 스타일 지도(그리드 배경 + 지역 핀: 등급색·잠금) + 필터 + 지역 진행 카드.
//            ⚠️ 실제 지리 지도(타일·GPS 핀)는 TODO(정찬희, flutter_map). 지금은 시안 스타일 재현.
// 구현일: 2026-06-19 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';
import 'create_scenario_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _filter = 0;
  static const _filters = ['전체', '전설', '영웅', '희귀'];

  // (지역명, 등급, x비율, y비율, 잠금)
  static const _pins = [
    ('서울', '전설', 0.42, 0.22, false),
    ('안동', '영웅', 0.62, 0.34, false),
    ('전주', '희귀', 0.34, 0.55, false),
    ('경주', '영웅', 0.68, 0.55, false),
    ('부산', '일반', 0.62, 0.74, true),
    ('제주', '일반', 0.30, 0.90, true),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader('WORLD MAP', '팔도 지도',
            trailing: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.my_location, size: 16, color: AppColors.teal),
              label: const Text('현재 위치', style: TextStyle(color: AppColors.teal, fontSize: 12)),
            )),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (var i = 0; i < _filters.length; i++)
            Pill(_filters[i], active: _filter == i, onTap: () => setState(() => _filter = i)),
        ]),
        const SizedBox(height: 16),
        // 지도 영역 (그리드 + 핀)
        AspectRatio(
          aspectRatio: 0.92,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C1322),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(children: [
              ..._pins.map((p) => _pin(p)),
              // 범례
              Positioned(
                right: 12, bottom: 12,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  _Legend('전설', AppColors.gold),
                  _Legend('영웅', AppColors.purple),
                  _Legend('희귀', AppColors.blue),
                  _Legend('일반', AppColors.textSecondary),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // 지역 진행 카드
        GlowCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: const [
              Text('서울', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Text('Seoul · 퀘스트 12개', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Spacer(),
              Text('68%', style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 10),
            const ProgressBar(0.68, color: AppColors.teal),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const CreateScenarioScreen())),
              child: const Text('이 지역 탐험하기  →'),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _pin((String, String, double, double, bool) p) {
    final c = p.$5 ? AppColors.textSecondary : tierColor(p.$2);
    // 분수 좌표(0..1) → Alignment(-1..1). Align은 Stack 직속으로 안전.
    return Align(
      alignment: Alignment(p.$3 * 2 - 1, p.$4 * 2 - 1),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: c.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: c),
            boxShadow: p.$5 ? null : [BoxShadow(color: c.withOpacity(0.4), blurRadius: 14)],
          ),
          child: Icon(p.$5 ? Icons.lock : Icons.location_on, color: c, size: 20),
        ),
        const SizedBox(height: 2),
        Text(p.$1, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
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
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ]),
      );
}
