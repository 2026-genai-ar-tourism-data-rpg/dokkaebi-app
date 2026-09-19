// ============================================================
// [v1] 네이티브 AR 뷰 — ArSearchScreen "스캔" 모드용 (Pokémon GO식 월드 트래킹)
// pipeline: 모바일 클라이언트 / iOS 네이티브 (Flutter PlatformView)
// 구현(요약): ar_flutter_plugin(3년 방치, pub.dev 정적분석 실패)에 기대지 않고
//            ARKit(ARSCNView)을 얇게 직접 감싼다. 세션 시작 시점 카메라 기준 고정
//            오프셋에 마커를 배치했다. 시뮬레이터는 ARKit 미지원이라 실기기 전용.
// 구현일: 2026-08-31 | 작성: 정찬희
// ------------------------------------------------------------
// [v2] 바닥 앵커링 + 실시간 거리·조준 스트리밍 (AR 타당성 검토 2026-08-19의 "A층").
// 구현(요약): v1은 마커가 카메라 앞 고정 오프셋에 1회 떠 있을 뿐이라, 걸어가도
//            거리가 변하는 연출을 만들 수 없었다(계획서의 "다가가면 자국이 늘고
//            겨누면 드러난다"가 통째로 빠져 있던 이유). 세 가지를 더한다:
//            ① planeDetection=[.horizontal] — 바닥을 찾아 그 높이에 마커를 앉힌다.
//               실외에서 바닥 스캔을 "요구"하진 않는다. 못 찾으면 v1처럼 카메라
//               기준으로 두고, 나중에 찾으면 그때 바닥 높이로 살짝 내려앉힌다.
//            ② 매 프레임 카메라↔마커 거리·조준각을 계산해 10Hz로 Dart에 보낸다.
//               미션 상태기계는 전부 Dart(ar_mission_controller.dart)에 있고
//               네이티브는 "재고 그리기"만 한다 — 연출을 바꾸려고 Xcode를 열지
//               않아도 되게(실기기 튜닝이 Dart 핫리로드로 끝난다).
//            ③ Dart가 마커의 표시 상태를 지시(hidden/ghost/solid + 크기).
//            ⚠️ 물체 인식(ML)은 쓰지 않는다 — 전부 거리와 시선으로 만드는 연출이다.
// 구현일: 2026-09-16 | 작성: kys (ar-realtime/kys/v1)
// ------------------------------------------------------------
// [v3] 참조 이미지 인식(Augmented Images) + 스냅샷.
// 구현(요약): ① creationParams.referenceImages(TourAPI 사진 URL)를 내려받아 ARReferenceImage로
//               등록한다. 카메라에 그 사진과 같은 면(안내판·현판)이 잡히면 ARImageAnchor가 생기고,
//               그 자리로 pattern 마커를 옮기고 Dart에 imageDetected를 보낸다 — 이때부터 AR은
//               "타깃이 어디 있는지"를 진짜로 안다. 비평면 사진은 인식이 안 될 뿐 해가 없다.
//               실물 폭은 모른다 → 1.0m로 추정(인식 자체엔 영향 작고 거리 추정만 틀린다).
//            ② snapshot: 지금 카메라+오버레이를 JPEG base64로. 촬영 미션의 셔터이자,
//               갤러리 사진으로 검증을 속일 수 없게 하는 장치(항상 라이브 프레임).
// 구현일: 2026-09-16 | 작성: kys (photo-verify/kys/v1)
// ------------------------------------------------------------
// [v4] beacon 마커(범용/하위호환) — 발광 피라미드 대신 기본 캐릭터 일러스트를 표시.
// 구현(요약): 사람 형상 이미지를 입체 지오메트리에 입힐 수 없어, pattern 마커와 같은
//            빌보드 판(SCNPlane + SCNBillboardConstraint)에 텍스처로 붙였다. 이미지는
//            Assets.xcassets의 DokkaebiCharacter(Flutter의 assets/images/dokkaebi_character.png와
//            동일 파일). 상시 회전 대신 은은한 상하 부유로 바꿨다 — 빌보드가 항상 정면을
//            보므로 Y축 회전 애니메이션과 겹치면 제자리에서 뒤집히는 것처럼 보인다.
// 구현일: 2026-09-17 | 작성: ljs (character-illustration/ljs/v1)
// ------------------------------------------------------------
// [v5] beacon 그림을 장소별 도깨비로 + HUNT 발자국을 엽전으로.
// 구현(요약): 마커 정의의 image(Flutter 에셋 경로, lib/game/npc_art.dart)를 앱 번들에서 읽어
//            판에 붙이고, 판 비율도 그 그림에 맞춘다. image가 없거나 못 읽으면 v4의 기본 캐릭터.
//            HUNT는 바닥의 발자국 대신 도깨비가 흘리고 간 엽전(빌보드 판, 바닥에 세움).
//            도깨비 판은 키 0.42→1.0m로 키우고 발끝을 바닥에 맞췄다(가운데가 바닥이라 반이 묻혔다).
//            엽전은 바닥 위 kCoinHoverM에 띄워 오르내리고, 흐릿할 때도 kCoinGhostOpacity로 진하게.
//            폴백 그림 DokkaebiCharacter도 새 세트의 기본 소년 도깨비(빨간 youth)로 바꿨다.
// 구현일: 2026-09-18 | 작성: ljs (npc-character-set/ljs/v1)
// ------------------------------------------------------------
// [v6] PHOTO_FIND 문양 마커 — 판(면) → 힌트 화살표, 상시 노출 → 지연 노출.
// 구현(요약): pattern 마커는 세션 시작 카메라 자세 기준 "정면 2.6m 앞"이라는 고정
//            오프셋일 뿐 실제 타깃 위치가 아닌데, 확정된 위치처럼 보이는 판으로
//            상시 그려서 실기기 테스트에서 사물과 무관한 자리에 뜨는 것으로 오인됐다
//            (팀 제보). 화살표 모양으로 바꿔 "추정"임을 드러내고, Dart 쪽에서
//            kPhotoHintDelaySec(8초)가 지나야 hidden→solid로 보여주게 했다
//            (ar_mission_controller.dart _tickPhoto). 진짜 이미지 인식이 되면
//            handleImageAnchor가 이 마커를 실제 위치로 옮기는 동작은 그대로다.
// 구현일: 2026-09-19 | 작성: Claude
// ------------------------------------------------------------
// [v7] 도깨비불 길들이기 지원 (AR 미션 교체 명세 v1.0, 2026-09-19).
// 구현(요약): ① kind=fire 마커 — 에셋 그림(fire_spirit_idle)을 카메라를 향하는 판에 붙인 빌보드
//               + 은은한 점광원, 작은 상하 부유·크기 변화(판정 중심 markerPositions는 고정).
//               그림을 못 읽으면 발광 구체 폴백. 바닥 스냅 제외(눈높이).
//            ② 텔레메트리에 dyaw(부호 있는 수평 각, +면 목표가 오른쪽) → 좌우 힌트.
//            ③ ARKit tracking 상태를 trackingState 이벤트({state, reason})로. 회전만 하는 게임이라
//               limited(insufficientFeatures/excessiveMotion)는 IMU 방향이 멀쩡해 정상으로 친다 —
//               초기화·재위치·notAvailable만 Dart가 게이지를 버린다.
//            ③' cameraFov 이벤트(세로 화면 가로 시야각°) 1회 — HUD 조준 원을 실제 6°와 같은 크기로.
//            ④ absorbMarker(id, image): 불꽃이 줄며 사라지고 그 자리에 흡수 소용돌이(capture_wisp)가
//               회전·축소·페이드로 약 800ms — 에셋 안내서(ar-fire-assets-guide) 권장값. 노드 제거.
//            목표는 세션 시작 카메라 기준 월드 좌표에 고정(placeMarkers가 이미 그렇다).
//            카메라 자식으로 두면 화면을 돌려도 따라붙어 게임이 성립하지 않는다 — 명세의 금지 사항.
// 구현일: 2026-09-19 | 작성: kys (fire-capture/kys/v1)
// ------------------------------------------------------------
// [v8] coin·part·hidden 마커를 나침반(진북) 고정 배치로 — "눈으로 보는 실제 세계와 맞게".
// 구현(요약): 이 셋도 지금까지 pattern·fire와 똑같이 "세션 시작 카메라가 우연히 향했던
//            방향" 기준이었다 — AR을 켤 때 폰이 어디를 보고 있었느냐에 따라 매번 다른
//            방향(벽 쪽·바닥 쪽 등)에 나타났다. 인식 자체가 랜덤해 보이는 원인 중 하나(팀 제보).
//            worldAlignment=.gravityAndHeading으로 세션을 열어(GPS로 이미 있는 위치 권한을
//            나침반에도 씀) 월드 -Z=진북·+X=동쪽으로 고정하고, 이 세 종류만
//            arMarkerWorldPositionCompassFixed로 배치한다(forward=북쪽 오프셋, right=동쪽).
//            서버가 개별 마커의 실제 GPS 좌표를 주지 않아(클라이언트가 지어내는 배치) 방위각·
//            거리 계산은 필요 없고, 나침반 방향만 고정해도 "실행마다 같은 방향"이 보장된다.
//            pattern은 그대로 둔다(실제 이미지 인식이 대신 위치를 잡아 준다 — handleImageAnchor).
//            fire도 그대로 둔다(명세상 "어디를 보든 같은 난이도"가 목적이라 나침반 고정은
//            오히려 방해). 나침반 오차(자성 간섭 등)는 실기기 튜닝 영역.
// 구현일: 2026-09-19 | 작성: Claude
// ============================================================
import ARKit
import Flutter
import SceneKit
import UIKit

