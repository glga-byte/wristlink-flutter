import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts
    where SharedContentBridge.shared.handleCallback(context.url)
      || GarminDeviceBridge.shared.handleCallback(context.url)
    {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    SharedContentBridge.shared.appDidBecomeActive()
  }
}
