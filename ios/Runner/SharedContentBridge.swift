import Flutter
import Foundation

final class SharedContentBridge: NSObject, FlutterStreamHandler {
  static let shared = SharedContentBridge()

  private static let methodChannelName = "wristlink/shared_content"
  private static let eventChannelName = "wristlink/shared_content_events"
  private static let appGroupInfoKey = "WristLinkShareAppGroup"
  private static let callbackSchemeInfoKey = "WristLinkShareCallbackScheme"

  private var store: SharedContentRecordStore?
  private var eventSink: FlutterEventSink?
  private var emittedIds = Set<String>()
  private let callbackSchemeOverride: String?

  override init() {
    callbackSchemeOverride = nil
    super.init()
  }

  init(store: SharedContentRecordStore, callbackScheme: String) {
    self.store = store
    callbackSchemeOverride = callbackScheme
    super.init()
  }

  static func register(with pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "SharedContentBridge") else {
      return
    }
    shared.configureStoreIfNeeded()
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "drainPending":
        result(shared.pendingMaps())
      case "acknowledge":
        guard
          let arguments = call.arguments as? [String: Any],
          let id = arguments["id"] as? String,
          !id.isEmpty
        else {
          result(
            FlutterError(
              code: "invalidArguments",
              message: "A shared-content id is required.",
              details: nil
            )
          )
          return
        }
        result(shared.acknowledge(id: id))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    ).setStreamHandler(shared)
  }

  func handleCallback(_ url: URL) -> Bool {
    guard Self.isShareCallback(url, callbackScheme: callbackSchemeOverride ?? Self.callbackScheme)
    else {
      return false
    }
    emitPending()
    return true
  }

  static func isShareCallback(_ url: URL, callbackScheme: String) -> Bool {
    !callbackScheme.isEmpty && url.scheme == callbackScheme
  }

  func appDidBecomeActive() {
    emitPending()
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    emitPending()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func pendingMaps() -> [[String: Any]] {
    configureStoreIfNeeded()
    let records = store?.pendingRecords() ?? []
    emittedIds.formUnion(records.map(\.id))
    return records.map(\.channelMap)
  }

  func acknowledge(id: String) -> Bool {
    configureStoreIfNeeded()
    let acknowledged = store?.acknowledge(id: id) ?? false
    if acknowledged {
      emittedIds.remove(id)
    }
    return acknowledged
  }

  private func emitPending() {
    guard let eventSink else { return }
    configureStoreIfNeeded()
    for record in store?.pendingRecords() ?? [] where emittedIds.insert(record.id).inserted {
      eventSink(record.channelMap)
    }
  }

  private func configureStoreIfNeeded() {
    guard store == nil, !Self.appGroupIdentifier.isEmpty else { return }
    store = try? SharedContentRecordStore(appGroupIdentifier: Self.appGroupIdentifier)
  }

  private static var appGroupIdentifier: String {
    (Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private static var callbackScheme: String {
    (Bundle.main.object(forInfoDictionaryKey: callbackSchemeInfoKey) as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
}