/// 마커 종류 — 미션별로 그리는 모양이 다르다. Dart의 ArMarkerKind와 문자열이 같아야 한다.
enum ArMarkerKind: String {
  case coin        // HUNT       — 도깨비가 흘리고 간 엽전
  case part        // RESTORE_AR — 흩어진 부재(주춧돌·기둥)
  case pattern     // PHOTO_FIND — 벽면 문양(수직 판)
  case hidden      // FIND       — 숨은 도깨비 자리의 풀숲
  case beacon      // 범용 — 기본 캐릭터 일러스트 빌보드(하위호환 기본값)
  case fire        // 도깨비불 길들이기 — 눈높이에 떠 있는 불꽃(바닥 스냅 제외)
}

/// 마커 표시 상태 — Dart가 거리·조준을 보고 지시한다.
enum ArMarkerState: String {
  case hidden      // 안 보임 (아직 발견 전)
  case ghost       // 흐릿함 (기척만)
  case solid       // 완전히 드러남
}

/// 엽전이 바닥 위로 떠 있는 높이(m) — 바닥에 두면 발밑이라 폰을 숙여야 보였다.
private let kCoinHoverM: Float = 0.6

/// 흐릿한(ghost) 엽전의 불투명도 — 다른 마커(0.28)보다 진하게, 카메라 배경에 묻히지 않게.
private let kCoinGhostOpacity: CGFloat = 0.5

