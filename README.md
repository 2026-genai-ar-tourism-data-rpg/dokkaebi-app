# dokkaebi-app

> **도깨비: 팔도의 비밀** AR 관광 탐정 RPG의 Flutter 모바일 클라이언트. (핵심 기능)

카메라로 현실 관광지를 스캔하면 AR NPC와 퀘스트가 등장하고, 실제 이동이 게임 진행 조건이 되는 위치 기반 RPG 앱입니다.

## Clone

```bash
git clone https://github.com/2026-genai-ar-tourism-data-rpg/dokkaebi-app.git
cd dokkaebi-app
```

## 스택

- **프레임워크**: Flutter / Dart
- **AR**: `ar_flutter_plugin` (ARCore on Android / ARKit on iOS)
- **위치**: `geolocator` (GPS 반경 트리거)
- **실시간**: `socket_io_client`
- **지도**: `flutter_map` 또는 Google Maps SDK
- **배포**: Codemagic / fastlane → App Store · Play Store

## 책임 범위

- AR 카메라 탐색 및 3D NPC·단서 오브젝트·힌트 텍스트 오버레이
- GPS 반경(도심 50m / 개방 공간 100m) 진입 시 퀘스트 자동 활성화
- 생성형 AI NPC 대화 UI
- 멀티유저 협력 파티(최대 4인)·경쟁·인게임 채팅·랭킹 화면
- 사용자 인증 플로우

## 결합 방식

서버·AI와는 **REST / WebSocket 계약으로만 결합**합니다. `dokkaebi-server`가 제공하는 OpenAPI 스펙으로 클라이언트 코드를 생성해 사용합니다.

## 의존 레포

- [`dokkaebi-server`](./dokkaebi-server.md) — API·실시간 동기화 백엔드
