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

  func testTransportMappingUsesTypedGatewayCodes() {
    XCTAssertNil(GarminTransportMapping.errorFor(resultRawValue: 0))
    XCTAssertEqual(
      GarminTransportMapping.errorFor(resultRawValue: 3)?.code,
      "deviceUnavailable"
    )
    XCTAssertEqual(
      GarminTransportMapping.errorFor(resultRawValue: 4)?.code,
      "appNotInstalled"
    )
    XCTAssertEqual(
      GarminTransportMapping.errorFor(resultRawValue: 7)?.code,
      "payloadTooLarge"
    )
    XCTAssertEqual(
      GarminTransportMapping.errorFor(resultRawValue: 999)?.code,
      "nativeFailure"
    )
  }

  func testEverySdkSendFailureHasAnExplicitGatewayMapping() {
    let expectedCodes: [Int: String?] = [
      0: nil,
      1: "nativeFailure",
      2: "nativeFailure",
      3: "deviceUnavailable",
      4: "appNotInstalled",
      5: "nativeFailure",
      6: "nativeFailure",
      7: "payloadTooLarge",
      8: "nativeFailure",
      9: "nativeFailure",
      10: "nativeFailure",
      11: "nativeFailure",
    ]

    for (rawValue, expectedCode) in expectedCodes {
      XCTAssertEqual(
        GarminTransportMapping.errorFor(resultRawValue: rawValue)?.code,
        expectedCode
      )
    }
  }

  func testRawAcknowledgementMappingKeepsOnlyAppMessageMaps() {
    let direct = GarminTransportMapping.rawMessageMaps(["id": "message-1"])
    XCTAssertEqual(direct.count, 1)
    XCTAssertEqual(direct.first?["id"] as? String, "message-1")

    let batched = GarminTransportMapping.rawMessageMaps([
      ["id": "message-2"],
      "ignored",
      ["id": "message-3"],
    ])
    XCTAssertEqual(batched.count, 2)
    XCTAssertEqual(batched[0]["id"] as? String, "message-2")
    XCTAssertEqual(batched[1]["id"] as? String, "message-3")
  }

  func testRawAcknowledgementDeliveryPreservesDuplicatesForDart() {
    let acknowledgement: [AnyHashable: Any] = [
      "id": "ack-1",
      7: "invalid-key-for-Dart-diagnostics",
    ]
    var delivered = [[AnyHashable: Any]]()

    GarminTransportMapping.deliverRawMessageMaps(
      ["ignored", acknowledgement, acknowledgement],
      deliver: { delivered.append($0) }
    )

    XCTAssertEqual(delivered.count, 2)
    XCTAssertEqual(delivered[0]["id"] as? String, "ack-1")
    XCTAssertEqual(delivered[1][7] as? String, "invalid-key-for-Dart-diagnostics")
  }

  func testSendArgumentValidationHappensBeforeSdkLookup() {
    let invalidArguments: [Any?] = [
      nil,
      "not-a-map",
      [String: Any](),
      ["deviceId": "watch-1"],
      ["deviceId": " ", "message": [String: Any]()],
      ["deviceId": "watch-1", "message": "not-a-map"],
    ]

    for arguments in invalidArguments {
      let harness = SwiftGarminSendHarness()

      harness.execute(arguments)

      XCTAssertEqual(harness.completions.first??.code, "nativeFailure")
      XCTAssertEqual(harness.deviceLookupCount, 0)
      XCTAssertEqual(harness.appLookupCount, 0)
      XCTAssertFalse(harness.sendInvoked)
    }
  }

  func testIOSDiscoveryIdResolvesTheMatchingUUIDNativeCacheEntry() throws {
    let fixture = try loadRoundTripFixture(platform: "ios")
    let discoveryPayload = fixture["discoveryPayload"] as! [String: Any]
    let rawDeviceId = fixture["rawDeviceId"] as! String
    let canonicalDeviceId = fixture["canonicalDeviceId"] as! String

    XCTAssertEqual(discoveryPayload["id"] as? String, rawDeviceId)
    XCTAssertEqual(canonicalDeviceId, "physical:\(rawDeviceId)")

    let uuid = try XCTUnwrap(UUID(uuidString: rawDeviceId))
    let cachedDevice = NSObject()
    let cachedApp = NSObject()
    let deviceCache = [uuid: cachedDevice]
    var sentDevice: NSObject?
    let coordinator = GarminSendCoordinator<NSObject, NSObject>(
      isSdkReady: { true },
      findDevice: { rawId in
        GarminNativeDeviceLookup.byRawUUID(rawId, in: deviceCache)
      },
      findApp: { _ in cachedApp },
      scheduleTimeout: { _ in ClosureGarminSendTimeout {} },
      send: { device, _, _, completion in
        sentDevice = device
        completion(nil)
      }
    )

    coordinator.execute(
      arguments: ["deviceId": rawDeviceId, "message": ["v": 1]]
    ) { error in
      XCTAssertNil(error)
    }

    XCTAssertTrue(sentDevice === cachedDevice)
  }

  func testHydrationDescriptorsRestoreDartOwnedIOSDeviceMetadata() throws {
    let rawId = "ad5d9a2e-2f51-4f20-a1c6-70cb988ac560"
    let descriptors = try XCTUnwrap(
      GarminTransportDeviceDescriptor.parseList([
        "devices": [
          [
            "id": rawId,
            "name": "  Ilias's Forerunner  ",
            "modelName": " Forerunner 965 ",
            "partNumber": " 006-B4321-00 ",
            "unitId": rawId,
          ]
        ]
      ])
    )

    XCTAssertEqual(
      descriptors,
      [
        GarminTransportDeviceDescriptor(
          id: try XCTUnwrap(UUID(uuidString: rawId)),
          friendlyName: "Ilias's Forerunner",
          modelName: "Forerunner 965",
          partNumber: "006-B4321-00"
        )
      ]
    )
  }

  func testHydrationDescriptorsSupportMissingOptionalNativeMetadata() throws {
    let rawId = "ad5d9a2e-2f51-4f20-a1c6-70cb988ac560"
    let descriptor = try XCTUnwrap(
      GarminTransportDeviceDescriptor.parseList([
        "devices": [["id": rawId, "name": "Venu"]]
      ])?.first
    )

    XCTAssertEqual(descriptor.friendlyName, "Venu")
    XCTAssertEqual(descriptor.modelName, "Venu")
    XCTAssertEqual(descriptor.partNumber, "")
  }

  func testHydrationDescriptorsRejectNonRawOrDuplicateDeviceIds() {
    let rawId = "ad5d9a2e-2f51-4f20-a1c6-70cb988ac560"
    let invalidArguments: [Any?] = [
      nil,
      ["devices": "not-a-list"],
      ["devices": [["id": "physical:\(rawId)", "name": "Forerunner"]]],
      ["devices": [["id": "not-a-uuid", "name": "Forerunner"]]],
      ["devices": [["id": rawId, "name": " "]]],
      [
        "devices": [
          ["id": rawId, "name": "Forerunner"],
          ["id": rawId, "name": "Forerunner duplicate"],
        ]
      ],
    ]

    for arguments in invalidArguments {
      XCTAssertNil(GarminTransportDeviceDescriptor.parseList(arguments))
    }
  }

  func testHydrationDescriptorsAllowDartToClearAuthorizedDevices() {
    XCTAssertEqual(
      GarminTransportDeviceDescriptor.parseList(["devices": [Any]()]),
      []
    )
  }

  func testSdkDeviceAndAppLookupFailuresDoNotSend() {
    let sdkUnavailable = SwiftGarminSendHarness(sdkReady: false)
    sdkUnavailable.execute(validSendArguments())
    XCTAssertEqual(sdkUnavailable.completions.first??.code, "sdkUnavailable")
    XCTAssertEqual(sdkUnavailable.deviceLookupCount, 0)

    let missingDevice = SwiftGarminSendHarness(device: nil)
    missingDevice.execute(validSendArguments())
    XCTAssertEqual(missingDevice.completions.first??.code, "deviceUnavailable")
    XCTAssertEqual(missingDevice.lookedUpDeviceIds, ["watch-1"])
    XCTAssertEqual(missingDevice.appLookupCount, 0)

    let missingApp = SwiftGarminSendHarness(app: nil)
    missingApp.execute(validSendArguments())
    XCTAssertEqual(missingApp.completions.first??.code, "appNotInstalled")
    XCTAssertEqual(missingApp.deviceLookupCount, 1)
    XCTAssertEqual(missingApp.appLookupCount, 1)

    XCTAssertFalse(sdkUnavailable.sendInvoked)
    XCTAssertFalse(missingDevice.sendInvoked)
    XCTAssertFalse(missingApp.sendInvoked)
  }

  func testSuccessfulSendCompletesOnceWithNormalizedMap() {
    let harness = SwiftGarminSendHarness()
    let arguments = validSendArguments(message: ["v": 1, "kind": "point"])

    harness.execute(arguments)
    harness.callback(nil)

    XCTAssertTrue(harness.sendInvoked)
    XCTAssertEqual(harness.sentMessage?["v"] as? Int, 1)
    XCTAssertEqual(harness.sentMessage?["kind"] as? String, "point")
    XCTAssertEqual(harness.completions.count, 1)
    XCTAssertNil(harness.completions[0])
    XCTAssertEqual(harness.timeout.cancelCount, 1)
  }

  func testDuplicateSdkCallbacksCompleteExactlyOnce() {
    let harness = SwiftGarminSendHarness()
    harness.execute(validSendArguments())

    harness.callback(nil)
    harness.callback(GarminTransportError(code: "nativeFailure", message: "late"))

    XCTAssertEqual(harness.completions.count, 1)
    XCTAssertNil(harness.completions[0])
    XCTAssertEqual(harness.timeout.cancelCount, 1)
  }

  func testTimeoutWinsRaceAndLateCallbackCannotCompleteAgain() {
    let harness = SwiftGarminSendHarness()
    harness.execute(validSendArguments())

    harness.timeout.fire()
    harness.callback(nil)

    XCTAssertEqual(harness.completions.count, 1)
    XCTAssertEqual(harness.completions.first??.code, "transportTimeout")
    XCTAssertTrue(harness.completions.first??.message.contains("timed out") == true)
    XCTAssertEqual(harness.timeout.cancelCount, 0)
  }

  private func validSendArguments(
    message: [AnyHashable: Any] = ["v": 1]
  ) -> [AnyHashable: Any] {
    ["deviceId": "watch-1", "message": message]
  }
}

