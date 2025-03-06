# Flutter Cleaner (f_cleaner) 🧹

A Dart CLI tool that automatically scans directories for Flutter projects and runs `flutter clean` to free up disk space.

## The Problem

Flutter projects accumulate large build directories that consume significant disk space. Manually cleaning each project becomes tedious when you're working on multiple projects.

## The Solution

This tool automatically:
- Scans directories to identify Flutter projects
- Calculates build directory sizes
- Runs `flutter clean` on each project
- Reports total space freed

## Installation
You can install flutter cleaner CLI from github repository or pub.dev:
```bash
# From Github
dart pub global activate -sgit https://github.com/Jamalianpour/f_cleaner.git

# From Pub.dev
dart pub global activate f_cleaner
```

Or install and active it from source code:
```bash
# Clone the repository
git clone https://github.com/yourusername/f_cleaner.git
cd f_cleaner

# Install dependencies
dart pub get

# Activate the CLI tool globally
dart pub global activate --source path .
```

## Usage

```bash
# Clean Flutter projects in current directory and subdirectories
f_cleaner

# Clean Flutter projects in a specific directory
f_cleaner --dir=/path/to/your/flutter/projects

# Non-recursive scan
f_cleaner --dir=/path/to/projects --no-recursive

# Show detailed output
f_cleaner --verbose

# Show help
f_cleaner --help
```

## Example Output

```
Flutter Projects Cleaner 🧹
===========================
🗂️ Scanning directory: /Users/username/development
Recursive scan: Yes

✅ Cleaned: /Users/username/development/project1 (freed 2.3 GB)
✅ Cleaned: /Users/username/development/project2 (freed 1.8 GB)
✅ Cleaned: /Users/username/development/clients/project3 (freed 3.2 GB)

Summary
-------
Flutter projects found: 3
Projects cleaned: 3
Approximate space freed: 7.3 GB
Time taken: 5 seconds
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Related

Read the full story behind this tool in my [Medium article](https://jamalianpour.medium.com/flutter-build-directories-are-eating-your-ssd-heres-how-to-fight-back-3e4adf22058b).