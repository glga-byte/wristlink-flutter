import CryptoKit
import Foundation

struct SharedContentFileRecord: Codable, Equatable {
  let id: String
  let receivedAt: String
  let platform: String
  let content: String
  let fingerprint: String

  var channelMap: [String: Any] {
    [
      "id": id,
      "receivedAt": receivedAt,
      "platform": platform,
      "content": content,
    ]
  }
}

enum SharedContentRecordStoreError: Error {
  case appGroupUnavailable
  case invalidContent
  case persistenceFailed
}

enum SharedContentIngestOutcome: Equatable {
  case stored(SharedContentFileRecord)
  case duplicate
}

struct SharedContentIngressService {
  init(
    store: SharedContentRecordStore,
    idFactory: @escaping () -> String = { UUID().uuidString },
    now: @escaping () -> Date = Date.init
  ) {
    self.store = store
    self.idFactory = idFactory
    self.now = now
  }

  private let store: SharedContentRecordStore
  private let idFactory: () -> String
  private let now: () -> Date

  func persist(_ rawContent: String) throws -> SharedContentIngestOutcome {
    let content = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !content.isEmpty else {
      throw SharedContentRecordStoreError.invalidContent
    }
    let bounded = String(content.prefix(SharedContentRecordStore.maximumContentCharacters))
    let fingerprint = SHA256.hash(data: Data(bounded.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    let date = now()
    if store.pendingRecords().contains(where: { $0.fingerprint == fingerprint })
      || store.wasRecentlyAcknowledged(fingerprint: fingerprint, at: date)
    {
      return .duplicate
    }
    let record = SharedContentFileRecord(
      id: idFactory(),
      receivedAt: ISO8601DateFormatter().string(from: date),
      platform: "ios",
      content: bounded,
      fingerprint: fingerprint
    )
    try store.write(record)
    return .stored(record)
  }
}

final class SharedContentRecordStore {
  static let maximumContentCharacters = 8192
  static let duplicateWindow: TimeInterval = 10 * 60

  private let directoryURL: URL
  private let defaults: UserDefaults
  private let fileManager: FileManager
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  convenience init(appGroupIdentifier: String) throws {
    guard
      let directoryURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      ),
      let defaults = UserDefaults(suiteName: appGroupIdentifier)
    else {
      throw SharedContentRecordStoreError.appGroupUnavailable
    }
    self.init(directoryURL: directoryURL, defaults: defaults)
  }

  init(
    directoryURL: URL,
    defaults: UserDefaults,
    fileManager: FileManager = .default
  ) {
    self.directoryURL = directoryURL.appendingPathComponent("SharedContent", isDirectory: true)
    self.defaults = defaults
    self.fileManager = fileManager
    encoder.outputFormatting = [.sortedKeys]
  }

  func write(_ record: SharedContentFileRecord) throws {
    try fileManager.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    let data = try encoder.encode(record)
    let destination = fileURL(for: record.id)
    do {
      try data.write(to: destination, options: [.atomic])
    } catch {
      throw SharedContentRecordStoreError.persistenceFailed
    }
  }

  func pendingRecords() -> [SharedContentFileRecord] {
    guard
      let urls = try? fileManager.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }
    return urls
      .filter { $0.pathExtension == "json" }
      .compactMap { url in
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(SharedContentFileRecord.self, from: data)
      }
      .sorted { $0.receivedAt < $1.receivedAt }
  }

  @discardableResult
  func acknowledge(id: String, at date: Date = Date()) -> Bool {
    guard let record = pendingRecords().first(where: { $0.id == id }) else {
      return false
    }
    do {
      try fileManager.removeItem(at: fileURL(for: id))
      var recent = recentAcknowledgements(at: date)
      recent[record.fingerprint] = date.timeIntervalSince1970
      defaults.set(recent, forKey: Self.recentAcknowledgementsKey)
      return true
    } catch {
      return false
    }
  }

  func wasRecentlyAcknowledged(fingerprint: String, at date: Date = Date()) -> Bool {
    recentAcknowledgements(at: date)[fingerprint] != nil
  }

  private func recentAcknowledgements(at date: Date) -> [String: TimeInterval] {
    let current = defaults.dictionary(forKey: Self.recentAcknowledgementsKey) ?? [:]
    let minimum = date.timeIntervalSince1970 - Self.duplicateWindow
    let recent = current.compactMapValues { value -> TimeInterval? in
      guard let timestamp = value as? TimeInterval, timestamp >= minimum else {
        return nil
      }
      return timestamp
    }
    if recent.count != current.count {
      defaults.set(recent, forKey: Self.recentAcknowledgementsKey)
    }
    return recent
  }

  private func fileURL(for id: String) -> URL {
    directoryURL.appendingPathComponent("shared-\(id).json", isDirectory: false)
  }

  private static let recentAcknowledgementsKey = "wristlink.recentShareAcknowledgements"
}