/// 마커 1개 정의 — Dart 쪽에서 creationParams로 전달.
private struct ArMarkerSpec {
  let id: String
  let label: String
  let colorHex: Int
  // 카메라 시작 위치 기준 상대 오프셋(미터). x=오른쪽+, y=위+, z=앞(카메라가 보는 방향)+.
  let forward: Float
  let right: Float
  let down: Float
  let kind: ArMarkerKind
  let state: ArMarkerState
  let image: String?  // beacon·coin에 붙일 Flutter 에셋 경로 — 없으면 기본 모양

  static func parse(_ dict: [String: Any]) -> ArMarkerSpec? {
    guard let id = dict["id"] as? String, let label = dict["label"] as? String else { return nil }
    return ArMarkerSpec(
      id: id,
      label: label,
      colorHex: (dict["color"] as? Int) ?? 0x2E7E76,
      forward: Float((dict["forward"] as? Double) ?? 1.6),
      right: Float((dict["right"] as? Double) ?? 0),
      down: Float((dict["down"] as? Double) ?? 0.2),
      kind: ArMarkerKind(rawValue: (dict["kind"] as? String) ?? "") ?? .beacon,
      state: ArMarkerState(rawValue: (dict["state"] as? String) ?? "") ?? .solid,
      image: dict["image"] as? String
    )
  }
}

/// 카메라 변환 기준 상대 오프셋(전방/우측/아래, 미터)을 월드 좌표로 변환한다.
/// ARKit 없이도(유닛 테스트) 검증 가능하도록 렌더링/씬 그래프와 분리한 순수 함수.
func arMarkerWorldPosition(
  cameraTransform: simd_float4x4,
  forward: Float,
  right: Float,
  down: Float
) -> simd_float3 {
  let rightAxis = simd_make_float3(cameraTransform.columns.0)
  let upAxis = simd_make_float3(cameraTransform.columns.1)
  let forwardAxis = -simd_make_float3(cameraTransform.columns.2)
  let camPos = simd_make_float3(cameraTransform.columns.3)
  return camPos
    + forwardAxis * forward
    + rightAxis * right
    - upAxis * down
}

/// 나침반(진북) 기준 상대 오프셋(북/동/아래, 미터)을 월드 좌표로 변환한다.
/// worldAlignment=.gravityAndHeading 세션에서만 축이 맞다(-Z=북, +X=동, +Y=위).
/// 카메라가 어느 쪽을 보고 있었는지와 무관하게 실제 나침반 방향에 고정하고 싶은
/// 마커(엽전·부재·기척)에 쓴다 — pattern·fire는 arMarkerWorldPosition을 그대로 쓴다.
func arMarkerWorldPositionCompassFixed(
  cameraPosition: simd_float3,
  forward: Float,
  right: Float,
  down: Float
) -> simd_float3 {
  let north = simd_float3(0, 0, -1)
  let east = simd_float3(1, 0, 0)
  let up = simd_float3(0, 1, 0)
  return cameraPosition
    + north * forward
    + east * right
    - up * down
}

/// 카메라가 목표를 얼마나 정확히 겨누고 있는지(라디안). 0이면 화면 정중앙.
/// "몇 초 겨누면 드러난다" 판정의 입력 — 거리와 함께 Dart로 보낸다.
func arAimError(cameraTransform: simd_float4x4, target: simd_float3) -> Float {
  let camPos = simd_make_float3(cameraTransform.columns.3)
  let toTarget = target - camPos
  let len = simd_length(toTarget)
  guard len > 0.0001 else { return 0 }
  let forwardAxis = -simd_make_float3(cameraTransform.columns.2)
  // 두 단위벡터의 내적 = cos(각). 부동소수 오차로 |dot|>1이 되면 acos가 NaN을 뱉는다.
  let dot = simd_dot(simd_normalize(toTarget), simd_normalize(forwardAxis))
  return acos(max(-1, min(1, dot)))
}

/// 카메라 전방 대비 목표의 **부호 있는 수평 각**(라디안). +면 목표가 오른쪽.
/// 카메라 로컬 좌표로 옮겨 atan2(x, z) — 좌우 힌트("오른쪽으로 천천히")의 입력.
func arSignedYaw(cameraTransform: simd_float4x4, target: simd_float3) -> Float {
  let camPos = simd_make_float3(cameraTransform.columns.3)
  let d = target - camPos
  let right = simd_make_float3(cameraTransform.columns.0)
  let forward = -simd_make_float3(cameraTransform.columns.2)
  return atan2(simd_dot(d, right), simd_dot(d, forward))
}

final class DokkaebiArViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return DokkaebiArView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

/// ARKit 지원 여부만 알려주는 정적 채널 — Dart가 네이티브 뷰를 붙이기 전에 먼저 물어본다.
/// 시뮬레이터·구형 기기에서는 항상 false → Dart가 2D 폴백으로 전환.
enum DokkaebiArSupport {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "dokkaebi/ar_support", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "isSupported" {
        result(ARWorldTrackingConfiguration.isSupported)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

final class DokkaebiArView: NSObject, FlutterPlatformView, ARSCNViewDelegate, ARSessionDelegate {
  private let sceneView: ARSCNView
  private let channel: FlutterMethodChannel
  private var placed = false
  private var fovSent = false
  private var markerSpecs: [ArMarkerSpec] = []

  /// 배치된 마커의 월드 좌표 — 매 프레임 거리·조준각을 재는 대상.
  private var markerPositions: [String: simd_float3] = [:]
  /// 바닥으로 인정한 평면의 높이(월드 Y). nil이면 아직 못 찾음.
  private var floorY: Float?
  /// 텔레메트리 송신 간격 — 매 프레임(60Hz) 보내면 채널이 포화된다. 10Hz면 연출에 충분.
  private var lastTelemetry: TimeInterval = 0
  private static let telemetryInterval: TimeInterval = 0.1

