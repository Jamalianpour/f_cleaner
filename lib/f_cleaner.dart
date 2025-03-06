import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  // Parse command line arguments
  final parser = ArgParser()
    ..addOption('dir',
        abbr: 'd',
        help: 'The root directory to scan for Flutter projects',
        defaultsTo: Directory.current.path)
    ..addFlag('recursive',
        abbr: 'r', help: 'Scan subdirectories recursively', defaultsTo: true)
    ..addFlag('verbose',
        abbr: 'v', help: 'Show detailed output', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'Show this help', negatable: false);

  ArgResults args;
  try {
    args = parser.parse(arguments);
    if (args['help']) {
      _printUsage(parser);
      exit(0);
    }
  } catch (e) {
    print('Error: $e');
    _printUsage(parser);
    exit(1);
  }

  final rootDir = args['dir'];
  final recursive = args['recursive'];
  final verbose = args['verbose'];

  print('Flutter Projects Cleaner 🧹');
  print('===========================');
  print('🗂️ Scanning directory: $rootDir');
  print('Recursive scan: ${recursive ? 'Yes' : 'No'}');
  print('');

  int projectsFound = 0;
  int projectsCleaned = 0;
  int spaceFreed = 0;

  try {
    final stopwatch = Stopwatch()..start();
    final results = await scanAndCleanFlutterProjects(
      rootDir,
      recursive: recursive,
      verbose: verbose,
    );
    stopwatch.stop();

    projectsFound = results.projectsFound;
    projectsCleaned = results.projectsCleaned;
    spaceFreed = results.spaceFreed;

    print('');
    print('Summary');
    print('-------');
    print('Flutter projects found: $projectsFound');
    print('Projects cleaned: $projectsCleaned');
    print('Approximate space freed: ${_formatSize(spaceFreed)}');
    print('Time taken: ${stopwatch.elapsed.inSeconds} seconds');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<CleanResults> scanAndCleanFlutterProjects(
  String rootDirPath, {
  required bool recursive,
  required bool verbose,
}) async {
  final rootDir = Directory(rootDirPath);
  if (!await rootDir.exists()) {
    throw Exception('Directory does not exist: $rootDirPath');
  }

  int projectsFound = 0;
  int projectsCleaned = 0;
  int spaceFreed = 0;

  final futures = <Future>[];

  await for (final entity in _listDirectories(rootDir, recursive: recursive)) {
    if (await _isFlutterProject(entity.path)) {
      projectsFound++;

      if (verbose) {
        print('Found Flutter project at: ${entity.path}');
      }

      final buildDir = Directory(path.join(entity.path, 'build'));
      final future = _calculateDirectorySize(buildDir).then((size) async {
        if (size > 0) {
          try {
            final result =
                await _runFlutterClean(entity.path, verbose: verbose);
            if (result.exitCode == 0) {
              projectsCleaned++;
              spaceFreed += size;
              print('✅ Cleaned: ${entity.path} (freed ${_formatSize(size)})');
            } else {
              print('❌ Failed to clean: ${entity.path}');
              if (verbose) {
                print('  Error: ${result.stderr}');
              }
            }
          } catch (e) {
            print('❌ Error cleaning: ${entity.path}');
            if (verbose) {
              print('  Error: $e');
            }
          }
        } else if (verbose) {
          print('🚫 Skipped: ${entity.path} (no build directory or empty)');
        }
      });

      futures.add(future);
    }
  }

  await Future.wait(futures);

  return CleanResults(
    projectsFound: projectsFound,
    projectsCleaned: projectsCleaned,
    spaceFreed: spaceFreed,
  );
}

Stream<Directory> _listDirectories(Directory dir,
    {required bool recursive}) async* {
  yield dir;

  if (recursive) {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory && !_isHiddenDirectory(entity)) {
        yield* _listDirectories(entity, recursive: true);
      }
    }
  }
}

bool _isHiddenDirectory(Directory dir) {
  final basename = path.basename(dir.path);
  return basename.startsWith('.') || basename == 'node_modules';
}

Future<bool> _isFlutterProject(String dirPath) async {
  // Check for pubspec.yaml file
  final pubspecFile = File(path.join(dirPath, 'pubspec.yaml'));
  if (!await pubspecFile.exists()) {
    return false;
  }

  // Read pubspec.yaml and check for Flutter dependency
  try {
    final content = await pubspecFile.readAsString();
    return content.contains('flutter:') || content.contains('sdk: flutter');
  } catch (_) {
    return false;
  }
}

Future<int> _calculateDirectorySize(Directory dir) async {
  if (!await dir.exists()) {
    return 0;
  }

  int size = 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
  } catch (_) {
    // Ignore errors
  }

  return size;
}

Future<ProcessResult> _runFlutterClean(String projectDir,
    {required bool verbose}) async {
  if (verbose) {
    print('Running flutter clean in $projectDir');
  }

  return await Process.run(
    'flutter',
    ['clean'],
    workingDirectory: projectDir,
    runInShell: true,
  );
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

void _printUsage(ArgParser parser) {
  print('Flutter Projects Cleaner');
  print('');
  print(
      'A CLI tool to scan directories for Flutter projects and run "flutter clean" to free up disk space.');
  print('');
  print('Usage:');
  print('  flutter_cleaner [options]');
  print('');
  print('Options:');
  print(parser.usage);
}

class CleanResults {
  final int projectsFound;
  final int projectsCleaned;
  final int spaceFreed;

  CleanResults({
    required this.projectsFound,
    required this.projectsCleaned,
    required this.spaceFreed,
  });
}
