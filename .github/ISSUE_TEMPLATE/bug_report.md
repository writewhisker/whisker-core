---
name: Bug Report
about: Report a bug in whisker-core
title: '[BUG] '
labels: bug
assignees: ''

---

## Bug Description
**A clear and concise description of what the bug is.**

## To Reproduce
Steps to reproduce the behavior:
1. Load story '...'
2. Execute command '...'
3. Navigate to '...'
4. See error

## Expected Behavior
**A clear and concise description of what you expected to happen.**

## Actual Behavior
**What actually happened.**

## Error Messages
```
Paste any error messages or logs here
```

## Environment
**Please complete the following information:**
- whisker-core Version: [e.g., 1.0.0]
- Lua Version: [e.g., 5.4, 5.3, 5.2, 5.1, LuaJIT 2.1]
- OS: [e.g., Windows 11, Ubuntu 22.04, macOS 14]
- Installation Method: [LuaRocks, manual, git clone]

## Story File
**If the bug is related to a specific story, please attach or paste the minimal story that reproduces the issue:**
```whisker
:: Start
<!-- Paste your minimal story code here -->
[[Next Passage]]

:: Next Passage
<!-- Example that triggers the bug -->
```

## Test Case
**If you've written a test that reproduces the bug:**
```lua
-- Lua test code
describe("Bug reproduction", function()
    it("should demonstrate the issue", function()
        -- Test code here
    end)
end)
```

## Additional Context
**Add any other context about the problem here.**

## Possible Solution
**If you have ideas on how to fix this, please share them.**

## Checklist
- [ ] I have searched existing issues to ensure this bug hasn't been reported
- [ ] I have provided all requested information
- [ ] I have tested with the latest version of whisker-core
- [ ] I can reproduce this bug consistently
- [ ] I have provided a minimal story file that reproduces the issue
