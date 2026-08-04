# 내 폰에서 실행하기

> 앱·서버가 **같은 Wi-Fi**에 있어야 합니다. (회사/학교 Wi-Fi는 기기 간 통신을 막는 경우가 있어 실패하면 휴대폰 핫스팟에 Mac을 연결하세요.)

## 0. 준비 — PC의 LAN IP 확인

```bash
ipconfig getifaddr en0     # 예: 192.168.0.102
```

이 주소를 아래 `<PC_IP>`에 넣습니다. **Wi-Fi를 바꾸면 IP도 바뀝니다.**

## 1. 서버 3종 기동

```bash
# ① DB (한 번만)
cd dokkaebi-infra && docker compose up -d postgres redis
#   docker 없이 로컬 설치를 쓴다면 dokkaebi-server/README-DEV.md 참고

# ② AI 백엔드 — 반드시 --host 0.0.0.0 (기본값 127.0.0.1은 폰에서 안 보임)
cd dokkaebi-ai && .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8001

# ③ 게임 서버
cd dokkaebi-server && npm run build && npm start
```

폰에서 접근 가능한지 **Mac에서 먼저** 확인:

```bash
curl http://<PC_IP>:8000/v1/health    # {"status":"ok"}
curl http://<PC_IP>:8001/v1/health    # {"status":"ok"}
```

여기서 실패하면 앱을 아무리 고쳐도 안 됩니다. macOS 방화벽(시스템 설정 → 네트워크 → 방화벽)에서 node·python 수신 허용을 확인하세요.

## 2. 폰 연결

### Android (지금 바로 가능)

1. 폰: **설정 → 휴대전화 정보 → 빌드번호 7번 탭** → 개발자 옵션 활성화
2. 폰: **개발자 옵션 → USB 디버깅 ON**
3. USB로 Mac에 연결 → 폰에 뜨는 **"USB 디버깅을 허용하시겠습니까?"** 허용
4. 확인:

```bash
flutter devices        # 폰 모델명이 보여야 함
```

### iOS (Xcode 설치 필요)

`flutter doctor` 기준 현재 **Xcode가 불완전 설치** 상태라 iOS 실기기 빌드가 안 됩니다. 먼저:

