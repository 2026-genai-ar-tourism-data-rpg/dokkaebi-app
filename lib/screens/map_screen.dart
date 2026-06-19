// ============================================================
// [v1] 화면: 팔도 지도 (시안 7번) — 탭 골격
// pipeline: 모바일 클라이언트 / 화면 (지도 탭)
// 구현(요약): 헤더 + placeholder. 실제 지도(핀·동선)는 TODO(정찬희, flutter_map).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/ui.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('WORLD MAP', '팔도 지도'),
          const SizedBox(height: 16),
          Expanded(
            child: GlowCard(
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, color: AppColors.teal, size: 40),
                    SizedBox(height: 12),
                    Text('지도 (준비 중)', style: TextStyle(color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('지역 핀·동선 = flutter_map 연동 예정',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