  /// 참조 이미지(Augmented Images) — URL 목록은 Dart가 주고, 여기서 내려받아 등록한다.
  private var referenceUrls: [String] = []
  private var referenceImages = Set<ARReferenceImage>()
  private static let referencePhysicalWidth: CGFloat = 1.0   // 안내판 폭 추정(m)
  private var imageDetectedOnce = false
  /// 마커 id → 종류. 인식된 이미지 자리로 옮길 pattern 마커를 찾을 때 쓴다.
  private var markerKinds: [String: ArMarkerKind] = [:]

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    sceneView = ARSCNView(frame: frame)
    channel = FlutterMethodChannel(name: "dokkaebi/ar_view_\(viewId)", binaryMessenger: messenger)
    if let dict = args as? [String: Any] {
      if let rawMarkers = dict["markers"] as? [[String: Any]] {
        markerSpecs = rawMarkers.compactMap(ArMarkerSpec.parse)
      }
      referenceUrls = (dict["referenceImages"] as? [String]) ?? []
    }
    super.init()
    for spec in markerSpecs { markerKinds[spec.id] = spec.kind }

    sceneView.delegate = self
    sceneView.session.delegate = self
    sceneView.autoenablesDefaultLighting = true
    sceneView.scene = SCNScene()

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    sceneView.addGestureRecognizer(tap)

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "removeMarker":
        if let id = call.arguments as? String { self?.removeMarker(id: id) }
        result(nil)
      case "setMarkerState":
        if let a = call.arguments as? [String: Any], let id = a["id"] as? String {
          self?.setMarkerState(
            id: id,
            state: ArMarkerState(rawValue: (a["state"] as? String) ?? "") ?? .solid,
            scale: Float((a["scale"] as? Double) ?? 1.0)
          )
        }
        result(nil)
      case "absorbMarker":
        if let id = call.arguments as? String {
          self?.absorbMarker(id: id, effectImage: nil)
        } else if let a = call.arguments as? [String: Any], let id = a["id"] as? String {
          self?.absorbMarker(id: id, effectImage: a["image"] as? String)
        }
        result(nil)
      case "snapshot":
        // ARSCNView.snapshot()은 카메라 프레임 + SceneKit 오버레이를 합친 이미지 — 메인 스레드 전용.
        DispatchQueue.main.async {
          guard let self = self else { result(nil); return }
          // 화면 해상도 그대로(예: 1170×2532)면 JPEG 1~3MB → base64 ×1.33. OCR엔 긴 변 1600px면
          // 충분하고(현판·안내판 글자가 잘 남는다) 업로드가 수백 KB로 내려온다.
          let img = Self.downscaled(self.sceneView.snapshot(), maxSide: 1600)
          if let data = img.jpegData(compressionQuality: 0.8) {
            result(data.base64EncodedString())
          } else {
            result(FlutterError(code: "snapshot_failed", message: "JPEG 인코딩 실패", details: nil))
          }
        }
      case "dispose":
        self?.sceneView.session.pause()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let config = ARWorldTrackingConfiguration()
    // v2: 바닥을 찾는다. 못 찾아도 진행하므로(아래 placeMarkers 폴백) 실외에서
    // "바닥을 비춰주세요" 같은 강요는 하지 않는다.
    config.planeDetection = [.horizontal]
    // v8: 나침반 사용 — coin·part·hidden 마커를 진북 기준으로 고정 배치하기 위함.
    config.worldAlignment = .gravityAndHeading
    sceneView.session.run(config)
    loadReferenceImages()
  }

