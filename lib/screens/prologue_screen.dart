// ============================================================
// [v1] 화면: 프롤로그 — 도깨비눈이 열린 날 (종로 MVP)
// pipeline: 모바일 클라이언트 / 프롤로그 컷신
// 구현(요약): 로그인 직후 1회만 노출되는 비주얼노벨식 대사 진행(탭하여 계속).
//            초롱 도깨비 NPC는 별도 이미지 에셋 없이 벡터로 구성 —
//            참고 이미지의 청록 피부·홍색 한복·금 장식을 코드로 재현.
// 구현일: 2026-08-04 | 작성: Claude
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scenario.dart';
import '../session.dart';
import '../theme.dart';
import 'scenario_screen.dart';

enum _Speaker { narration, npc, player, beat }

/// 대사 대신 자동 재생되는 연출 컷 — 플레이어 행동 묘사를 텍스트 대신 화면 연출로 대체.
enum _Beat { reach, reveal, recoil, longing }

class _Line {
  final _Speaker speaker;
  final String text;
  final _Beat? beat;
  const _Line(this.speaker, this.text, {this.beat});
}

class PrologueScreen extends StatefulWidget {
  final Scenario scenario;
  const PrologueScreen({super.key, required this.scenario});
  @override
  State<PrologueScreen> createState() => _PrologueScreenState();
}

class _PrologueScreenState extends State<PrologueScreen> {
  int _i = 0;

  static const _npcEntersAt = 12;

  static const _lines = <_Line>[
    _Line(_Speaker.narration, '{name}는 종로를 지나던 평범한 사람이다.'),
    _Line(_Speaker.narration, '오래된 골목길을 걷던 중, 낡은 담장 아래에서 희미하게 흔들리는 푸른빛을 발견한다.'),
    _Line(_Speaker.narration, '처음에는 누군가 떨어뜨린 조명이나 반사광이라고 생각한다.'),
    _Line(_Speaker.narration,
        '하지만 빛은 가까이 다가갈수록 점점 또렷해지고, 마치 살아 있는 것처럼 골목 안쪽으로 흘러간다.'),
    _Line(_Speaker.beat, '', beat: _Beat.reach),
    _Line(_Speaker.narration, '사람들의 발걸음은 느려지고, 익숙하던 거리는 낯선 모습으로 바뀐다.'),
    _Line(_Speaker.beat, '', beat: _Beat.reveal),
    _Line(_Speaker.narration, '오래된 처마 밑에 웅크린 작은 도깨비. 깨진 돌 조각 주변을 맴도는 푸른 불씨.'),
    _Line(_Speaker.narration, '검은 안개에 휘감겨 힘없이 떠도는 도깨비 영혼들.'),
    _Line(_Speaker.narration, '그들은 무언가를 잃어버린 듯 같은 자리를 맴돌고 있다.'),
    _Line(_Speaker.narration, '몇몇은 망각귀에게 당해 이름도, 자신이 지키던 장소도 잊어가고 있다.'),
    _Line(_Speaker.beat, '', beat: _Beat.recoil),
    _Line(_Speaker.narration, '그때, 작은 초롱을 든 도깨비 하나가 {name} 앞에 나타난다.'),
    _Line(_Speaker.npc, '드디어… 우리를 볼 수 있는 인간이 나타났구나.'),
    _Line(_Speaker.player, '너희 뭐야? 왜 나한테 이런 게 보이는 거야?'),
    _Line(_Speaker.narration, '도깨비는 깨진 기억석 조각을 가리킨다.'),
    _Line(_Speaker.npc,
        '네가 본 것은 기억의 빛이니라. 망각귀가 이 땅의 기억석을 깨뜨렸고, 그 빛이 네 눈에 깃들었다. 이제 너는 인간들이 잊어버린 것들을 보게 되었느니라.'),
    _Line(_Speaker.beat, '', beat: _Beat.longing),
    _Line(_Speaker.narration, '도깨비는 잠시 침묵하다가 대답한다.'),
    _Line(_Speaker.npc,
        '돌아갈 방법은 있다. 흩어진 기억석 조각을 모아 망각귀의 봉인을 되살리면, 네 눈에 깃든 도깨비의 기운도 거두어 주마.'),
    _Line(_Speaker.narration, '그리고 도깨비는 {name}에게 첫 번째 의뢰를 건넨다.'),
    _Line(_Speaker.npc,
        '탐사자여, 두렵겠지만 우리를 도와다오. 이곳의 기억이 완전히 사라지기 전에, 첫 번째 조각을 찾아야 하느니라.'),
    _Line(_Speaker.narration, '이 순간부터 {name}는 탐사자가 된다.'),
    _Line(_Speaker.narration, '처음에는 평범한 인간으로 돌아가기 위해. 하지만 점점, 잊혀진 장소의 기억을 되살리기 위해.'),
  ];

