import XCTest
@testable import Runner

final class GarminBridgeMappingTests: XCTestCase {
  func testCompanionInstallStateMapping() {
    XCTAssertEqual(GarminBridgeMapping.companionInstallState(isInstalled: true), "installed")
    XCTAssertEqual(GarminBridgeMapping.companionInstallState(isInstalled: false), "missing")
    XCTAssertEqual(GarminBridgeMapping.companionInstallState(isInstalled: nil), "unknown")
  }

  func testReachabilityMapping() {
    XCTAssertEqual(GarminBridgeMapping.reachability(rawValue: 4), "reachable")
    XCTAssertEqual(GarminBridgeMapping.reachability(rawValue: 1), "offline")
    XCTAssertEqual(GarminBridgeMapping.reachability(rawValue: 2), "offline")
    XCTAssertEqual(GarminBridgeMapping.reachability(rawValue: 3), "offline")
    XCTAssertEqual(GarminBridgeMapping.reachability(rawValue: 999), "unknown")
  }

  func testDevicePayloadUsesSharedMetadataKeys() {
    let payload = GarminBridgeMapping.devicePayload(
      id: "watch-1",
      name: "Forerunner",
      modelName: "Forerunner 965",
      family: "006-B1234-00",
      unitId: "watch-1",
      statusRawValue: 4,
      companionInstallState: "installed"
    )

    XCTAssertEqual(payload["id"] as? String, "watch-1")
    XCTAssertEqual(payload["name"] as? String, "Forerunner")
    XCTAssertEqual(payload["modelName"] as? String, "Forerunner 965")
    XCTAssertEqual(payload["family"] as? String, "006-B1234-00")
    XCTAssertEqual(payload["unitId"] as? String, "watch-1")
    XCTAssertEqual(payload["reachability"] as? String, "reachable")
    XCTAssertEqual(payload["companionInstallState"] as? String, "installed")
  }

  func testDevicePayloadFallsBackToStableName() {
    let payload = GarminBridgeMapping.devicePayload(
      id: "watch-1",
      name: " ",
      modelName: nil,
      family: nil,
      unitId: "watch-1",
      statusRawValue: 0,
      companionInstallState: "unknown"
    )

    XCTAssertEqual(payload["name"] as? String, "Garmin device")
    XCTAssertNil(payload["modelName"] as? String)
    XCTAssertNil(payload["family"] as? String)
    XCTAssertEqual(payload["reachability"] as? String, "unknown")
  }

  func testOneShotCompletionRunsOnlyOnce() {
    let completion = OneShotCompletion()
    var count = 0

    XCTAssertTrue(completion.run { count += 1 })
    XCTAssertFalse(completion.run { count += 1 })

    XCTAssertEqual(count, 1)
    XCTAssertTrue(completion.isCompleted)
  }
}
