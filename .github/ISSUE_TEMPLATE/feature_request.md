---
name: Feature Request
about: Suggest a new feature for whisker-core
title: '[FEATURE] '
labels: enhancement
assignees: ''

---

## Feature Description
**A clear and concise description of the feature you'd like to see.**

## Problem/Use Case
**Is your feature request related to a problem? Please describe.**
A clear description of what the problem is. Ex. "I'm always frustrated when [...]"

**Or describe the use case:**
Explain how this feature would be used in practice.

## Proposed Solution
**Describe the solution you'd like:**
A clear and concise description of what you want to happen.

## Example Usage

### Story Syntax Example
```whisker
:: Start
This is an example using the new feature
<<newfeature "parameter">>
[[Next Passage]]

:: Next Passage
The feature would enable: [describe outcome]
```

### API Example
```lua
-- Example Lua API usage
local whisker = require("whisker")

story = whisker.parse(story_text)
story:newFeature({
    parameter = "value"
})
```

## Alternatives Considered
**Describe alternatives you've considered:**
A clear description of any alternative solutions or features you've considered.

## Impact
**Who would benefit from this feature?**
- [ ] Story authors
- [ ] Players/readers
- [ ] Developers/integrators
- [ ] Runtime players (web, CLI, desktop)
- [ ] All users

**What components would be affected?**
- [ ] Parser
- [ ] Story engine
- [ ] State management
- [ ] Template system
- [ ] Runtime API
- [ ] Documentation
- [ ] Examples

## Backward Compatibility
**Would this feature break existing stories?**
- [ ] No - fully backward compatible
- [ ] Possibly - needs careful implementation
- [ ] Yes - breaking change (requires major version bump)

## Additional Context
**Add any other context or screenshots about the feature request here.**

## Related Issues
**Are there any related issues or discussions?**
Link to related issues, discussions, or pull requests.

## Implementation Complexity
**What do you think the complexity of this feature would be?**
- [ ] Low - Simple addition, minimal changes
- [ ] Medium - Requires moderate changes to parser/engine
- [ ] High - Major feature, significant refactoring needed
- [ ] I'm not sure

## Willingness to Contribute
- [ ] I'd be willing to implement this feature
- [ ] I'd be willing to test this feature
- [ ] I'd be willing to help document this feature
- [ ] I just want to suggest the idea
