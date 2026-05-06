import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts where GarminDeviceBridge.shared.handleCallback(context.url) {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
