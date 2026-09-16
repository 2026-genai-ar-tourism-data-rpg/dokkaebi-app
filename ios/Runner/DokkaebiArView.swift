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
// ============================================================
import ARKit
import Flutter
import SceneKit
import UIKit

/// 마커 종류 — 미션별로 그리는 모양이 다르다. Dart의 ArMarkerKind와 문자열이 같아야 한다.
enum ArMarkerKind: String {
  case footprint   // HUNT       — 바닥에 찍힌 발자국
  case part        // RESTORE_AR — 흩어진 부재(주춧돌·기둥)
  case pattern     // PHOTO_FIND — 벽면 문양(수직 판)
  case hidden      // FIND       — 숨은 도깨비 자리의 풀숲
  case beacon      // 범용 — v1의 피라미드 마커(하위호환 기본값)
}

/// 마커 표시 상태 — Dart가 거리·조준을 보고 지시한다.
enum ArMarkerState: String {
  case hidden      // 안 보임 (아직 발견 전)
  case ghost       // 흐릿함 (기척만)
  case solid       // 완전히 드러남
}

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
      state: ArMarkerState(rawValue: (dict["state"] as? String) ?? "") ?? .solid
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
      // 바닥을 이미 찾았으면 바닥에 앉힌다(발자국·부재는 공중에 뜨면 안 된다).
      if let y = floorY, spec.kind != .pattern { pos.y = y }

      let node = markerNode(spec: spec)
      node.simdPosition = pos
      node.name = "marker:\(spec.id)"
      sceneView.scene.rootNode.addChildNode(node)
      markerPositions[spec.id] = pos
      applyState(node: node, state: spec.state, scale: 1.0)

      // 등장 애니메이션. 발자국은 바닥에 찍히는 것이라 부유시키지 않는다.
      node.runAction(.scale(to: CGFloat(spec.state == .hidden ? 0.01 : 1.0), duration: 0.4))
      if spec.kind == .beacon || spec.kind == .part {
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
      p.y = y
      node.simdPosition = p
      markerPositions[spec.id] = p
    }
  }

  private func setMarkerState(id: String, state: ArMarkerState, scale: Float) {
    guard let node = sceneView.scene.rootNode.childNode(withName: "marker:\(id)", recursively: false) else { return }
    applyState(node: node, state: state, scale: scale)
  }

  /// 표시 상태를 실제 재질·크기에 반영. 상태 판단은 전부 Dart에 있다.
  private func applyState(node: SCNNode, state: ArMarkerState, scale: Float) {
    let opacity: CGFloat
    switch state {
    case .hidden: opacity = 0.0
    case .ghost: opacity = 0.28
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
    case .footprint: node = footprintNode(color: color)
    case .part: node = partNode(color: color)
    case .pattern: node = patternNode(color: color, label: spec.label)
    case .hidden: node = grassNode(color: color)
    case .beacon: node = beaconNode(color: color)
    }
    // 발자국·문양은 이름표가 오히려 방해된다(바닥에 붙은 자국 위에 글자가 뜬다).
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

  /// 발자국 — 바닥에 눕힌 납작한 타원. 걸어오면서 하나씩 켜지는 것이 HUNT의 핵심.
  private func footprintNode(color: UIColor) -> SCNNode {
    let geo = SCNPlane(width: 0.16, height: 0.30)
    geo.cornerRadius = 0.08
    geo.materials = [glowMaterial(color, intensity: 0.8)]
    let node = SCNNode(geometry: geo)
    node.eulerAngles.x = -Float.pi / 2   // 바닥에 눕힌다
    return node
  }

  /// 기억석 부재 — 모난 돌덩이.
  private func partNode(color: UIColor) -> SCNNode {
    let geo = SCNBox(width: 0.18, height: 0.14, length: 0.18, chamferRadius: 0.03)
    geo.materials = [glowMaterial(color)]
    return SCNNode(geometry: geo)
  }

  /// 문양 — 벽면에 걸린 수직 판. 가까이 가서 정면으로 겨눠야 "스캔"이 된다.
  private func patternNode(color: UIColor, label: String) -> SCNNode {
    let geo = SCNPlane(width: 0.4, height: 0.4)
    geo.cornerRadius = 0.02
    geo.materials = [glowMaterial(color, intensity: 0.4)]
    let node = SCNNode(geometry: geo)
    let billboard = SCNBillboardConstraint()
    billboard.freeAxes = .Y
    node.constraints = [billboard]
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

  /// v1의 피라미드 — 범용/하위호환.
  private func beaconNode(color: UIColor) -> SCNNode {
    let geo = SCNPyramid(width: 0.22, height: 0.26, length: 0.22)
    let mat = glowMaterial(color)
    mat.transparency = 0.92
    geo.materials = [mat]
    let node = SCNNode(geometry: geo)
    let spin = CABasicAnimation(keyPath: "rotation")
    spin.fromValue = NSValue(scnVector4: SCNVector4(0, 1, 0, 0))
    spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Float.pi * 2))
    spin.duration = 6
    spin.repeatCount = .infinity
    node.addAnimation(spin, forKey: "spin")
    return node
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