private func loadRoundTripFixture(platform: String) throws -> [String: Any] {
  let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let fixtureURL =
    repositoryRoot
    .appendingPathComponent("test/fixtures/garmin_device_id_round_trip.json")
  let data = try Data(contentsOf: fixtureURL)
  let root = try XCTUnwrap(
    JSONSerialization.jsonObject(with: data) as? [String: Any]
  )
  let cases = try XCTUnwrap(root["cases"] as? [[String: Any]])
  return try XCTUnwrap(cases.first { $0["platform"] as? String == platform })
}

private final class SwiftGarminSendHarness {
  let sdkReady: Bool
  let device: String?
  let app: String?
  let timeout = SwiftFakeGarminSendTimeout()
  var completions = [GarminTransportError?]()
  var lookedUpDeviceIds = [String]()
  var deviceLookupCount = 0
  var appLookupCount = 0
  var sendInvoked = false
  var sentMessage: [AnyHashable: Any]?
  private var sendCallback: ((GarminTransportError?) -> Void)?

  private lazy var coordinator = GarminSendCoordinator<String, String>(
    isSdkReady: { [unowned self] in self.sdkReady },
    findDevice: { [unowned self] deviceId in
      self.deviceLookupCount += 1
      self.lookedUpDeviceIds.append(deviceId)
      return self.device
    },
    findApp: { [unowned self] _ in
      self.appLookupCount += 1
      return self.app
    },
    scheduleTimeout: { [unowned self] callback in
      self.timeout.callback = callback
      return self.timeout
    },
    send: { [unowned self] _, _, message, callback in
      self.sendInvoked = true
      self.sentMessage = message
      self.sendCallback = callback
    }
  )

  init(
    sdkReady: Bool = true,
    device: String? = "device",
    app: String? = "app"
  ) {
    self.sdkReady = sdkReady
    self.device = device
    self.app = app
  }

  func execute(_ arguments: Any?) {
    coordinator.execute(arguments: arguments) { [unowned self] error in
      self.completions.append(error)
    }
  }

  func callback(_ error: GarminTransportError?) {
    sendCallback?(error)
  }
}

private final class SwiftFakeGarminSendTimeout: GarminSendTimeout {
  var callback: (() -> Void)?
  var cancelCount = 0

  func cancel() {
    cancelCount += 1
  }

  func fire() {
    callback?()
  }
}
