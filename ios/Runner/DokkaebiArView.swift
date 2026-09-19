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
    let camPos = simd_make_float3(camTransform.columns.3)
    let payload: [[String: Any]] = markerPositions.map { id, pos in
      [
        "id": id,
        "dist": Double(simd_distance(camPos, pos)),
        "aim": Double(arAimError(cameraTransform: camTransform, target: pos)),
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

  // MARK: - 마커 배치·탭

  private func placeMarkers(cameraTransform: simd_float4x4) {
    for spec in markerSpecs {
      var pos = arMarkerWorldPosition(
        cameraTransform: cameraTransform,
        forward: spec.forward,
        right: spec.right,
        down: spec.down
      )
      // 바닥을 이미 찾았으면 바닥에 앉힌다(부재·도깨비는 공중에 뜨면 안 된다. 엽전은 바닥 위로 띄운다).
      if let y = floorY, spec.kind != .pattern { pos.y = floorHeight(y, for: spec.kind) }

      let node = markerNode(spec: spec)
      node.simdPosition = pos
      node.name = "marker:\(spec.id)"
      sceneView.scene.rootNode.addChildNode(node)
      markerPositions[spec.id] = pos
      applyState(node: node, state: spec.state, scale: 1.0, kind: spec.kind)

      // 등장 애니메이션 + 은은한 오르내림(떠 있는 것들).
      node.runAction(.scale(to: CGFloat(spec.state == .hidden ? 0.01 : 1.0), duration: 0.4))
      if spec.kind == .beacon || spec.kind == .part || spec.kind == .coin {
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
    for spec in markerSpecs where spec.kind != .pattern {
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
