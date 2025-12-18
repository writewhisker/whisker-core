# Phase 1 Implementation: Foundation & Modularity Architecture

## Document Information
- **Project:** whisker-core
- **Phase:** 1 of 7
- **Depends On:** whisker-core-roadmap.md (Gap Analysis)
- **Estimated Duration:** 8-10 weeks
- **Total Stages:** 21
- **Generation Status:** Complete

---

## Phase 1 Context

This section provides the shared context needed by all implementation stages. It summarizes the architectural requirements, interface definitions, patterns, and file structure from the roadmap document.

### 1.1 Project Overview

whisker-core is a Lua-based interactive fiction framework designed for extreme modularity, embeddability, and compatibility with Twine and Ink formats. The framework currently has basic implementations of core story primitives (Story, Passage, Choice, Variable), a runtime engine, Twine format support, and developer tools—but lacks the foundational modularity architecture that Phase 1 will establish.

**Current Repository Structure:**
```
lib/whisker/
├── core/           # Story primitives (story.lua, passage.lua, choice.lua, variable.lua)
├── runtime/        # Engine, state, history
├── format/         # twine/, json.lua, compact.lua
├── parser/         # twee.lua, markdown.lua
├── tools/          # validator.lua, debugger.lua, profiler.lua
└── utils/          # helpers.lua
```

**Target Repository Structure (after Phase 1):**
```
lib/whisker/
├── kernel/         # NEW: Microkernel infrastructure
│   ├── init.lua
│   ├── container.lua
│   ├── events.lua
│   ├── registry.lua
│   └── loader.lua
├── interfaces/     # NEW: Pure interface definitions
│   ├── init.lua
│   ├── format.lua
│   ├── state.lua
│   ├── engine.lua
│   ├── serializer.lua
│   ├── condition.lua
│   └── plugin.lua
├── core/           # REFACTORED: Compliant with interfaces
├── services/       # NEW: Service implementations
│   ├── state/
│   ├── history/
│   └── conditions/
├── formats/        # REFACTORED: IFormat implementations
├── engines/        # NEW: IEngine implementations
└── [existing dirs]
```

### 1.2 Architectural Principles

Phase 1 establishes five core architectural principles that govern all subsequent development:

#### Principle 1: Microkernel Architecture
The core runtime is a minimal "microkernel" (<200 lines total) that does almost nothing by itself. All functionality—including "core" features—is implemented as modules that plug into this kernel. The kernel provides only: module loading, dependency injection, event bus, and registry services.

#### Principle 2: Interface-First Design
Every module defines and depends on **interfaces**, never concrete implementations. This enables swapping implementations without changing dependent code, testing with mocks/stubs, and platform-specific implementations behind common interfaces.

```lua
-- WRONG: Direct dependency
local JsonFormat = require("whisker.format.json")

-- RIGHT: Interface dependency via registry
local format = whisker.formats:get("json")  -- Returns whatever implements IFormat
```

#### Principle 3: Dependency Injection Container
A central container manages all component lifecycles and dependencies:

```lua
-- Registration
whisker.container:register("state_manager", StateManager, { singleton = true })
whisker.container:register("format.json", JsonFormat, { implements = "IFormat" })

-- Resolution (automatic dependency injection)
local engine = whisker.container:resolve("engine")
```

#### Principle 4: Event-Driven Communication
Modules communicate through events, not direct calls:

```lua
-- Publisher doesn't know subscribers
whisker.events:emit("passage:entered", { passage = passage })

-- Subscriber doesn't know publishers
whisker.events:on("passage:entered", function(data) ... end)
```

#### Principle 5: Feature Flags and Capability Detection
Even "core" features are optional and detectable:

```lua
if whisker.capabilities:has("variables") then ... end
if whisker.capabilities:has("format.ink") then ... end
```

### 1.3 Interface Definitions

These interfaces must be implemented during Phase 1. All swappable components must conform to these contracts.

#### IFormat - Story format handler
```lua
IFormat = {
  name = "string",           -- Format identifier
  can_import = function(self, source) end,  -- Returns boolean
  import = function(self, source) end,      -- Returns Story
  can_export = function(self, story) end,   -- Returns boolean
  export = function(self, story) end,       -- Returns string/bytes
}
```

#### IState - State management
```lua
IState = {
  get = function(self, key) end,            -- Returns value or nil
  set = function(self, key, value) end,     -- Sets value
  has = function(self, key) end,            -- Returns boolean
  clear = function(self) end,               -- Clears all state
  snapshot = function(self) end,            -- Returns state snapshot
  restore = function(self, snapshot) end,   -- Restores from snapshot
}
```

#### IEngine - Runtime engine
```lua
IEngine = {
  load = function(self, story) end,             -- Loads story
  start = function(self) end,                   -- Starts execution
  get_current_passage = function(self) end,     -- Returns Passage
  get_available_choices = function(self) end,   -- Returns Choice[]
  make_choice = function(self, index) end,      -- Advances story
  can_continue = function(self) end,            -- Returns boolean
}
```

#### ISerializer - Data serialization
```lua
ISerializer = {
  serialize = function(self, data) end,     -- Returns string
  deserialize = function(self, str) end,    -- Returns data
}
```

#### IConditionEvaluator - Condition evaluation
```lua
IConditionEvaluator = {
  evaluate = function(self, condition, context) end,  -- Returns boolean
  register_operator = function(self, name, fn) end,   -- Extends operators
}
```

#### IPlugin - Plugin contract
```lua
IPlugin = {
  name = "string",
  version = "string",
  dependencies = {},      -- Optional
  init = function(self, container) end,
  destroy = function(self) end,
}
```

### 1.4 Container API

The dependency injection container follows this API pattern:

```lua
-- Registration
container:register(name, implementation, options)
-- options: { singleton = bool, implements = "interface", depends = {}, capability = "name" }

-- Resolution
container:resolve(name)           -- Returns instance with dependencies injected
container:resolve_all(interface)  -- Returns all implementations of interface

-- Lifecycle
container:init()      -- Initialize all singletons
container:destroy()   -- Cleanup all components
```

### 1.5 Event Bus API

```lua
events:on(event, handler)      -- Subscribe to event
events:off(event, handler)     -- Unsubscribe
events:emit(event, data)       -- Publish event
events:once(event, handler)    -- Subscribe for single occurrence
```

### 1.6 Modularity Validation Checklist

Every module MUST pass this checklist after refactoring:

