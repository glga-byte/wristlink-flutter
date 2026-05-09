import ConnectIQ
import Flutter
import UIKit

final class GarminDeviceBridge: NSObject, IQUIOverrideDelegate, IQDeviceEventDelegate {
  static let shared = GarminDeviceBridge()

  private static let channelName = "wristlink/garmin_devices"
  private static let eventChannelName = "wristlink/garmin_device_events"
  private static let callbackScheme = "wristlink-ciq"
  private static let connectIqAppIdPlaceholder =
    "00000000-0000-0000-0000-000000000000"

  private var pendingRequest: DiscoveryRequest?
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
    guard pendingRequest == nil else {
      result(
        FlutterError(
          code: "nativeFailure",
          message: "Garmin device discovery is already in progress.",
          details: nil
        )
      )
      return
    }

    let request = DiscoveryRequest(result: result)
    pendingRequest = request
    ConnectIQ.sharedInstance().showDeviceSelection()
    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self, requestId = request.id] in
      self?.completePendingRequest(requestId: requestId) { pendingResult in
        pendingResult(
          FlutterError(
            code: "timeout",
            message: "Garmin device authorization timed out.",
            details: nil
          )
        )
      }
    }
  }

  func handleCallback(_ url: URL) -> Bool {
    guard url.scheme == Self.callbackScheme else { return false }
    guard let request = pendingRequest else { return true }

    DispatchQueue.main.async { [weak self, requestId = request.id] in
      guard let self else { return }

      if self.isCancellationCallback(url) {
        self.completePendingRequest(requestId: requestId) { pendingResult in
          pendingResult(
            FlutterError(
              code: "authorizationCancelled",
              message: "Garmin device authorization was cancelled.",
              details: nil
            )
          )
        }
        return
      }

      let parsedDevices = ConnectIQ.sharedInstance()
        .parseDeviceSelectionResponse(from: url) as? [IQDevice]
      guard let devices = parsedDevices, !devices.isEmpty else {
        self.completePendingRequest(requestId: requestId) { pendingResult in
          pendingResult(
            FlutterError(
              code: "noAuthorizedDevices",
              message: "No authorized Garmin devices were returned.",
              details: nil
            )
          )
        }
        return
      }

      self.latestDevices.removeAll()
      for device in devices {
        self.latestDevices[device.uuid] = device
        ConnectIQ.sharedInstance().register(forDeviceEvents: device, delegate: self)
      }
      self.mapDevicesWithCompanionState(devices, requestId: requestId)
    }
    return true
  }

  private func completePendingRequest(
    requestId: UUID,
    completion: @escaping (FlutterResult) -> Void
  ) {
    guard let request = pendingRequest, request.id == requestId else { return }
    request.completion.run { [weak self] in
      self?.pendingRequest = nil
      completion(request.result)
    }
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
    guard let request = pendingRequest else { return }
    DispatchQueue.main.async { [weak self, requestId = request.id] in
      self?.completePendingRequest(requestId: requestId) { pendingResult in
        pendingResult(
          FlutterError(
            code: "garminConnectMissing",
            message: "Garmin Connect Mobile is not installed.",
            details: nil
          )
        )
      }
    }
  }

  func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
    DispatchQueue.main.async { [weak self] in
      self?.latestDevices[device.uuid] = device
      self?.emitDeviceUpdate(device, status: status)
    }
  }

  func deviceCharacteristicsDiscovered(_ device: IQDevice) {
    DispatchQueue.main.async { [weak self] in
      self?.latestDevices[device.uuid] = device
    }
  }

  private func mapDevicesWithCompanionState(
    _ devices: [IQDevice],
    requestId: UUID
  ) {
    guard let appId = connectIqAppId() else {
      for device in devices {
        latestCompanionStates[device.uuid] = GarminBridgeMapping.unknownCompanionState
      }
      completePendingRequest(requestId: requestId) { pendingResult in
        pendingResult(
          devices.map {
            self.mapDevice(
              $0,
              companionInstallState: GarminBridgeMapping.unknownCompanionState
            )
          }
        )
      }
      return
    }

    var states: [UUID: String] = [:]
    var remaining = devices.count
    let completion = OneShotCompletion()

    func finish() {
      completion.run {
        completePendingRequest(requestId: requestId) { pendingResult in
          pendingResult(
            devices.map { device in
              self.latestCompanionStates[device.uuid] =
                states[device.uuid] ?? GarminBridgeMapping.unknownCompanionState
              return self.mapDevice(
                device,
                companionInstallState: states[device.uuid]
                  ?? GarminBridgeMapping.unknownCompanionState
              )
            }
          )
        }
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      finish()
    }

    for device in devices {
      let app = IQApp(uuid: appId, store: appId, device: device)
      ConnectIQ.sharedInstance().getAppStatus(app) { [weak self] status in
        DispatchQueue.main.async {
          guard self != nil else { return }
          guard !completion.isCompleted else { return }
          states[device.uuid] = GarminBridgeMapping.companionInstallState(
            isInstalled: status?.isInstalled
          )
          remaining -= 1
          if remaining == 0 {
            finish()
          }
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
    return GarminBridgeMapping.devicePayload(
      id: device.uuid.uuidString,
      name: device.friendlyName,
      modelName: device.modelName,
      family: device.partNumber,
      unitId: device.uuid.uuidString,
      statusRawValue: status.rawValue,
      companionInstallState: companionInstallState
    )
  }

  private func emitDeviceUpdate(_ device: IQDevice, status: IQDeviceStatus) {
    guard let eventSink else { return }
    guard let appId = connectIqAppId() else {
      eventSink(
        mapDevice(
          device,
          companionInstallState: latestCompanionStates[device.uuid]
            ?? GarminBridgeMapping.unknownCompanionState,
          status: status
        )
      )
      return
    }

    let app = IQApp(uuid: appId, store: appId, device: device)
    ConnectIQ.sharedInstance().getAppStatus(app) { [weak self] appStatus in
      DispatchQueue.main.async {
        guard let self else { return }
        let companionState = GarminBridgeMapping.companionInstallState(
          isInstalled: appStatus?.isInstalled
        )
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

private final class DiscoveryRequest {
  let id = UUID()
  let result: FlutterResult
  let completion = OneShotCompletion()

  init(result: @escaping FlutterResult) {
    self.result = result
  }
}
