import ConnectIQ
import Flutter
import UIKit

final class GarminDeviceBridge: NSObject, IQUIOverrideDelegate, IQDeviceEventDelegate,
  IQAppMessageDelegate
{
  static let shared = GarminDeviceBridge()

  private static let channelName = "wristlink/garmin_devices"
  private static let eventChannelName = "wristlink/garmin_device_events"
  private static let sendChannelName = "wristlink/garmin_send"
  private static let acknowledgementEventChannelName = "wristlink/garmin_acknowledgements"
  private static let callbackSchemeInfoKey = "WristLinkGarminCallbackScheme"
  private static let sendTimeout: TimeInterval = 30

  private var pendingRequest: DiscoveryRequest?
  private var latestDevices: [UUID: IQDevice] = [:]
  private var latestApps: [UUID: IQApp] = [:]
  private var latestCompanionStates: [UUID: String] = [:]
  private var registeredDeviceIds = Set<UUID>()
  private var registeredAppMessageKeys = Set<AppMessageKey>()
  private var registeredMessengerIds = Set<ObjectIdentifier>()
  private var deviceEventSinks: [ObjectIdentifier: FlutterEventSink] = [:]
  private var acknowledgementEventSinks: [ObjectIdentifier: FlutterEventSink] = [:]
  private var sdkInitialized = false

  static func register(with pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "GarminDeviceBridge") else {
      return
    }
    let messenger = registrar.messenger()
    let messengerId = ObjectIdentifier(messenger)
    guard shared.registeredMessengerIds.insert(messengerId).inserted else { return }
    shared.initializeSdk()

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "discoverDevices":
        shared.discoverDevices(result: result)
      case "hydrateTransport":
        shared.hydrateTransport(arguments: call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(
      MessengerEventStreamHandler(
        onListen: { events in
          shared.deviceEventSinks[messengerId] = events
        },
        onCancel: {
          shared.deviceEventSinks.removeValue(forKey: messengerId)
        }
      )
    )

    let sendChannel = FlutterMethodChannel(
      name: sendChannelName,
      binaryMessenger: messenger
    )
    sendChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "sendMessage":
        shared.sendMessage(arguments: call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let acknowledgementEventChannel = FlutterEventChannel(
      name: acknowledgementEventChannelName,
      binaryMessenger: messenger
    )
    acknowledgementEventChannel.setStreamHandler(
      MessengerEventStreamHandler(
        onListen: { events in
          shared.acknowledgementEventSinks[messengerId] = events
        },
        onCancel: {
          shared.acknowledgementEventSinks.removeValue(forKey: messengerId)
        }
      )
    )
  }

  func initializeSdk() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { [weak self] in self?.initializeSdk() }
      return
    }
    guard !sdkInitialized else { return }
    guard !Self.callbackScheme.isEmpty else {
      NSLog("WristLink Garmin callback scheme is missing; Connect IQ SDK was not initialized.")
      return
    }
    sdkInitialized = true
    ConnectIQ.sharedInstance().initialize(
      withUrlScheme: Self.callbackScheme,
      uiOverrideDelegate: self,
      stateRestorationIdentifier: Self.callbackScheme
    )
  }

  private func sendMessage(arguments: Any?, result: @escaping FlutterResult) {
    let performSend: () -> Void = { [weak self] in
      guard let self else { return }
      self.sendMessageOnMain(arguments: arguments, result: result)
    }
    if Thread.isMainThread {
      performSend()
    } else {
      DispatchQueue.main.async(execute: performSend)
    }
  }

  private func hydrateTransport(arguments: Any?, result: @escaping FlutterResult) {
    let performHydration: () -> Void = { [weak self] in
      guard let self else { return }
      self.hydrateTransportOnMain(arguments: arguments, result: result)
    }
    if Thread.isMainThread {
      performHydration()
    } else {
      DispatchQueue.main.async(execute: performHydration)
    }
  }

  private func hydrateTransportOnMain(arguments: Any?, result: @escaping FlutterResult) {
    dispatchPrecondition(condition: .onQueue(.main))
    initializeSdk()
    guard sdkInitialized else {
      result(
        FlutterError(
          code: "sdkUnavailable",
          message: "Garmin Connect IQ Mobile SDK is not ready.",
          details: nil
        )
      )
      return
    }
    guard let descriptors = GarminTransportDeviceDescriptor.parseList(arguments) else {
      result(
        FlutterError(
          code: "nativeFailure",
          message: "Garmin transport hydration requires valid authorized-device descriptors.",
          details: nil
        )
      )
      return
    }

    // Dart's persisted authorized-device descriptors are the source of truth.
    // These SDK objects remain process-local transport state only.
    let devices = descriptors.compactMap { descriptor in
      IQDevice(
        id: descriptor.id,
        modelName: descriptor.modelName,
        friendlyName: descriptor.friendlyName,
        partNumber: descriptor.partNumber
      )
    }
    guard devices.count == descriptors.count else {
      result(
        FlutterError(
          code: "nativeFailure",
          message: "Garmin Connect IQ Mobile SDK could not restore an authorized device.",
          details: nil
        )
      )
      return
    }
    replaceAuthorizedDevices(devices)
    refreshDevicesWithCompanionState(devices, completion: result)
  }

  private func sendMessageOnMain(arguments: Any?, result: @escaping FlutterResult) {
    dispatchPrecondition(condition: .onQueue(.main))
    let coordinator = GarminSendCoordinator<IQDevice, IQApp>(
      isSdkReady: { [weak self] in self?.sdkInitialized == true },
      findDevice: { [weak self] deviceId in
        guard let devices = self?.latestDevices else { return nil }
        return GarminNativeDeviceLookup.byRawUUID(deviceId, in: devices)
      },
      findApp: { [weak self] device in self?.latestApps[device.uuid] },
      scheduleTimeout: { onTimeout in
        let workItem = DispatchWorkItem(block: onTimeout)
        DispatchQueue.main.asyncAfter(
          deadline: .now() + Self.sendTimeout,
          execute: workItem
        )
        return ClosureGarminSendTimeout(workItem.cancel)
      },
      send: { device, app, message, completion in
        ConnectIQ.sharedInstance().sendMessage(
          message,
          to: app,
          progress: { _, _ in },
          completion: { sendResult in
            DispatchQueue.main.async {
              completion(
                GarminTransportMapping.errorFor(resultRawValue: sendResult.rawValue)
              )
            }
          }
        )
      }
    )
    coordinator.execute(arguments: arguments) { error in
      if let error {
        result(FlutterError(code: error.code, message: error.message, details: nil))
      } else {
        result(nil)
      }
    }
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
      self?.completePendingAuthorizationRequest(requestId: requestId) { pendingResult in
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

      let parsedDevices =
        ConnectIQ.sharedInstance()
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

      self.replaceAuthorizedDevices(devices)
      guard self.markAuthorizationComplete(requestId: requestId) else {
        return
      }
      self.refreshDevicesWithCompanionState(devices) { payloads in
        self.completePendingRequest(requestId: requestId) { pendingResult in
          pendingResult(payloads)
        }
      }
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

  private func completePendingAuthorizationRequest(
    requestId: UUID,
    completion: @escaping (FlutterResult) -> Void
  ) {
    guard
      let request = pendingRequest,
      request.id == requestId,
      request.isAuthorizationPending
    else {
      return
    }
    request.completion.run { [weak self] in
      self?.pendingRequest = nil
      completion(request.result)
    }
  }

  private func markAuthorizationComplete(requestId: UUID) -> Bool {
    guard let request = pendingRequest, request.id == requestId else { return false }
    return request.markAuthorizationComplete()
  }

  private func isCancellationCallback(_ url: URL) -> Bool {
    let items =
      URLComponents(url: url, resolvingAgainstBaseURL: false)?
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

  func receivedMessage(_ message: Any, from app: IQApp) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      GarminTransportMapping.deliverRawMessageMaps(
        message,
        deliver: self.emitAcknowledgement
      )
    }
  }

  private func refreshDevicesWithCompanionState(
    _ devices: [IQDevice],
    completion: @escaping ([[String: Any?]]) -> Void
  ) {
    guard !devices.isEmpty else {
      completion([])
      return
    }
    guard let appId = connectIqAppId() else {
      for device in devices {
        latestCompanionStates[device.uuid] = GarminBridgeMapping.unknownCompanionState
      }
      completion(
        devices.map {
          self.mapDevice(
            $0,
            companionInstallState: GarminBridgeMapping.unknownCompanionState
          )
        }
      )
      return
    }

    var states: [UUID: String] = [:]
    var remaining = devices.count
    let oneShot = OneShotCompletion()

    func finish() {
      oneShot.run {
        let payloads = devices.map { device in
          self.latestCompanionStates[device.uuid] =
            states[device.uuid] ?? GarminBridgeMapping.unknownCompanionState
          return self.mapDevice(
            device,
            companionInstallState: states[device.uuid]
              ?? GarminBridgeMapping.unknownCompanionState
          )
        }
        completion(payloads)
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      finish()
    }

    for device in devices {
      guard let app = IQApp(uuid: appId, store: appId, device: device) else {
        states[device.uuid] = GarminBridgeMapping.unknownCompanionState
        remaining -= 1
        if remaining == 0 {
          finish()
        }
        continue
      }
      ConnectIQ.sharedInstance().getAppStatus(app) { [weak self] status in
        DispatchQueue.main.async {
          guard
            let self,
            self.latestDevices[device.uuid] === device
          else {
            return
          }
          let companionState = GarminBridgeMapping.companionInstallState(
            isInstalled: status?.isInstalled
          )
          self.updateCachedApp(app, for: device, isInstalled: status?.isInstalled)
          self.latestCompanionStates[device.uuid] = companionState
          guard !oneShot.isCompleted else {
            self.emitDevicePayload(
              self.mapDevice(
                device,
                companionInstallState: companionState
              )
            )
            return
          }
          states[device.uuid] = companionState
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
    guard let appId = connectIqAppId() else {
      emitDevicePayload(
        mapDevice(
          device,
          companionInstallState: latestCompanionStates[device.uuid]
            ?? GarminBridgeMapping.unknownCompanionState,
          status: status
        )
      )
      return
    }

    guard let app = IQApp(uuid: appId, store: appId, device: device) else {
      emitDevicePayload(
        mapDevice(
          device,
          companionInstallState: GarminBridgeMapping.unknownCompanionState,
          status: status
        )
      )
      return
    }
    ConnectIQ.sharedInstance().getAppStatus(app) { [weak self] appStatus in
      DispatchQueue.main.async {
        guard let self else { return }
        self.updateCachedApp(app, for: device, isInstalled: appStatus?.isInstalled)
        let companionState = GarminBridgeMapping.companionInstallState(
          isInstalled: appStatus?.isInstalled
        )
        self.latestCompanionStates[device.uuid] = companionState
        self.emitDevicePayload(
          self.mapDevice(
            device,
            companionInstallState: companionState,
            status: status
          )
        )
      }
    }
  }

  private func emitDevicePayload(_ payload: [String: Any?]) {
    deviceEventSinks.values.forEach { $0(payload) }
  }

  private func replaceAuthorizedDevices(_ devices: [IQDevice]) {
    dispatchPrecondition(condition: .onQueue(.main))
    let connectIq = ConnectIQ.sharedInstance()!
    connectIq.unregister(forAllAppMessages: self)
    connectIq.unregister(forAllDeviceEvents: self)
    registeredAppMessageKeys.removeAll()
    registeredDeviceIds.removeAll()
    latestApps.removeAll()
    latestDevices = Dictionary(uniqueKeysWithValues: devices.map { ($0.uuid, $0) })
    latestCompanionStates = latestCompanionStates.filter {
      latestDevices[$0.key] != nil
    }
    devices.forEach(registerForDeviceEventsIfNeeded)
  }

  private func registerForDeviceEventsIfNeeded(_ device: IQDevice) {
    guard registeredDeviceIds.insert(device.uuid).inserted else { return }
    ConnectIQ.sharedInstance().register(forDeviceEvents: device, delegate: self)
  }

  private func updateCachedApp(
    _ app: IQApp,
    for device: IQDevice,
    isInstalled: Bool?
  ) {
    let key = AppMessageKey(deviceId: device.uuid, appId: app.uuid)
    guard isInstalled == true else {
      if let previousApp = latestApps.removeValue(forKey: device.uuid),
        registeredAppMessageKeys.remove(key) != nil
      {
        ConnectIQ.sharedInstance().unregister(forAppMessages: previousApp, delegate: self)
      }
      return
    }

    latestApps[device.uuid] = app
    guard registeredAppMessageKeys.insert(key).inserted else { return }
    ConnectIQ.sharedInstance().register(forAppMessages: app, delegate: self)
  }

  private func emitAcknowledgement(_ message: [AnyHashable: Any]) {
    acknowledgementEventSinks.values.forEach { $0(message) }
  }

  private func connectIqAppId() -> UUID? {
    guard
      let value = Bundle.main.object(forInfoDictionaryKey: "WristLinkConnectIQAppUUID")
        as? String,
      !value.isEmpty
    else {
      return nil
    }
    return UUID(uuidString: value)
  }

  private static var callbackScheme: String {
    guard
      let value = Bundle.main.object(forInfoDictionaryKey: callbackSchemeInfoKey) as? String
    else {
      return ""
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private struct AppMessageKey: Hashable {
  let deviceId: UUID
  let appId: UUID
}

private final class MessengerEventStreamHandler: NSObject, FlutterStreamHandler {
  private let listen: (@escaping FlutterEventSink) -> Void
  private let cancel: () -> Void

  init(
    onListen: @escaping (@escaping FlutterEventSink) -> Void,
    onCancel: @escaping () -> Void
  ) {
    listen = onListen
    cancel = onCancel
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    listen(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    cancel()
    return nil
  }
}

private final class DiscoveryRequest {
  let id = UUID()
  let result: FlutterResult
  let completion = OneShotCompletion()
  private var authorizationPending = true

  var isAuthorizationPending: Bool {
    authorizationPending
  }

  init(result: @escaping FlutterResult) {
    self.result = result
  }

  func markAuthorizationComplete() -> Bool {
    guard authorizationPending else { return false }
    authorizationPending = false
    return true
  }
}
