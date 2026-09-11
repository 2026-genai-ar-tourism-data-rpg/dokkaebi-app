// ============================================================
// [v1] 화면: 설정 — 프로필 탭에서 분리된 별도 페이지.
// 구현(요약): 앱 설정 열기(LocationService.openSettings 재사용) · 전체 진행
//            초기화(ScenarioStore.resetAll) · 앱 정보(package_info_plus).
//            profile_screen.dart의 아코디언 버전을 대체 — 사용자가 토글 대신
//            새 페이지로 열리길 원함.
// 구현일: 2026-09-01 | 작성: ljs (profile-tab/ljs/v1)
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../debug_flags.dart';
import '../game/location_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlowCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _row(
                  icon: Icons.my_location,
                  label: '위치 권한 설정',
                  onTap: () => _openLocationSettings(context),
                ),
                const Divider(height: 1, color: AppColors.border),
                _row(
                  icon: Icons.restart_alt,
                  label: '전체 진행 초기화',
                  onTap: () => _resetAll(context),
                ),
                const Divider(height: 1, color: AppColors.border),
                _row(
                  icon: Icons.info_outline,
                  label: '앱 정보',
                  trailing: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) => Text(
                      snapshot.hasData ? 'v${snapshot.data!.version}' : '',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ),
              ]),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              const _DevOptions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
          trailing ?? const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }

  // iOS는 앱 일반 설정 페이지까지만 열어줘서(권한 개별 행 딥링크 불가 — OS 제약),
  // 넘어가기 전에 어디를 눌러야 하는지 미리 안내한다.
  Future<void> _openLocationSettings(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('위치 권한 설정', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('설정 앱 → Dokkaebi App → 위치에서 권한을 바꿀 수 있어요.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('설정 앱 열기', style: TextStyle(color: AppColors.teal))),
        ],
      ),
    );
    if (proceed != true) return;
    await const LocationService().openSettings();
  }

  Future<void> _resetAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('전체 진행 초기화', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('내가 만든 모든 코스와 진행 상황이 전부 삭제됩니다. 계속할까요?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('초기화', style: TextStyle(color: AppColors.vermilion))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ScenarioStore.I.resetAll();
  }
}

/// 디버그 빌드에서만 보이는 개발자 옵션 — 릴리즈 빌드에는 이 위젯 자체가 트리에서 빠진다.
class _DevOptions extends StatefulWidget {
  const _DevOptions();
  @override
  State<_DevOptions> createState() => _DevOptionsState();
}

class _DevOptionsState extends State<_DevOptions> {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 8),
        child: Text('개발자 옵션', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ),
      GlowCard(
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            const Expanded(
              child: Text('GPS 인증 건너뛰기 (테스트용)',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ),
            Switch(
              value: DebugFlags.skipGpsVerify,
              onChanged: (v) => setState(() => DebugFlags.skipGpsVerify = v),
            ),
          ]),
        ),
      ),
    ]);
  }
}
