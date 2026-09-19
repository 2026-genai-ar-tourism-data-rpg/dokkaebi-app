// ============================================================
// [v1] 화면: 로그인 (게스트)
// pipeline: 모바일 클라이언트 / 인증
// 구현(요약): 닉네임 입력 → 서버 게스트 로그인(토큰) → 세션 저장 → 메인.
//            디버그 빌드에선 접속 중인 서버 주소를 화면에 노출(실기기 진단).
//            카카오/구글은 같은 화면에 버튼 추가 예정(키 발급 후).
// 구현일: 2026-06-18 (서버주소 진단 배너: 2026-08-04) | 작성: kys (auth-guest/kys/v1)
// ------------------------------------------------------------
// [v2] 이메일 로그인/회원가입 추가 — 게스트는 매번 새 계정이라 다시 로그인해도
//      이전 진행도로 이어지지 않았다. Supabase Auth로 신원을 증명하면 서버가
//      같은 user_id를 재발급한다(api_client.supabaseLogin). 회원가입은 이메일
//      확인이 끝나야 세션이 생기므로(Supabase 기본 설정) 그 경우 안내만 하고
//      로그인은 확인 후 별도로 하게 한다.
// 구현일: 2026-09-17 | 작성: jch
// ------------------------------------------------------------
// [v3] 카카오·네이버 로그인 추가(둘 다 Supabase OAuth — 카카오는 기본 제공
//      provider, 네이버는 Custom OAuth2 provider `custom:naver`). 모바일
//      OAuth는 브라우저로 나갔다 딥링크로 돌아오는 구조라 결과를 바로 받지
//      못한다 — signInWithOAuth 호출 자체는 브라우저를 여는 것뿐이고, 실제
//      로그인 완료는 onAuthStateChange 리스너로 받는다(SDK 문서 권장 패턴).
//      그래서 이메일 로그인 성공 처리도 이 리스너로 합쳐 경로를 하나로 뒀다
//      (안 그러면 이메일은 직접 처리 + OAuth는 리스너, 두 경로가 같은
//      supabaseLogin을 중복 호출할 수 있었다).
//      두 provider 다 Supabase 대시보드에 client id/secret을 등록해야 실제로
//      동작한다 — 코드만으로는 안 됨(README나 PR 설명 참고).
// 구현일: 2026-09-17 | 작성: jch
// ------------------------------------------------------------
// [v4] 인증 오류 메시지 정리 + Apple 로그인 추가 (App Store 심사 반려 조치).
// 구현(요약): ① 모든 오류 화면 표시가 '$e'로 예외를 그대로 찍고 있었다 — 리뷰어가
//            회원가입 중 겪은 AuthApiException(email rate limit exceeded, 429,
//            over_email_send_rate_limit)도 원문 그대로 노출됐다(Guideline 2.1(a)
//            반려 사유). authErrorMessage로 원인별 한국어 안내로 바꾸고, 원문은
//            debugPrint로만 남긴다.
//            ② Apple 로그인 버튼 추가(Guideline 4.8 반려 사유 — 서드파티 로그인은
//            있는데 동등 요건을 만족하는 로그인이 없다고 지적받음). 카카오·네이버와
//            같은 방식으로 signInWithIdToken 후 onAuthStateChange 리스너가 마무리한다.
//            ⚠️ 이 버튼은 Apple Developer에서 App ID에 Sign In with Apple capability를
//            켜고 프로비저닝 프로파일을 다시 받은 뒤, iOS 쪽 entitlements를 붙여야
//            실제로 동작한다(그 전엔 무해하게 실패만 한다) — 코드만으로는 안 됨.
//            Supabase 대시보드의 Apple provider도 별도로 켜야 한다(Client ID=Services ID,
//            Team ID, Key ID, .p8 키 — Apple Developer에서만 발급 가능).
// 구현일: 2026-09-19 | 작성: Claude
// ------------------------------------------------------------
// [v5] 카카오·네이버·Apple 로그인 전부 제거 — 이메일+게스트만 남긴다.
// 구현(요약): 실기기 확인 결과 카카오(KOE205)·네이버 둘 다 "서비스 설정 오류"로
//            로그인 자체가 안 되고 있었다(redirect/callback URL이 카카오·네이버
//            개발자 콘솔에 등록 안 된 것으로 추정 — 그쪽 계정에서만 고칠 수 있다).
//            Guideline 4.8은 "서드파티/소셜 로그인 서비스"가 있을 때만 적용된다.
//            이메일+비밀번호는 외부 업체를 거치지 않고 사용자가 직접 우리 앱에
//            입력하는 것이라 이 조항 대상이 아니고, 게스트도 외부 서비스가
//            없어 마찬가지다. 그래서 카카오·네이버·Apple을 전부 빼면 4.8 자체가
//            적용 대상에서 빠진다 — [v4]에서 추가했던 Apple 로그인(코드는 동작
//            준비까지 됐지만 Apple Developer·Supabase 쪽 계정 설정이 남아있던
//            상태)도 더 이상 필요 없어 함께 제거한다.
// 구현일: 2026-09-19 | 작성: Claude
// ------------------------------------------------------------
// [v6] 이메일 로그인/회원가입도 제거 — 게스트만 남긴다(팀 결정, 심사 제출용).
// 구현(요약): rate limit 크래시([v4])는 Supabase "Confirm email" 끄기로 이미
//            실증까지 마쳤지만("게스트만" 쪽이 여기서 조금 더 안전하니 심사
//            통과·출시부터 확실히 하고 이메일 로그인은 출시 후 다시 켜기로 했다.
//            게스트 로그인(_api.guestLogin)은 Supabase를 아예 거치지 않는
//            별개 경로라 이번 rate limit 문제와 원래도 무관했다.
//            이 파일만 되돌리면 이메일 로그인이 복원된다 — 로직 자체는
//            git 히스토리([v2]~[v5] 커밋)에 그대로 남아 있다.
//            authErrorMessage는 남긴다: 원인이 Supabase든 서버(ApiException)든
//            "원본 예외를 화면에 그대로 보여주지 않는다"는 원칙 자체가 심사
//            지적사항이라 게스트 로그인 오류에도 적용해야 한다 — 다만 이제
//            Supabase 예외는 이 화면에서 안 나므로 ApiException.message
//            (서버가 애초에 사용자용으로 보낸 문구)를 우선 보여주는 쪽으로 바꿨다.
// 구현일: 2026-09-19 | 작성: Claude
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../main.dart' show MainShell;
import '../store.dart';
import '../theme.dart';

