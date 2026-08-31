// ============================================================
// [v7] 설정 아코디언 → 별도 페이지(SettingsScreen)로 이동.
// 구현(요약): "설정" 한 줄을 펼쳐서 보여주던 방식을 접고, 탭하면
//            settings_screen.dart로 push하는 방식으로 변경(사용자 요청 —
//            토글 대신 새 페이지). 앱 설정 열기·전체 초기화·앱 정보 로직은
//            그대로 SettingsScreen으로 옮김. StatefulWidget이던 것도 펼침
//            상태가 필요 없어져 다시 StatelessWidget으로.
// 구현일: 2026-09-01 | 작성: ljs (profile-tab/ljs/v1)
// ------------------------------------------------------------
// [v6] 설정 3항목을 개별 카드 나열 → "설정" 한 줄을 펼치면 나오는 아코디언으로.
// 구현(요약): StatelessWidget → StatefulWidget 전환(펼침 상태 _settingsOpen
//            보관). 기능·데이터는 v5와 동일, 표시 방식만 변경.
// 구현일: 2026-09-01 | 작성: ljs (profile-tab/ljs/v1)
// ------------------------------------------------------------
// [v5] 설정 3항목 실연결 — 앱 설정 열기·전체 초기화·앱 버전.
// 구현(요약): "설정 (준비 중)" 문구를 실제 동작하는 3개 행으로 교체. 앱 설정
//            열기는 지도·위치인증 화면과 같은 LocationService.openSettings()
//            재사용(정확히는 OS "위치" 설정이 아니라 앱 설정 페이지 — Geolocator
//            API 한계). 전체 초기화는 ScenarioStore.resetAll() 신규 추가(기존
//            per-scenario resetProgress/remove와 같은 clear-후-persist 패턴).
//            앱 버전은 package_info_plus 신규 의존성 추가. 알림·사운드·테마·
//            언어는 저장 인프라 자체가 없어 여전히 제외(로그인 정보와 함께
//            사용자와 확인 후 범위 확정).
// 구현일: 2026-09-01 | 작성: ljs (profile-tab/ljs/v1)
// ------------------------------------------------------------
// [v4] 로그인 정보 실연결 — 닉네임·로그아웃.
// 구현(요약): 하드코딩 "용사님" → Session.nickname(로그인 시 서버가 내려준 실제
//            값). Session.clear()는 있었지만 아무 데서도 안 부르던 죽은 함수라
//            로그아웃 버튼으로 연결(확인 다이얼로그 후 온보딩으로 이동 —
//            main.dart가 Session을 앱 시작 시 1회만 보는 비반응형 구조라
//            pushAndRemoveUntil로 직접 네비게이션 필요).
// 구현일: 2026-09-01 | 작성: ljs (profile-tab/ljs/v1)
// ------------------------------------------------------------
// [v3] 탐사 등급·칭호 UI 제거.
// 구현(요약): "탐사 등급 17 · 종로의 기억 복원자" 서브텍스트와 칭호 StatTile('5')
//            제거 — PlayerState 등 어디에도 등급·칭호 개념 자체가 없어 연결할
//            데이터가 없다(v2 주석에 이미 명시했던 데이터 갭).
// 구현일: 2026-09-01 | 작성: ljs (profile-tab/ljs/v1)
// ------------------------------------------------------------
// [v2] 도감·방문률을 실제 데이터로 연결.
// 구현(요약): 도감 개수는 ScenarioStore.metDokkaebi() 재사용(전체 수 없어 개수만
//            표시). 방문률은 "전체 방문 가능 장소"라는 고정 분모가 없어, 내가
//            만든 모든 코스의 (완료 조각 합)/(전체 조각 합)으로 계산
//            (ScenarioStore.visitRate). ⚠️ 닉네임·탐사 등급·칭호는 여전히
//            placeholder — 소스 필드 없음.
// 구현일: 2026-09-01 | 작성: ljs (profile-tab/ljs/v1)
// ------------------------------------------------------------
// [v1] 화면: 프로필 — 탭 골격
// pipeline: 모바일 클라이언트 / 화면 (프로필 탭)
// 구현(요약): 헤더 + 유저 요약 placeholder. 인증·도감률·방문률은 TODO(이지선/정찬희).
// 구현일: 2026-06-18 | 작성: kys (app-theme/kys/v1)
// ============================================================
import 'package:flutter/material.dart';

import '../session.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ScenarioStore.I,
      builder: (context, _) {
        // 전체 도깨비 수가 정해지지 않아 "N/전체" 형식 대신 수집한 수만 표시.
        final metCount = ScenarioStore.I.metDokkaebi().length;
        // "전체 방문 가능 장소" 분모가 없어, 내가 만든 코스 기준 조각 완료율로 계산.
        final visitPct = (ScenarioStore.I.visitRate * 100).round();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader('PROFILE', '내 정보'),
            const SizedBox(height: 16),
            GlowCard(
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.teal.withOpacity(0.18),
                  child: const Icon(Icons.person, color: AppColors.teal),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(Session.nickname ?? '용사님',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              StatTile(Icons.place_outlined, '$visitPct%', '방문률', AppColors.teal),
              const SizedBox(width: 10),
              StatTile(Icons.menu_book_outlined, '$metCount', '도감', AppColors.purple),
            ]),
            const SizedBox(height: 12),
            GlowCard(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: const Row(children: [
                Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 18),
                SizedBox(width: 10),
                Expanded(
                    child: Text('설정',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ]),
            ),
            const SizedBox(height: 12),
            GlowCard(
              glow: AppColors.vermilion,
              onTap: () => _logout(context),
              child: const Row(children: [
                Icon(Icons.logout, color: AppColors.vermilion, size: 18),
                SizedBox(width: 8),
                Text('로그아웃',
                    style: TextStyle(color: AppColors.vermilion, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('로그아웃', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('로그아웃하시겠어요?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('로그아웃', style: TextStyle(color: AppColors.vermilion))),
        ],
      ),
    );
    if (confirmed != true) return;
    await Session.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }
}