  bool get _npcVisible => _i >= _npcEntersAt;
  bool get _last => _i == _lines.length - 1;

  void _next() {
    if (_last) {
      _finish();
      return;
    }
    setState(() => _i++);
  }

  void _back() {
    if (_i > 0) setState(() => _i--);
  }

  Future<void> _finish() async {
    await Session.markPrologueSeen();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ScenarioScreen(scenario: widget.scenario)));
  }

  @override
  Widget build(BuildContext context) {
    final line = _lines[_i];
    final isBeat = line.speaker == _Speaker.beat;
    final Widget visual = isBeat
        ? _BeatVisual(key: ValueKey('beat_$_i'), beat: line.beat!, onDone: _next)
        : (_npcVisible
            ? const _LanternDokkaebi(key: ValueKey('npc'))
            : const _MemoryLight(key: ValueKey('light')));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _next,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Opacity(
                    opacity: _i > 0 ? 1 : 0,
                    child: IconButton(
                      onPressed: _i > 0 ? _back : null,
                      icon: const Icon(Icons.arrow_back_ios_new,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('건너뛰기',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: visual,
                  ),
                ),
              ),
              if (!isBeat) _DialogueBox(line: line),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  isBeat ? '' : (_last ? '탭해서 시작하기 ›' : '탭해서 계속 ›'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 플레이어 행동 묘사(대사) 대신 자동 재생되는 연출 컷. 재생이 끝나면 [onDone]으로 자동 진행.
/// 탭하면(화면 전체 GestureDetector) 애니메이션 위젯이 즉시 폐기되며 스킵된다.
class _BeatVisual extends StatelessWidget {
  final _Beat beat;
  final VoidCallback onDone;
  const _BeatVisual({super.key, required this.beat, required this.onDone});

  Duration get _duration {
    switch (beat) {
      case _Beat.reach:
        return const Duration(milliseconds: 1600);
      case _Beat.reveal:
        return const Duration(milliseconds: 1800);
      case _Beat.recoil:
        return const Duration(milliseconds: 1100);
      case _Beat.longing:
        return const Duration(milliseconds: 1600);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeInOut,
      onEnd: onDone,
      builder: (context, t, _) {
        switch (beat) {
          case _Beat.reach:
            return _paintReach(t);
          case _Beat.reveal:
            return _paintReveal(t);
          case _Beat.recoil:
            return _paintRecoil(t);
          case _Beat.longing:
            return _paintLonging(t);
        }
      },
    );
  }

  /// 빛에 손을 뻗는 순간 — 빛이 점점 밝고 커진다.
  Widget _paintReach(double t) {
    return Container(
      width: 90 + 50 * t,
      height: 90 + 50 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [AppColors.teal.withOpacity(0.95), Colors.transparent]),
        boxShadow: [
          BoxShadow(
              color: AppColors.teal.withOpacity(0.3 + 0.45 * t),
              blurRadius: 60 + 60 * t,
              spreadRadius: 10 + 14 * t),
        ],
      ),
    );
  }

  /// 골목 안쪽 풍경이 원형으로 열리며 드러난다(도깨비·푸른 불씨 실루엣).
  Widget _paintReveal(double t) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: (t * 2).clamp(0, 1),
            child: Container(
              width: 30 + 190 * t,
              height: 30 + 190 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.teal.withOpacity(1 - t * 0.7), width: 2),
              ),
            ),
          ),
          Opacity(
            opacity: ((t - 0.35) / 0.65).clamp(0, 1),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _wisp(20),
              const SizedBox(width: 30),
              _wisp(13),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _wisp(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.teal.withOpacity(0.85),
        boxShadow: [
          BoxShadow(color: AppColors.teal.withOpacity(0.6), blurRadius: 18, spreadRadius: 4),
        ],
      ));

  /// 겁에 질려 뒷걸음질 — 화면이 흔들리고 순간적으로 어두워진다.
  Widget _paintRecoil(double t) {
    final shake = math.sin(t * math.pi * 8) * (1 - t) * 12;
    return Transform.translate(
      offset: Offset(shake, 0),
      child: Container(
        width: 100 - 24 * t,
        height: 100 - 24 * t,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.vermilion.withOpacity(0.22 * (1 - t) + 0.06),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.55 * math.sin(t * math.pi)),
                blurRadius: 90,
                spreadRadius: 40),
          ],
        ),
      ),
    );
  }

  /// 원래대로 돌아가고 싶은 마음 — 옅은 빛이 천천히 숨쉬듯 명멸한다.
  Widget _paintLonging(double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi);
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [AppColors.textSecondary.withOpacity(pulse * 0.5), Colors.transparent]),
        boxShadow: [
          BoxShadow(
              color: AppColors.textSecondary.withOpacity(pulse * 0.3),
              blurRadius: 44,
              spreadRadius: 8),
        ],
      ),
    );
  }
}