  /// 긴 변이 maxSide를 넘으면 비율 유지로 줄인다. 작으면 그대로.
  private static func downscaled(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let w = image.size.width, h = image.size.height
    let longest = max(w, h)
    guard longest > maxSide, longest > 0 else { return image }
    let scale = maxSide / longest
    let size = CGSize(width: floor(w * scale), height: floor(h * scale))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  // MARK: - 참조 이미지(Augmented Images)

  /// URL들을 비동기로 내려받아 ARReferenceImage로 만들고, 하나라도 되면 세션 설정에 얹는다.
  /// 실패한 URL은 건너뛴다 — 참조가 없으면 v2(거리·조준)로 동작할 뿐이다.
  private func loadReferenceImages() {
    guard !referenceUrls.isEmpty else { return }
    let group = DispatchGroup()
    var built: [ARReferenceImage] = []
    let lock = NSLock()
    for (idx, urlStr) in referenceUrls.prefix(8).enumerated() {
      guard let url = URL(string: urlStr) else { continue }
      group.enter()
      URLSession.shared.dataTask(with: url) { data, _, _ in
        defer { group.leave() }
        guard let data = data, let ui = UIImage(data: data), let cg = ui.cgImage else { return }
        let ref = ARReferenceImage(cg, orientation: .up, physicalWidth: Self.referencePhysicalWidth)
        ref.name = "ref\(idx)|\(urlStr)"
        lock.lock(); built.append(ref); lock.unlock()
      }.resume()
    }
    group.notify(queue: .main) { [weak self] in
      guard let self = self, !built.isEmpty else { return }
      self.referenceImages = Set(built)
      let config = ARWorldTrackingConfiguration()
      config.planeDetection = [.horizontal]
      config.worldAlignment = .gravityAndHeading
      config.detectionImages = self.referenceImages
      config.maximumNumberOfTrackedImages = 1
      // 옵션 없이 run — 기존 월드 트래킹·앵커를 리셋하지 않고 설정만 갱신한다.
      self.sceneView.session.run(config)
      self.channel.invokeMethod("referenceImagesLoaded", arguments: built.count)
    }
  }

  /// 인식된 이미지 앵커 자리로 pattern 마커를 옮긴다 — 이제 AR이 타깃 위치를 안다.
  private func handleImageAnchor(_ anchor: ARImageAnchor) {
    let pos = simd_make_float3(anchor.transform.columns.3)
    let name = anchor.referenceImage.name ?? "ref"
    if let (id, _) = markerKinds.first(where: { $0.value == .pattern }),
       let node = sceneView.scene.rootNode.childNode(withName: "marker:\(id)", recursively: false) {
      node.simdPosition = pos
      markerPositions[id] = pos
      channel.invokeMethod("markerAnchored", arguments: id)
    }
    if !imageDetectedOnce {
      imageDetectedOnce = true
      channel.invokeMethod("imageDetected", arguments: name)
    }
  }

  func view() -> UIView { sceneView }

  // MARK: - ARSCNViewDelegate

  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    guard let frame = sceneView.session.currentFrame else { return }
    let camTransform = frame.camera.transform

    if !placed, !markerSpecs.isEmpty {
      placed = true
      DispatchQueue.main.async { [weak self] in
        self?.placeMarkers(cameraTransform: camTransform)
      }
      return
    }

    guard time - lastTelemetry >= Self.telemetryInterval, !markerPositions.isEmpty else { return }
    lastTelemetry = time
    if !fovSent {
      // 세로 화면 기준 가로 시야각 — 투영 행렬의 [0][0] = 1/tan(fovx/2). 한 번만 보낸다.
      fovSent = true
      let size = sceneView.bounds.size
      if size.width > 0, size.height > 0 {
        let p = frame.camera.projectionMatrix(for: .portrait, viewportSize: size, zNear: 0.01, zFar: 100)
        let fovx = Double(2 * atan(1 / p.columns.0.x)) * 180 / .pi
        DispatchQueue.main.async { [weak self] in
          self?.channel.invokeMethod("cameraFov", arguments: ["fovx": fovx])
        }
      }
    }
    let camPos = simd_make_float3(camTransform.columns.3)
    let payload: [[String: Any]] = markerPositions.map { id, pos in
      [
        "id": id,
        "dist": Double(simd_distance(camPos, pos)),
        "aim": Double(arAimError(cameraTransform: camTransform, target: pos)),
        "dyaw": Double(arSignedYaw(cameraTransform: camTransform, target: pos)),
      ]
    }
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("telemetry", arguments: payload)
    }
  }

