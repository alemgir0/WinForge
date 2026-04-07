# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-04-02
### Added
- Precision diagnostic logging to tweak execution core
- Integration of `Powercfg` commands seamlessly into Tweak logic.
- Included comprehensive documentation structure under `docs/`
- Included `package-release.ps1` for release pipelines.

### Changed
- Refactored winget preflight module to implement robust process-level timeout. (Dropped generic blocking `winget list` fallback)
- Cleaned up app install and tweak application summaries for standard UX reporting.
- Simplified Tweak 'Applicable' errors directly to localized outputs.

### Fixed
- Fixed random startup hangs tied to interactive winget license approvals.
- Fixed 'High Performance' powerplan failing on certain registry hooks by dropping Registry targeting via Powercfg fallback.
