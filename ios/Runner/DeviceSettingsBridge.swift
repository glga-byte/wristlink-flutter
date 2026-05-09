import Flutter
import Foundation

final class DeviceSettingsBridge {
  private static let channelName = "wristlink/device_settings"
  private static let suiteName = "wristlink_device_settings"

  static func register(with pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "DeviceSettingsBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      let key = arguments?["key"] as? String
      let defaults = UserDefaults(suiteName: suiteName) ?? .standard
      switch call.method {
      case "readString":
        result(key.flatMap { defaults.string(forKey: $0) })
      case "writeString":
        if let key, let value = arguments?["value"] as? String {
          defaults.set(value, forKey: key)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
