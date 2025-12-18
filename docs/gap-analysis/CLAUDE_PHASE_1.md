# Whisker-Core Development Guide

## Project Overview

whisker-core is a Lua-based interactive fiction framework designed for extreme modularity, embeddability, and compatibility with Twine and Ink formats.

**Repository:** https://github.com/writewhisker/whisker-core
**Language:** Lua 5.1+ (must work on 5.1, 5.2, 5.3, 5.4, and LuaJIT)
**Test Framework:** busted
**Linting:** luacheck

## Current Phase

**Phase 1: Foundation & Modularity Architecture**

Implementation guide: `docs/gap-analysis/PHASE_1_IMPLEMENTATION.md`

This phase establishes the microkernel architecture, dependency injection, event bus, and refactors all modules to comply with the modularity checklist.

## Git Workflow

**Each stage gets its own branch and PR.**

### Branch Naming
```
phase1/stage-XX-short-description
```

Examples:
- `phase1/stage-01-repository-audit`
- `phase1/stage-03-microkernel-core`
- `phase1/stage-05-di-container`

### Starting a New Stage

```bash
# Ensure you're on main with latest changes
git checkout main
git pull origin main

# Create branch for the stage
git checkout -b phase1/stage-XX-description

# Execute the stage
claude "Execute Stage XX from docs/gap-analysis/PHASE_1_IMPLEMENTATION.md"
```

### Completing a Stage

```bash
# After stage is complete and tests pass
git add -A
git commit -m "Stage XX: [Stage Title]

- [Brief summary of what was implemented]
- [Key files created/modified]

Acceptance criteria:
- [x] Criterion 1
- [x] Criterion 2
..."

# Push and create PR
git push -u origin phase1/stage-XX-description
gh pr create --title "Phase 1 - Stage XX: [Stage Title]" --body-file .github/PR_TEMPLATE.md
```

### After PR Merge

```bash
git checkout main
git pull origin main
# Update progress tracker in CLAUDE.md
# Start next stage
```

## Stage Execution Workflow

### Before Starting Any Stage

1. Read the **Phase 1 Context** section in `docs/gap-analysis/PHASE_1_IMPLEMENTATION.md`
2. Verify prerequisites for the target stage are complete (PR merged)
3. Review the stage's Inputs to ensure required files exist
4. Create feature branch from main

### Executing a Stage

1. Read the complete stage definition
2. Execute tasks in order
3. Create/modify files as specified in Outputs
4. Write tests alongside implementation
5. Run tests: `busted spec/`
6. Verify all Acceptance Criteria pass

### After Completing a Stage

1. Run full test suite: `busted`
2. Run linter: `luacheck lib/ spec/`
3. Commit with descriptive message
4. Push branch and create PR
5. Update progress tracker below after merge

## Progress Tracker

Update this section as PRs are merged:

| Stage | Title | Branch | PR | Status |
|-------|-------|--------|-----|--------|
| 01 | Repository Audit | `phase1/stage-01-repository-audit` | | ⬜ |
| 02 | Refactoring Plan | `phase1/stage-02-refactoring-plan` | | ⬜ |
| 03 | Microkernel Core | `phase1/stage-03-microkernel-core` | | ⬜ |
| 04 | Interface Definitions | `phase1/stage-04-interfaces` | | ⬜ |
| 05 | DI Container | `phase1/stage-05-di-container` | | ⬜ |
| 06 | Event Bus | `phase1/stage-06-event-bus` | | ⬜ |
| 07 | Module Loader | `phase1/stage-07-module-loader` | | ⬜ |
| 08 | Mock Factory | `phase1/stage-08-mock-factory` | | ⬜ |
| 09 | Test Container | `phase1/stage-09-test-container` | | ⬜ |
| 10 | Fixtures & Helpers | `phase1/stage-10-fixtures` | | ⬜ |
| 11 | IFormat Contract | `phase1/stage-11-format-contract` | | ⬜ |
| 12 | IState/IEngine Contracts | `phase1/stage-12-state-engine-contracts` | | ⬜ |
| 13 | Refactor Passage | `phase1/stage-13-passage` | | ⬜ |
| 14 | Refactor Choice | `phase1/stage-14-choice` | | ⬜ |
| 15 | Refactor Variable | `phase1/stage-15-variable` | | ⬜ |
| 16 | Refactor Story | `phase1/stage-16-story` | | ⬜ |
| 17 | State Service | `phase1/stage-17-state-service` | | ⬜ |
| 18 | Engine Service | `phase1/stage-18-engine-service` | | ⬜ |
| 19 | History Service | `phase1/stage-19-history-service` | | ⬜ |
| 20 | Condition Evaluator | `phase1/stage-20-conditions` | | ⬜ |
| 21 | CI/CD & Integration | `phase1/stage-21-cicd` | | ⬜ |

**Status Legend:** ⬜ Not Started | 🟡 In Progress | 🔵 PR Open | ✅ Merged

**Current Stage:** 01

## Key Commands

