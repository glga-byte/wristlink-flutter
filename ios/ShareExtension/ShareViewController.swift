import Foundation
import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
  private var isHandlingShare = false

  override func isContentValid() -> Bool {
    !isHandlingShare
  }

  override func didSelectPost() {
    guard !isHandlingShare else { return }
    isHandlingShare = true
    extractSharedContent { [weak self] content in
      DispatchQueue.main.async {
        self?.storeAndHandoff(content)
      }
    }
  }

  override func configurationItems() -> [Any]! {
    []
  }

  private func extractSharedContent(completion: @escaping (String?) -> Void) {
    let providers = extensionContext?.inputItems
      .compactMap { $0 as? NSExtensionItem }
      .flatMap { $0.attachments ?? [] } ?? []
    guard let provider = providers.first(where: {
      $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        || $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
    }) else {
      completion(nil)
      return
    }

    let type = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
      ? UTType.url.identifier
      : UTType.plainText.identifier
    provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
      switch item {
      case let url as URL:
        completion(url.absoluteString)
      case let text as String:
        completion(text)
      case let text as NSString:
        completion(text as String)
      default:
        completion(nil)
      }
    }
  }

  private func storeAndHandoff(_ rawContent: String?) {
    guard
      let content = rawContent?.trimmingCharacters(in: .whitespacesAndNewlines),
      !content.isEmpty,
      let appGroup = Bundle.main.object(
        forInfoDictionaryKey: "WristLinkShareAppGroup"
      ) as? String,
      let callbackScheme = Bundle.main.object(
        forInfoDictionaryKey: "WristLinkShareCallbackScheme"
      ) as? String,
      let store = try? SharedContentRecordStore(appGroupIdentifier: appGroup)
    else {
      finish(message: "This item could not be saved to WristLink.")
      return
    }

    let record: SharedContentFileRecord
    do {
      switch try SharedContentIngressService(store: store).persist(content) {
      case let .stored(storedRecord):
        record = storedRecord
      case .duplicate:
        finish(message: "This point is already waiting in WristLink.")
        return
      }
    } catch {
      finish(message: "This item could not be saved to WristLink.")
      return
    }

    var components = URLComponents()
    components.scheme = callbackScheme
    components.host = "shared-content"
    components.queryItems = [URLQueryItem(name: "id", value: record.id)]
    guard let callback = components.url else {
      finish(message: "Saved. Open WristLink to continue.")
      return
    }
    extensionContext?.open(callback) { [weak self] opened in
      DispatchQueue.main.async {
        self?.finish(
          message: opened
            ? "Opening WristLink…"
            : "Saved. Open WristLink to continue."
        )
      }
    }
  }

  private func finish(message: String) {
    placeholder = message
    textView.text = ""
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.extensionContext?.completeRequest(returningItems: nil)
    }
  }
}
