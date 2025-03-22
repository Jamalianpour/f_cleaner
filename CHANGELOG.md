## 1.1.0

- Dry run mode (--dry-run flag) to preview what would be cleaned without making changes
- Confirmation prompt before cleaning projects
- Option to skip confirmation (--no-confirm flag) for use in automated scripts
- Enhanced the output format to display all projects before cleaning
- Updated documentation to reflect new features and add comment to the code

## 1.0.0

- Initial release of Flutter Cleaner
- Scan directories recursively for Flutter projects
- Identify Flutter projects by checking pubspec.yaml
- Calculate build directory sizes before cleaning
- Run flutter clean on identified projects
- Report total space freed
- Parallel processing of multiple projects
- Command-line arguments for customization
  - Directory selection (--dir)
  - Recursive scanning control (--recursive)
  - Verbose output (--verbose)
  - Help display (--help)