```bash
# Run all tests
busted

# Run specific test file
busted spec/kernel/container_spec.lua

# Run tests with coverage
busted --coverage

# View coverage report
luacov && cat luacov.report.out

# Lint code
luacheck lib/ spec/

# Run tests for a specific directory
busted spec/kernel/

# Create PR with GitHub CLI
gh pr create --title "Phase 1 - Stage XX: Title" --body "Description"

# View PR status
gh pr status
```

## Project Structure (Target)

```
whisker-core/
├── lib/whisker/
│   ├── kernel/           # Microkernel (Stages 03-07)
│   │   ├── init.lua
│   │   ├── container.lua
│   │   ├── events.lua
│   │   ├── registry.lua
│   │   └── loader.lua
│   ├── interfaces/       # Interface definitions (Stage 04)
│   │   ├── init.lua
│   │   ├── format.lua
│   │   ├── state.lua
│   │   ├── engine.lua
│   │   ├── serializer.lua
│   │   ├── condition.lua
│   │   └── plugin.lua
│   ├── core/             # Core data structures (Stages 13-16)
│   ├── services/         # Service implementations (Stages 17-20)
│   │   ├── state/
│   │   ├── history/
│   │   └── conditions/
│   ├── engines/          # Engine implementations (Stage 18)
│   └── formats/          # Format handlers
├── spec/                 # Test files (mirror lib structure)
├── tests/
│   ├── support/          # Test utilities (Stages 08-10)
│   ├── contracts/        # Contract tests (Stages 11-12)
│   ├── fixtures/         # Test data (Stage 10)
│   └── integration/      # Integration tests
└── docs/
    ├── gap-analysis/PHASE_1_IMPLEMENTATION.md
    ├── audit/            # Stage 01 outputs
    └── architecture/     # Stage 02 outputs
```

## Code Conventions

### Lua Style
- 2-space indentation
- Use `local` for all variables
- Module pattern: return table at end of file
- No globals except explicit exports

### Module Metadata Pattern
Every module should export registration metadata:
```lua
local MyModule = {}

-- Module implementation...

MyModule._whisker = {
  name = "my_module",
  version = "1.0.0",
  implements = "IMyInterface",  -- if applicable
  depends = {},                  -- dependencies
  capability = "my_capability"   -- capability flag
}

return MyModule
```

### Test File Naming
- Unit tests: `spec/{module_path}_spec.lua`
- Contract tests: `tests/contracts/{interface}_contract.lua`
- Integration tests: `tests/integration/{feature}_spec.lua`

### Event Naming
Use namespaced event names:
- `passage:entered`
- `choice:made`
- `state:changed`
- `story:loaded`

## Modularity Checklist

Every module must pass before stage completion:

- [ ] No hardcoded dependencies (uses container/registry)
- [ ] Implements a defined interface
- [ ] Testable in isolation with mocks
- [ ] Optional loading (system works if absent)
- [ ] Event-based communication
- [ ] Single responsibility
- [ ] Documented contract
- [ ] No global state

## Coverage Targets

| Component | Line Coverage | Branch Coverage |
|-----------|--------------|-----------------|
| kernel/* | 95% | 90% |
| core/* | 90% | 85% |
| services/* | 85% | 80% |
| formats/* | 80% | 75% |

## Common Prompts

### Start a new stage (with branch)
```
Create branch phase1/stage-XX-description and execute Stage XX from docs/gap-analysis/PHASE_1_IMPLEMENTATION.md
```

### Execute current stage
```
Execute Stage XX from docs/gap-analysis/PHASE_1_IMPLEMENTATION.md
```

### Verify and prepare PR
```
Verify all acceptance criteria for Stage XX are met, run tests, and show me a commit message for this stage
```

### Check overall progress
```
Review the codebase against docs/gap-analysis/PHASE_1_IMPLEMENTATION.md and summarize current progress
```

### Resume work on in-progress stage
```
Check what branch I'm on, review the current stage status, and continue implementation
```

## Constraints

- Microkernel must be <200 lines total
- No module may directly `require` another whisker module (use container)
- All cross-module communication via events or interfaces
- Individual files should stay under 500 lines
- All tests must be deterministic (no flaky tests)
- Maintain backward compatibility where possible

## PR Checklist Template

Use this when creating PRs:

```markdown
## Stage XX: [Title]

### Summary
[Brief description of what this stage implements]

### Changes
- [ ] Created `path/to/file.lua`
- [ ] Modified `path/to/other.lua`
- [ ] Added tests in `spec/...`

### Acceptance Criteria
- [ ] Criterion 1 from stage definition
- [ ] Criterion 2
- [ ] All tests pass
- [ ] Linting passes

### Testing
- [ ] `busted spec/` passes
- [ ] `luacheck lib/ spec/` passes
- [ ] Coverage meets targets

### Dependencies
- Requires Stage XX-1 to be merged first
```

## Notes

<!-- Add implementation notes, decisions, and blockers here as work progresses -->
