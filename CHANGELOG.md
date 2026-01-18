# Changelog

All notable changes to Calque are documented in this file.

## [1.4.1] - 2026-01-15

### Fixed
- Removed ex_doc from formatter configuration
- Corrected wrong type in typespec

### Changed
- Updated documentation with more idiomatic descriptions
- Upgraded credo and makeup_erlang dependencies

## [1.4.0] - 2025-11-18

### Changed
- Improved the diff algorithm
- Added demo gif to README
- Upgraded credo and exdoc dependencies

## [1.3.1] - 2025-10-29

### Added
- CI pipeline for automated testing
- Support for older Elixir versions

### Fixed
- UI elements display issues

## [1.3.0] - 2025-10-28

### Added
- Command suggestions when misspelling commands

## [1.2.0] - 2025-10-27

### Changed
- Snapshot with an empty title now throws an error for better developer feedback

## [1.1.0] - 2025-10-24

### Added
- `check/1` macro that uses the caller function name as the snapshot title
- Credo for code quality checks

### Fixed
- Various credo issues

## [1.0.1] - 2025-10-23

### Fixed
- Typos in the README
- Removed unnecessary documentation from the diff module

### Changed
- Updated mix.exs for Hex publication

## [1.0.0] - 2025-10-23

### Added
- Initial release of Calque
- Snapshot testing functionality for Elixir
- `Calque.check/2` macro for snapshot assertions
- Diff visualization for comparing snapshots
- Interactive CLI for accepting/rejecting snapshots