/// 오류를 사용자에게 보여줄 메시지로 바꾼다 — 원본 예외를 절대 그대로 노출하지
/// 않는다(Apple 심사에서 "버그"로 지적받았다). ApiException.message는 서버가
/// 애초에 사용자용으로 보내는 문구라 그대로 쓰고, 그 외 예외는 로그로만 남긴다.
String authErrorMessage(Object e) {
  if (e is ApiException && e.message.isNotEmpty) return e.message;
  debugPrint('로그인 오류: $e');
  return '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// 디버그 전용 — 지금 어느 서버로 붙는지 화면에 보여준다.
/// 실기기에서 localhost로 남아 있으면(= 폰 자신을 가리킴) 연결이 절대 안 되므로
/// "왜 안 되지"로 시간 날리지 않게 경고까지 띄운다.
class _ServerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bad = AppConfig.isLoopback &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            bad ? Colors.red.withOpacity(0.12) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: bad ? Colors.red.withOpacity(0.5) : Colors.white24),
      ),
      child: Column(children: [
        Text('서버: ${AppConfig.serverBaseUrl}',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: bad ? Colors.red.shade200 : AppColors.textSecondary,
                fontSize: 11)),
        if (bad) ...[
          const SizedBox(height: 4),
          const Text(
            '실기기에서 localhost는 폰 자신을 가리킵니다.\n'
            '--dart-define=SERVER_BASE_URL=http://<PC_IP>:8000 으로 실행하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent, fontSize: 10),
          ),
        ],
      ]),
    );
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = ApiClient();
  final _nick = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  /// 로그인 성공 후 공통 처리.
  Future<void> _afterLogin() async {
    await ScenarioStore.I.load(); // 이 유저의 저장된 탐험 복원
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  Future<void> _guest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api
          .guestLogin(_nick.text.trim().isEmpty ? '탐험가' : _nick.text.trim());
      await _afterLogin();
    } catch (e) {
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // 화면이 좁으면 스크롤되게 하고, 넉넉하면 기존처럼 중앙 정렬.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 기억석 글로우
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        margin: const EdgeInsets.only(bottom: 28),
                        child: Transform.rotate(
                          angle: 0.785,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [AppColors.teal, AppColors.blue]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.teal.withOpacity(0.5),
                                    blurRadius: 32,
                                    spreadRadius: 2)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text('도깨비: 팔도의 비밀',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('이름을 정하고 탐사를 시작하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _nick,
                      textAlign: TextAlign.center,
                      decoration:
                          const InputDecoration(hintText: '닉네임 (예: 지민)'),
                      onSubmitted: (_) => _guest(),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _guest,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('게스트로 시작'),
                    ),
                    const SizedBox(height: 8),
                    const Text('게스트는 앱을 지우거나 로그아웃하면 진행도가 사라집니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      _ServerBanner(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
