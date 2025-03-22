import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'clean_results.dart';
import 'flutter_project.dart';

/// The main entry point for the Flutter Projects Cleaner.
///
/// This function takes a list of command line arguments and uses them to
/// configure the behavior of the cleaner. It then scans the specified
/// directory for Flutter projects, calculates the size of their build
/// directories, and asks the user for confirmation before cleaning them.
///
/// If the user confirms, the cleaner will run `flutter clean` on each project
/// and report the total space freed. If the user cancels, no changes are made.
///
/// The following command line options are supported:
///
/// * `-d` or `--dir`: The root directory to scan for Flutter projects.
/// * `-r` or `--recursive`: A flag indicating whether to scan subdirectories
///   recursively.
/// * `-v` or `--verbose`: A flag indicating whether to show detailed output.
/// * `--dry-run`: A flag indicating that the cleaner should only show what
///   would be cleaned, without actually cleaning anything.
/// * `--no-confirm`: A flag indicating that the cleaner should skip the
///   confirmation prompt before cleaning.
/// * `-h` or `--help`: A flag indicating that the cleaner should show this help
///   and exit.
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
    ..addFlag('dry-run',
        help: 'Only show what would be cleaned, without actually cleaning',
        defaultsTo: false)
    ..addFlag('no-confirm',
        help: 'Skip confirmation prompt before cleaning', defaultsTo: false)
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
  final dryRun = args['dry-run'];
  final noConfirm = args['no-confirm'];

  print('Flutter Projects Cleaner 🧹');
  print('===========================');
  print('🗂️ Scanning directory: $rootDir');
  print('Recursive scan: ${recursive ? 'Yes' : 'No'}');
  if (dryRun) {
    print('Mode: Dry run (no changes will be made)');
  }
  print('');

  // number of projects found
  int projectsFound = 0;
  // number of projects cleaned
  int projectsCleaned = 0;
  // total space freed
  int spaceFreed = 0;

  try {
    final stopwatch = Stopwatch()..start();
    // First scan to identify projects
    final projectsToClean = await scanForFlutterProjects(
      rootDir,
      recursive: recursive,
      verbose: verbose,
    );

    // Show what was found and ask for confirmation if needed
    if (projectsToClean.isNotEmpty) {
      int totalSize = 0;
      print(
          'Found ${projectsToClean.length} Flutter project(s) with build directories:');

      for (final project in projectsToClean) {
        print('- ${project.path} (${_formatSize(project.buildSize)})');
        totalSize += project.buildSize;
      }

      print('\nTotal space that can be freed: ${_formatSize(totalSize)}');

      bool proceed = dryRun ? false : true;

      if (!dryRun && !noConfirm) {
        proceed = await _confirmCleanup();
      }

      if (dryRun) {
        print('\nDry run completed. No changes were made.');
        projectsFound = projectsToClean.length;
        exit(0);
      }

      if (!proceed) {
        print('\nOperation cancelled. No changes were made.');
        exit(0);
      }

      print('\nCleaning projects...');

      // If we get here, we're proceeding with the cleanup
      final results = await cleanFlutterProjects(
        projectsToClean,
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
    }
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

/// Scans a given directory to identify Flutter projects with non-empty build directories.
///
/// This function searches for Flutter projects within the specified `rootDirPath`.
/// It checks each directory to determine if it's a Flutter project by looking for
/// a `pubspec.yaml` file that declares Flutter as a dependency. If a valid Flutter
/// project is found, the function calculates the size of its `build` directory.
///
/// If the `recursive` flag is set to `true`, the scan will include all subdirectories
/// within the specified root directory. The `verbose` flag, if enabled, will provide
/// detailed output of the scanning process, including paths of found projects and
/// skipped directories.
///
/// Throws an exception if the specified `rootDirPath` does not exist.
///
/// Returns a `Future` containing a list of `FlutterProject` objects, each representing
/// a discovered project with its path and build directory size.
Future<List<FlutterProject>> scanForFlutterProjects(
  String rootDirPath, {
  required bool recursive,
  required bool verbose,
}) async {
  final rootDir = Directory(rootDirPath);
  if (!await rootDir.exists()) {
    throw Exception('Directory does not exist: $rootDirPath');
  }

  final flutterProjects = <FlutterProject>[];

  await for (final entity in _listDirectories(rootDir, recursive: recursive)) {
    if (await _isFlutterProject(entity.path)) {
      if (verbose) {
        print('Found Flutter project at: ${entity.path}');
      }

      final buildDir = Directory(path.join(entity.path, 'build'));
      final size = await _calculateDirectorySize(buildDir);

      if (size > 0) {
        flutterProjects.add(FlutterProject(
          path: entity.path,
          buildSize: size,
        ));
      } else if (verbose) {
        print('• Skipped: ${entity.path} (no build directory or empty)');
      }
    }
  }

  return flutterProjects;
}

///
/// Runs `flutter clean` on each of the given `projects` and returns a `Future`
/// containing a `CleanResults` object with the summary of the cleaning
/// operation.
///
/// The `verbose` flag controls whether detailed output is shown.
///
/// If the `flutter clean` command succeeds, the `exitCode` is 0 and the
/// `buildSize` of the project is added to the total `spaceFreed`. A
/// success message is printed.
///
/// If the `flutter clean` command fails, an error message is printed. If
/// `verbose` is true, the error output is also printed.
///
/// Any unhandled exceptions during the cleaning process are caught and
/// reported as errors.
///
Future<CleanResults> cleanFlutterProjects(
  List<FlutterProject> projects, {
  required bool verbose,
}) async {
  int projectsCleaned = 0;
  int spaceFreed = 0;
  final futures = <Future>[];

  for (final project in projects) {
    final future = Future(() async {
      try {
        final result = await _runFlutterClean(project.path, verbose: verbose);
        if (result.exitCode == 0) {
          projectsCleaned++;
          spaceFreed += project.buildSize;
          print(
              '✅ Cleaned: ${project.path} (freed ${_formatSize(project.buildSize)})');
        } else {
          print('❌ Failed to clean: ${project.path}');
          if (verbose) {
            print(' ❌❌ Error: ${result.stderr}');
          }
        }
      } catch (e) {
        print('❌ Error cleaning: ${project.path}');
        if (verbose) {
          print(' ❌❌ Error: $e');
        }
      }
    });

    futures.add(future);
  }

  await Future.wait(futures);

  return CleanResults(
    projectsFound: projects.length,
    projectsCleaned: projectsCleaned,
    spaceFreed: spaceFreed,
  );
}

/// Prompts the user to confirm whether to proceed with cleaning the
/// projects.
///
/// Prints a message to the console and waits for user input. If the
/// response is 'y' or 'yes', the function returns true. Otherwise, it
/// returns false.
Future<bool> _confirmCleanup() async {
  stdout.write('Do you want to proceed with cleaning these projects? [y/N]: ');
  final response = stdin.readLineSync()?.toLowerCase() ?? '';
  return response == 'y' || response == 'yes';
}

/// Streams a list of directories in a given directory.
///
/// If the `recursive` parameter is set to `true`, the function will
/// recursively traverse all subdirectories. Otherwise, it only yields
/// the given root directory.
///
/// Skips hidden directories (directories starting with a '.' and 'node_modules')
/// from the stream.
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

/// Determines if a given directory is hidden or is a 'node_modules' directory.
///
/// A directory is considered hidden if its name starts with a '.' or if it is named 'node_modules'.
/// This function returns `true` for hidden directories, otherwise `false`.
///
/// [dir] The directory to check.

bool _isHiddenDirectory(Directory dir) {
  final basename = path.basename(dir.path);
  return basename.startsWith('.') || basename == 'node_modules';
}

/// Checks if a given directory is a Flutter project.
///
/// A Flutter project is a directory that contains a `pubspec.yaml` file
/// that declares a dependency on the `flutter` package or has `sdk: flutter`
/// in its `pubspec.yaml`.
///
/// [dirPath] The path of the directory to check.
///
/// Returns `true` if the directory is a Flutter project, `false` otherwise.
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

/// Calculates the size of a given directory.
///
/// The size of a directory is the sum of the lengths of all files directly
/// inside the directory, and recursively all files inside subdirectories.
///
/// If the directory does not exist, this function returns 0.
///
/// [dir] The directory of which to calculate the size.
///
/// Returns the size of the directory in bytes.
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

/// Runs the `flutter clean` command in the specified `projectDir`.
///
/// This function executes the `flutter clean` command, which removes the
/// build and temporary directories within a Flutter project to free up
/// disk space and resolve potential build issues.
///
/// The `verbose` parameter, if set to `true`, will print a message indicating
/// that the `flutter clean` command is being run in the specified directory.
///
/// Returns a `Future` that completes with a `ProcessResult` containing the
/// exit code, stdout, and stderr of the `flutter clean` command execution.
///
/// [projectDir] The directory of the Flutter project where the clean command
/// should be executed.
/// [verbose] If `true`, prints a message when the clean command is executed.

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

/// Formats a given number of bytes as a human-readable string.
///
/// The method takes the number of bytes as an argument and returns a string
/// that represents the size of the given number of bytes in bytes (B), kilobytes
/// (KB), megabytes (MB), or gigabytes (GB), with one decimal place.
String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Prints the usage message for the Flutter Projects Cleaner tool.
///
/// This function takes an `ArgParser` and prints a message with the tool's
/// name, description, usage, and options.
///
/// The usage message is printed to the console as follows:
///
///
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
