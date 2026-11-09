// Self-check for tool/release.dart; no Flutter SDK needed.
// Run from the project root: dart run tool/release_test.dart

import 'dart:io';

import 'release.dart';

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _expectUsage(void Function() action, String contains) {
  try {
    action();
    throw StateError('expected UsageException containing "$contains"');
  } on UsageException catch (error) {
    _expect(
      error.message.contains(contains),
      'unexpected message: ${error.message}',
    );
  }
}

void _testPlanAndForwarding() {
  final plan = planRelease(<String>[
    'android',
    '--dart-define=OUTLOOK_OAUTH_CLIENT_ID=secret',
    '--dart-define-from-file=oauth.env',
    '--build-name=1.0.1',
    '--build-number=2',
    '--no-pub',
  ], now: DateTime.utc(2000, 1, 1));
  final joined = plan.args.join(' ');
  _expect(
    plan.args.take(4).join(' ') == 'build apk --release --split-debug-info=build/symbols/android/20000101T000000000Z',
    'fixed arguments: $joined',
  );
  _expect(plan.args.contains('--split-per-abi'), 'Android split');
  _expect(
    joined.contains('--dart-define-from-file=oauth.env'),
    'define file forwarded',
  );
  _expect(joined.contains('--build-name=1.0.1'), 'build name forwarded');
  _expect(joined.contains('--build-number=2'), 'build number forwarded');
  _expect(joined.contains('--no-pub'), 'other args forwarded');
  _expect(!joined.contains('obfuscate'), 'obfuscation disabled');
  _expect(plan.artifacts.length == 3, 'three split APK paths');
  _expect(
    plan.artifacts.every((path) => path.contains('-release.apk')),
    'split paths',
  );
  _expect(
    !plan.artifacts.any((path) => path.endsWith('app-release.apk')),
    'no universal path',
  );

  final macos = planRelease(<String>['macos', '--build-name=1.0.1']);
  _expect(macos.args[1] == 'macos', 'macOS subcommand');
  _expect(!macos.args.contains('--split-per-abi'), 'macOS is not split');

  _expectUsage(
    () => planRelease(<String>['android', '--obfuscate']),
    'obfuscate',
  );
  _expectUsage(
    () => planRelease(<String>['android', '--release']),
    '--release',
  );
  _expectUsage(
    () => planRelease(<String>['android', '--split-debug-info=x']),
    'split-debug-info',
  );
  _expectUsage(
    () => planRelease(<String>['android', '--analyze-size']),
    'analyze-size',
  );
  _expectUsage(() => planRelease(<String>['linux']), 'Linux 发布未配置');
  _expectUsage(() => planRelease(<String>['unknown']), '未知目标');
}

void _testFakeFlutter() {
  if (Platform.isWindows) {
    stdout.writeln(
      'release_test: skip POSIX fake-Flutter integration test on Windows',
    );
    return;
  }
  final temp = Directory.systemTemp.createTempSync('email_release_test_');
  try {
    Directory('${temp.path}/build/app/outputs/flutter-apk')
        .createSync(recursive: true);
    final stale = File(
      '${temp.path}/build/app/outputs/flutter-apk/app-release.apk',
    )..writeAsStringSync('stale');

    final fake = File('${temp.path}/fake_flutter.sh');
    fake.writeAsStringSync('''#!/bin/sh
set -eu
for arg in "\$@"; do
  case "\$arg" in
    --split-debug-info=*) dir="\${arg#*=}" ;;
  esac
done
mkdir -p "\$dir"
printf symbols > "\$dir/app.symbols"
mkdir -p build/app/outputs/flutter-apk
printf apk > build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
''');
    Process.runSync('chmod', <String>['+x', fake.path]);

    final script = File('tool/release.dart').absolute.path;
    final results = <ProcessResult>[];
    for (var i = 0; i < 2; i++) {
      results.add(
        Process.runSync(
          Platform.resolvedExecutable,
          <String>[
            script,
            'android',
            '--dart-define=OUTLOOK_OAUTH_CLIENT_ID=secret',
          ],
          workingDirectory: temp.path,
          environment: <String, String>{
            ...Platform.environment,
            'FLUTTER': fake.path,
          },
        ),
      );
    }
    final output = '${results[0].stdout}${results[0].stderr}';
    _expect(
      results.every((result) => result.exitCode == 0),
      'fake build exit: $output',
    );
    _expect(!output.contains('secret'), 'define values are not logged');
    _expect(
      output.contains(
        'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk',
      ),
      'armv7 path printed',
    );
    _expect(
      output.contains('build/app/outputs/flutter-apk/app-x86_64-release.apk'),
      'x64 path printed',
    );
    _expect(stale.existsSync(), 'existing artifacts are not deleted');

    final symbols = Directory('${temp.path}/build/symbols/android')
        .listSync()
        .whereType<Directory>()
        .toList();
    _expect(symbols.length == 2, 'two builds use distinct symbol directories');
    _expect(
      symbols[0].path != symbols[1].path,
      'symbol directories are unique',
    );
  } finally {
    temp.deleteSync(recursive: true);
  }
}

void main() {
  _testPlanAndForwarding();
  _testFakeFlutter();
  stdout.writeln('release_test: all checks passed');
}
