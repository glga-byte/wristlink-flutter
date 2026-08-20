import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android registers app-owned channels for every Flutter engine', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final pluginPubspec = File(
      'packages/wristlink_engine_bridge/pubspec.yaml',
    ).readAsStringSync();
    final plugin = File(
      'packages/wristlink_engine_bridge/android/src/main/kotlin/'
      'com/wristlink/engine_bridge/WristLinkEngineBridgePlugin.kt',
    ).readAsStringSync();
    final registrar = File(
      'android/app/src/main/kotlin/com/wristlink/wristlink_flutter/'
      'WristLinkEngineBridgeRegistrar.kt',
    ).readAsStringSync();

    expect(pubspec, contains('path: packages/wristlink_engine_bridge'));
    expect(pluginPubspec, contains('pluginClass: WristLinkEngineBridgePlugin'));
    expect(plugin, contains('onAttachedToEngine'));
    expect(plugin, contains('onDetachedFromEngine'));
    expect(registrar, contains('GarminDeviceBridge.getInstance'));
    expect(registrar, contains('DeviceSettingsBridge'));
    expect(registrar, contains('registeredMessengers'));
  });

  test('iOS registers BGAppRefresh and custom headless-engine channels', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    const identifier = 'com.wristlink.sendQueue.backgroundRetry';

    expect(infoPlist, contains('BGTaskSchedulerPermittedIdentifiers'));
    expect(infoPlist, contains(identifier));
    expect(infoPlist, contains('<string>fetch</string>'));
    expect(
      appDelegate,
      contains('WorkmanagerPlugin.setPluginRegistrantCallback'),
    );
    expect(appDelegate, contains('WorkmanagerPlugin.registerPeriodicTask'));
    expect(appDelegate, contains('GeneratedPluginRegistrant.register'));
    expect(appDelegate, contains('GarminDeviceBridge.register'));
    expect(appDelegate, contains('DeviceSettingsBridge.register'));
    expect(appDelegate, contains(identifier));
  });
}
