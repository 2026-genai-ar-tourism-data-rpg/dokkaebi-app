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

## 아직 안 한 것 — 패키지 추가

일부러 넣지 않았습니다. 쓰지 않는 네이티브 패키지는 빌드만 무겁게 하고 iOS pod 문제를 미리 끌어옵니다. 실제 배선하는 PR에서 함께 넣으세요.

```yaml
dependencies:
  geolocator: ^13.0.0          # GPS 좌표 + 정확도(accuracy_m) → 서버 verify-location
  permission_handler: ^11.3.0  # 런타임 권한 요청 (선언만으로는 부족)
  flutter_map: ^7.0.0          # 지도 타일 (구글맵보다 키 발급이 간단)
  latlong2: ^0.9.0             # flutter_map 좌표 타입
  camera: ^0.11.0              # AR 카메라 프리뷰
  flutter_compass: ^0.8.0      # AR 방위 오버레이
```

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