```bash
# App Store에서 Xcode 설치 후
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

그다음 `open ios/Runner.xcworkspace` → Signing & Capabilities에서 본인 Apple ID로 Team 설정(무료 계정 가능, 7일마다 재설치 필요).

## 3. 실행

```bash
cd dokkaebi-app
flutter run --dart-define=SERVER_BASE_URL=http://<PC_IP>:8000
```

**`--dart-define`을 빠뜨리면 `localhost`가 기본값이라 폰이 자기 자신을 찾습니다.** 로그인 화면 하단(디버그 빌드)에 접속 중인 서버 주소가 표시되고, `localhost`면 빨간 경고가 뜹니다.

APK를 만들어 설치하려면:

```bash
flutter build apk --debug --dart-define=SERVER_BASE_URL=http://<PC_IP>:8000
flutter install
```

## 4. 안 될 때

| 증상 | 원인 |
|---|---|
| 로그인에서 연결 실패 | `--dart-define` 누락 / Wi-Fi 다름 / 방화벽 |
| 로그인 화면에 빨간 경고 | `localhost` 사용 중 — `--dart-define` 넣기 |
| 시나리오 생성만 실패 (422) | AI 서버 미기동 또는 공공데이터포털 TourAPI 장애 |
| `Gradle`/`Java` 버전 오류 | `flutter config --jdk-dir=<JDK 17 또는 21 경로>` |

## 5. 지금 되는 것 / 안 되는 것

**됩니다** — 게스트 로그인, 시나리오 생성(코스·NPC 대사·미션), 도깨비 분기 대화, UI 전 화면.

**아직 안 됩니다** — 실제 GPS(좌표 직접 입력), 실제 지도 타일, AR 카메라, 멀티(파티).
`pubspec.yaml`에 `geolocator`·`flutter_map`·`camera`가 아직 없습니다. 서버 게임 루프(GPS 판정·조각 획득·보상)는 완성돼 있으나 앱이 아직 호출하지 않습니다.

---

# 다음 단계 사전 설정 (GPS · AR)

플랫폼 권한은 **미리 선언해 뒀습니다.** iOS는 사유 문구가 없으면 권한 요청 순간 앱이 **강제 종료**되고, 이건 실기기에서만 드러나서 나중에 원인 찾기가 어렵습니다.

## 이미 되어 있는 것

| 항목 | Android | iOS |
|---|---|---|
| 인터넷 | `INTERNET` | — |
| 평문 HTTP(로컬 서버) | `usesCleartextTraffic` | `NSAppTransportSecurity` |
| 위치(GPS) | `ACCESS_FINE_LOCATION`·`ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` |
| 카메라(AR) | `CAMERA` | `NSCameraUsageDescription` |
| 방향 센서(AR 나침반) | — | `NSMotionUsageDescription` |
| 사진 저장 | — | `NSPhotoLibraryAddUsageDescription` |
| 하드웨어 필터 회피 | `uses-feature required="false"` | — |
| NDK 버전 고정 | `27.0.12077973` | — |

`uses-feature required="false"`는 중요합니다 — `true`면 Play 스토어가 **카메라·GPS 없는 기기를 아예 설치 대상에서 제외**합니다.

## GPS는 배선 완료 — 버전에 제약이 있습니다

`geolocator`를 **10.x에 고정**했습니다. 13+는 `Color.toARGB32()`(Flutter 3.27+)를 쓰고, 팀 SDK는 3.24.3이라 빌드가 깨집니다. C7 원칙대로 SDK 업그레이드를 강요하지 않습니다.

추가로 `android/build.gradle`에 **geolocator 심**이 들어가 있습니다. `geolocator_android`가 자기 build.gradle에서 `flutter.compileSdkVersion`을 참조하는데, 그 확장은 Flutter 3.27+ Gradle 플러그인이 등록해 줍니다. 없는 상태라 플러그인 서브프로젝트에만 같은 이름의 프로퍼티를 미리 넣어 우회했습니다.

> ⚠️ **Flutter를 3.27+로 올리면** `geolocator`를 최신으로 되돌리고 이 심을 **제거**해야 합니다. 진짜 확장과 충돌합니다.

`permission_handler`는 넣었다가 **뺐습니다** — geolocator가 위치 권한을 자체 처리해서 쓸 데가 없었고, 13.x가 빌드를 깨뜨렸습니다.

## 아직 안 한 것 — 나머지 패키지

쓰지 않는 네이티브 패키지는 빌드만 무겁게 하고 iOS pod 문제를 미리 끌어옵니다. 실제 배선하는 PR에서 함께 넣으세요.

```yaml
dependencies:
  flutter_map: ^7.0.0          # 지도 타일 (구글맵보다 키 발급이 간단)
  latlong2: ^0.9.0             # flutter_map 좌표 타입
  camera: ^0.11.0              # AR 카메라 프리뷰
  flutter_compass: ^0.8.0      # AR 방위 오버레이
