import 'dart:io';

import 'package:path/path.dart' as path;

typedef CommandRunner =
    Future<CommandResult> Function(String executable, List<String> arguments);

typedef FileExists = bool Function(String filePath);

typedef InheritedProcessRunner =
    Future<int> Function(
      String executable,
      List<String> arguments, {
      required String workingDirectory,
      required Map<String, String> environment,
      required bool runInShell,
    });

class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class JdkResolutionException implements Exception {
  const JdkResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class JdkResolver {
  JdkResolver({
    Map<String, String>? environment,
    bool? isWindows,
    CommandRunner? runCommand,
    FileExists? fileExists,
  }) : environment = environment ?? Platform.environment,
       isWindows = isWindows ?? Platform.isWindows,
       _runCommand = runCommand ?? _runCommandNormally,
       _fileExists = fileExists ?? _fileExistsNormally;

  final Map<String, String> environment;
  final bool isWindows;
  final CommandRunner _runCommand;
  final FileExists _fileExists;

  Future<String> resolve() async {
    final configuredJavaHome = environment['JAVA_HOME']?.trim();
    if (configuredJavaHome != null && configuredJavaHome.isNotEmpty) {
      final validated = await _validateJavaHome(configuredJavaHome);
      if (validated != null) {
        return validated;
      }
    }

    CommandResult doctorResult;
    try {
      doctorResult = await _runCommand('flutter', const ['doctor', '-v']);
    } on ProcessException {
      throw const JdkResolutionException(
        'Unable to run `flutter doctor -v` while locating a supported JDK.\n'
        'Install Flutter or configure its JDK with '
        '`flutter config --jdk-dir="<path>"`, then retry.',
      );
    }

    final doctorOutput = '${doctorResult.stdout}\n${doctorResult.stderr}';
    final javaBinary = extractJavaBinaryPath(doctorOutput);
    if (javaBinary != null) {
      final javaHome = deriveJavaHome(javaBinary, isWindows: isWindows);
      final validated = await _validateJavaHome(javaHome);
      if (validated != null) {
        return validated;
      }
    }

    throw const JdkResolutionException(
      'WristLink Android Gradle tasks require Java 17 or Java 21, but neither '
      '`JAVA_HOME` nor Flutter supplied a supported JDK.\n'
      'Configure Flutter with `flutter config --jdk-dir="<path>"`, then retry.',
    );
  }

  Future<String?> _validateJavaHome(String javaHome) async {
    final context = path.Context(
      style: isWindows ? path.Style.windows : path.Style.posix,
    );
    final normalizedHome = context.normalize(javaHome);
    final javaExecutable = javaExecutableFor(
      normalizedHome,
      isWindows: isWindows,
    );
    if (!_fileExists(javaExecutable)) {
      return null;
    }

    CommandResult versionResult;
    try {
      versionResult = await _runCommand(javaExecutable, const ['-version']);
    } on ProcessException {
      return null;
    }
    if (versionResult.exitCode != 0) {
      return null;
    }

    final versionOutput = '${versionResult.stdout}\n${versionResult.stderr}';
    final majorVersion = parseJavaMajorVersion(versionOutput);
    if (majorVersion != 17 && majorVersion != 21) {
      return null;
    }
    return normalizedHome;
  }

  static String? extractJavaBinaryPath(String doctorOutput) {
    const marker = 'Java binary at:';
    for (final line in doctorOutput.split(RegExp(r'\r?\n'))) {
      final markerIndex = line.indexOf(marker);
      if (markerIndex < 0) {
        continue;
      }
      final value = line.substring(markerIndex + marker.length).trim();
      if (value.isEmpty) {
        return null;
      }
      return _stripOuterQuotes(value);
    }
    return null;
  }

  static String deriveJavaHome(String javaBinary, {required bool isWindows}) {
    final context = path.Context(
      style: isWindows ? path.Style.windows : path.Style.posix,
    );
    return context.normalize(context.dirname(context.dirname(javaBinary)));
  }

  static String javaExecutableFor(String javaHome, {required bool isWindows}) {
    final context = path.Context(
      style: isWindows ? path.Style.windows : path.Style.posix,
    );
    return context.join(javaHome, 'bin', isWindows ? 'java.exe' : 'java');
  }

  static int? parseJavaMajorVersion(String versionOutput) {
    final quotedVersion = RegExp(
      r'(?:java|openjdk) version "([^"]+)"',
      caseSensitive: false,
    ).firstMatch(versionOutput);
    final unquotedVersion = RegExp(
      r'(?:java|openjdk)\s+([0-9][^\s]*)',
      caseSensitive: false,
    ).firstMatch(versionOutput);
    final version = quotedVersion?.group(1) ?? unquotedVersion?.group(1);
    if (version == null) {
      return null;
    }

    final numericParts = RegExp(
      r'\d+',
    ).allMatches(version).map((match) => int.parse(match.group(0)!)).toList();
    if (numericParts.isEmpty) {
      return null;
    }
    if (numericParts.first == 1 && numericParts.length > 1) {
      return numericParts[1];
    }
    return numericParts.first;
  }

  static String _stripOuterQuotes(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static Future<CommandResult> _runCommandNormally(
    String executable,
    List<String> arguments,
  ) async {
    final result = await Process.run(executable, arguments);
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }

  static bool _fileExistsNormally(String filePath) =>
      File(filePath).existsSync();
}

class AndroidGradleInvocation {
  const AndroidGradleInvocation({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.runInShell,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final bool runInShell;
}

AndroidGradleInvocation buildAndroidGradleInvocation({
  required String repositoryRoot,
  required List<String> forwardedArguments,
  required bool isWindows,
}) {
  final context = path.Context(
    style: isWindows ? path.Style.windows : path.Style.posix,
  );
  final wrapperName = isWindows ? 'gradlew.bat' : 'gradlew';
  return AndroidGradleInvocation(
    executable: context.join(repositoryRoot, 'android', wrapperName),
    arguments: ['-p', 'android', ...forwardedArguments],
    workingDirectory: repositoryRoot,
    runInShell: isWindows,
  );
}

class AndroidGradleLauncher {
  AndroidGradleLauncher({bool? isWindows, InheritedProcessRunner? runProcess})
    : isWindows = isWindows ?? Platform.isWindows,
      _runProcess = runProcess ?? _runProcessNormally;

  final bool isWindows;
  final InheritedProcessRunner _runProcess;

  Future<int> run({
    required String repositoryRoot,
    required String javaHome,
    required List<String> forwardedArguments,
  }) {
    final invocation = buildAndroidGradleInvocation(
      repositoryRoot: repositoryRoot,
      forwardedArguments: forwardedArguments,
      isWindows: isWindows,
    );
    return _runProcess(
      invocation.executable,
      invocation.arguments,
      workingDirectory: invocation.workingDirectory,
      environment: {'JAVA_HOME': javaHome},
      runInShell: invocation.runInShell,
    );
  }

  static Future<int> _runProcessNormally(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    required Map<String, String> environment,
    required bool runInShell,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: true,
      mode: ProcessStartMode.inheritStdio,
      runInShell: runInShell,
    );
    return process.exitCode;
  }
}

String repositoryRootFromScript(Uri script, {required bool isWindows}) {
  final context = path.Context(
    style: isWindows ? path.Style.windows : path.Style.posix,
  );
  final scriptPath = script.toFilePath(windows: isWindows);
  return context.normalize(context.dirname(context.dirname(scriptPath)));
}

Future<void> main(List<String> arguments) async {
  try {
    final javaHome = await JdkResolver().resolve();
    final repositoryRoot = repositoryRootFromScript(
      Platform.script,
      isWindows: Platform.isWindows,
    );
    exitCode = await AndroidGradleLauncher().run(
      repositoryRoot: repositoryRoot,
      javaHome: javaHome,
      forwardedArguments: arguments,
    );
  } on JdkResolutionException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } on ProcessException catch (error) {
    stderr.writeln('Unable to start Android Gradle: $error');
    exitCode = 1;
  }
}
