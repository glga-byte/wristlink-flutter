import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const devUuidKey = 'WRISTLINK_DEV_CONNECT_IQ_APP_UUID';
  const prodUuidKey = 'WRISTLINK_PROD_CONNECT_IQ_APP_UUID';
  const androidUuidKey = 'WRISTLINK_CONNECT_IQ_APP_UUID';
  const devMapsKey = 'WRISTLINK_DEV_GOOGLE_MAPS_API_KEY';
  const prodMapsKey = 'WRISTLINK_PROD_GOOGLE_MAPS_API_KEY';
  final sharedFlavorConfig = File(
    'config/wristlink-flavors.xcconfig',
  ).readAsStringSync();
  final sharedFlavorValues = _parseXcconfigValues(sharedFlavorConfig);

  group('Android flavor configuration', () {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final bridge = File(
      'android/app/src/main/kotlin/com/wristlink/wristlink_flutter/'
      'GarminDeviceBridge.kt',
    ).readAsStringSync();

    test('declares dev and prod application ids', () {
      expect(
        buildGradle,
        contains('applicationId = "com.wristlink.wristlink_flutter"'),
      );
      expect(buildGradle, contains('flavorDimensions += "environment"'));
      expect(buildGradle, contains('create("dev")'));
      expect(buildGradle, contains('applicationIdSuffix = ".dev"'));
      expect(buildGradle, contains('create("prod")'));
    });

    test('feeds manifest metadata from the selected flavor UUID', () {
      expect(buildGradle, contains(androidUuidKey));
      expect(
        buildGradle,
        contains(
          'WRISTLINK_FLAVOR_CONFIG_PATH = "../config/wristlink-flavors.xcconfig"',
        ),
      );
      expect(
        buildGradle,
        contains(
          'wristLinkFlavorConfigValue(WRISTLINK_DEV_CONNECT_IQ_APP_UUID)',
        ),
      );
      expect(
        buildGradle,
        contains(
          'wristLinkFlavorConfigValue(WRISTLINK_PROD_CONNECT_IQ_APP_UUID)',
        ),
      );
      final devUuid = sharedFlavorValues[devUuidKey];
      final prodUuid = sharedFlavorValues[prodUuidKey];
      expect(devUuid, isAConnectIqUuid);
      expect(prodUuid, isAConnectIqUuid);
      expect(devUuid, isNot(prodUuid));
      expect(buildGradle, isNot(contains(devUuid)));
      expect(buildGradle, isNot(contains(prodUuid)));
      expect(
        manifest,
        contains('android:name="com.wristlink.CONNECT_IQ_APP_ID"'),
      );
      expect(
        manifest,
        contains(r'android:value="${WRISTLINK_CONNECT_IQ_APP_UUID}"'),
      );
    });

    test('treats placeholder-shaped UUIDs uniformly', () {
      expect(bridge, isNot(contains('CONNECT_IQ_APP_ID_PLACEHOLDER')));
      expect(bridge, isNot(contains('00000000-0000-0000-0000-000000000000')));
    });

    test('wires flavor map keys and the plugin minimum SDK', () {
      expect(buildGradle, contains('minSdk = 24'));
      expect(buildGradle, contains(devMapsKey));
      expect(buildGradle, contains(prodMapsKey));
      expect(
        manifest,
        contains('android:name="com.google.android.geo.API_KEY"'),
      );
      expect(
        manifest,
        contains(r'android:value="${WRISTLINK_GOOGLE_MAPS_API_KEY}"'),
      );
      expect(manifest, contains('android.permission.ACCESS_COARSE_LOCATION'));
      expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(buildGradle, contains('config/wristlink-maps.local.xcconfig'));
    });

    test('registers text sharing for cold and warm singleTop delivery', () {
      final activity = File(
        'android/app/src/main/kotlin/com/wristlink/wristlink_flutter/'
        'MainActivity.kt',
      ).readAsStringSync();
      expect(manifest, contains('android:launchMode="singleTop"'));
      expect(manifest, contains('android.intent.action.SEND'));
      expect(manifest, contains('android:mimeType="text/plain"'));
      expect(activity, contains('consumeShareIntent(intent)'));
      expect(activity, contains('override fun onNewIntent(intent: Intent)'));
      expect(activity, contains('ShareIntentLifecycle'));
      expect(activity, contains('shareIntentLifecycle.replacementFor'));
      expect(activity, contains('Intent(Intent.ACTION_MAIN).setPackage'));
    });
  });

  group('iOS flavor configuration', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final bridge = File(
      'ios/Runner/GarminDeviceBridge.swift',
    ).readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    test('declares shared dev and prod schemes', () {
      expect(
        File(
          'ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'ios/Runner.xcodeproj/xcshareddata/xcschemes/prod.xcscheme',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme',
        ).readAsStringSync(),
        contains('buildConfiguration = "Debug-dev"'),
      );
      expect(
        File(
          'ios/Runner.xcodeproj/xcshareddata/xcschemes/prod.xcscheme',
        ).readAsStringSync(),
        contains('buildConfiguration = "Debug-prod"'),
      );
    });

    test('declares flavor build configurations', () {
      for (final name in [
        'Debug-dev',
        'Profile-dev',
        'Release-dev',
        'Debug-prod',
        'Profile-prod',
        'Release-prod',
      ]) {
        expect(project, contains(name));
        expect(File('ios/Flutter/$name.xcconfig').existsSync(), isTrue);
      }
    });

    test('resolves flavor bundle identifiers and UUIDs from xcconfig files', () {
      expect(
        File('ios/Flutter/Flavor-dev.xcconfig').readAsStringSync(),
        allOf(
          contains('#include "../../config/wristlink-flavors.xcconfig"'),
          contains(
            'PRODUCT_BUNDLE_IDENTIFIER = com.wristlink.wristlinkFlutter.dev',
          ),
          contains(
            r'WRISTLINK_CONNECT_IQ_APP_UUID = $(WRISTLINK_DEV_CONNECT_IQ_APP_UUID)',
          ),
        ),
      );
      expect(
        File('ios/Flutter/Flavor-prod.xcconfig').readAsStringSync(),
        allOf(
          contains('#include "../../config/wristlink-flavors.xcconfig"'),
          contains(
            'PRODUCT_BUNDLE_IDENTIFIER = com.wristlink.wristlinkFlutter',
          ),
          contains(
            r'WRISTLINK_CONNECT_IQ_APP_UUID = $(WRISTLINK_PROD_CONNECT_IQ_APP_UUID)',
          ),
        ),
      );
      expect(
        File('ios/Flutter/Debug-dev.xcconfig').readAsStringSync(),
        allOf(
          contains('#include "Debug.xcconfig"'),
          contains('#include "Flavor-dev.xcconfig"'),
        ),
      );
      expect(
        File('ios/Flutter/Debug-prod.xcconfig').readAsStringSync(),
        allOf(
          contains('#include "Debug.xcconfig"'),
          contains('#include "Flavor-prod.xcconfig"'),
        ),
      );
      expect(sharedFlavorConfig, contains(devUuidKey));
      expect(sharedFlavorConfig, contains(prodUuidKey));
      expect(
        infoPlist,
        contains(r'<string>$(WRISTLINK_CONNECT_IQ_APP_UUID)</string>'),
      );
    });

    test('uses flavor-specific Garmin callback schemes', () {
      expect(
        File('ios/Flutter/Flavor-dev.xcconfig').readAsStringSync(),
        contains('WRISTLINK_GARMIN_CALLBACK_SCHEME = wristlink-ciq-dev'),
      );
      expect(
        File('ios/Flutter/Flavor-prod.xcconfig').readAsStringSync(),
        contains('WRISTLINK_GARMIN_CALLBACK_SCHEME = wristlink-ciq'),
      );
      expect(
        infoPlist,
        contains(r'<string>$(WRISTLINK_GARMIN_CALLBACK_SCHEME)</string>'),
      );
      expect(bridge, contains('WristLinkGarminCallbackScheme'));
      expect(
        bridge,
        isNot(contains('private static let callbackScheme = "wristlink-ciq"')),
      );
    });

    test('treats placeholder-shaped UUIDs uniformly', () {
      expect(bridge, isNot(contains('connectIqAppIdPlaceholder')));
      expect(bridge, isNot(contains('00000000-0000-0000-0000-000000000000')));
    });

    test('uses iOS 14 and flavor-owned maps/share configuration', () {
      expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0')));
      expect(
        RegExp('IPHONEOS_DEPLOYMENT_TARGET = 14.0').allMatches(project),
        isNotEmpty,
      );
      expect(
        File('ios/Podfile').readAsStringSync(),
        contains("platform :ios, '14.0'"),
      );
      expect(
        File('ios/Flutter/Flavor-dev.xcconfig').readAsStringSync(),
        allOf(
          contains(r'$(WRISTLINK_DEV_GOOGLE_MAPS_API_KEY)'),
          contains('WRISTLINK_SHARE_CALLBACK_SCHEME = wristlink-share-dev'),
          contains(
            'WRISTLINK_APP_GROUP = group.com.wristlink.wristlinkFlutter.dev',
          ),
        ),
      );
      expect(
        File('ios/Flutter/Flavor-prod.xcconfig').readAsStringSync(),
        allOf(
          contains(r'$(WRISTLINK_PROD_GOOGLE_MAPS_API_KEY)'),
          contains('WRISTLINK_SHARE_CALLBACK_SCHEME = wristlink-share'),
          contains(
            'WRISTLINK_APP_GROUP = group.com.wristlink.wristlinkFlutter',
          ),
        ),
      );
      expect(infoPlist, contains('WristLinkGoogleMapsApiKey'));
      expect(infoPlist, contains('NSLocationWhenInUseUsageDescription'));
      expect(appDelegate, contains('GMSServices.provideAPIKey(key)'));
      expect(appDelegate, isNot(contains('AIza')));
      expect(
        File('android/app/build.gradle.kts').readAsStringSync(),
        isNot(contains('AIza')),
      );
    });

    test('embeds one flavor-configured iOS Share Extension', () {
      final extensionInfo = File(
        'ios/ShareExtension/Info.plist',
      ).readAsStringSync();
      final runnerEntitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final extensionEntitlements = File(
        'ios/ShareExtension/ShareExtension.entitlements',
      ).readAsStringSync();
      expect(project, contains('PBXNativeTarget "ShareExtension"'));
      expect(project, contains('Embed App Extensions'));
      expect(
        RegExp(
          'ShareExtension.appex in Embed App Extensions',
        ).allMatches(project),
        isNotEmpty,
      );
      expect(
        project,
        contains(
          r'PRODUCT_BUNDLE_IDENTIFIER = "$(WRISTLINK_SHARE_EXTENSION_BUNDLE_IDENTIFIER)"',
        ),
      );
      expect(project, contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0'));
      expect(extensionInfo, contains('NSExtensionActivationSupportsText'));
      expect(
        extensionInfo,
        contains('NSExtensionActivationSupportsWebURLWithMaxCount'),
      );
      expect(runnerEntitlements, contains(r'$(WRISTLINK_APP_GROUP)'));
      expect(extensionEntitlements, contains(r'$(WRISTLINK_APP_GROUP)'));
      expect(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains('SharedContentBridge.shared.handleCallback(url)'),
      );
      expect(
        File('ios/Runner/SceneDelegate.swift').readAsStringSync(),
        contains('SharedContentBridge.shared.handleCallback(context.url)'),
      );
    });
  });
}

final Matcher isAConnectIqUuid = matches(
  RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ),
);

Map<String, String> _parseXcconfigValues(String contents) {
  final values = <String, String>{};

  for (final line in contents.split('\n')) {
    final match = RegExp(r'^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$').firstMatch(line);
    if (match == null) {
      continue;
    }
    values[match.group(1)!] = match.group(2)!;
  }

  return values;
}