  /// 수평 평면을 처음 찾으면 그 높이를 바닥으로 삼고, 이미 놓인 마커를 그 높이에 앉힌다.
  /// 실외에선 평면이 늦게(또는 아예 안) 잡히므로 "찾으면 보정" 방식이어야 한다.
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    if let image = anchor as? ARImageAnchor {
      DispatchQueue.main.async { [weak self] in self?.handleImageAnchor(image) }
      return
    }
    guard let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal else { return }
    let y = plane.transform.columns.3.y
    // 카메라보다 위에 있는 평면(천장·책상 윗면)은 바닥이 아니다.
    guard let frame = sceneView.session.currentFrame else { return }
    let camY = frame.camera.transform.columns.3.y
    guard y < camY - 0.3 else { return }
    guard floorY == nil else { return }
    floorY = y
    DispatchQueue.main.async { [weak self] in
      self?.snapMarkersToFloor(y: y)
      self?.channel.invokeMethod("planeFound", arguments: Double(y))
    }
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    channel.invokeMethod("sessionError", arguments: error.localizedDescription)
  }

  /// tracking 품질 — Dart는 normal이 아니면 도깨비불 유지 시간을 버린다(명세 3쪽).
  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    let state: String
    var reason = ""
    switch camera.trackingState {
    case .normal: state = "normal"
    case .limited(let r):
      state = "limited"
      switch r {
      case .initializing: reason = "initializing"
      case .relocalizing: reason = "relocalizing"
      case .excessiveMotion: reason = "excessiveMotion"
      case .insufficientFeatures: reason = "insufficientFeatures"
      @unknown default: reason = "unknown"
      }
    case .notAvailable: state = "notAvailable"
    }
    channel.invokeMethod("trackingState", arguments: ["state": state, "reason": reason])
  }

  // MARK: - 마커 배치·탭

  private func placeMarkers(cameraTransform: simd_float4x4) {
    let camPos = simd_make_float3(cameraTransform.columns.3)
    for spec in markerSpecs {
      var pos: simd_float3
      switch spec.kind {
      case .coin, .part, .hidden:
        // 실제 나침반 방향에 고정 — "AR 켤 때 우연히 향했던 쪽"이 아니라 눈으로 보는
        // 실제 세계(동서남북)와 맞게 둔다(v8).
        pos = arMarkerWorldPositionCompassFixed(
          cameraPosition: camPos, forward: spec.forward, right: spec.right, down: spec.down
        )
      case .pattern, .fire, .beacon:
        pos = arMarkerWorldPosition(
          cameraTransform: cameraTransform, forward: spec.forward, right: spec.right, down: spec.down
        )
      }
      // 바닥을 이미 찾았으면 바닥에 앉힌다(부재·도깨비는 공중에 뜨면 안 된다. 엽전은 바닥 위로 띄운다).
      if let y = floorY, spec.kind != .pattern, spec.kind != .fire { pos.y = floorHeight(y, for: spec.kind) }

      let node = markerNode(spec: spec)
      node.simdPosition = pos
      node.name = "marker:\(spec.id)"
      sceneView.scene.rootNode.addChildNode(node)
      markerPositions[spec.id] = pos
      applyState(node: node, state: spec.state, scale: 1.0, kind: spec.kind)

      // 등장 애니메이션 + 은은한 오르내림(떠 있는 것들).
      node.runAction(.scale(to: CGFloat(spec.state == .hidden ? 0.01 : 1.0), duration: 0.4))
      if spec.kind == .beacon || spec.kind == .part || spec.kind == .coin || spec.kind == .fire {
        node.runAction(.repeatForever(.sequence([
          .moveBy(x: 0, y: 0.06, z: 0, duration: 1.1),
          .moveBy(x: 0, y: -0.06, z: 0, duration: 1.1),
        ])))
      }
    }
    channel.invokeMethod("markersPlaced", arguments: markerSpecs.map { $0.id })
  }

  /// 이미 놓인 마커를 바닥 높이로 내려앉힌다(평면을 늦게 찾은 경우).
  private func snapMarkersToFloor(y: Float) {
    for spec in markerSpecs where spec.kind != .pattern && spec.kind != .fire {
      guard let node = sceneView.scene.rootNode.childNode(withName: "marker:\(spec.id)", recursively: false) else { continue }
      var p = node.simdPosition
      p.y = floorHeight(y, for: spec.kind)
      node.simdPosition = p
      markerPositions[spec.id] = p
    }
  }

  /// 바닥 높이 y에 이 종류의 마커를 둘 높이 — 엽전만 바닥 위로 띄운다.
  private func floorHeight(_ y: Float, for kind: ArMarkerKind) -> Float {
    kind == .coin ? y + kCoinHoverM : y
  }

  private func setMarkerState(id: String, state: ArMarkerState, scale: Float) {
    guard let node = sceneView.scene.rootNode.childNode(withName: "marker:\(id)", recursively: false) else { return }
    applyState(node: node, state: state, scale: scale, kind: markerKinds[id])
  }

  /// 표시 상태를 실제 재질·크기에 반영. 상태 판단은 전부 Dart에 있다.
  private func applyState(node: SCNNode, state: ArMarkerState, scale: Float, kind: ArMarkerKind?) {
    let opacity: CGFloat
    switch state {
    case .hidden: opacity = 0.0
    case .ghost: opacity = kind == .coin ? kCoinGhostOpacity : 0.28
    case .solid: opacity = 1.0
    }
    node.runAction(.group([
      .fadeOpacity(to: opacity, duration: 0.25),
      .scale(to: CGFloat(max(0.01, scale)), duration: 0.25),
    ]))
  }

  private func markerNode(spec: ArMarkerSpec) -> SCNNode {
    let color = UIColor(
      red: CGFloat((spec.colorHex >> 16) & 0xFF) / 255.0,
      green: CGFloat((spec.colorHex >> 8) & 0xFF) / 255.0,
      blue: CGFloat(spec.colorHex & 0xFF) / 255.0,
      alpha: 1.0
    )
    let node: SCNNode
    switch spec.kind {
    case .coin: node = coinNode(imageAsset: spec.image, color: color)
    case .part: node = partNode(color: color)
    case .pattern: node = patternNode(color: color, label: spec.label)
    case .hidden: node = grassNode(color: color)
    case .beacon: node = beaconNode(imageAsset: spec.image)
    case .fire: node = fireNode(imageAsset: spec.image, color: color)
    }
    // 엽전·문양은 이름표가 오히려 방해된다(바닥의 엽전 위에 글자가 뜬다).
    if spec.kind == .beacon || spec.kind == .part {
      let labelNode = SCNNode(geometry: textGeometry(spec.label, color: color))
      labelNode.scale = SCNVector3(0.01, 0.01, 0.01)
      labelNode.position = SCNVector3(-Float(spec.label.count) * 0.6, 0.24, 0)
      let billboard = SCNBillboardConstraint()
      billboard.freeAxes = .Y
      labelNode.constraints = [billboard]
      node.addChildNode(labelNode)
    }
    return node
  }

  private func glowMaterial(_ color: UIColor, intensity: CGFloat = 0.55) -> SCNMaterial {
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.emission.contents = color
    mat.emission.intensity = intensity
    mat.isDoubleSided = true
    return mat
  }

  /// 엽전 — 도깨비가 흘리고 간 것. 그림을 카메라를 향하는 판에 붙여 바닥에 세운다
  /// (마커 위치=바닥이라 판을 반 높이만큼 올린다). 그림을 못 읽으면 발광 원판.
  private func coinNode(imageAsset: String?, color: UIColor) -> SCNNode {
    let size: CGFloat = 0.3  // 기본 지름(m) — 거리별 배율은 Dart(coinScaleFor)가 곱한다
    let geo = SCNPlane(width: size, height: size)
    if let image = imageAsset.flatMap({ flutterAssetImage($0) }) {
      let mat = SCNMaterial()
      mat.diffuse.contents = image
      mat.isDoubleSided = true
      mat.lightingModel = .constant
      geo.materials = [mat]
    } else {
      geo.cornerRadius = size / 2
      geo.materials = [glowMaterial(color, intensity: 0.8)]
    }
    let plane = SCNNode(geometry: geo)
    plane.position = SCNVector3(0, Float(size / 2), 0)
    let billboard = SCNBillboardConstraint()
    billboard.freeAxes = .Y
    plane.constraints = [billboard]
    let node = SCNNode()
    node.addChildNode(plane)
    return node
  }

  /// 기억석 부재 — 모난 돌덩이.
  private func partNode(color: UIColor) -> SCNNode {
    let geo = SCNBox(width: 0.18, height: 0.14, length: 0.18, chamferRadius: 0.03)
    geo.materials = [glowMaterial(color)]
    return SCNNode(geometry: geo)
  }

  /// 문양 힌트 화살표 — Dart(ArMissionController._tickPhoto)가 kPhotoHintDelaySec가
  /// 지난 뒤에만 이 마커를 드러낸다. "확실한 위치"가 아니라 카메라 시작 자세 기준
  /// 고정 오프셋의 "대략 이쯤"이라는 추정이라, 확정된 타깃처럼 보이는 판(면) 대신
  /// 그 자리 위에서 아래를 가리키는 화살표로 그린다 — 진짜 이미지 인식(handleImageAnchor)이
  /// 되면 이 자리 자체가 실제 위치로 옮겨진다.
  private func patternNode(color: UIColor, label: String) -> SCNNode {
    let node = SCNNode()
    let head = SCNCone(topRadius: 0, bottomRadius: 0.09, height: 0.16)
    head.materials = [glowMaterial(color, intensity: 0.6)]
    let headNode = SCNNode(geometry: head)
    headNode.eulerAngles.x = Float.pi   // 원뿔 끝이 아래(대상)를 가리키게 뒤집는다
    headNode.position = SCNVector3(0, -0.06, 0)
    node.addChildNode(headNode)

    let shaft = SCNCylinder(radius: 0.03, height: 0.14)
    shaft.materials = [glowMaterial(color, intensity: 0.6)]
    let shaftNode = SCNNode(geometry: shaft)
    shaftNode.position = SCNVector3(0, 0.09, 0)
    node.addChildNode(shaftNode)

    let billboard = SCNBillboardConstraint()
    billboard.freeAxes = .Y
    node.constraints = [billboard]
    // 통통 튀며 "여기를 보라"는 힌트임을 알린다.
    node.runAction(.repeatForever(.sequence([
      .moveBy(x: 0, y: 0.05, z: 0, duration: 0.45),
      .moveBy(x: 0, y: -0.05, z: 0, duration: 0.45),
    ])))
    return node
  }

  /// 풀숲 — 숨은 도깨비의 기척. 거리에 따라 Dart가 크기를 키운다(흔들림 연출).
  private func grassNode(color: UIColor) -> SCNNode {
    let node = SCNNode()
    for i in 0..<5 {
      let blade = SCNCylinder(radius: 0.012, height: 0.22)
      blade.materials = [glowMaterial(color, intensity: 0.35)]
      let b = SCNNode(geometry: blade)
      let a = Float(i) * 1.26
      b.position = SCNVector3(cos(a) * 0.07, 0.11, sin(a) * 0.07)
      b.eulerAngles.z = (Float(i % 3) - 1) * 0.18
      // 좌우로 흔들린다 — "무언가 숨어 있다"는 느낌은 이 움직임에서 나온다.
      b.runAction(.repeatForever(.sequence([
        .rotateBy(x: 0, y: 0, z: 0.16, duration: 0.7 + Double(i) * 0.08),
        .rotateBy(x: 0, y: 0, z: -0.16, duration: 0.7 + Double(i) * 0.08),
      ])))
      node.addChildNode(b)
    }
    return node
  }

  /// 범용/하위호환 — 캐릭터 그림을 항상 카메라를 향하는 평면에 텍스처로 붙인다.
  /// (v1의 피라미드는 사람 형상 이미지를 입체에 입힐 수 없어 빌보드 판으로 교체)
  /// imageAsset(장소 도깨비)을 못 읽으면 기본 캐릭터 DokkaebiCharacter(기본 소년 도깨비와 같은 그림).
  /// 판의 발끝을 마커 위치(바닥)에 맞춘다 — 전엔 판 가운데가 바닥이라 아래 절반이 바닥에 묻혔다.
  private func beaconNode(imageAsset: String?) -> SCNNode {
    let image = imageAsset.flatMap { flutterAssetImage($0) } ?? UIImage(named: "DokkaebiCharacter")
    let heightOverWidth: CGFloat = image.map { $0.size.height / max($0.size.width, 1) }
      ?? 768.0 / 573.0 // DokkaebiCharacter.png(기본 소년 도깨비) 픽셀 비율
    let height: CGFloat = 1.0  // 도깨비 키(m) — 아이 키만큼 보여야 눈에 띈다
    let geo = SCNPlane(width: height / heightOverWidth, height: height)
    let mat = SCNMaterial()
    mat.diffuse.contents = image
    mat.isDoubleSided = true
    mat.lightingModel = .constant
    geo.materials = [mat]
    let plane = SCNNode(geometry: geo)
    plane.position = SCNVector3(0, Float(height / 2), 0)
    let billboard = SCNBillboardConstraint()
    billboard.freeAxes = .Y
    plane.constraints = [billboard]
    let node = SCNNode()
    node.addChildNode(plane)
    node.runAction(.repeatForever(.sequence([
      .moveBy(x: 0, y: 0.04, z: 0, duration: 1.6),
      .moveBy(x: 0, y: -0.04, z: 0, duration: 1.6),
    ])))
    return node
  }

  /// Flutter 에셋(pubspec에 등록한 경로)을 앱 번들에서 읽는다.
  private func flutterAssetImage(_ asset: String) -> UIImage? {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
    return UIImage(contentsOfFile: path)
  }

  /// 도깨비불 — 에셋 그림(민트색 불꽃 캐릭터) 빌보드 + 은은한 점광원. 그림이 없으면 발광 구체.
  /// 부유감은 자식 판만 움직인다 — 마커 노드(=판정 중심)는 그대로라 조준 각이 흔들리지 않는다.
  private func fireNode(imageAsset: String?, color: UIColor) -> SCNNode {
    let node = SCNNode()
    let visual: SCNNode
    if let image = imageAsset.flatMap({ flutterAssetImage($0) }) {
      // 2.4m 거리에서 약 7° — 조준 원(6° 반경=12° 지름) 안에 그림이 통째로 들어가야
      // "원 안에 있다"와 "판정 안이다"가 같은 말이 된다. 원본 캔버스 여백 포함.
      let size: CGFloat = 0.30
      let geo = SCNPlane(width: size, height: size)
      let mat = SCNMaterial()
      mat.diffuse.contents = image
      mat.isDoubleSided = true
      mat.lightingModel = .constant
      mat.blendMode = .alpha
      mat.writesToDepthBuffer = false   // 투명 가장자리가 뒤 마커를 가리지 않게
      geo.materials = [mat]
      visual = SCNNode(geometry: geo)
      visual.constraints = [SCNBillboardConstraint()]
    } else {
      let core = SCNSphere(radius: 0.09)
      let mat = SCNMaterial()
      mat.diffuse.contents = color
      mat.emission.contents = color
      mat.emission.intensity = 1.4
      mat.lightingModel = .constant
      core.materials = [mat]
      visual = SCNNode(geometry: core)
      let halo = SCNSphere(radius: 0.16)
      let hmat = SCNMaterial()
      hmat.diffuse.contents = color.withAlphaComponent(0.18)
      hmat.emission.contents = color
      hmat.emission.intensity = 0.5
      hmat.lightingModel = .constant
      hmat.transparency = 0.35
      hmat.isDoubleSided = true
      halo.materials = [hmat]
      visual.addChildNode(SCNNode(geometry: halo))
    }
    node.addChildNode(visual)

    // 이미지에 발광이 이미 들어 있어 점광원은 약하게(안내서: 추가 bloom 과하지 않게).
    let light = SCNLight()
    light.type = .omni
    light.color = color
    light.intensity = 120
    light.attenuationEndDistance = 1.6
    let lightNode = SCNNode()
    lightNode.light = light
    node.addChildNode(lightNode)

    visual.runAction(.repeatForever(.group([
      .sequence([.moveBy(x: 0, y: 0.03, z: 0, duration: 0.9), .moveBy(x: 0, y: -0.03, z: 0, duration: 0.9)]),
      .sequence([.scale(to: 1.05, duration: 0.7), .scale(to: 0.95, duration: 0.7)]),
    ])))
    return node
  }

  /// 흡수 연출(약 800ms) — 불꽃은 빠르게 줄며 사라지고, 같은 자리에 흡수 소용돌이 그림이
  /// 회전·축소·페이드된다(effectImage가 없으면 기존처럼 커졌다 줄어드는 연출). 텔레메트리 대상에서도 빠진다.
  private func absorbMarker(id: String, effectImage: String?) {
    guard let node = sceneView.scene.rootNode.childNode(withName: "marker:\(id)", recursively: false) else { return }
    markerPositions.removeValue(forKey: id)
    node.removeAllActions()
    node.childNodes.forEach { $0.removeAllActions() }
    guard let image = effectImage.flatMap({ flutterAssetImage($0) }) else {
      node.runAction(.sequence([
        .scale(to: 1.5, duration: 0.18),
        .group([.scale(to: 0.02, duration: 0.5), .fadeOut(duration: 0.5)]),
        .removeFromParentNode(),
      ]))
      return
    }
    // 불꽃: 0.25초 만에 흡수
    node.childNodes.forEach {
      $0.runAction(.group([.scale(to: 0.05, duration: 0.25), .fadeOut(duration: 0.25)]))
    }
    // 소용돌이: 같은 위치에 카메라를 향하는 판 — 회전하며 줄고 사라진다
    let size: CGFloat = 0.6
    let geo = SCNPlane(width: size, height: size)
    let mat = SCNMaterial()
    mat.diffuse.contents = image
    mat.isDoubleSided = true
    mat.lightingModel = .constant
    mat.blendMode = .alpha
    mat.writesToDepthBuffer = false
    geo.materials = [mat]
    let wisp = SCNNode(geometry: geo)
    wisp.position = node.position
    wisp.constraints = [SCNBillboardConstraint()]
    wisp.opacity = 0
    wisp.scale = SCNVector3(0.6, 0.6, 0.6)
    sceneView.scene.rootNode.addChildNode(wisp)
    wisp.runAction(.sequence([
      .group([.fadeIn(duration: 0.12), .scale(to: 1.0, duration: 0.12)]),
      .group([
        .rotateBy(x: 0, y: 0, z: -CGFloat.pi * 1.5, duration: 0.68),  // 빌보드 판의 z축 = 화면 회전
        .scale(to: 0.05, duration: 0.68),
        .sequence([.wait(duration: 0.3), .fadeOut(duration: 0.38)]),
      ]),
      .removeFromParentNode(),
    ]))
    node.runAction(.sequence([.wait(duration: 0.3), .removeFromParentNode()]))
  }

  private func textGeometry(_ text: String, color: UIColor) -> SCNText {
    let t = SCNText(string: text, extrusionDepth: 0.4)
    t.font = UIFont.boldSystemFont(ofSize: 20)
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.emission.contents = color
    t.materials = [mat]
    return t
  }

  private func removeMarker(id: String) {
    sceneView.scene.rootNode.childNode(withName: "marker:\(id)", recursively: false)?.removeFromParentNode()
    markerPositions.removeValue(forKey: id)
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    let point = gesture.location(in: sceneView)
    let hits = sceneView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
    for hit in hits {
      var n: SCNNode? = hit.node
      while let node = n {
        if let name = node.name, name.hasPrefix("marker:") {
          let id = String(name.dropFirst("marker:".count))
          channel.invokeMethod("markerTapped", arguments: id)
          return
        }
        n = node.parent
      }
    }
  }
}
