// ============================================================
// [v1] 도깨비 이름 → 캐릭터 그림(NpcArt) 테스트.
// pipeline: 모바일 클라이언트 / 테스트
// 구현(요약): 이름 접두 매핑·피날레·초롱·모르는 이름 폴백, 그림 파일·pubspec 등록 누락,
//            AR 마커에 그림 경로가 실리는지 확인.
// 구현일: 2026-09-18
// ============================================================
import 'dart:io';

import 'package:dokkaebi_app/game/npc_art.dart';
import 'package:dokkaebi_app/widgets/native_ar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'assets/game/characters';

void main() {
  group('이름 → 그림', () {
    test('AI가 붙인 이름의 접두로 그 도깨비 폴더를 고른다', () {
      final art = NpcArt.of('먹 도깨비');
      expect(art.full, '$_dir/heritage_meok/full_idle.webp');
      expect(art.bust, '$_dir/heritage_meok/bust_idle.webp');
      expect(art.bustTalk, '$_dir/heritage_meok/bust_talk.webp');
      expect(NpcArt.of('  물안개 도깨비 ').full, '$_dir/nature_mulangae/full_idle.webp', reason: '앞뒤 공백 무시');
    });

    test('피날레는 이름과 무관하게 수호 도깨비다', () {
      expect(NpcArt.of('수호 도깨비', isFinale: true).full, '$_dir/guardian_suho/full_idle.webp');
      expect(NpcArt.of('글빛 수호 도깨비', isFinale: true).full, '$_dir/guardian_suho/full_idle.webp',
          reason: '종로 시연 코스의 피날레 이름');
      expect(NpcArt.of('', isFinale: true).full, '$_dir/guardian_suho/full_idle.webp');
    });

    test('초롱 도깨비는 프롤로그와 같은 기존 그림이다', () {
      expect(NpcArt.of('초롱 도깨비'), same(NpcArt.lantern));
      expect(NpcArt.lantern.full, 'assets/images/dokkaebi_character.png');
    });

    test('표에 없거나 빈 이름은 기본 소년 도깨비로 폴백한다', () {
      for (final name in ['온기 도깨비', '붓장수 도깨비', '', '도깨비']) {
        expect(NpcArt.of(name).full, '$_dir/base_youth/full_idle.webp', reason: name);
      }
    });
  });

  group('그림 파일', () {
    final folders = {...NpcArt.folderByPrefix.values, NpcArt.baseFolder};

    test('표의 모든 도깨비·기본 도깨비의 세 장이 실제로 있다', () {
      expect(folders, hasLength(20));
      for (final f in folders) {
        for (final file in ['full_idle', 'bust_idle', 'bust_talk']) {
          expect(File('$_dir/$f/$file.webp').existsSync(), isTrue, reason: '$f/$file');
        }
      }
      for (final path in [NpcArt.lantern.full, NpcArt.lantern.bust]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('폴더마다 pubspec에 등록돼 있다 — 폴더 등록은 하위 폴더를 포함하지 않는다', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final f in folders) {
        expect(pubspec, contains('- $_dir/$f/'), reason: f);
      }
    });
  });

  group('AR 마커 그림', () {
    test('image를 주면 네이티브로 넘기는 정의에 실린다', () {
      final m = ArMarkerDef(id: 'summon', label: '먹 도깨비', color: Colors.teal, image: NpcArt.of('먹 도깨비').full);
      expect(m.toMap()['image'], '$_dir/heritage_meok/full_idle.webp');
    });

    test('image가 없으면 키 자체를 빼서 네이티브가 기본 캐릭터를 쓴다', () {
      const m = ArMarkerDef(id: 'fragment', label: '기억석 조각', color: Colors.teal);
      expect(m.toMap().containsKey('image'), isFalse);
    });
  });
}
