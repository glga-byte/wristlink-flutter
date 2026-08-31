import Foundation

enum GarminBridgeMapping {
  static let unknownCompanionState = "unknown"
  static let unknownDeviceName = "Garmin device"

  static func companionInstallState(isInstalled: Bool?) -> String {
    guard let isInstalled else { return unknownCompanionState }
    return isInstalled ? "installed" : "missing"
  }

  static func reachability(rawValue: Int) -> String {
    switch rawValue {
    case 4:
      return "reachable"
    case 1, 2, 3:
      return "offline"
    default:
      return "unknown"
    }
  }

  static func devicePayload(
    id: String,
    name: String?,
    modelName: String?,
    family: String?,
    unitId: String?,
    statusRawValue: Int,
    companionInstallState: String
  ) -> [String: Any?] {
    [
      "id": id,
      "name": nonBlank(name) ?? nonBlank(modelName) ?? unknownDeviceName,
      "modelName": nonBlank(modelName),
      "family": nonBlank(family),
      "unitId": nonBlank(unitId),
      "reachability": reachability(rawValue: statusRawValue),
      "companionInstallState": companionInstallState,
    ]
  }

  private static func nonBlank(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
      !value.isEmpty
    else {
      return nil
    }
    return value
  }
}

struct GarminTransportError: Equatable {
  let code: String
  let message: String
}

enum GarminTransportMapping {
  // IQSendMessageResult values are stable SDK constants. Keeping the pure mapping
  // raw-value based makes it testable without constructing SDK-owned objects.
  static func errorFor(resultRawValue: Int) -> GarminTransportError? {
    switch resultRawValue {
    case 0:
      return nil
    case 3:
      return GarminTransportError(
        code: "deviceUnavailable",
        message: "The selected Garmin device is unavailable."
      )
    case 4:
      return GarminTransportError(
        code: "appNotInstalled",
        message: "The WristLink companion app is not installed on the selected Garmin device."
      )
    case 7:
      // The iOS SDK reports an app-message that cannot fit on the device as
      // insufficient memory; this is its equivalent of Android's too-large result.
      return GarminTransportError(
        code: "payloadTooLarge",
        message: "The Garmin app-message payload is too large."
      )
    default:
      return GarminTransportError(
        code: "nativeFailure",
        message: "Garmin message transport failed (result \(resultRawValue))."
      )
    }
  }

  static func rawMessageMaps(_ message: Any) -> [[AnyHashable: Any]] {
    if let map = message as? [AnyHashable: Any] {
      return [map]
    }
    guard let messages = message as? [Any] else { return [] }
    return messages.compactMap { $0 as? [AnyHashable: Any] }
  }

  static func deliverRawMessageMaps(
    _ message: Any,
    deliver: ([AnyHashable: Any]) -> Void
  ) {
    rawMessageMaps(message).forEach(deliver)
  }
}

final class OneShotCompletion {
  private let lock = NSLock()
  private var completed = false

  var isCompleted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return completed
  }

  @discardableResult
  func run(_ completion: () -> Void) -> Bool {
    lock.lock()
    guard !completed else {
      lock.unlock()
      return false
    }
    completed = true
    lock.unlock()
    completion()
    return true
  }
}

struct GarminSendArguments {
  let deviceId: String
  let message: [AnyHashable: Any]

  static func parse(_ arguments: Any?) -> GarminSendArguments? {
    guard
      let argumentMap = arguments as? [AnyHashable: Any],
      let rawDeviceId = argumentMap["deviceId"] as? String,
      !rawDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let message = argumentMap["message"] as? [AnyHashable: Any]
    else {
      return nil
    }
    return GarminSendArguments(
      deviceId: rawDeviceId.trimmingCharacters(in: .whitespacesAndNewlines),
      message: message
    )
  }
}

enum GarminNativeDeviceLookup {
  static func byRawUUID<Device>(
    _ rawDeviceId: String,
    in devices: [UUID: Device]
  ) -> Device? {
    guard let uuid = UUID(uuidString: rawDeviceId) else { return nil }
    return devices[uuid]
  }
}

struct GarminTransportDeviceDescriptor: Equatable {
  let id: UUID
  let friendlyName: String
  let modelName: String
  let partNumber: String

