import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    GarminDeviceBridge.register(with: engineBridge.pluginRegistry)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    GarminDeviceBridge.shared.handleCallback(url)
      || super.application(app, open: url, options: options)
  }
}

final class GarminDeviceBridge {
  static let shared = GarminDeviceBridge()

  private static let channelName = "wristlink/garmin_devices"
  private static let callbackScheme = "wristlink-ciq"
  private static let gcmDeviceSelectUrl =
    "gcm-ciq://device-select?callback=wristlink-ciq://garmin-device-callback"

  private var pendingResult: FlutterResult?

  static func register(with pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "GarminDeviceBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "discoverDevices":
        shared.discoverDevices(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func discoverDevices(result: @escaping FlutterResult) {
    guard let deviceSelectionUrl = URL(string: Self.gcmDeviceSelectUrl) else {
      result(
        FlutterError(
          code: "nativeFailure",
          message: "Garmin device selection URL is invalid.",
          details: nil
        )
      )
      return
    }

    guard UIApplication.shared.canOpenURL(deviceSelectionUrl) else {
      result(
        FlutterError(
          code: "garminConnectMissing",
          message: "Garmin Connect Mobile is not installed.",
          details: nil
        )
      )
      return
    }

    pendingResult = result
    UIApplication.shared.open(deviceSelectionUrl)
    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
      guard let pendingResult = self?.pendingResult else { return }
      self?.pendingResult = nil
      pendingResult(
        FlutterError(
          code: "timeout",
          message: "Garmin device authorization timed out.",
          details: nil
        )
      )
    }
  }

  func handleCallback(_ url: URL) -> Bool {
    guard url.scheme == Self.callbackScheme else { return false }
    guard let pendingResult else { return true }
    self.pendingResult = nil

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let items = components?.queryItems ?? []
    if let cancelled = items.first(where: { $0.name == "cancelled" })?.value,
       cancelled == "true" {
      pendingResult(
        FlutterError(
          code: "authorizationCancelled",
          message: "Garmin device authorization was cancelled.",
          details: nil
        )
      )
      return true
    }

    let devices = items
      .filter { $0.name == "device" || $0.name == "devices[]" }
      .compactMap { item -> [String: Any?]? in
        guard let value = item.value, !value.isEmpty else { return nil }
        return [
          "id": value,
          "name": value,
          "unitId": value,
          "reachability": "unknown",
          "companionInstallState": "unknown",
        ]
      }

    if devices.isEmpty {
      pendingResult(
        FlutterError(
          code: "noAuthorizedDevices",
          message: "No authorized Garmin devices were returned.",
          details: nil
        )
      )
    } else {
      pendingResult(devices)
    }
    return true
  }
}
