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
// ============================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../main.dart' show MainShell;
import '../store.dart';
import '../theme.dart';

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
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _notice; // 오류는 아니지만 알려줘야 하는 것(이메일 확인 요청 등)
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // OAuth(카카오·네이버)는 브라우저 왕복 후 이 이벤트로만 결과를 알 수 있다.
    // 이메일 로그인 성공도 여기로 합쳐서 처리 경로를 하나로 유지한다.
    // Supabase.initialize()가 실패했으면(main.dart에서 실패해도 앱은 계속 띄움 —
    // 카카오맵 init과 같은 원칙) Supabase.instance 접근 자체가 던진다 — 그래도
    // 게스트 로그인은 계속 동작해야 하므로 여기서 막는다.
    try {
      _authSub =
          Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn && state.session != null) {
          _onSupabaseSignedIn(state.session!.accessToken);
        }
      });
    } catch (e) {
      debugPrint('Supabase auth 리스너 등록 실패 — 이메일/OAuth 로그인만 비활성: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nick.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 로그인 성공 후 공통 처리 — 게스트·이메일·OAuth 로그인 모두 여기로 모인다.
  Future<void> _afterLogin() async {
    await ScenarioStore.I.load(); // 이 유저의 저장된 탐험 복원
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  /// Supabase 세션이 생긴 뒤(이메일 로그인 또는 OAuth 딥링크 복귀) 공통 처리.
  Future<void> _onSupabaseSignedIn(String accessToken) async {
    if (_loading) return; // 이미 처리 중이면 중복 이벤트 무시
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.supabaseLogin(accessToken, nickname: _nick.text.trim());
      await _afterLogin();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guest() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await _api
          .guestLogin(_nick.text.trim().isEmpty ? '탐험가' : _nick.text.trim());
      await _afterLogin();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSubmitEmail =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  /// 로그인 자체의 성공 처리는 _onSupabaseSignedIn(리스너)이 한다 — 여기서는
  /// 잘못된 비밀번호 등 signInWithPassword가 직접 던지는 오류만 잡는다.
  Future<void> _emailSignIn() async {
    if (!_canSubmitEmail) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _emailSignUp() async {
    if (!_canSubmitEmail) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      // 이메일 확인이 켜져 있으면(기본값) 가입 직후엔 세션이 없다 — 그 경우만
      // 여기서 안내하고, 세션이 바로 생기는 경우는 _onSupabaseSignedIn이 처리한다.
      if (res.session == null) {
        setState(() => _notice = '확인 이메일을 보냈습니다. 메일의 링크를 연 뒤 로그인해 주세요.');
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 카카오·네이버 등 OAuth 로그인 — 브라우저를 열 뿐, 로그인 완료는
  /// onAuthStateChange 리스너(_onSupabaseSignedIn)로 비동기로 온다.
  Future<void> _oauthSignIn(OAuthProvider provider) async {
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: AppConfig.oauthRedirectUrl,
      );
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // 이메일 로그인 필드·버튼이 늘어나면서 작은 화면(iPhone SE 등)에서
        // 오버플로가 났다 — 화면이 좁으면 스크롤되게 하고, 넉넉하면 기존처럼 중앙 정렬.
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
                    if (_notice != null)
                      Text(_notice!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.teal, fontSize: 12)),
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
                    const SizedBox(height: 24),
                    Row(children: const [
                      Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('또는 이메일로 이어하기',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ),
                      Expanded(child: Divider(color: Colors.white24)),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: '이메일'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      textAlign: TextAlign.center,
                      obscureText: true,
                      decoration:
                          const InputDecoration(hintText: '비밀번호 (6자 이상)'),
                      onSubmitted: (_) => _emailSignIn(),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading || !_canSubmitEmail
                              ? null
                              : _emailSignIn,
                          child: const Text('로그인'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading || !_canSubmitEmail
                              ? null
                              : _emailSignUp,
                          child: const Text('회원가입'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _oauthSignIn(OAuthProvider.kakao),
                      child: const Text('카카오로 로그인'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () =>
                              _oauthSignIn(const OAuthProvider('custom:naver')),
                      child: const Text('네이버로 로그인'),
                    ),
                    const SizedBox(height: 8),
                    const Text('구글 로그인 (준비 중)',
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
