## Description
**Please include a summary of the changes and the related issue.**

Fixes # (issue number)

## Type of Change
**Please delete options that are not relevant.**

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring
- [ ] Build/CI changes
- [ ] Tests

## Component
**Which component(s) does this PR affect?**

- [ ] Core Engine (Parser/Story)
- [ ] Template System
- [ ] State Management
- [ ] Format Converters
- [ ] Runtime Players (web/CLI/desktop)
- [ ] CLI Tools
- [ ] Documentation
- [ ] Build System
- [ ] Tests
- [ ] Examples

## Changes Made
**List the main changes:**

1.
2.
3.

## Testing
**Describe the tests you ran and provide instructions to reproduce.**

### Test Configuration
- Lua Version: [e.g., 5.4, LuaJIT 2.1]
- OS: [e.g., Ubuntu 22.04, macOS 14]
- Installation: [LuaRocks, manual]

### Test Cases
- [ ] Unit tests pass (`busted tests/`)
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Tested across multiple Lua versions
- [ ] Performance impact assessed

### How to Test
```bash
# Commands to test these changes
make test
# or
busted tests/
```

### Test Story (if applicable)
```whisker
:: Start
<!-- Example story demonstrating the changes -->
[[Next Passage]]

:: Next Passage
<!-- Test case for new feature/fix -->
```

## Breaking Changes
**Does this PR introduce any breaking changes?**

- [ ] No breaking changes
- [ ] Yes, breaking changes (describe below)

**If yes, describe the breaking changes and migration path:**

**Migration example:**
```lua
-- Before
old_api()

-- After
new_api()
```

## Performance Impact
**Does this change affect performance?**

- [ ] No performance impact
- [ ] Performance improvement (benchmark results below)
- [ ] Minor performance regression (justified below)
- [ ] Significant performance regression (requires discussion)

**Benchmark results (if applicable):**
```
Before: [time/memory usage]
After:  [time/memory usage]
```

## Documentation
**Have you updated the documentation?**

- [ ] Documentation updated (in this PR)
- [ ] Documentation not needed
- [ ] Documentation will be added in separate PR (link: )

**Updated documentation:**
- [ ] README.md
- [ ] API documentation (inline comments)
- [ ] AUTHORING.md (story author guide)
- [ ] TESTING.md
- [ ] Examples

## Compatibility
**Lua version compatibility:**
- [ ] Tested on Lua 5.1
- [ ] Tested on Lua 5.2
- [ ] Tested on Lua 5.3
- [ ] Tested on Lua 5.4
- [ ] Tested on LuaJIT

**OS compatibility:**
- [ ] Tested on Linux
- [ ] Tested on macOS
- [ ] Tested on Windows

## Checklist
**Before submitting, ensure you have:**

- [ ] Read the CONTRIBUTING.md guidelines
- [ ] Self-reviewed my own code
- [ ] Commented code, particularly in hard-to-understand areas
- [ ] Made corresponding changes to documentation
- [ ] Added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally
- [ ] Any dependent changes have been merged and published
- [ ] Checked that changes don't break backward compatibility (or documented breaking changes)
- [ ] Ran luacheck and fixed any warnings
- [ ] Updated CHANGELOG.md (if applicable)

## Additional Notes
**Any additional information for reviewers:**

## Related PRs/Issues
**Link to related pull requests or issues:**

- Related to #
- Depends on #
- Blocks #

## License
By submitting this pull request, I confirm that my contribution is made under the terms of the MIT License.

---

## For Maintainers
**Reviewer checklist:**
- [ ] Code quality is acceptable
- [ ] Tests are comprehensive
- [ ] Documentation is adequate
- [ ] Breaking changes are justified and documented
- [ ] Performance impact is acceptable
- [ ] Lua version compatibility verified
- [ ] Security implications considered
