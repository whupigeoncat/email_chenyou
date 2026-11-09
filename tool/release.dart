import 'dart:io';

const _usage = '''
Release build helper.

Targets: android (split APK), appbundle, macos, ios, windows.
Arguments after the target are forwarded to Flutter unchanged.
Always adds --release and --split-debug-info=<unique UTC dir>; Android APKs
also get --split-per-abi. Obfuscation is not enabled.
--dry-run prints the plan; --help shows this message.
''';

class UsageException implements Exception {
  UsageException(this.message);
  final String message;
}

typedef Plan = ({
  String target,
  String flutter,
  List<String> args,
  String dir,
  List<String> artifacts,
  bool dryRun,
});

const _subcommands = <String, String>{
  'android': 'apk',
  'appbundle': 'appbundle',
  'macos': 'macos',
  'ios': 'ipa',
  'windows': 'windows',
};

const _artifacts = <String, List<String>>{
  'android': <String>[
    'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk',
    'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk',
    'build/app/outputs/flutter-apk/app-x86_64-release.apk',
  ],
  'appbundle': <String>['build/app/outputs/bundle/release/app-release.aab'],
  'macos': <String>['build/macos/Build/Products/Release/local_mail_client.app'],
  'ios': <String>['build/ios/ipa/'],
  'windows': <String>['build/windows/<arch>/runner/Release/'],
};

// Flags that would override the release/symbol/obfuscation policy.
const _conflicts = <String>[
  '--debug',
  '--profile',
  '--release',
  '--split-debug-info',
  '--obfuscate',
  '--no-obfuscate',
  '--analyze-size',
  '--no-analyze-size',
];

String _utcStamp(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}T'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}'
      '${now.millisecond.toString().padLeft(3, '0')}Z';
}

String _symbolsDir(String target, DateTime now) {
  final stamp = _utcStamp(now.toUtc());
  var dir = 'build/symbols/$target/$stamp';
  for (var suffix = 1; Directory(dir).existsSync(); suffix++) {
    dir = 'build/symbols/$target/${stamp}_$suffix';
  }
  return dir;
}

Plan planRelease(
  List<String> argv, {
  String flutter = 'flutter',
  DateTime? now,
}) {
  final args = List<String>.of(argv);
  final dryRun = args.remove('--dry-run');
  if (args.isEmpty) {
    throw UsageException('缺少目标；可用目标：${_subcommands.keys.join(', ')}');
  }
  final target = args.removeAt(0);
  if (target == 'linux') {
    throw UsageException('当前仓库没有 linux/ 目录，Linux 发布未配置；脚本不会创建平台或猜测工具链。');
  }
  final subcommand = _subcommands[target];
  if (subcommand == null) {
    throw UsageException('未知目标 "$target"；可用目标：${_subcommands.keys.join(', ')}');
  }
  for (final arg in args) {
    for (final conflict in _conflicts) {
      if (arg == conflict || arg.startsWith('$conflict=')) {
        throw UsageException(
          '不能覆盖 $conflict；发布构建固定 release + split-debug-info，且不启用 obfuscation。',
        );
      }
    }
  }
  final dir = _symbolsDir(target, now ?? DateTime.now());
  return (
    target: target,
    flutter: flutter,
    args: <String>[
      'build',
      subcommand,
      '--release',
      '--split-debug-info=$dir',
      if (target == 'android') '--split-per-abi',
      ...args,
    ],
    dir: dir,
    artifacts: _artifacts[target]!,
    dryRun: dryRun,
  );
}

Future<void> main(List<String> argv) async {
  if (argv.isEmpty || argv.contains('--help') || argv.contains('-h')) {
    stdout.write(_usage);
    if (argv.isEmpty) exitCode = 64;
    return;
  }
  try {
    final plan = planRelease(
      argv,
      flutter: Platform.environment['FLUTTER'] ?? 'flutter',
    );
    stdout.writeln('[release] symbols: ${plan.dir}');
    stdout.writeln(
      '[release] command: flutter build ${plan.args[1]} '
      '--release --split-debug-info=<dir>'
      '${plan.target == 'android' ? ' --split-per-abi' : ''} '
      '(+ forwarded args)',
    );
    stdout.writeln(
      '[release] expected artifacts:\n  '
      '${plan.artifacts.join('\n  ')}',
    );
    if (plan.dryRun) return;

    Directory(plan.dir).createSync(recursive: true);
    final process = await Process.start(
      plan.flutter,
      plan.args,
      workingDirectory: Directory.current.path,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on UsageException catch (error) {
    stderr.writeln('[release] ${error.message}');
    exitCode = 64;
  } on ProcessException catch (error) {
    stderr.writeln('[release] 无法运行 Flutter：${error.message}');
    exitCode = 1;
  }
}
