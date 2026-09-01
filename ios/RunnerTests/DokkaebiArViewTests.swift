import XCTest
import simd
@testable import Runner

final class DokkaebiArViewTests: XCTestCase {

  private let accuracy: Float = 0.0001

  func testForwardOffsetWithIdentityCamera() {
    let pos = arMarkerWorldPosition(
      cameraTransform: matrix_identity_float4x4,
      forward: 1.6,
      right: 0,
      down: 0.2
    )
    // 카메라 기본 방향(-Z)으로 forward만큼, 아래로 down만큼.
    XCTAssertEqual(pos.x, 0, accuracy: accuracy)
    XCTAssertEqual(pos.y, -0.2, accuracy: accuracy)
    XCTAssertEqual(pos.z, -1.6, accuracy: accuracy)
  }

  func testForwardOffsetRotatesWithCameraYaw() {
    // 카메라가 Y축 기준 +90도 회전(오른쪽을 보는 상태)하면
    // "정면" 오프셋은 월드 -Z가 아니라 월드 -X 방향으로 나와야 한다.
    let yaw90 = simd_float4x4(simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0)))
    let pos = arMarkerWorldPosition(
      cameraTransform: yaw90,
      forward: 1.6,
      right: 0,
      down: 0
    )
    XCTAssertEqual(pos.x, -1.6, accuracy: accuracy)
    XCTAssertEqual(pos.y, 0, accuracy: accuracy)
    XCTAssertEqual(pos.z, 0, accuracy: accuracy)
  }

  func testNegativeRightAndDownPlaceMarkerLeftAndAbove() {
    let pos = arMarkerWorldPosition(
      cameraTransform: matrix_identity_float4x4,
      forward: 0,
      right: -0.5,
      down: -0.3
    )
    XCTAssertEqual(pos.x, -0.5, accuracy: accuracy) // right<0 → 왼쪽
    XCTAssertEqual(pos.y, 0.3, accuracy: accuracy)  // down<0 → 위쪽
    XCTAssertEqual(pos.z, 0, accuracy: accuracy)
  }

  func testOffsetIsRelativeToCameraWorldPosition() {
    var transform = matrix_identity_float4x4
    transform.columns.3 = SIMD4<Float>(2, 1, -3, 1)
    let pos = arMarkerWorldPosition(
      cameraTransform: transform,
      forward: 1,
      right: 0,
      down: 0
    )
    XCTAssertEqual(pos.x, 2, accuracy: accuracy)
    XCTAssertEqual(pos.y, 1, accuracy: accuracy)
    XCTAssertEqual(pos.z, -4, accuracy: accuracy)
  }
}