/// 담장 아래에서 흔들리던 푸른 기억의 빛 (도깨비 등장 전).
class _MemoryLight extends StatelessWidget {
  const _MemoryLight({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [AppColors.teal.withOpacity(0.9), Colors.transparent]),
        boxShadow: [
          BoxShadow(
              color: AppColors.teal.withOpacity(0.55),
              blurRadius: 60,
              spreadRadius: 10),
        ],
      ),
    );
  }
}

/// 초롱 도깨비 — 별도 이미지 에셋 없이 벡터로 구성.
/// (참고 이미지의 청록 피부·검은 뿔·홍색 한복·금 장식을 이 앱의 기존 팔레트로 재현)
class _LanternDokkaebi extends StatelessWidget {
  const _LanternDokkaebi({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 몸(홍색 한복 + 금 테두리)
              Positioned(
                bottom: 0,
                child: Container(
                  width: 112,
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppColors.vermilion,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.gold, width: 2.5),
                  ),
                ),
              ),
              // 얼굴(청록 피부)
              Positioned(
                top: 4,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration:
                      const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                  child: Stack(
                    children: [
                      Positioned(left: 12, top: -8, child: _horn()),
                      Positioned(
                          right: 12, top: -8, child: Transform.flip(flipX: true, child: _horn())),
                      const Positioned(left: 24, top: 44, child: _Eye()),
                      const Positioned(right: 24, top: 44, child: _Eye()),
                      Positioned(left: 12, top: 64, child: _blush()),
                      Positioned(right: 12, top: 64, child: _blush()),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 68,
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 8,
                            decoration: BoxDecoration(
                                color: const Color(0xFF241C12),
                                borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 초롱(손에 든 불빛)
              Positioned(
                right: -8,
                bottom: 30,
                child: Container(
                  width: 26,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.gold.withOpacity(0.75),
                          blurRadius: 26,
                          spreadRadius: 5),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('초롱 도깨비', style: dokkaebiTitle(size: 13, color: AppColors.goldDim)),
      ],
    );
  }

  Widget _horn() => Container(
      width: 14,
      height: 26,
      decoration:
          BoxDecoration(color: const Color(0xFF2A2118), borderRadius: BorderRadius.circular(7)));

  Widget _blush() => Container(
      width: 14,
      height: 9,
      decoration: BoxDecoration(
          color: AppColors.vermilion.withOpacity(0.55), borderRadius: BorderRadius.circular(6)));
}

class _Eye extends StatelessWidget {
  const _Eye();
  @override
  Widget build(BuildContext context) => Container(
      width: 10,
      height: 12,
      decoration:
          BoxDecoration(color: const Color(0xFF241C12), borderRadius: BorderRadius.circular(5)));
}

class _DialogueBox extends StatelessWidget {
  final _Line line;
  const _DialogueBox({required this.line});

  @override
  Widget build(BuildContext context) {
    final isNpc = line.speaker == _Speaker.npc;
    final isPlayer = line.speaker == _Speaker.player;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNpc ? AppColors.gold : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNpc || isPlayer)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(isNpc ? '초롱 도깨비' : (Session.nickname ?? '탐험가'),
                  style: dokkaebiTitle(size: 12, color: isNpc ? AppColors.goldDim : AppColors.teal)),
            ),
          Text(
            line.text.replaceAll('{name}', Session.nickname ?? '탐험가'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.6,
              fontStyle:
                  line.speaker == _Speaker.narration ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