  static func parseList(_ arguments: Any?) -> [GarminTransportDeviceDescriptor]? {
    guard
      let argumentMap = arguments as? [AnyHashable: Any],
      let rawDevices = argumentMap["devices"] as? [Any]
    else {
      return nil
    }

    var deviceIds = Set<UUID>()
    var descriptors = [GarminTransportDeviceDescriptor]()
    descriptors.reserveCapacity(rawDevices.count)
    for rawDevice in rawDevices {
      guard
        let descriptor = parse(rawDevice),
        deviceIds.insert(descriptor.id).inserted
      else {
        return nil
      }
      descriptors.append(descriptor)
    }
    return descriptors
  }

  private static func parse(_ rawDevice: Any) -> GarminTransportDeviceDescriptor? {
    guard
      let device = rawDevice as? [AnyHashable: Any],
      let rawId = nonBlank(device["id"]),
      let id = UUID(uuidString: rawId),
      let friendlyName = nonBlank(device["name"])
    else {
      return nil
    }
    return GarminTransportDeviceDescriptor(
      id: id,
      friendlyName: friendlyName,
      modelName: nonBlank(device["modelName"]) ?? friendlyName,
      partNumber: nonBlank(device["partNumber"]) ?? ""
    )
  }

  private static func nonBlank(_ value: Any?) -> String? {
    guard
      let value = value as? String,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

protocol GarminSendTimeout {
  func cancel()
}

final class ClosureGarminSendTimeout: GarminSendTimeout {
  private let cancellation: () -> Void

  init(_ cancellation: @escaping () -> Void) {
    self.cancellation = cancellation
  }

  func cancel() {
    cancellation()
  }
}

/// Pure transport orchestration used by the iOS bridge.
///
/// Device/app values remain SDK-owned and opaque. Dart owns contract validation,
/// acknowledgement parsing, correlation, and queue policy.
final class GarminSendCoordinator<Device, App> {
  typealias Completion = (GarminTransportError?) -> Void

  private let isSdkReady: () -> Bool
  private let findDevice: (String) -> Device?
  private let findApp: (Device) -> App?
  private let scheduleTimeout: (@escaping () -> Void) -> GarminSendTimeout
  private let send: (Device, App, [AnyHashable: Any], @escaping Completion) -> Void

  init(
    isSdkReady: @escaping () -> Bool,
    findDevice: @escaping (String) -> Device?,
    findApp: @escaping (Device) -> App?,
    scheduleTimeout: @escaping (@escaping () -> Void) -> GarminSendTimeout,
    send: @escaping (Device, App, [AnyHashable: Any], @escaping Completion) -> Void
  ) {
    self.isSdkReady = isSdkReady
    self.findDevice = findDevice
    self.findApp = findApp
    self.scheduleTimeout = scheduleTimeout
    self.send = send
  }

  func execute(arguments: Any?, completion: @escaping Completion) {
    guard let arguments = GarminSendArguments.parse(arguments) else {
      completion(
        GarminTransportError(
          code: "nativeFailure",
          message: "Garmin send requires a deviceId and normalized message map."
        )
      )
      return
    }
    guard isSdkReady() else {
      completion(
        GarminTransportError(
          code: "sdkUnavailable",
          message: "Garmin Connect IQ Mobile SDK is not ready."
        )
      )
      return
    }
    guard let device = findDevice(arguments.deviceId) else {
      completion(
        GarminTransportError(
          code: "deviceUnavailable",
          message: "The selected Garmin device is no longer available."
        )
      )
      return
    }
    guard let app = findApp(device) else {
      completion(
        GarminTransportError(
          code: "appNotInstalled",
          message: "The WristLink companion app is not installed on the selected Garmin device."
        )
      )
      return
    }

    let oneShot = OneShotCompletion()
    let timeout = scheduleTimeout {
      oneShot.run {
        completion(
          GarminTransportError(
            code: "transportTimeout",
            message: "Garmin message transport timed out."
          )
        )
      }
    }
    send(device, app, arguments.message) { error in
      oneShot.run {
        timeout.cancel()
        completion(error)
      }
    }
  }
}
