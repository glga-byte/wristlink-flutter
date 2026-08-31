import Foundation
import XCTest
@testable import Runner

final class SharedContentRecordStoreTests: XCTestCase {
  private var directoryURL: URL!
  private var suiteName: String!
  private var defaults: UserDefaults!

  override func setUpWithError() throws {
    directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    suiteName = "SharedContentRecordStoreTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directoryURL)
    defaults.removePersistentDomain(forName: suiteName)
  }

  func testAtomicWriteDrainAndAcknowledgement() throws {
    let store = SharedContentRecordStore(directoryURL: directoryURL, defaults: defaults)
    let record = SharedContentFileRecord(
      id: "share-1",
      receivedAt: "2026-08-20T10:00:00Z",
      platform: "ios",
      content: "geo:1,2",
      fingerprint: "fingerprint"
    )

    try store.write(record)

    XCTAssertEqual(store.pendingRecords(), [record])
    XCTAssertTrue(store.acknowledge(id: record.id, at: Date(timeIntervalSince1970: 100)))
    XCTAssertTrue(store.pendingRecords().isEmpty)
    XCTAssertTrue(
      store.wasRecentlyAcknowledged(
        fingerprint: record.fingerprint,
        at: Date(timeIntervalSince1970: 101)
      )
    )
    XCTAssertFalse(store.acknowledge(id: record.id))
  }

  func testMalformedFilesDoNotPreventValidDrain() throws {
    let store = SharedContentRecordStore(directoryURL: directoryURL, defaults: defaults)
    try store.write(
      SharedContentFileRecord(
        id: "share-1",
        receivedAt: "2026-08-20T10:00:00Z",
        platform: "ios",
        content: "geo:1,2",
        fingerprint: "fingerprint"
      )
    )
    try Data("not-json".utf8).write(
      to: directoryURL
        .appendingPathComponent("SharedContent", isDirectory: true)
        .appendingPathComponent("shared-malformed.json")
    )

    XCTAssertEqual(store.pendingRecords().map(\.id), ["share-1"])
  }

  func testDuplicateWindowExpires() throws {
    let store = SharedContentRecordStore(directoryURL: directoryURL, defaults: defaults)
    let record = SharedContentFileRecord(
      id: "share-1",
      receivedAt: "2026-08-20T10:00:00Z",
      platform: "ios",
      content: "geo:1,2",
      fingerprint: "fingerprint"
    )
    try store.write(record)
    XCTAssertTrue(store.acknowledge(id: record.id, at: Date(timeIntervalSince1970: 100)))
    XCTAssertFalse(
      store.wasRecentlyAcknowledged(
        fingerprint: record.fingerprint,
        at: Date(timeIntervalSince1970: 100 + SharedContentRecordStore.duplicateWindow + 1)
      )
    )
  }

  func testShareCallbackRoutingDoesNotClaimGarminURLs() {
    XCTAssertTrue(
      SharedContentBridge.isShareCallback(
        URL(string: "wristlink-share-dev://shared-content?id=1")!,
        callbackScheme: "wristlink-share-dev"
      )
    )
    XCTAssertFalse(
      SharedContentBridge.isShareCallback(
        URL(string: "wristlink-ciq-dev://callback")!,
        callbackScheme: "wristlink-share-dev"
      )
    )
  }

  func testStoppedAppDrainsExtensionRecordExactlyOnceWhenListening() throws {
    let store = SharedContentRecordStore(directoryURL: directoryURL, defaults: defaults)
    let now = Date()
    let service = SharedContentIngressService(
      store: store,
      idFactory: { "share-cold" },
      now: { now }
    )
    let outcome = try service.persist("geo:52.5200,13.4050")
    guard case let .stored(record) = outcome else {
      return XCTFail("Expected the extension service to persist a record.")
    }

    let bridge = SharedContentBridge(
      store: store,
      callbackScheme: "wristlink-share-dev"
    )
    var emitted = [[String: Any]]()
    XCTAssertNil(
      bridge.onListen(withArguments: nil) { value in
        if let map = value as? [String: Any] {
          emitted.append(map)
        }
      }
    )
    bridge.appDidBecomeActive()
    XCTAssertTrue(
      bridge.handleCallback(
        URL(string: "wristlink-share-dev://shared-content?id=share-cold")!
      )
    )

    XCTAssertEqual(emitted.compactMap { $0["id"] as? String }, [record.id])
    XCTAssertTrue(bridge.acknowledge(id: record.id))
    XCTAssertTrue(store.pendingRecords().isEmpty)
    XCTAssertEqual(try service.persist("geo:52.5200,13.4050"), .duplicate)
  }

  func testRunningAppReceivesNewExtensionRecordWithoutDuplicateResumeDelivery() throws {
    let store = SharedContentRecordStore(directoryURL: directoryURL, defaults: defaults)
    let bridge = SharedContentBridge(
      store: store,
      callbackScheme: "wristlink-share-dev"
    )
    var emittedIds = [String]()
    XCTAssertNil(
      bridge.onListen(withArguments: nil) { value in
        if let id = (value as? [String: Any])?["id"] as? String {
          emittedIds.append(id)
        }
      }
    )
    let service = SharedContentIngressService(
      store: store,
      idFactory: { "share-warm" }
    )
    XCTAssertEqual(
      try service.persist("https://www.google.com/maps/@48.1372,11.5756,15z"),
      .stored(store.pendingRecords().single)
    )

    XCTAssertTrue(
      bridge.handleCallback(
        URL(string: "wristlink-share-dev://shared-content?id=share-warm")!
      )
    )
    bridge.appDidBecomeActive()
    XCTAssertFalse(
      bridge.handleCallback(URL(string: "wristlink-ciq-dev://callback")!)
    )

    XCTAssertEqual(emittedIds, ["share-warm"])
  }

  func testExtensionPersistenceBoundsContentAndRejectsEmptyInput() throws {
    let store = SharedContentRecordStore(directoryURL: directoryURL, defaults: defaults)
    let service = SharedContentIngressService(
      store: store,
      idFactory: { "share-large" }
    )

    guard case let .stored(record) = try service.persist(String(repeating: "x", count: 9000))
    else {
      return XCTFail("Expected a bounded record.")
    }
    XCTAssertEqual(record.content.count, SharedContentRecordStore.maximumContentCharacters)
    XCTAssertThrowsError(try service.persist("   "))
  }
}

private extension Array {
  var single: Element {
    precondition(count == 1)
    return self[0]
  }
}
