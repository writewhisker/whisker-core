# Changelog

All notable changes to whisker-core will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