- [ ] **No hardcoded dependencies** - Uses container/registry for all dependencies
- [ ] **Implements an interface** - Has a corresponding interface definition
- [ ] **Testable in isolation** - Can be unit tested with mocks
- [ ] **Optional loading** - System works if module is absent (for feature modules)
- [ ] **Event-based communication** - Uses events for cross-module communication
- [ ] **Single responsibility** - Does one thing well
- [ ] **Documented contract** - Clear documentation of inputs/outputs/events
- [ ] **No global state** - All state through injected services

### 1.7 Testing Infrastructure Requirements

Phase 1 establishes comprehensive testing infrastructure:

**Test Directory Structure:**
```
tests/
├── unit/              # Isolated unit tests
│   ├── kernel/
│   ├── core/
│   ├── services/
│   └── formats/
├── contracts/         # Interface contract tests
│   ├── format_contract.lua
│   ├── state_contract.lua
│   └── engine_contract.lua
├── integration/       # Cross-module tests
├── fixtures/          # Test data
│   ├── stories/
│   └── edge_cases/
└── support/           # Test utilities
    ├── mock_factory.lua
    ├── test_container.lua
    └── helpers.lua
```

**Coverage Requirements:**
| Component | Line Coverage | Branch Coverage |
|-----------|--------------|-----------------|
| kernel/* | 95% | 90% |
| core/* | 90% | 85% |
| services/* | 85% | 80% |
| formats/* | 80% | 75% |

### 1.8 Constraints

- Microkernel must be <200 lines total
- No module may directly require another module (use container)
- All cross-module communication via events or interfaces
- Every interface must have a contract test suite
- All tests must be deterministic (no flaky tests)
- Maintain backward compatibility where possible
- Individual files should stay under 500 lines

### 1.9 Success Criteria

Phase 1 is complete when:
- All tests pass on Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT
- Any module can be swapped by registering a different implementation
- Modules communicate only via events or interface contracts
- Each module passes the modularity validation checklist
- Test coverage meets or exceeds targets per component
- Every interface has a passing contract test suite
- CI/CD pipeline operational with coverage enforcement
- API documentation complete for all public interfaces

---

## Stage Definitions

---

## Stage 01: Repository Audit and Gap Documentation

### Prerequisites
- Access to whisker-core repository
- Understanding of roadmap document architecture requirements

### Objectives
- Perform comprehensive audit of existing codebase
- Document current module dependencies and coupling
- Identify all files requiring refactoring
- Create prioritized issue list

### Inputs
- Current repository at https://github.com/writewhisker/whisker-core
- Roadmap document Section 1 (Gap Analysis)
- Modularity validation checklist from Section 0.6

### Tasks
1. Clone and analyze repository structure, documenting all files in `lib/whisker/`
2. For each existing module, analyze: direct requires, global state usage, hardcoded dependencies
3. Create `docs/audit/MODULE_INVENTORY.md` listing all modules with their current dependency graph
4. Create `docs/audit/COUPLING_ANALYSIS.md` documenting violations of modularity principles
5. Create `docs/audit/ISSUES.md` with prioritized list of refactoring tasks
6. Verify test coverage baseline using `busted` and `luacov`

### Outputs
- `docs/audit/MODULE_INVENTORY.md` — Complete inventory of existing modules (~100 lines)
- `docs/audit/COUPLING_ANALYSIS.md` — Dependency analysis and violations (~80 lines)
- `docs/audit/ISSUES.md` — Prioritized refactoring task list (~60 lines)
- `docs/audit/COVERAGE_BASELINE.md` — Current test coverage report (~40 lines)

### Acceptance Criteria
- [ ] All files in `lib/whisker/` are documented in inventory
- [ ] Dependency graph shows all direct requires between modules
- [ ] Each modularity violation is documented with file and line reference
- [ ] Issues list includes at least: coupling violations, missing interfaces, test gaps
- [ ] Coverage baseline established and documented

### Estimated Scope
- New lines: ~280 (documentation)
- Modified lines: ~0
- Test lines: ~0

### Implementation Notes
- Use `grep -r "require" lib/whisker/` to find dependencies
- Use `grep -r "^[^-]*=" lib/whisker/` to find potential global state
- Focus on identifying patterns, not fixing them yet
- The audit output drives all subsequent stages

---

## Stage 02: Refactoring Plan and Architecture Design

### Prerequisites
- Stage 01 completed
- Audit documents reviewed and validated

### Objectives
- Create detailed refactoring plan based on audit findings
- Design file organization for new infrastructure
- Define migration path for existing modules
- Create architecture decision records (ADRs)

### Inputs
- `docs/audit/MODULE_INVENTORY.md` — Module inventory from Stage 01
- `docs/audit/COUPLING_ANALYSIS.md` — Coupling analysis from Stage 01
- `docs/audit/ISSUES.md` — Issue list from Stage 01
- Roadmap Section 0.5 (File Organization for Modularity)

### Tasks
1. Create `docs/architecture/REFACTORING_PLAN.md` with phased migration approach
2. Create `docs/architecture/FILE_STRUCTURE.md` documenting target organization
3. Create `docs/architecture/ADR-001-microkernel.md` documenting microkernel decision
4. Create `docs/architecture/ADR-002-di-container.md` documenting DI approach
5. Create `docs/architecture/ADR-003-event-bus.md` documenting event system design
6. Create `docs/architecture/MIGRATION_CHECKLIST.md` for tracking module migrations

### Outputs
- `docs/architecture/REFACTORING_PLAN.md` — Step-by-step refactoring guide (~150 lines)
- `docs/architecture/FILE_STRUCTURE.md` — Target file organization (~80 lines)
- `docs/architecture/ADR-001-microkernel.md` — Architecture decision record (~60 lines)
- `docs/architecture/ADR-002-di-container.md` — DI design decisions (~60 lines)
- `docs/architecture/ADR-003-event-bus.md` — Event bus design decisions (~60 lines)
- `docs/architecture/MIGRATION_CHECKLIST.md` — Module migration tracker (~40 lines)

### Acceptance Criteria
- [ ] Refactoring plan covers all modules identified in audit
- [ ] File structure matches roadmap Section 0.5 specification
- [ ] Each ADR follows standard format: Context, Decision, Consequences
- [ ] Migration checklist includes all existing modules
- [ ] Plan specifies backward compatibility approach

### Estimated Scope
- New lines: ~450 (documentation)
- Modified lines: ~0
- Test lines: ~0

### Implementation Notes
- ADRs should be numbered sequentially and immutable once accepted
- The refactoring plan should minimize breaking changes
- Consider creating compatibility shims for existing API consumers
- Reference roadmap Principle 1-5 in ADRs

---

## Stage 03: Microkernel Core Implementation

### Prerequisites
- Stage 02 completed
- Lua 5.4+ development environment configured
- busted test framework installed

### Objectives
- Implement the microkernel core that bootstraps the entire system
- Establish the module registration pattern
- Create the capability detection system
- Keep total kernel under 200 lines

### Inputs
- `docs/architecture/ADR-001-microkernel.md` — Microkernel design decisions
- Roadmap Section 0.1 (Microkernel Architecture)

### Tasks
1. Create directory structure `lib/whisker/kernel/`
2. Create `lib/whisker/kernel/init.lua` — Main kernel entry point with version, module registry table, and bootstrap function
3. Create `lib/whisker/kernel/registry.lua` — Module registration functions (register, unregister, get, has)
4. Create `lib/whisker/kernel/capabilities.lua` — Capability detection and feature flag system
5. Create `lib/whisker/kernel/errors.lua` — Kernel-level error definitions
6. Create `spec/kernel/init_spec.lua` — Kernel bootstrap tests
7. Create `spec/kernel/registry_spec.lua` — Registry tests

### Outputs
- `lib/whisker/kernel/init.lua` — Kernel entry point (~40 lines)
- `lib/whisker/kernel/registry.lua` — Module registry (~60 lines)
- `lib/whisker/kernel/capabilities.lua` — Capability system (~50 lines)
- `lib/whisker/kernel/errors.lua` — Error definitions (~30 lines)
- `spec/kernel/init_spec.lua` — Kernel tests (~50 lines)
- `spec/kernel/registry_spec.lua` — Registry tests (~50 lines)

### Acceptance Criteria
- [ ] Kernel loads with zero dependencies beyond Lua standard library
- [ ] Can register and retrieve modules by name
- [ ] Capability queries return accurate results
- [ ] Total kernel code (excluding tests) < 200 lines
- [ ] All tests pass: `busted spec/kernel/`

### Estimated Scope
- New lines: ~180
- Modified lines: ~0
- Test lines: ~100

### Implementation Notes
- The kernel should NOT require any whisker modules—it's the foundation
- Use metatables for lazy module loading if implementing require-on-access
- Error messages should include module name and expected interface
- Registry should support namespaced modules (e.g., "format.json")
- Consider using weak tables for optional module references

```lua
-- Example kernel structure
local Kernel = {
  _VERSION = "0.1.0",
  _modules = {},
  _capabilities = {}
}

function Kernel.bootstrap()
  -- Minimal initialization
end

return Kernel
```

---

## Stage 04: Interface Definitions

### Prerequisites
- Stage 03 completed
- Kernel registry functional

### Objectives
- Define all core interfaces as Lua tables
- Create interface validation utilities
- Establish interface documentation pattern
- Enable interface-based type checking

### Inputs
- Roadmap Section 0.3 (Interface Definitions)
- `lib/whisker/kernel/init.lua` — For integration

### Tasks
1. Create directory `lib/whisker/interfaces/`
2. Create `lib/whisker/interfaces/init.lua` — Interface loader and validator
3. Create `lib/whisker/interfaces/format.lua` — IFormat interface definition
4. Create `lib/whisker/interfaces/state.lua` — IState interface definition
5. Create `lib/whisker/interfaces/engine.lua` — IEngine interface definition
6. Create `lib/whisker/interfaces/serializer.lua` — ISerializer interface definition
7. Create `lib/whisker/interfaces/condition.lua` — IConditionEvaluator interface
8. Create `lib/whisker/interfaces/plugin.lua` — IPlugin interface definition
9. Create `spec/interfaces/validator_spec.lua` — Interface validation tests

### Outputs
- `lib/whisker/interfaces/init.lua` — Interface registry and validator (~60 lines)
- `lib/whisker/interfaces/format.lua` — IFormat (~25 lines)
- `lib/whisker/interfaces/state.lua` — IState (~25 lines)
- `lib/whisker/interfaces/engine.lua` — IEngine (~30 lines)
- `lib/whisker/interfaces/serializer.lua` — ISerializer (~20 lines)
- `lib/whisker/interfaces/condition.lua` — IConditionEvaluator (~25 lines)
- `lib/whisker/interfaces/plugin.lua` — IPlugin (~25 lines)
- `spec/interfaces/validator_spec.lua` — Validation tests (~80 lines)

### Acceptance Criteria
- [ ] All six interfaces defined with complete method signatures
- [ ] Interface validator can check if object implements interface
- [ ] Each interface includes documentation comments
- [ ] Validation tests cover positive and negative cases
- [ ] All tests pass: `busted spec/interfaces/`

### Estimated Scope
- New lines: ~210
- Modified lines: ~0
- Test lines: ~80

### Implementation Notes
- Interfaces are pure data structures (tables with function signatures)
- Use metatables to enable `implements(obj, IFormat)` syntax
- Document expected parameters and return types in comments
- Consider optional vs required methods (mark in interface)

```lua
-- Example interface structure
local IFormat = {
  _name = "IFormat",
  _required = {"can_import", "import", "can_export", "export"},
  _optional = {"name", "version"},
  
  -- Method signatures (for documentation/validation)
  can_import = "function(self, source) -> boolean",
  import = "function(self, source) -> Story",
  can_export = "function(self, story) -> boolean",
  export = "function(self, story) -> string",
}
```

---

## Stage 05: Dependency Injection Container

### Prerequisites
- Stage 03 completed (kernel registry)
- Stage 04 completed (interfaces defined)

### Objectives
- Implement dependency injection container
- Support singleton and transient lifecycles
- Enable automatic dependency resolution
- Integrate with interface system

### Inputs
- `lib/whisker/kernel/registry.lua` — For integration
- `lib/whisker/interfaces/init.lua` — For interface validation
- Roadmap Section 0.1 (Principle 3: DI Container)
- `docs/architecture/ADR-002-di-container.md` — Design decisions

### Tasks
1. Create `lib/whisker/kernel/container.lua` — Main DI container implementation
2. Implement registration with options (singleton, implements, depends, capability)
3. Implement resolution with automatic dependency injection
4. Implement lifecycle management (init, destroy)
5. Integrate with capability system from Stage 03
6. Create `spec/kernel/container_spec.lua` — Comprehensive container tests

### Outputs
- `lib/whisker/kernel/container.lua` — DI container (~150 lines)
- `spec/kernel/container_spec.lua` — Container tests (~120 lines)

### Acceptance Criteria
- [ ] Can register components with various lifecycle options
- [ ] Singleton instances are reused across resolutions
- [ ] Transient instances are created fresh each time
- [ ] Dependencies are automatically injected during resolution
- [ ] Circular dependency detection throws clear error
- [ ] Interface validation occurs on registration
- [ ] All tests pass: `busted spec/kernel/container_spec.lua`

### Estimated Scope
- New lines: ~150
- Modified lines: ~20 (kernel/init.lua integration)
- Test lines: ~120

### Implementation Notes
- Use a factory function pattern: register takes a factory, resolve calls it
- Dependencies should be resolved recursively
- Track resolution stack to detect circular dependencies
- Consider lazy initialization for singletons

```lua
-- Example container usage
container:register("state", StateManager, {
  singleton = true,
  implements = "IState"
})

container:register("engine", Engine, {
  depends = {"state", "events"},
  implements = "IEngine"
})

local engine = container:resolve("engine")  -- Gets Engine with state, events injected
```

---

## Stage 06: Event Bus Implementation

### Prerequisites
- Stage 03 completed (kernel core)
- Stage 05 completed (container for integration)

### Objectives
- Implement pub/sub event bus
- Support namespaced events
- Enable once/many subscription modes
- Provide event debugging capabilities

### Inputs
- `lib/whisker/kernel/init.lua` — For integration
- Roadmap Section 0.1 (Principle 4: Event-Driven Communication)
- Roadmap Section 0.4 (Module Communication Patterns)
- `docs/architecture/ADR-003-event-bus.md` — Design decisions

### Tasks
1. Create `lib/whisker/kernel/events.lua` — Event bus implementation
2. Implement `on(event, handler)` — Subscribe to events
3. Implement `off(event, handler)` — Unsubscribe from events
4. Implement `emit(event, data)` — Publish events
5. Implement `once(event, handler)` — Single-fire subscription
6. Add event namespacing (e.g., "passage:entered", "story:loaded")
7. Add debugging mode for event tracing
8. Create `spec/kernel/events_spec.lua` — Event bus tests

### Outputs
- `lib/whisker/kernel/events.lua` — Event bus (~100 lines)
- `spec/kernel/events_spec.lua` — Event tests (~100 lines)

### Acceptance Criteria
- [ ] Can subscribe and receive events
- [ ] Can unsubscribe from specific handlers
- [ ] once() handlers fire exactly once then auto-unsubscribe
- [ ] Namespaced events work (e.g., "passage:*" wildcard optional)
- [ ] Debug mode logs all event emissions
- [ ] Handlers receive data parameter correctly
- [ ] All tests pass: `busted spec/kernel/events_spec.lua`

### Estimated Scope
- New lines: ~100
- Modified lines: ~15 (kernel/init.lua integration)
- Test lines: ~100

### Implementation Notes
- Store handlers in table keyed by event name
- Support wildcard subscriptions if complexity permits
- Consider async event emission for non-blocking operations
- Event data should be passed by reference (tables) for efficiency

```lua
-- Example event bus usage
events:on("passage:entered", function(data)
  print("Entered: " .. data.passage.id)
end)

events:emit("passage:entered", { passage = current_passage })
```

---

## Stage 07: Module Loader Implementation

### Prerequisites
- Stage 03-06 completed (kernel infrastructure)

### Objectives
- Implement dynamic module loading
- Integrate with container and events
- Support lazy loading pattern
- Enable module hot-reloading (optional)

### Inputs
- `lib/whisker/kernel/init.lua` — Kernel core
- `lib/whisker/kernel/container.lua` — DI container
- `lib/whisker/kernel/registry.lua` — Module registry

### Tasks
1. Create `lib/whisker/kernel/loader.lua` — Module loader implementation
2. Implement path-based module discovery
3. Implement lazy loading with proxies
4. Integrate loader with container registration
5. Add capability auto-detection from loaded modules
6. Update `lib/whisker/kernel/init.lua` to export loader
7. Create `spec/kernel/loader_spec.lua` — Loader tests

### Outputs
- `lib/whisker/kernel/loader.lua` — Module loader (~80 lines)
- `spec/kernel/loader_spec.lua` — Loader tests (~70 lines)
- Updated `lib/whisker/kernel/init.lua` (~10 lines modified)

### Acceptance Criteria
- [ ] Can load modules by path
- [ ] Lazy loading defers require until first use
- [ ] Loaded modules auto-register with container if they export registration info
- [ ] Capabilities are detected from module metadata
- [ ] Missing modules produce clear error messages
- [ ] All tests pass: `busted spec/kernel/loader_spec.lua`

### Estimated Scope
- New lines: ~80
- Modified lines: ~10
- Test lines: ~70

### Implementation Notes
- Use metatables with __index for lazy loading proxies
- Module files should export a `_whisker` metadata table for auto-registration
- Support both explicit and convention-based loading
- Keep loader lightweight—complex logic belongs in container

---

## Stage 08: Test Infrastructure - Mock Factory

### Prerequisites
- Stage 04 completed (interfaces defined)
- busted test framework installed

### Objectives
- Create mock factory that generates mocks from interfaces
- Support call tracking and verification
- Enable return value stubbing
- Provide spy functionality

### Inputs
- `lib/whisker/interfaces/init.lua` — Interface definitions
- Roadmap Section 0.9.3 (Test Infrastructure)

### Tasks
1. Create `tests/support/mock_factory.lua` — Mock generation utility
2. Implement `from_interface(interface)` — Generate mock from interface
3. Implement call tracking (method, args, count)
4. Implement `when(method).returns(value)` stubbing
5. Implement `verify(method).called(times)` verification
6. Implement `verify(method).called_with(...)` argument verification
7. Create `tests/support/mock_factory_spec.lua` — Self-tests

### Outputs
- `tests/support/mock_factory.lua` — Mock factory (~120 lines)
- `tests/support/mock_factory_spec.lua` — Factory tests (~100 lines)

### Acceptance Criteria
- [ ] Can generate mock from any interface
- [ ] Mock tracks all method calls with arguments
- [ ] Can stub return values for specific methods
- [ ] Can verify call count and arguments
- [ ] Works with all six defined interfaces
- [ ] All tests pass: `busted tests/support/mock_factory_spec.lua`

### Estimated Scope
- New lines: ~120
- Modified lines: ~0
- Test lines: ~100

### Implementation Notes
- Store calls in array: `{method = "name", args = {...}, timestamp = os.time()}`
- Use fluent API for stubbing/verification
- Consider supporting argument matchers (any, type-based)

```lua
-- Example usage
local MockFactory = require("tests.support.mock_factory")
local IState = require("whisker.interfaces.state")

local mock_state = MockFactory.from_interface(IState)
mock_state:when("get"):returns("test_value")

local result = mock_state:get("key")
assert.equals("test_value", result)
mock_state:verify("get"):called(1)
mock_state:verify("get"):called_with("key")
```

---

## Stage 09: Test Infrastructure - Test Container

### Prerequisites
- Stage 05 completed (DI container)
- Stage 08 completed (mock factory)

### Objectives
- Create test container for isolated DI in tests
- Simplify mock injection
- Enable per-test container isolation
- Integrate with mock factory

### Inputs
- `lib/whisker/kernel/container.lua` — Production container
- `tests/support/mock_factory.lua` — Mock factory

### Tasks
1. Create `tests/support/test_container.lua` — Test container utility
2. Implement fresh container creation per test
3. Implement `mock(name, interface)` — Easy mock registration
4. Implement `get_mock(name)` — Retrieve mock for verification
5. Implement `reset()` — Clear container between tests
6. Create `tests/support/test_container_spec.lua` — Self-tests

### Outputs
- `tests/support/test_container.lua` — Test container (~80 lines)
- `tests/support/test_container_spec.lua` — Container tests (~70 lines)

### Acceptance Criteria
- [ ] Creates isolated container per test
- [ ] Mocks can be registered and retrieved
- [ ] Reset clears all registrations
- [ ] Integrates with mock factory for verification
- [ ] All tests pass: `busted tests/support/test_container_spec.lua`

### Estimated Scope
- New lines: ~80
- Modified lines: ~0
- Test lines: ~70

### Implementation Notes
- Wrap production container with test-friendly API
- Store mock references separately for easy verification access
- Consider before_each/after_each integration patterns

```lua
-- Example usage in tests
describe("Engine", function()
  local container
  
  before_each(function()
    container = TestContainer.new()
    container:mock("state", IState)
    container:get_mock("state"):when("get"):returns("value")
  end)
  
  it("uses state service", function()
    local engine = container:resolve("engine")
    -- ... test ...
    container:get_mock("state"):verify("get"):called(1)
  end)
end)
```

---

## Stage 10: Test Infrastructure - Fixtures and Helpers

### Prerequisites
- Stage 08-09 completed (test infrastructure base)

### Objectives
- Create test fixture management system
- Build common test helpers
- Establish fixture directory structure
- Create sample story fixtures

### Inputs
- Roadmap Section 0.9.3 (Fixture Management)
- Existing `stories/examples/` for reference

### Tasks
1. Create `tests/fixtures/stories/simple.json` — Basic test story
2. Create `tests/fixtures/stories/complex_branching.json` — Multi-branch story
3. Create `tests/fixtures/stories/variables_heavy.json` — Variable-intensive story
4. Create `tests/fixtures/edge_cases/empty_passages.json` — Edge case story
5. Create `tests/fixtures/edge_cases/circular_links.json` — Circular reference story
6. Create `tests/support/helpers.lua` — Common test utilities
7. Create `tests/support/fixtures.lua` — Fixture loading utilities

### Outputs
- `tests/fixtures/stories/simple.json` — Basic fixture (~30 lines)
- `tests/fixtures/stories/complex_branching.json` — Complex fixture (~80 lines)
- `tests/fixtures/stories/variables_heavy.json` — Variable fixture (~60 lines)
- `tests/fixtures/edge_cases/empty_passages.json` — Edge case (~20 lines)
- `tests/fixtures/edge_cases/circular_links.json` — Edge case (~25 lines)
- `tests/support/helpers.lua` — Test helpers (~60 lines)
- `tests/support/fixtures.lua` — Fixture loader (~40 lines)

### Acceptance Criteria
- [ ] All fixture files are valid JSON
- [ ] Fixture loader can load by path or name
- [ ] Helpers include: assert_passage, assert_choice, assert_story_valid
- [ ] Edge case fixtures test boundary conditions
- [ ] All fixtures load without error

### Estimated Scope
- New lines: ~315 (fixtures and utilities)
- Modified lines: ~0
- Test lines: ~0 (fixtures are test data)

### Implementation Notes
- Fixtures should be minimal but complete
- Include both happy path and error cases
- Helpers should wrap common assertions for readability
- Consider JSON and Lua table formats for flexibility

---

## Stage 11: Contract Tests - IFormat Contract

### Prerequisites
- Stage 04 completed (interfaces)
- Stage 08-10 completed (test infrastructure)

### Objectives
- Create reusable contract test suite for IFormat
- Ensure any IFormat implementation can be validated
- Test all interface methods systematically
- Establish contract test pattern for other interfaces

### Inputs
- `lib/whisker/interfaces/format.lua` — IFormat definition
- `tests/support/mock_factory.lua` — For creating test doubles
- `tests/fixtures/stories/simple.json` — Test data

### Tasks
1. Create `tests/contracts/format_contract.lua` — Reusable contract test suite
2. Implement tests for `can_import()` return type and semantics
3. Implement tests for `import()` return type and error handling
4. Implement tests for `can_export()` return type and semantics
5. Implement tests for `export()` return type and error handling
6. Implement round-trip test (import → export → import)
7. Create `tests/contracts/json_format_spec.lua` — Apply contract to JSON format

### Outputs
- `tests/contracts/format_contract.lua` — Contract test suite (~120 lines)
- `tests/contracts/json_format_spec.lua` — JSON format contract tests (~30 lines)

### Acceptance Criteria
- [ ] Contract tests are parameterized (accept implementation + fixtures)
- [ ] Tests verify all IFormat methods
- [ ] Round-trip test verifies data preservation
- [ ] Contract can be applied to any IFormat implementation
- [ ] All tests pass: `busted tests/contracts/`

### Estimated Scope
- New lines: ~150
- Modified lines: ~0
- Test lines: ~150 (all test code)

### Implementation Notes
- Contract returns a function that takes (implementation, fixtures)
- Use describe blocks that include implementation name
- Test both success and error cases
- Round-trip test is critical for format handlers

```lua
-- Contract test pattern
return function(FormatImpl, fixtures)
  describe("IFormat contract: " .. FormatImpl.name, function()
    local format
    
    before_each(function()
      format = FormatImpl.new()
    end)
    
    describe("can_import", function()
      it("returns boolean for valid source", function()
        assert.is_boolean(format:can_import(fixtures.valid_source))
      end)
      -- ...
    end)
  end)
end
```

---

## Stage 12: Contract Tests - IState and IEngine Contracts

### Prerequisites
- Stage 11 completed (contract test pattern established)

### Objectives
- Create contract test suite for IState
- Create contract test suite for IEngine
- Apply contracts to existing implementations

### Inputs
- `lib/whisker/interfaces/state.lua` — IState definition
- `lib/whisker/interfaces/engine.lua` — IEngine definition
- `tests/contracts/format_contract.lua` — Pattern reference

### Tasks
1. Create `tests/contracts/state_contract.lua` — IState contract tests
2. Implement tests for get/set/has/clear operations
3. Implement tests for snapshot/restore cycle
4. Create `tests/contracts/engine_contract.lua` — IEngine contract tests
5. Implement tests for load/start/navigation operations
6. Implement tests for choice selection and progression
7. Apply contracts to existing implementations (placeholder if not refactored yet)

### Outputs
- `tests/contracts/state_contract.lua` — State contract (~100 lines)
- `tests/contracts/engine_contract.lua` — Engine contract (~120 lines)

### Acceptance Criteria
- [ ] IState contract tests all six methods
- [ ] Snapshot/restore round-trip preserves state
- [ ] IEngine contract tests story lifecycle
- [ ] Choice navigation advances story correctly
- [ ] All tests pass when applied to compliant implementations

### Estimated Scope
- New lines: ~220
- Modified lines: ~0
- Test lines: ~220 (all test code)

### Implementation Notes
- State contract should test isolation (set doesn't affect unrelated keys)
- Engine contract needs story fixtures
- Consider testing error conditions (invalid choice index, etc.)

---

## Stage 13: Refactor Core - Passage Module

### Prerequisites
- Stage 03-07 completed (kernel infrastructure)
- Stage 04 completed (interfaces)

### Objectives
- Refactor Passage module to comply with modularity checklist
- Remove direct dependencies
- Add container registration metadata
- Maintain backward compatibility

### Inputs
- `lib/whisker/core/passage.lua` — Existing implementation
- Modularity validation checklist
- `docs/audit/MODULE_INVENTORY.md` — Dependency analysis

### Tasks
1. Analyze current `lib/whisker/core/passage.lua` for violations
2. Extract any dependencies into constructor parameters
3. Add `_whisker` metadata for auto-registration
4. Create compatibility shim if API changes
5. Update `lib/whisker/core/init.lua` to use new pattern
6. Create/update `spec/core/passage_spec.lua` with unit tests

### Outputs
- `lib/whisker/core/passage.lua` — Refactored module (~100 lines)
- `spec/core/passage_spec.lua` — Unit tests (~80 lines)

### Acceptance Criteria
- [ ] No direct require() of other whisker modules
- [ ] Module passes all items on modularity checklist
- [ ] Existing tests still pass
- [ ] New unit tests achieve 90% coverage
- [ ] Backward compatible with existing usage

### Estimated Scope
- New lines: ~20 (metadata, compatibility)
- Modified lines: ~80
- Test lines: ~80

### Implementation Notes
- Passage is a data structure module—likely few dependencies
- Focus on removing any hidden coupling
- Add clear documentation of public API
- Consider if Passage should emit events (probably not—it's data)

---

## Stage 14: Refactor Core - Choice Module

### Prerequisites
- Stage 13 completed (Passage refactored)

### Objectives
- Refactor Choice module to comply with modularity checklist
- Ensure Choice works independently of Passage
- Add container registration metadata

### Inputs
- `lib/whisker/core/choice.lua` — Existing implementation
- Modularity validation checklist

### Tasks
1. Analyze current `lib/whisker/core/choice.lua` for violations
2. Extract dependencies into constructor parameters
3. Add `_whisker` metadata for auto-registration
4. Remove any direct Passage references (use IDs instead)
5. Create/update `spec/core/choice_spec.lua` with unit tests

### Outputs
- `lib/whisker/core/choice.lua` — Refactored module (~80 lines)
- `spec/core/choice_spec.lua` — Unit tests (~70 lines)

### Acceptance Criteria
- [ ] No direct require() of other whisker modules
- [ ] Choice references targets by ID, not object reference
- [ ] Module passes modularity checklist
- [ ] Unit tests achieve 90% coverage

### Estimated Scope
- New lines: ~15
- Modified lines: ~60
- Test lines: ~70

### Implementation Notes
- Choices often reference target passages—use string IDs
- Condition evaluation should be delegated, not embedded
- Choice is also primarily a data structure

---

## Stage 15: Refactor Core - Variable Module

### Prerequisites
- Stage 14 completed

### Objectives
- Refactor Variable module to comply with modularity checklist
- Ensure clean separation from state management
- Support different variable types

### Inputs
- `lib/whisker/core/variable.lua` — Existing implementation
- Modularity validation checklist

### Tasks
1. Analyze current `lib/whisker/core/variable.lua` for violations
2. Ensure Variable is a pure data container
3. Add `_whisker` metadata
4. Add type validation if not present
5. Create/update `spec/core/variable_spec.lua` with unit tests

### Outputs
- `lib/whisker/core/variable.lua` — Refactored module (~70 lines)
- `spec/core/variable_spec.lua` — Unit tests (~60 lines)

### Acceptance Criteria
- [ ] Variable is a pure value container
- [ ] No side effects in Variable operations
- [ ] Module passes modularity checklist
- [ ] Unit tests achieve 90% coverage

### Estimated Scope
- New lines: ~10
- Modified lines: ~50
- Test lines: ~60

### Implementation Notes
- Variables should be immutable where possible
- Type validation can be optional but useful
- Consider supporting computed variables (lazy evaluation)

---

## Stage 16: Refactor Core - Story Module

### Prerequisites
- Stage 13-15 completed (Passage, Choice, Variable refactored)

### Objectives
- Refactor Story module as container for passages
- Implement IFormat-compatible structure
- Enable serialization support
- Add event emission for story operations

### Inputs
- `lib/whisker/core/story.lua` — Existing implementation
- `lib/whisker/interfaces/format.lua` — For compatibility
- `lib/whisker/kernel/events.lua` — For event integration

### Tasks
1. Analyze current `lib/whisker/core/story.lua` for violations
2. Refactor to use injected services
3. Add event emission for add_passage, set_start, etc.
4. Ensure Story structure is IFormat-export compatible
5. Add `_whisker` metadata with container registration
6. Create/update `spec/core/story_spec.lua` with unit tests

### Outputs
- `lib/whisker/core/story.lua` — Refactored module (~120 lines)
- `spec/core/story_spec.lua` — Unit tests (~100 lines)

### Acceptance Criteria
- [ ] Story uses injected services
- [ ] Events emitted for structural changes
- [ ] Story structure compatible with JSON export
- [ ] Module passes modularity checklist
- [ ] Unit tests achieve 90% coverage

### Estimated Scope
- New lines: ~30
- Modified lines: ~90
- Test lines: ~100

### Implementation Notes
- Story is a critical module—careful with breaking changes
- Consider immutable operations (return new Story instead of mutating)
- Passage lookup should be O(1) via hash table

---

## Stage 17: Refactor Runtime - State Service

### Prerequisites
- Stage 05 completed (DI container)
- Stage 04 completed (IState interface)

### Objectives
- Create State service implementing IState
- Replace existing state management
- Support snapshot/restore for save games
- Emit events for state changes

### Inputs
- `lib/whisker/runtime/state.lua` — Existing implementation
- `lib/whisker/interfaces/state.lua` — IState interface
- `tests/contracts/state_contract.lua` — Contract tests

### Tasks
1. Create `lib/whisker/services/state/init.lua` — IState implementation
2. Implement get/set/has/clear operations
3. Implement snapshot/restore for serialization
4. Add event emission for state changes
5. Register with container as IState implementation
6. Apply state contract tests
7. Create `spec/services/state_spec.lua` with additional tests

### Outputs
- `lib/whisker/services/state/init.lua` — State service (~100 lines)
- `spec/services/state_spec.lua` — Unit tests (~80 lines)

### Acceptance Criteria
- [ ] Implements complete IState interface
- [ ] Passes state contract tests
- [ ] Emits "state:changed" events
- [ ] Snapshot captures complete state
- [ ] Restore replaces state atomically
- [ ] Unit tests achieve 85% coverage

### Estimated Scope
- New lines: ~100
- Modified lines: ~10 (container registration)
- Test lines: ~80

### Implementation Notes
- State should be a simple key-value store
- Consider type preservation in snapshot/restore
- Events should include old and new values
- Use deep copy for snapshot to prevent mutations

---

## Stage 18: Refactor Runtime - Engine Service

### Prerequisites
- Stage 17 completed (State service)
- Stage 16 completed (Story refactored)

### Objectives
- Refactor Engine to implement IEngine
- Use injected State service
- Emit navigation events
- Support multiple engine implementations

### Inputs
- `lib/whisker/runtime/engine.lua` — Existing implementation
- `lib/whisker/interfaces/engine.lua` — IEngine interface
- `lib/whisker/services/state/init.lua` — State service
- `tests/contracts/engine_contract.lua` — Contract tests

### Tasks
1. Create `lib/whisker/engines/default.lua` — Default IEngine implementation
2. Refactor to use injected IState service
3. Implement all IEngine methods
4. Add event emission for passage changes, choices
5. Register with container as IEngine implementation
6. Apply engine contract tests
7. Create `spec/engines/default_spec.lua` with additional tests

### Outputs
- `lib/whisker/engines/default.lua` — Default engine (~150 lines)
- `spec/engines/default_spec.lua` — Unit tests (~120 lines)

### Acceptance Criteria
- [ ] Implements complete IEngine interface
- [ ] Passes engine contract tests
- [ ] Uses injected IState (not direct require)
- [ ] Emits "passage:entered", "choice:made" events
- [ ] Unit tests achieve 85% coverage

### Estimated Scope
- New lines: ~150
- Modified lines: ~0 (new location)
- Test lines: ~120

### Implementation Notes
- Engine is a complex module—take care with refactoring
- Consider keeping old engine as compatibility layer
- Choice evaluation should use IConditionEvaluator
- History tracking should be separate service

---

## Stage 19: History Service Implementation

### Prerequisites
- Stage 17-18 completed (State and Engine services)

### Objectives
- Create History service for navigation tracking
- Support undo/back navigation
- Integrate with State snapshots
- Enable history-based game saves

### Inputs
- `lib/whisker/runtime/history.lua` — Existing implementation (if any)
- `lib/whisker/services/state/init.lua` — For snapshot integration
- Event bus for navigation events

### Tasks
1. Create `lib/whisker/services/history/init.lua` — History service
2. Implement push/pop navigation stack
3. Implement back() with state restoration
4. Subscribe to "passage:entered" events
5. Integrate with State snapshots
6. Register with container
7. Create `spec/services/history_spec.lua` with tests

### Outputs
- `lib/whisker/services/history/init.lua` — History service (~90 lines)
- `spec/services/history_spec.lua` — Unit tests (~80 lines)

### Acceptance Criteria
- [ ] Tracks navigation history automatically via events
- [ ] back() returns to previous passage with correct state
- [ ] History can be cleared
- [ ] Works with State snapshot/restore
- [ ] Unit tests achieve 85% coverage

### Estimated Scope
- New lines: ~90
- Modified lines: ~0
- Test lines: ~80

### Implementation Notes
- History entries should include state snapshots
- Consider max history length to prevent memory issues
- back() should emit appropriate events

---

## Stage 20: Condition Evaluator Service

### Prerequisites
- Stage 04 completed (IConditionEvaluator interface)
- Stage 17 completed (State service for context)

### Objectives
- Create Condition Evaluator implementing IConditionEvaluator
- Support standard comparison operators
- Enable custom operator registration
- Integrate with Choice visibility

### Inputs
- `lib/whisker/interfaces/condition.lua` — Interface definition
- `lib/whisker/services/state/init.lua` — For variable access

### Tasks
1. Create `lib/whisker/services/conditions/init.lua` — Evaluator implementation
2. Implement evaluate() with standard operators (==, !=, <, >, <=, >=, and, or, not)
3. Implement register_operator() for extensions
4. Integrate with State service for variable resolution
5. Register with container as IConditionEvaluator
6. Create `spec/services/conditions_spec.lua` with tests

### Outputs
- `lib/whisker/services/conditions/init.lua` — Condition evaluator (~100 lines)
- `spec/services/conditions_spec.lua` — Unit tests (~90 lines)

### Acceptance Criteria
- [ ] Evaluates all standard operators correctly
- [ ] Custom operators can be registered
- [ ] Variables resolved from State context
- [ ] Nested conditions supported (and/or/not)
- [ ] Unit tests achieve 90% coverage

### Estimated Scope
- New lines: ~100
- Modified lines: ~0
- Test lines: ~90

### Implementation Notes
- Conditions might be tables or strings—support both
- Consider expression parsing for string conditions
- Short-circuit evaluation for and/or
- Provide clear error messages for invalid conditions

---

## Stage 21: CI/CD Pipeline and Final Integration

### Prerequisites
- All previous stages completed
- All tests passing locally

### Objectives
- Establish GitHub Actions CI/CD pipeline
- Configure multi-Lua-version testing
- Add coverage enforcement
- Complete documentation updates
- Final integration verification

### Inputs
- All test files from previous stages
- `.github/workflows/` — Existing CI if any
- Roadmap Section 0.9.5 (CI/CD Testing)

### Tasks
1. Create/update `.github/workflows/test.yml` — Main test workflow
2. Configure matrix testing (Lua 5.1, 5.2, 5.3, 5.4, LuaJIT)
3. Add luacov coverage reporting
4. Add coverage enforcement (fail if below thresholds)
5. Add luacheck linting step
6. Update `README.md` with new architecture docs
7. Create `docs/API_REFERENCE.md` with interface documentation
8. Run full integration test suite
9. Verify all modules pass modularity checklist

### Outputs
- `.github/workflows/test.yml` — CI pipeline (~80 lines)
- `.github/workflows/lint.yml` — Linting workflow (~30 lines)
- `docs/API_REFERENCE.md` — Updated API docs (~200 lines)
- Updated `README.md` (~50 lines changed)

### Acceptance Criteria
- [ ] CI runs on all PRs and pushes to main
- [ ] Tests pass on all Lua versions in matrix
- [ ] Coverage thresholds enforced in CI
- [ ] Linting passes with no errors
- [ ] All modularity checklists pass for all modules
- [ ] API documentation complete and accurate

### Estimated Scope
- New lines: ~360
- Modified lines: ~50
- Test lines: ~0 (tests already written)

### Implementation Notes
- Use `leafo/gh-actions-lua` for Lua setup
- Use `leafo/gh-actions-luarocks` for LuaRocks
- Coverage thresholds: kernel 95%, core 90%, services 85%, formats 80%
- Consider adding badge to README for build status

```yaml
# Example workflow structure
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        lua: ['5.1', '5.2', '5.3', '5.4', 'luajit-2.1']
    steps:
      - uses: actions/checkout@v3
      - uses: leafo/gh-actions-lua@v10
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install busted
      - run: luarocks install luacov
      - run: busted --coverage
```

---

## Phase 1 Completion Checklist

- [ ] All 21 stages completed
- [ ] All modules pass modularity validation checklist
- [ ] Test coverage ≥80% overall (with component-specific targets met)
- [ ] API documentation complete for all interfaces
- [ ] CI/CD pipeline operational with coverage enforcement
- [ ] All contract tests pass for all interface implementations
- [ ] Event bus integrated throughout system
- [ ] DI container manages all component lifecycles
- [ ] Ready for Phase 2 (Ink Integration)

---

## Appendix: File Manifest

| File Path | Stage | Purpose | Est. Lines |
|-----------|-------|---------|------------|
| `docs/audit/MODULE_INVENTORY.md` | 01 | Module inventory | 100 |
| `docs/audit/COUPLING_ANALYSIS.md` | 01 | Dependency analysis | 80 |
| `docs/audit/ISSUES.md` | 01 | Issue list | 60 |
| `docs/audit/COVERAGE_BASELINE.md` | 01 | Coverage report | 40 |
| `docs/architecture/REFACTORING_PLAN.md` | 02 | Migration plan | 150 |
| `docs/architecture/FILE_STRUCTURE.md` | 02 | Target structure | 80 |
| `docs/architecture/ADR-001-microkernel.md` | 02 | ADR | 60 |
| `docs/architecture/ADR-002-di-container.md` | 02 | ADR | 60 |
| `docs/architecture/ADR-003-event-bus.md` | 02 | ADR | 60 |
| `docs/architecture/MIGRATION_CHECKLIST.md` | 02 | Tracker | 40 |
| `lib/whisker/kernel/init.lua` | 03 | Kernel entry | 40 |
| `lib/whisker/kernel/registry.lua` | 03 | Module registry | 60 |
| `lib/whisker/kernel/capabilities.lua` | 03 | Capability system | 50 |
| `lib/whisker/kernel/errors.lua` | 03 | Error definitions | 30 |
| `lib/whisker/interfaces/init.lua` | 04 | Interface loader | 60 |
| `lib/whisker/interfaces/format.lua` | 04 | IFormat | 25 |
| `lib/whisker/interfaces/state.lua` | 04 | IState | 25 |
| `lib/whisker/interfaces/engine.lua` | 04 | IEngine | 30 |
| `lib/whisker/interfaces/serializer.lua` | 04 | ISerializer | 20 |
| `lib/whisker/interfaces/condition.lua` | 04 | IConditionEvaluator | 25 |
| `lib/whisker/interfaces/plugin.lua` | 04 | IPlugin | 25 |
| `lib/whisker/kernel/container.lua` | 05 | DI container | 150 |
| `lib/whisker/kernel/events.lua` | 06 | Event bus | 100 |
| `lib/whisker/kernel/loader.lua` | 07 | Module loader | 80 |
| `tests/support/mock_factory.lua` | 08 | Mock generation | 120 |
| `tests/support/test_container.lua` | 09 | Test DI | 80 |
| `tests/support/helpers.lua` | 10 | Test helpers | 60 |
| `tests/support/fixtures.lua` | 10 | Fixture loader | 40 |
| `tests/fixtures/stories/*.json` | 10 | Test stories | 215 |
| `tests/contracts/format_contract.lua` | 11 | IFormat contract | 120 |
| `tests/contracts/state_contract.lua` | 12 | IState contract | 100 |
| `tests/contracts/engine_contract.lua` | 12 | IEngine contract | 120 |
| `lib/whisker/core/passage.lua` | 13 | Refactored | ~100 |
| `lib/whisker/core/choice.lua` | 14 | Refactored | ~80 |
| `lib/whisker/core/variable.lua` | 15 | Refactored | ~70 |
| `lib/whisker/core/story.lua` | 16 | Refactored | ~120 |
| `lib/whisker/services/state/init.lua` | 17 | State service | 100 |
| `lib/whisker/engines/default.lua` | 18 | Default engine | 150 |
| `lib/whisker/services/history/init.lua` | 19 | History service | 90 |
| `lib/whisker/services/conditions/init.lua` | 20 | Condition eval | 100 |
| `.github/workflows/test.yml` | 21 | CI pipeline | 80 |
| `.github/workflows/lint.yml` | 21 | Lint workflow | 30 |
| `docs/API_REFERENCE.md` | 21 | API docs | 200 |

**Total New Production Code:** ~1,700 lines
**Total Test Code:** ~1,800 lines
**Total Documentation:** ~1,200 lines

---

## Appendix: Stage Dependencies Graph

```
Stage 01 ─→ Stage 02 ─→ Stage 03 ─→ Stage 04 ─→ Stage 05 ─→ Stage 06 ─→ Stage 07
                         │          │
                         │          └──────────────────────────────────────────────┐
                         │                                                         │
                         └─→ Stage 08 ─→ Stage 09 ─→ Stage 10 ─→ Stage 11 ─→ Stage 12
                                                                    │
Stage 03-07 ──────────────────────────────────────────────────────→│
                                                                    ↓
                              Stage 13 ─→ Stage 14 ─→ Stage 15 ─→ Stage 16
                                                                    │
                                                                    ↓
                              Stage 17 ─→ Stage 18 ─→ Stage 19 ─→ Stage 20 ─→ Stage 21
```

---

*Document generated for whisker-core Phase 1 implementation. Each stage is designed to be executable independently with clear inputs, outputs, and acceptance criteria.*
