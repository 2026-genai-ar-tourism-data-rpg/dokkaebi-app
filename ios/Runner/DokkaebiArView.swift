// ============================================================
// [v1] 네이티브 AR 뷰 — ArSearchScreen "스캔" 모드용 (Pokémon GO식 월드 트래킹)
// pipeline: 모바일 클라이언트 / iOS 네이티브 (Flutter PlatformView)
// 구현(요약): ar_flutter_plugin(3년 방치, pub.dev 정적분석 실패)에 기대지 않고
//            ARKit(ARSCNView)을 얇게 직접 감싼다. 실외 탐험 게임이라 바닥/평면
//            스캔을 요구하지 않고, 세션 시작 시점 카메라 위치 기준 고정 오프셋에
//            마커를 배치한다(평면 인식 불필요 — 실외에서 바닥 스캔 유도는 비현실적).
//            시뮬레이터는 ARKit 자체가 미지원이라 실기기에서만 동작 확인 가능.
// 구현일: 2026-08-31 | 작성: 정찬희
// ============================================================
import ARKit
import Flutter
import SceneKit
import UIKit

/// 마커 1개 정의 — Dart 쪽에서 creationParams로 전달.
private struct ArMarkerSpec {
  let id: String
  let label: String
  let colorHex: Int
  // 카메라 시작 위치 기준 상대 오프셋(미터). x=오른쪽+, y=위+, z=앞(카메라가 보는 방향)+.
  let forward: Float
  let right: Float
  let down: Float

  static func parse(_ dict: [String: Any]) -> ArMarkerSpec? {
    guard let id = dict["id"] as? String, let label = dict["label"] as? String else { return nil }
    return ArMarkerSpec(
      id: id,
      label: label,
      colorHex: (dict["color"] as? Int) ?? 0x2E7E76,
      forward: Float((dict["forward"] as? Double) ?? 1.6),
      right: Float((dict["right"] as? Double) ?? 0),
      down: Float((dict["down"] as? Double) ?? 0.2)
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

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    sceneView = ARSCNView(frame: frame)
    channel = FlutterMethodChannel(name: "dokkaebi/ar_view_\(viewId)", binaryMessenger: messenger)
    if let dict = args as? [String: Any], let rawMarkers = dict["markers"] as? [[String: Any]] {
      markerSpecs = rawMarkers.compactMap(ArMarkerSpec.parse)
    }
    super.init()

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
      case "dispose":
        self?.sceneView.session.pause()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let config = ARWorldTrackingConfiguration()
    config.planeDetection = [] // 실외 탐험용 — 바닥 스캔 요구 안 함, world tracking만 사용
    sceneView.session.run(config)
  }

  func view() -> UIView { sceneView }

  // MARK: - ARSCNViewDelegate

  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    guard !placed, !markerSpecs.isEmpty else { return }
    guard let frame = sceneView.session.currentFrame else { return }
    placed = true
    let camTransform = frame.camera.transform
    DispatchQueue.main.async { [weak self] in
      self?.placeMarkers(cameraTransform: camTransform)
    }
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    channel.invokeMethod("sessionError", arguments: error.localizedDescription)
  }

  // MARK: - 마커 배치·탭

  private func placeMarkers(cameraTransform: simd_float4x4) {
    for spec in markerSpecs {
      let pos = arMarkerWorldPosition(
        cameraTransform: cameraTransform,
        forward: spec.forward,
        right: spec.right,
        down: spec.down
      )

      let node = markerNode(spec: spec)
      node.simdPosition = pos
      node.name = "marker:\(spec.id)"
      sceneView.scene.rootNode.addChildNode(node)

      // 등장 애니메이션 + 살짝 위아래로 부유.
      node.scale = SCNVector3(0.01, 0.01, 0.01)
      node.runAction(.sequence([
        .scale(to: 1.0, duration: 0.4),
        .repeatForever(.sequence([
          .moveBy(x: 0, y: 0.06, z: 0, duration: 1.1),
          .moveBy(x: 0, y: -0.06, z: 0, duration: 1.1),
        ])),
      ]))
    }
    channel.invokeMethod("markersPlaced", arguments: markerSpecs.map { $0.id })
  }

  private func markerNode(spec: ArMarkerSpec) -> SCNNode {
    let color = UIColor(
      red: CGFloat((spec.colorHex >> 16) & 0xFF) / 255.0,
      green: CGFloat((spec.colorHex >> 8) & 0xFF) / 255.0,
      blue: CGFloat(spec.colorHex & 0xFF) / 255.0,
      alpha: 1.0
    )
    let geo = SCNPyramid(width: 0.22, height: 0.26, length: 0.22)
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.emission.contents = color
    mat.emission.intensity = 0.55
    mat.transparency = 0.92
    geo.materials = [mat]
    let node = SCNNode(geometry: geo)

    let spin = CABasicAnimation(keyPath: "rotation")
    spin.fromValue = NSValue(scnVector4: SCNVector4(0, 1, 0, 0))
    spin.toValue = NSValue(scnVector4: SCNVector4(0, 1, 0, Float.pi * 2))
    spin.duration = 6
    spin.repeatCount = .infinity
    node.addAnimation(spin, forKey: "spin")

    let labelNode = SCNNode(geometry: textGeometry(spec.label, color: color))
    labelNode.scale = SCNVector3(0.01, 0.01, 0.01)
    labelNode.position = SCNVector3(-Float(spec.label.count) * 0.6, 0.24, 0)
    node.addChildNode(labelNode)
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
