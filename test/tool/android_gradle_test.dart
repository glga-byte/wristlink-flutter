import 'package:flutter_test/flutter_test.dart';

import '../../tool/android_gradle.dart';

void main() {
  group('JdkResolver', () {
    test('uses a supported JAVA_HOME without consulting Flutter', () async {
      const javaHome =
          '/Applications/Android Studio.app/Contents/jbr/Contents/Home';
      final commands = <String>[];
      final resolver = JdkResolver(
        environment: const {'JAVA_HOME': javaHome},
        isWindows: false,
        fileExists: (_) => true,
        runCommand: (executable, arguments) async {
          commands.add('$executable ${arguments.join(' ')}');
          return const CommandResult(
            exitCode: 0,
            stdout: '',
            stderr: 'openjdk version "21.0.7" 2025-04-15 LTS',
          );
        },
      );

      expect(await resolver.resolve(), javaHome);
      expect(commands, hasLength(1));
      expect(commands.single, endsWith('/bin/java -version'));
    });

    test('falls back to the JDK selected by Flutter', () async {
      const configuredHome = '/unsupported/jdk';
      const flutterHome =
          '/Applications/Android Studio.app/Contents/jbr/Contents/Home';
      final resolver = JdkResolver(
        environment: const {'JAVA_HOME': configuredHome},
        isWindows: false,
        fileExists: (_) => true,
        runCommand: (executable, arguments) async {
          if (executable == 'flutter') {
            return const CommandResult(
              exitCode: 0,
              stdout:
                  '[✓] Android toolchain\n'
                  '    • Java binary at: '
                  '$flutterHome/bin/java\n',
              stderr: '',
            );
          }
          if (executable.startsWith(configuredHome)) {
            return const CommandResult(
              exitCode: 0,
              stdout: '',
              stderr: 'openjdk version "26" 2026-03-17',
            );
          }
          return const CommandResult(
            exitCode: 0,
            stdout: '',
            stderr: 'openjdk version "17.0.15" 2025-04-15 LTS',
          );
        },
      );

      expect(await resolver.resolve(), flutterHome);
    });

    test('uses Flutter JDK output despite unrelated doctor failures', () async {
      const flutterHome = '/opt/android-studio/jbr';
      final resolver = JdkResolver(
        environment: const {},
        isWindows: false,
        fileExists: (_) => true,
        runCommand: (executable, arguments) async {
          if (executable == 'flutter') {
            return const CommandResult(
              exitCode: 1,
              stdout:
                  '[✓] Android toolchain\n'
                  '    • Java binary at: $flutterHome/bin/java\n'
                  '[✗] Chrome - develop for the web',
              stderr: '',
            );
          }
          return const CommandResult(
            exitCode: 0,
            stdout: '',
            stderr: 'openjdk version "21.0.7" 2025-04-15 LTS',
          );
        },
      );

      expect(await resolver.resolve(), flutterHome);
    });

    test('rejects missing and unsupported JDKs with setup guidance', () async {
      final resolver = JdkResolver(
        environment: const {'JAVA_HOME': '/missing/jdk'},
        isWindows: false,
        fileExists: (filePath) => filePath == '/java-26/bin/java',
        runCommand: (executable, arguments) async {
          if (executable == 'flutter') {
            return const CommandResult(
              exitCode: 0,
              stdout: '• Java binary at: /java-26/bin/java',
              stderr: '',
            );
          }
          return const CommandResult(
            exitCode: 0,
            stdout: '',
            stderr: 'openjdk version "26.0.1" 2026-04-21',
          );
        },
      );

      await expectLater(
        resolver.resolve(),
        throwsA(
          isA<JdkResolutionException>()
              .having(
                (error) => error.message,
                'message',
                contains('Java 17 or Java 21'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('flutter config --jdk-dir'),
              ),
        ),
      );
    });

    test('extracts Java paths from macOS, Linux, and Windows doctor output', () {
      const cases = <String, String>{
        '[✓] Android toolchain\n'
                '    • Java binary at: '
                '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java':
            '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java',
        '[✓] Android toolchain\n'
                '    • Java binary at: /opt/android-studio/jbr/bin/java':
            '/opt/android-studio/jbr/bin/java',
        '[√] Android toolchain\r\n'
                '    • Java binary at: '
                r'C:\Program Files\Android\Android Studio\jbr\bin\java.exe':
            r'C:\Program Files\Android\Android Studio\jbr\bin\java.exe',
      };

      for (final MapEntry(key: output, value: expected) in cases.entries) {
        expect(JdkResolver.extractJavaBinaryPath(output), expected);
      }
    });

    test('derives platform JDK homes from Java binary paths', () {
      expect(
        JdkResolver.deriveJavaHome(
          '/opt/android-studio/jbr/bin/java',
          isWindows: false,
        ),
        '/opt/android-studio/jbr',
      );
      expect(
        JdkResolver.deriveJavaHome(
          r'C:\Program Files\Android\Android Studio\jbr\bin\java.exe',
          isWindows: true,
        ),
        r'C:\Program Files\Android\Android Studio\jbr',
      );
    });

    test('parses supported and legacy Java version formats', () {
      expect(
        JdkResolver.parseJavaMajorVersion(
          'openjdk version "17.0.15" 2025-04-15',
        ),
        17,
      );
      expect(
        JdkResolver.parseJavaMajorVersion(
          'openjdk version "21.0.7" 2025-04-15 LTS',
        ),
        21,
      );
      expect(JdkResolver.parseJavaMajorVersion('java version "1.8.0_451"'), 8);
    });
  });

  group('Android Gradle invocation', () {
    test('selects the Unix wrapper and supplies the Android project', () {
      final invocation = buildAndroidGradleInvocation(
        repositoryRoot: '/workspace/wristlink',
        forwardedArguments: const ['testDevDebugUnitTest', '--stacktrace'],
        isWindows: false,
      );

      expect(invocation.executable, '/workspace/wristlink/android/gradlew');
      expect(invocation.arguments, const [
        '-p',
        'android',
        'testDevDebugUnitTest',
        '--stacktrace',
      ]);
      expect(invocation.workingDirectory, '/workspace/wristlink');
      expect(invocation.runInShell, isFalse);
    });

    test('selects the Windows wrapper', () {
      final invocation = buildAndroidGradleInvocation(
        repositoryRoot: r'C:\workspace\wristlink',
        forwardedArguments: const ['connectedDevDebugAndroidTest'],
        isWindows: true,
      );

      expect(
        invocation.executable,
        r'C:\workspace\wristlink\android\gradlew.bat',
      );
      expect(invocation.arguments, const [
        '-p',
        'android',
        'connectedDevDebugAndroidTest',
      ]);
      expect(invocation.runInShell, isTrue);
    });

    test('injects JAVA_HOME and propagates the Gradle exit code', () async {
      String? capturedExecutable;
      List<String>? capturedArguments;
      String? capturedWorkingDirectory;
      Map<String, String>? capturedEnvironment;
      bool? capturedRunInShell;
      final launcher = AndroidGradleLauncher(
        isWindows: false,
        runProcess:
            (
              executable,
              arguments, {
              required workingDirectory,
              required environment,
              required runInShell,
            }) async {
              capturedExecutable = executable;
              capturedArguments = arguments;
              capturedWorkingDirectory = workingDirectory;
              capturedEnvironment = environment;
              capturedRunInShell = runInShell;
              return 37;
            },
      );

      final result = await launcher.run(
        repositoryRoot: '/workspace/wristlink',
        javaHome: '/jdk 21',
        forwardedArguments: const ['clean', 'build'],
      );

      expect(result, 37);
      expect(capturedExecutable, '/workspace/wristlink/android/gradlew');
      expect(capturedArguments, const ['-p', 'android', 'clean', 'build']);
      expect(capturedWorkingDirectory, '/workspace/wristlink');
      expect(capturedEnvironment, const {'JAVA_HOME': '/jdk 21'});
      expect(capturedRunInShell, isFalse);
    });
  });
}
