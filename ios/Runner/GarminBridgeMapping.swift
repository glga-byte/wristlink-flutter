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

final class OneShotCompletion {
  private var completed = false

  var isCompleted: Bool {
    completed
  }

  @discardableResult
  func run(_ completion: () -> Void) -> Bool {
    guard !completed else { return false }
    completed = true
    completion()
    return true
  }
}
