import Flutter
import GoogleMaps
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleMaps()
    GarminDeviceBridge.shared.initializeSdk()
    configureBackgroundSending()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureBackgroundSending() {
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
      GarminDeviceBridge.register(with: registry)
      DeviceSettingsBridge.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.wristlink.sendQueue.backgroundRetry",
      earliestBeginInSeconds: NSNumber(value: 15 * 60)
    )
  }

  private func configureGoogleMaps() {
    guard let key = Bundle.main.object(
      forInfoDictionaryKey: "WristLinkGoogleMapsApiKey"
    ) as? String,
      !key.isEmpty,
      key != "MISSING_GOOGLE_MAPS_API_KEY",
      !key.hasPrefix("YOUR_")
    else {
      NSLog(
        "WristLink Google Maps key is missing. Configure a package/bundle-restricted key in config/wristlink-maps.local.xcconfig."
      )
      return
    }
    GMSServices.provideAPIKey(key)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    GarminDeviceBridge.register(with: engineBridge.pluginRegistry)
    DeviceSettingsBridge.register(with: engineBridge.pluginRegistry)
    SharedContentBridge.register(with: engineBridge.pluginRegistry)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    SharedContentBridge.shared.handleCallback(url)
      || GarminDeviceBridge.shared.handleCallback(url)
      || super.application(app, open: url, options: options)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    SharedContentBridge.shared.appDidBecomeActive()
  }
}
