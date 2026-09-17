// ============================================================
// [v1] 도깨비 번호 핀 — 코스 지도(scenario_screen)의 "다음/완료" 노드 핀.
// pipeline: 모바일 클라이언트 / 위젯 (SVG 템플릿)
// 구현(요약): design/pin_and_loading_mockup.html에서 사용자가 확정한 SVG(글로시
//            레드/틸 몸통 + 금장 구름(여의두) 장식 링 + 숫자·체크 배지)를 그대로
//            옮긴다. 번호·색이 노드마다 달라 정적 PNG 대신 문자열 템플릿으로 만들고
//            flutter_svg로 그린다 — 아이디는 인스턴스마다(Key) 달라야 한다
//            (SVG <defs> id가 겹치면 같은 화면에 여러 핀이 있을 때 그라디언트가
//            서로 덮어써진다).
// 구현일: 2026-09-18 | 작성: Claude · 시안 승인: jch(뿔 제거 버전, v6)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 핀 색 톤 — "다음"(레드)과 "완료"(틸)만 이 디자인을 쓴다. 미방문·식음 노드는
/// scenario_screen의 기존 이슬빛 빈 원/이모지 점을 그대로 쓴다(핀이 너무 무거워짐).
enum DokkaebiPinTone { next, done }

class DokkaebiPin extends StatelessWidget {
  final DokkaebiPinTone tone;

  /// 배지에 보일 번호. done 톤은 무시하고 체크 표시를 그린다.
  final int? number;
  final double size;

  const DokkaebiPin({super.key, required this.tone, this.number, this.size = 46});

  @override
  Widget build(BuildContext context) {
    // <defs> id 충돌 방지 — 화면에 핀이 여러 개면(코스 지도) 같은 id를 쓰는 순간
    // 뒤에 그려진 핀의 그라디언트가 앞 핀 것까지 덮어써 색이 다 같아진다.
    final uid = identityHashCode(this).toRadixString(36);
    return SvgPicture.string(
      _svg(uid: uid, tone: tone, number: number),
      width: size,
      height: size * 80 / 64, // 시안 viewBox(64x80)와 같은 비율
    );
  }
}

String _svg({required String uid, required DokkaebiPinTone tone, int? number}) {
  final isDone = tone == DokkaebiPinTone.done;
  // 레드(다음)는 시안 확정 색 그대로. 틸(완료)은 앱 테마(AppColors.teal/tealDeep)에
  // 맞춘 같은 톤 3단계 그라디언트 — 핀 모양·금장 링·구성은 두 톤이 동일하다.
  final bodyStops = isDone
      ? ['#8FE9D8', '#3AA88F', '#155E4F']
      : ['#ff6b5a', '#ee2a24', '#af1414'];
  final bodyStroke = isDone ? '#0d3f34' : '#7a0d0d';
  final badgeStops = isDone ? ['#0f3d33', '#06231f'] : ['#8a1414', '#6b0f0f'];
  final badgeInner = isDone
      ? '<path d="M25,36 L30,41 L40,29" fill="none" stroke="#eafff9" stroke-width="4" '
          'stroke-linecap="round" stroke-linejoin="round"/>'
      : '<text x="32" y="44" text-anchor="middle" font-size="21" font-weight="800" '
          'fill="${isDone ? '' : '#5c0c0c'}">${number ?? ''}</text>'
          '<text x="32" y="43" text-anchor="middle" font-size="21" font-weight="800" '
          'fill="#fdf3df">${number ?? ''}</text>';

  return '''
<svg viewBox="0 0 64 80" xmlns="http://www.w3.org/2000/svg">
<defs>
<linearGradient id="red$uid" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="${bodyStops[0]}"/><stop offset="45%" stop-color="${bodyStops[1]}"/><stop offset="100%" stop-color="${bodyStops[2]}"/></linearGradient>
<linearGradient id="gold$uid" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffd97a"/><stop offset="100%" stop-color="#c9861f"/></linearGradient>
<linearGradient id="badge$uid" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="${badgeStops[0]}"/><stop offset="100%" stop-color="${badgeStops[1]}"/></linearGradient>
<g id="cloud$uid"><circle cx="0" cy="0" r="6.5" fill="url(#gold$uid)" stroke="#8a5a1e" stroke-width="1"/><circle cx="5.5" cy="-3.5" r="4" fill="url(#gold$uid)" stroke="#8a5a1e" stroke-width="1"/><circle cx="-4.5" cy="-4.5" r="3.5" fill="url(#gold$uid)" stroke="#8a5a1e" stroke-width="1"/><path d="M-2,-0.5 Q1,-3.5 3.5,-0.8" stroke="#8a5a1e" stroke-width="1" fill="none" stroke-linecap="round"/></g>
</defs>
<ellipse cx="32" cy="70" rx="10" ry="2.8" fill="#000" opacity=".28"/>
<path d="M32,66 C20,54 8,46 8,36 C8,18 18,6 32,6 C46,6 56,18 56,36 C56,46 44,54 32,66 Z" fill="url(#red$uid)" stroke="$bodyStroke" stroke-width="2.5"/>
<ellipse cx="21" cy="19" rx="9" ry="5.5" fill="#fff" opacity=".28" transform="rotate(-25 21 19)"/>
<circle cx="32" cy="36" r="21" fill="${isDone ? '#0c332b' : '#c22020'}"/>
<circle cx="32" cy="36" r="20" fill="none" stroke="url(#gold$uid)" stroke-width="3"/>
<use href="#cloud$uid" transform="translate(17.9,21.9)"/>
<use href="#cloud$uid" transform="translate(17.9,50.1)"/>
<use href="#cloud$uid" transform="translate(46.1,21.9) scale(-1,1)"/>
<use href="#cloud$uid" transform="translate(46.1,50.1) scale(-1,1)"/>
<circle cx="32" cy="36" r="15" fill="url(#badge$uid)"/>
$badgeInner
</svg>
''';
}