```

> 새 플러그인을 넣을 때 `flutter.compileSdkVersion` 참조가 있으면 위 심의 도움을 받습니다.
> `Color.toARGB32` 같은 3.27+ API를 쓰면 빌드가 깨지니 버전을 낮춰 고정하세요.

추가 후 필요한 작업:

1. `cd ios && pod install` (Xcode 설치 후)
2. Android `minSdk` 확인 — `geolocator`·`camera`는 21+, `flutter_map`은 이슈 없음. 현재 `flutter.minSdkVersion` 사용 중이라 대부분 충족
3. 런타임 권한 흐름: 권한 거부/영구 거부 분기를 반드시 처리 (거부 시 `openAppSettings()` 안내)

## 서버는 이미 준비됨

앱이 GPS를 얻으면 바로 붙일 수 있게 게임 루프가 완성돼 있습니다 (server#9).

```
POST /v1/runs {scenario_id}                         → run_id
POST /v1/runs/:runId/nodes/:nodeId/verify-location  {lat, lng, accuracy_m}
POST /v1/runs/:runId/nodes/:nodeId/collect
POST /v1/runs/:runId/nodes/:nodeId/complete
```

`accuracy_m`을 꼭 같이 보내세요 — 서버가 GPS 오차만큼 반경 판정을 관대하게 해주고, 오차가 너무 크면 `LOW_ACCURACY`로 보류합니다.

## 로컬 에러 확인 방법

```bash
flutter test                 # 전 화면 스모크 포함 (117 통과 / 9 보류)
flutter analyze              # 정적 분석
```

`test/screens_smoke_test.dart`가 모든 화면을 **320·390·768 폭**으로 렌더링해 예외와 오버플로를 잡습니다. 새 화면을 만들면 이 파일의 `screens` 맵에 한 줄 추가하세요.

---

# 배포 전 검증 (스모크로는 부족합니다)

## 두 층의 테스트 — 목적이 다릅니다

| | `flutter test` | `flutter test test_e2e` |
|---|---|---|
| 무엇을 보나 | 화면이 안 깨지는지, 모델 파싱 | **실제로 플레이가 되는지** |
| 의존 | 없음 (오프라인·결정론) | 서버·DB·AI·LLM 전부 기동 |
| 언제 | 매 커밋 | **배포 전 필수** |
| 서버 없으면 | 상관없음 | **실패한다** (건너뛰지 않음) |

위젯 스모크는 "빨간 화면이 안 뜬다"만 보장합니다. **서버 계약이 어긋나거나 GPS 판정이 죽어도 초록입니다.** 배포 전에는 실스택 E2E가 게이트여야 합니다.

## 실스택 E2E 실행

```bash
# 1) 전체 스택 기동 (README-DEV.md 참고)
cd dokkaebi-infra && docker compose up -d postgres redis
cd dokkaebi-ai    && .venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8001
cd dokkaebi-server && npm run build && npm start

# 2) E2E
cd dokkaebi-app
flutter test test_e2e --dart-define=SERVER_BASE_URL=http://localhost:8000
```

검증 내용:

1. **실스택 완주** — 로그인 → 시나리오 생성(실 TourAPI + 실 LLM) → run 시작 → 노드마다 GPS 인증·조각 획득·완료 → 지역 복원까지
2. **mock 응답 차단** — NPC 대사에 `[mock 도깨비]`가 있으면 실패 (mock이 배포에 나가면 안 됨)
3. **반경 밖 거절** — 8km 밖에서 인증되면 실패
4. **미인증 획득 차단** — GPS 없이 조각을 얻으면 실패
5. **동시 중복 획득** — 5회 동시 요청에 조각이 1번만 지급되는지
6. **에러 형태** — 도메인 실패가 500이 아닌지, JSON 원문이 사용자에게 노출되지 않는지
7. **미인증 접근** — 토큰 없이 게임 루프에 접근하면 401

> `redis-cli`가 있으면 노드 이동마다 스푸핑 이력을 지웁니다. 테스트는 좌표를 순간이동하듯 옮기므로 실제 사람의 이동과 다릅니다.

## 배포 전 반드시 되돌릴 것

개발 편의로 열어 둔 것들입니다. **이대로 스토어에 올리면 안 됩니다.**

| 항목 | 위치 | 조치 |
|---|---|---|
| 평문 HTTP 허용 | `AndroidManifest.xml` `usesCleartextTraffic="true"` | 서버 HTTPS 전환 후 **제거** |
| ATS 전체 예외 | `Info.plist` `NSAllowsArbitraryLoads` | 서버 HTTPS 전환 후 **제거** (App Store 심사에서 사유 요구) |
| 릴리스 서명 | `android/app/build.gradle` — 현재 **debug 키로 서명** | 릴리스 키스토어 생성 후 `signingConfigs.release` 연결 |
| 서버 주소 | `--dart-define=SERVER_BASE_URL` | 운영 도메인(HTTPS)으로 |

서버 쪽 배포 가드(`AUTH_SECRET`·`DB_SYNC`·CORS·Swagger)는 dokkaebi-server#12에서 기동 시 자동 검사합니다.
