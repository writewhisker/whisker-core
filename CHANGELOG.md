# Changelog

All notable changes to whisker-core will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Format v2.0 Support (Phase 1)**:
  - Typed variables with `{ type, default }` format
  - Choice IDs for stable tracking across versions
  - Passage and choice metadata system
  - Passage size property (width, height)
  - Asset management with `asset://` URL scheme
  - Auto-migration from v1.0 to v2.0 format
- **Enhanced API (Phase 2)**:
  - Metadata helper methods: `get_metadata(key, default)`, `has_metadata(key)`, `delete_metadata(key)`, `clear_metadata()`, `get_all_metadata()` on both Passage and Choice
  - Asset management methods: `add_asset(asset)`, `get_asset(asset_id)`, `remove_asset(asset_id)`, `list_assets()`, `has_asset(asset_id)`, `get_asset_references(asset_id)` on Story
  - Asset serialization in Story format
  - Example files demonstrating v2.0 features: typed variables, metadata usage, asset integration
- Initial release of whisker-core as separate repository
- Core Lua library for interactive fiction
- Story parser supporting passage-based narratives
- State management system
- Template system for dynamic content
- Choice and link handling
- CLI tools for story validation and testing
- Runtime players (web, CLI, desktop)
- Comprehensive test suite with busted
- LuaRocks package configuration
- GitHub Actions CI/CD workflows
- Documentation (README, AUTHORING, TESTING)
- Examples and templates

### Changed
- Separated from original jmspring/whisker repository
- Maintained MIT license for backward compatibility
- Updated documentation for writewhisker organization

### Infrastructure
- GitHub Actions workflow for multi-Lua-version testing
- LuaRocks package configuration
- Makefile build system
- Luacheck configuration for code quality

## Release Notes

### Version Numbering

whisker-core follows [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible new features
- **PATCH** version for backwards-compatible bug fixes

### Deprecation Policy

- Features marked as deprecated will remain for at least one minor version
- Breaking changes will be announced in advance
- Migration guides will be provided for breaking changes

---

## Template for Future Releases

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Features that will be removed in upcoming releases

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security vulnerability fixes (see SECURITY.md)

### Performance
- Performance improvements
```

---

[Unreleased]: https://github.com/writewhisker/whisker-core/compare/v1.0.0...HEAD
