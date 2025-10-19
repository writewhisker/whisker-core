# Contributing to whisker-core

Thank you for your interest in contributing to whisker-core! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Submitting Changes](#submitting-changes)
- [License](#license)

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## Getting Started

### Prerequisites

- Lua 5.1, 5.2, 5.3, 5.4, or LuaJIT 2.1+
- LuaRocks (for installing dependencies)
- Git
- Basic familiarity with interactive fiction concepts

### Installing Dependencies

```bash
# Clone the repository
git clone https://github.com/writewhisker/whisker-core.git
cd whisker-core

# Install development dependencies
luarocks install busted      # Testing framework
luarocks install luacheck    # Linter
```

### Running Tests

```bash
# Run the full test suite
busted tests/

# Run specific test file
busted tests/test_story.lua

# Run with coverage
busted --coverage tests/
```

### Running the Linter

```bash
# Lint all Lua files
luacheck lib/ bin/ tests/

# Auto-fix some issues
luacheck lib/ --fix
```

## Development Setup

### Project Structure

```
whisker-core/
├── lib/whisker/          # Core library modules
│   ├── parser/           # Story file parsing
│   ├── story.lua         # Story engine
│   ├── passage.lua       # Passage management
│   ├── state.lua         # State management
│   └── ...
├── bin/whisker           # CLI tools
├── tests/                # Test suite
├── docs/                 # Documentation
├── examples/             # Example stories
├── publisher/            # Runtime players
└── config/               # Build configurations
```

### Branch Naming

Use descriptive branch names:

- `feature/add-new-template-type` - New features
- `fix/parser-crash-on-empty-passage` - Bug fixes
- `docs/improve-api-documentation` - Documentation updates
- `refactor/simplify-state-management` - Code refactoring
- `perf/optimize-passage-lookup` - Performance improvements

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Use the bug report template** when creating a new issue
3. **Provide a minimal reproducible example** as a story file
4. **Include your environment details** (Lua version, OS, etc.)

### Suggesting Features

1. **Check existing issues and discussions** for similar requests
2. **Use the feature request template** when creating a new issue
3. **Explain the use case** and how it benefits story authors
4. **Consider backward compatibility** and implementation complexity

### Contributing Code

1. **Fork the repository** and create a new branch
2. **Make your changes** following our coding standards
3. **Add tests** for new functionality
4. **Update documentation** as needed
5. **Run tests and linter** before committing
6. **Submit a pull request** using our PR template

## Coding Standards

### Lua Style Guide

#### Indentation and Formatting

- Use **4 spaces** for indentation (no tabs)
- Maximum line length: **100 characters**
- Use Unix-style line endings (LF)
- See `.editorconfig` for detailed formatting rules

#### Naming Conventions

```lua
-- Modules and classes: PascalCase
local MyModule = {}

-- Functions and variables: snake_case
local function parse_passage(text)
  local passage_name = "Start"
  return passage_name
end

-- Constants: UPPER_SNAKE_CASE
local DEFAULT_PASSAGE = "Start"
local MAX_DEPTH = 100

-- Private functions: prefix with underscore
local function _internal_helper()
  -- ...
end
```

#### Documentation

Use LDoc-style comments for all public APIs:

```lua
--- Parse a story file and return a Story object.
-- @param story_text The raw story text to parse
-- @param options Optional table of parsing options
-- @return Story object on success
-- @return nil, error_message on failure
function whisker.parse(story_text, options)
  -- Implementation
end
```

#### Error Handling

```lua
-- Return nil + error message for expected errors
function MyModule:process(input)
  if not input then
    return nil, "Input cannot be nil"
  end

  -- Process input
  return result
end

-- Use assertions for programming errors
function MyModule:_internal_method(required_param)
  assert(required_param, "required_param is mandatory")
  -- ...
end
```

### Lua Version Compatibility

whisker-core supports Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT. Ensure your code is compatible with all versions:

#### Avoid Version-Specific Features

```lua
-- ❌ BAD: Lua 5.3+ only (bitwise operators)
local result = a & b

-- ✅ GOOD: Compatible with all versions
local bit = require("bit") or require("bit32")
local result = bit.band(a, b)

-- ❌ BAD: Lua 5.2+ only (goto)
goto skip_section

-- ✅ GOOD: Use control structures
if not should_skip then
  -- section code
end
```

#### Use Compatibility Shims

```lua
-- Load with compatibility
local unpack = table.unpack or unpack

-- Check for feature availability
if _VERSION == "Lua 5.1" then
  -- Lua 5.1-specific code
end
```

## Testing Guidelines

### Writing Tests

We use **Busted** for BDD-style testing:

```lua
describe("Story parser", function()
  local whisker = require("whisker")

  before_each(function()
    -- Setup code
  end)

  after_each(function()
    -- Cleanup code
  end)

  it("should parse a basic story", function()
    local story_text = [[
      :: Start
      Welcome to the story!
      [[Next->Passage Two]]

      :: Passage Two
      This is the second passage.
    ]]

    local story = whisker.parse(story_text)
    assert.is_not_nil(story)
    assert.equals(2, #story:get_all_passages())
  end)

  it("should return error for invalid syntax", function()
    local invalid_text = ":: [Invalid Name"
    local story, err = whisker.parse(invalid_text)

    assert.is_nil(story)
    assert.is_string(err)
  end)
end)
```

### Test Coverage

- **Aim for >80% code coverage** for new code
- **Test edge cases** and error conditions
- **Test across Lua versions** (CI will verify)
- **Include performance tests** for critical paths

### Running Specific Tests

```bash
# Run tests matching a pattern
busted --filter="Story parser" tests/

# Run with verbose output
busted --verbose tests/

# Run with coverage report
busted --coverage --coverage-report tests/
```

## Submitting Changes

### Commit Messages

Follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process or auxiliary tool changes

**Examples:**

```
feat(parser): Add support for passage tags

Added ability to tag passages with arbitrary labels for organization
and filtering. Tags are specified using #hashtag syntax.

Closes #42
```

```
fix(state): Prevent variable name collision with Lua keywords

Variables named after Lua keywords (if, then, else, etc.) were causing
parser errors. Now properly escaping these names.

Fixes #38
```

### Pull Request Process

1. **Update documentation** if you changed APIs or added features
2. **Add tests** for new functionality or bug fixes
3. **Run the full test suite** and ensure all tests pass
4. **Run luacheck** and fix any warnings
5. **Update CHANGELOG.md** with your changes
6. **Fill out the PR template** completely
7. **Link related issues** in the PR description
8. **Wait for review** - maintainers will review within 7 days
9. **Address feedback** promptly and professionally
10. **Squash commits** if requested before merge

### Review Criteria

Your PR will be reviewed for:

- **Correctness**: Does it work as intended?
- **Test coverage**: Are there tests for new code?
- **Code quality**: Is it readable and maintainable?
- **Documentation**: Are APIs and changes documented?
- **Compatibility**: Does it work across all Lua versions?
- **Performance**: Does it impact performance negatively?
- **Backward compatibility**: Does it break existing stories?

## Release Process

Releases are managed by maintainers:

1. Version bump in `VERSION` file
2. Update `CHANGELOG.md`
3. Tag release: `git tag -a v1.2.3 -m "Release 1.2.3"`
4. Push to GitHub: `git push --tags`
5. Publish to LuaRocks: `luarocks upload rockspec/whisker-*.rockspec`
6. Create GitHub release with notes

## Getting Help

- **Documentation**: Check [docs/](docs/) and [AUTHORING.md](AUTHORING.md)
- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Report bugs or request features via GitHub Issues
- **Community**: Join discussions in issues and PRs

## Recognition

Contributors are recognized in:

- GitHub contributors list
- `CHANGELOG.md` for significant contributions
- Release notes

Thank you for contributing to whisker-core!

## License

By contributing to whisker-core, you agree that your contributions will be licensed under the **MIT License**. See [LICENSE](LICENSE) for details.
