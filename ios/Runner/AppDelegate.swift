import ConnectIQ
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GarminDeviceBridge.shared.initializeSdk()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    GarminDeviceBridge.register(with: engineBridge.pluginRegistry)
    DeviceSettingsBridge.register(with: engineBridge.pluginRegistry)
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

final class GarminDeviceBridge: NSObject, IQUIOverrideDelegate, IQDeviceEventDelegate {
  static let shared = GarminDeviceBridge()

  private static let channelName = "wristlink/garmin_devices"
  private static let eventChannelName = "wristlink/garmin_device_events"
  private static let callbackScheme = "wristlink-ciq"
  private static let connectIqAppIdPlaceholder =
    "00000000-0000-0000-0000-000000000000"

  private var pendingResult: FlutterResult?
  private var pendingRequestId: UUID?
  private var latestDevices: [UUID: IQDevice] = [:]
  private var latestCompanionStates: [UUID: String] = [:]
  private var eventSink: FlutterEventSink?

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
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(shared)
  }

  func initializeSdk() {
    ConnectIQ.sharedInstance().initialize(
      withUrlScheme: Self.callbackScheme,
      uiOverrideDelegate: self,
      stateRestorationIdentifier: Self.callbackScheme
    )
  }

  func discoverDevices(result: @escaping FlutterResult) {
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "nativeFailure",
          message: "Garmin device discovery is already in progress.",
          details: nil
        )
      )
      return
    }

    let requestId = UUID()
    pendingRequestId = requestId
    pendingResult = result
    ConnectIQ.sharedInstance().showDeviceSelection()
    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
      guard
        let self,
        self.pendingRequestId == requestId,
        let pendingResult = self.pendingResult
      else {
        return
      }
      self.pendingRequestId = nil
      self.pendingResult = nil
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
    pendingRequestId = nil
    self.pendingResult = nil

    if isCancellationCallback(url) {
      pendingResult(
        FlutterError(
          code: "authorizationCancelled",
          message: "Garmin device authorization was cancelled.",
          details: nil
        )
      )
      return true
    }

    let parsedDevices = ConnectIQ.sharedInstance()
      .parseDeviceSelectionResponse(from: url) as? [IQDevice]
    guard let devices = parsedDevices, !devices.isEmpty else {
      pendingResult(
        FlutterError(
          code: "noAuthorizedDevices",
          message: "No authorized Garmin devices were returned.",
          details: nil
        )
      )
      return true
    }

    latestDevices.removeAll()
    for device in devices {
      latestDevices[device.uuid] = device
      ConnectIQ.sharedInstance().register(forDeviceEvents: device, delegate: self)
    }
    mapDevicesWithCompanionState(devices, result: pendingResult)
    return true
  }

  private func isCancellationCallback(_ url: URL) -> Bool {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems ?? []
    return items.contains { item in
      let name = item.name.lowercased()
      let value = item.value?.lowercased()
      return (name == "cancelled" || name == "canceled" || name == "cancel")
        && (value == nil || value == "true" || value == "1")
        || (name == "status" && (value == "cancelled" || value == "canceled"))
    }
  }

  func needsToInstallConnectMobile() {
    guard let pendingResult else { return }
    pendingRequestId = nil
    self.pendingResult = nil
    pendingResult(
      FlutterError(
        code: "garminConnectMissing",
        message: "Garmin Connect Mobile is not installed.",
        details: nil
      )
    )
  }

  func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
    latestDevices[device.uuid] = device
    emitDeviceUpdate(device, status: status)
  }

  func deviceCharacteristicsDiscovered(_ device: IQDevice) {
    latestDevices[device.uuid] = device
  }

  private func mapDevicesWithCompanionState(
    _ devices: [IQDevice],
    result: @escaping FlutterResult
  ) {
    guard let appId = connectIqAppId() else {
      for device in devices {
        latestCompanionStates[device.uuid] = "unknown"
      }
      result(devices.map { mapDevice($0, companionInstallState: "unknown") })
      return
    }

    var states: [UUID: String] = [:]
    var remaining = devices.count
    var finished = false

    func finish() {
      guard !finished else { return }
      finished = true
      result(
        devices.map { device in
          latestCompanionStates[device.uuid] = states[device.uuid] ?? "unknown"
          mapDevice(
            device,
            companionInstallState: states[device.uuid] ?? "unknown"
          )
        }
      )
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      finish()
    }

    for device in devices {
      let app = IQApp(uuid: appId, store: appId, device: device)
      ConnectIQ.sharedInstance().getAppStatus(app) { status in
        states[device.uuid] = status?.isInstalled == true ? "installed" : "missing"
        self.latestCompanionStates[device.uuid] = states[device.uuid]
        remaining -= 1
        if remaining == 0 {
          finish()
        }
      }
    }
  }

  private func mapDevice(
    _ device: IQDevice,
    companionInstallState: String,
    status statusOverride: IQDeviceStatus? = nil
  ) -> [String: Any?] {
    let status = statusOverride ?? ConnectIQ.sharedInstance().getDeviceStatus(device)
    return [
      "id": device.uuid.uuidString,
      "name": device.friendlyName ?? device.modelName ?? "Garmin device",
      "modelName": device.modelName,
      "family": device.partNumber,
      "unitId": device.uuid.uuidString,
      "reachability": mapReachability(status),
      "companionInstallState": companionInstallState,
    ]
  }

  private func emitDeviceUpdate(_ device: IQDevice, status: IQDeviceStatus) {
    guard let eventSink else { return }
    guard let appId = connectIqAppId() else {
      eventSink(
        mapDevice(
          device,
          companionInstallState: latestCompanionStates[device.uuid] ?? "unknown",
          status: status
        )
      )
      return
    }

    let app = IQApp(uuid: appId, store: appId, device: device)
    ConnectIQ.sharedInstance().getAppStatus(app) { [weak self] appStatus in
      guard let self else { return }
      let companionState = appStatus?.isInstalled == true ? "installed" : "missing"
      self.latestCompanionStates[device.uuid] = companionState
      eventSink(
        self.mapDevice(
          device,
          companionInstallState: companionState,
          status: status
        )
      )
    }
  }

  private func mapReachability(_ status: IQDeviceStatus) -> String {
    switch status.rawValue {
    case 4:
      return "reachable"
    case 1, 2, 3:
      return "offline"
    default:
      return "unknown"
    }
  }

  private func connectIqAppId() -> UUID? {
    guard
      let value = Bundle.main.object(forInfoDictionaryKey: "WristLinkConnectIQAppUUID")
        as? String,
      !value.isEmpty,
      value != Self.connectIqAppIdPlaceholder
    else {
      return nil
    }
    return UUID(uuidString: value)
  }
}

extension GarminDeviceBridge: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

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
