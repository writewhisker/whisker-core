# Whisker-Core Implementation Roadmap

## Executive Summary

This document provides a comprehensive analysis and implementation roadmap for achieving the stated goal: creating a Lua-based interactive fiction framework that is flexible, embeddable, and compatible with Twine and Ink formats. Based on analysis of the existing whisker-core repository at https://github.com/writewhisker/whisker-core, this roadmap outlines what exists, what's missing, and a phased approach to completion.

**Recommendation: Improve the existing project rather than starting fresh.** The existing architecture is sound, well-documented, and provides a solid foundation. The gaps are primarily in implementation depth and format compatibility rather than fundamental design flaws.

---

## 0. Architectural Foundation: Extreme Modularity

**This section establishes the architectural principles that must govern ALL phases of implementation.**

The requirement for "extreme modularity" means the system should be decomposable to the finest practical granularity, with every component being replaceable, testable in isolation, and composable with other components.

### 0.1 Core Architectural Principles

#### Principle 1: Microkernel Architecture
The core runtime should be a minimal "microkernel" that does almost nothing by itself. All functionality—including what might seem like "core" features—should be implemented as modules that plug into this kernel.

```
┌─────────────────────────────────────────────────────────────┐
│                      Applications                           │
│  (CLI Player, Web Player, Editor, Custom Integrations)      │
├─────────────────────────────────────────────────────────────┤
│                    Extension Layer                          │
│  (Format Handlers, Export Plugins, Tool Plugins)            │
├─────────────────────────────────────────────────────────────┤
│                    Service Layer                            │
│  (State, History, Variables, Events, Persistence)           │
├─────────────────────────────────────────────────────────────┤
│                    Core Abstractions                        │
│  (Story, Passage, Choice, Condition Interfaces)             │
├─────────────────────────────────────────────────────────────┤
│                    Microkernel                              │
│  (Module Loader, Dependency Injection, Event Bus)           │
└─────────────────────────────────────────────────────────────┘
```

#### Principle 2: Interface-First Design
Every module defines and depends on **interfaces**, never concrete implementations. This enables:
- Swapping implementations without changing dependent code
- Testing with mocks/stubs
- Platform-specific implementations behind common interfaces

```lua
-- WRONG: Direct dependency
local JsonFormat = require("whisker.format.json")

-- RIGHT: Interface dependency via registry
local format = whisker.formats:get("json")  -- Returns whatever implements IFormat for "json"
```

#### Principle 3: Dependency Injection Container
A central container manages all component lifecycles and dependencies:

```lua
-- Registration (at startup or by plugins)
whisker.container:register("state_manager", StateManager, { singleton = true })
whisker.container:register("history", HistoryService, { depends = {"state_manager"} })
whisker.container:register("format.json", JsonFormat, { implements = "IFormat" })

-- Resolution (automatic dependency injection)
local engine = whisker.container:resolve("engine")  -- Gets instance with all deps injected
```

#### Principle 4: Event-Driven Communication
Modules communicate through events, not direct calls. This eliminates tight coupling:

```lua
-- Module A doesn't know Module B exists
whisker.events:emit("passage:entered", { passage = passage, context = ctx })

-- Module B subscribes to events it cares about
whisker.events:on("passage:entered", function(data)
  -- React to passage entry
end)
```

#### Principle 5: Feature Flags and Capability Detection
Even "core" features should be optional and detectable:

```lua
if whisker.capabilities:has("variables") then
  -- Use variable system
end

if whisker.capabilities:has("format.ink") then
  -- Ink support is available
end
```

### 0.2 Module Granularity Guidelines

**Level 1: Atomic Modules** (finest granularity)
Each does ONE thing. Can be used independently.

| Module | Responsibility | Dependencies |
|--------|---------------|--------------|
| `whisker.core.passage` | Passage data structure | None |
| `whisker.core.choice` | Choice data structure | None |
| `whisker.core.condition` | Condition evaluation | None |
| `whisker.util.events` | Event bus | None |
| `whisker.util.registry` | Generic registry pattern | None |

**Level 2: Service Modules** (composed from atomic)
Provide cohesive functionality. Depend only on interfaces.

| Module | Responsibility | Interface Dependencies |
|--------|---------------|----------------------|
| `whisker.services.state` | State management | ISerializer |
| `whisker.services.history` | Navigation history | IState |
| `whisker.services.variables` | Variable system | IState, ICondition |
| `whisker.services.persistence` | Save/load | IState, ISerializer |

**Level 3: Feature Modules** (optional capabilities)
Can be entirely omitted without breaking core.

| Module | Responsibility | Adds Capability |
|--------|---------------|-----------------|
| `whisker.format.json` | JSON import/export | format.json |
| `whisker.format.ink` | Ink compatibility | format.ink |
| `whisker.format.twine.*` | Twine formats | format.twine.* |
| `whisker.script` | Whisker Script lang | script |
| `whisker.tools.debugger` | Debugging | tools.debug |

**Level 4: Application Modules** (consumers)
Full applications built on the framework.

| Module | Type |
|--------|------|
| `whisker.apps.cli` | CLI player |
| `whisker.apps.web` | Web player |
| `whisker.apps.validator` | Story validator |

### 0.3 Interface Definitions

Every swappable component must implement a defined interface:

```lua
-- lib/whisker/interfaces/init.lua

-- Story format handler interface
IFormat = {
  can_import = function(self, source) end,  -- Returns boolean
  import = function(self, source) end,       -- Returns Story
  can_export = function(self, story) end,    -- Returns boolean  
  export = function(self, story) end,        -- Returns string/bytes
}

-- State manager interface
IState = {
  get = function(self, key) end,
  set = function(self, key, value) end,
  has = function(self, key) end,
  clear = function(self) end,
  snapshot = function(self) end,
  restore = function(self, snapshot) end,
}

-- Serializer interface
ISerializer = {
  serialize = function(self, data) end,
  deserialize = function(self, str) end,
}

-- Condition evaluator interface  
IConditionEvaluator = {
  evaluate = function(self, condition, context) end,
  register_operator = function(self, name, fn) end,
}

-- Runtime engine interface
IEngine = {
  load = function(self, story) end,
  start = function(self) end,
  get_current_passage = function(self) end,
  get_available_choices = function(self) end,
  make_choice = function(self, index) end,
  can_continue = function(self) end,
}

-- Plugin interface
IPlugin = {
  name = "string",
  version = "string",
  dependencies = {},  -- Optional
  init = function(self, container) end,
  destroy = function(self) end,
}
```

### 0.4 Module Communication Patterns

#### Pattern 1: Event Bus (preferred for loose coupling)
```lua
-- Publisher (format module)
whisker.events:emit("story:loaded", { story = story, format = "ink" })

-- Subscriber (analytics plugin) - doesn't know about format module
whisker.events:on("story:loaded", function(data)
  track("story_load", { format = data.format })
end)
```

#### Pattern 2: Service Locator (for required services)
```lua
-- Get a service by interface
local state = whisker.services:get(IState)
state:set("player_name", "Alice")
```

#### Pattern 3: Middleware Pipeline (for extensible processing)
```lua
-- Register middleware
whisker.pipeline:use("render_passage", function(passage, next)
  -- Pre-processing
  passage.content = expand_variables(passage.content)
  -- Continue pipeline
  local result = next(passage)
  -- Post-processing
  return result
end)
```

#### Pattern 4: Strategy Pattern (for swappable algorithms)
```lua
-- Register strategy
whisker.strategies:register("condition_eval", "lua", LuaConditionEvaluator)
whisker.strategies:register("condition_eval", "simple", SimpleConditionEvaluator)

-- Use configured strategy
local evaluator = whisker.strategies:get("condition_eval")
```

### 0.5 File Organization for Modularity

```
lib/whisker/
├── kernel/                     # Microkernel (MINIMAL)
│   ├── init.lua               # Bootstrap only
│   ├── container.lua          # Dependency injection
│   ├── events.lua             # Event bus
│   ├── registry.lua           # Generic registry
│   └── loader.lua             # Module loader
│
├── interfaces/                 # Pure interface definitions
│   ├── init.lua
│   ├── format.lua             # IFormat
│   ├── state.lua              # IState
│   ├── engine.lua             # IEngine
│   ├── serializer.lua         # ISerializer
│   └── plugin.lua             # IPlugin
│
├── core/                       # Core data structures (no deps)
│   ├── story.lua
│   ├── passage.lua
│   ├── choice.lua
│   └── condition.lua
│
├── services/                   # Service implementations
│   ├── state/
│   │   ├── init.lua           # Default IState impl
│   │   ├── memory.lua         # In-memory state
│   │   └── persistent.lua     # Persistent state
│   ├── history/
│   ├── variables/
│   └── persistence/
│
├── formats/                    # Format handlers (IFormat impls)
│   ├── json/
│   ├── ink/
│   ├── twine/
│   │   ├── base.lua           # Shared Twine logic
│   │   ├── harlowe.lua
│   │   ├── sugarcube.lua
│   │   └── ...
│   └── whisker/
│
├── script/                     # Whisker Script (optional feature)
│   ├── lexer.lua
│   ├── parser.lua
│   └── compiler.lua
│
├── engines/                    # Runtime engines (IEngine impls)
│   ├── default.lua
│   ├── streaming.lua          # For async/large stories
│   └── debug.lua              # Debug-enabled engine
│
├── export/                     # Export handlers
│   ├── html/
│   ├── text/
│   └── ...
│
├── plugins/                    # Plugin system
│   ├── manager.lua
│   ├── sandbox.lua            # Plugin isolation
│   └── builtin/               # Built-in plugins
│
└── apps/                       # Application entry points
    ├── cli/
    └── validator/
```

### 0.6 Modularity Validation Checklist

For EVERY module, verify:

- [ ] **No hardcoded dependencies** - Uses container/registry for all dependencies
- [ ] **Implements an interface** - Has a corresponding interface definition
- [ ] **Testable in isolation** - Can be unit tested with mocks
- [ ] **Optional loading** - System works if module is absent (for feature modules)
- [ ] **Event-based communication** - Uses events for cross-module communication
- [ ] **Single responsibility** - Does one thing well
- [ ] **Documented contract** - Clear documentation of inputs/outputs/events
- [ ] **No global state** - All state through injected services

### 0.7 Integration with Implementation Phases

**This modularity architecture affects EVERY phase:**

| Phase | Modularity Considerations |
|-------|--------------------------|
| Phase 1 | Implement microkernel, container, events, interfaces FIRST |
| Phase 2 | Ink support as IFormat implementation, pluggable |
| Phase 3 | Script compiler as optional feature module |
| Phase 4 | Each Twine format as separate IFormat implementation |
| Phase 5 | Plugin system uses existing container/events infrastructure |
| Phase 6 | Export handlers as IExporter implementations |
| Phase 7 | Profile each module independently, optimize hot paths |

### 0.8 Example: Adding a New Format (Demonstrates Modularity)

To add support for a new format (e.g., Yarn Spinner):

```lua
-- lib/whisker/formats/yarn/init.lua
local IFormat = require("whisker.interfaces.format")

local YarnFormat = {}
setmetatable(YarnFormat, { __index = IFormat })

function YarnFormat:can_import(source)
  return source:match("^title:") ~= nil
end

function YarnFormat:import(source)
  -- Parse Yarn format, return Story
end

function YarnFormat:can_export(story)
  return true
end

function YarnFormat:export(story)
  -- Generate Yarn format
end

return YarnFormat
```

Registration (in plugin or config):
```lua
whisker.container:register("format.yarn", YarnFormat, {
  implements = "IFormat",
  capability = "format.yarn"
})
```

**Zero changes to core code required.**

### 0.9 Comprehensive Testing Strategy

Testing is a **first-class architectural concern**, not an afterthought. The extreme modularity requirement actually enables superior testing—each module being isolated and interface-driven means it can be tested independently with mocks.

#### 0.9.1 Testing Philosophy

| Principle | Description |
|-----------|-------------|
| **Test Pyramid** | Many unit tests, fewer integration tests, minimal E2E tests |
| **Interface Testing** | Test against interfaces, not implementations |
| **Contract Testing** | Verify modules fulfill their interface contracts |
| **Isolation by Default** | Every test runs with mocked dependencies unless explicitly integration |
| **Deterministic** | No flaky tests; all randomness seeded; no timing dependencies |
| **Fast Feedback** | Unit tests run in <1 second total; full suite <30 seconds |

#### 0.9.2 Test Categories

**Level 1: Unit Tests (Target: 90%+ of tests)**
Test individual functions and modules in complete isolation.

```lua
-- tests/unit/core/passage_spec.lua
describe("Passage", function()
  local Passage = require("whisker.core.passage")
  
  describe("new", function()
    it("creates passage with required fields", function()
      local p = Passage.new({ id = "start", content = "Hello" })
      assert.equals("start", p.id)
      assert.equals("Hello", p.content)
    end)
    
    it("rejects missing id", function()
      assert.has_error(function()
        Passage.new({ content = "Hello" })
      end, "Passage requires 'id' field")
    end)
  end)
end)
```

**Level 2: Contract Tests (Target: Every interface)**
Verify that implementations correctly fulfill interface contracts. These are reusable test suites that any implementation must pass.

```lua
-- tests/contracts/format_contract.lua
-- Any IFormat implementation must pass these tests

return function(FormatImpl, test_fixtures)
  describe("IFormat contract: " .. FormatImpl.name, function()
    local format
    
    before_each(function()
      format = FormatImpl.new()
    end)
    
    describe("can_import", function()
      it("returns boolean", function()
        local result = format:can_import(test_fixtures.valid_source)
        assert.is_boolean(result)
      end)
      
      it("returns true for valid format", function()
        assert.is_true(format:can_import(test_fixtures.valid_source))
      end)
      
      it("returns false for invalid format", function()
        assert.is_false(format:can_import(test_fixtures.invalid_source))
      end)
    end)
    
    describe("import", function()
      it("returns Story object", function()
        local story = format:import(test_fixtures.valid_source)
        assert.is_not_nil(story)
        assert.is_not_nil(story.passages)
      end)
      
      it("preserves passage count", function()
        local story = format:import(test_fixtures.valid_source)
        assert.equals(test_fixtures.expected_passage_count, #story.passages)
      end)
    end)
    
    describe("round-trip", function()
      it("import then export preserves data", function()
        local story = format:import(test_fixtures.valid_source)
        local exported = format:export(story)
        local reimported = format:import(exported)
        assert.same(story.passages, reimported.passages)
      end)
    end)
  end)
end
```

Usage for each format implementation:
```lua
-- tests/contracts/json_format_spec.lua
local contract = require("tests.contracts.format_contract")
local JsonFormat = require("whisker.formats.json")

contract(JsonFormat, {
  valid_source = '{"passages": [{"id": "start", "content": "Hello"}]}',
  invalid_source = 'not json at all',
  expected_passage_count = 1
})
```

**Level 3: Integration Tests (Target: Critical paths)**
Test module interactions through real interfaces (not mocks).

```lua
-- tests/integration/story_playthrough_spec.lua
describe("Story playthrough integration", function()
  local whisker = require("whisker")
  
  it("plays through a complete story", function()
    local story = whisker.load("tests/fixtures/simple_story.json")
    local engine = whisker.engine.new(story)
    
    engine:start()
    assert.equals("start", engine:get_current_passage().id)
    
    local choices = engine:get_available_choices()
    assert.equals(2, #choices)
    
    engine:make_choice(1)
    assert.not_equals("start", engine:get_current_passage().id)
  end)
end)
```

**Level 4: Property-Based Tests (Target: Core algorithms)**
Use generative testing to find edge cases.

```lua
-- tests/property/condition_evaluator_spec.lua
local lqc = require("lqc")  -- Lua QuickCheck

describe("ConditionEvaluator properties", function()
  local evaluator = require("whisker.services.conditions")
  
  lqc.property("AND is commutative", function()
    local a = lqc.bool()
    local b = lqc.bool()
    local ctx = {}
    
    local result1 = evaluator:evaluate({ op = "and", left = a, right = b }, ctx)
    local result2 = evaluator:evaluate({ op = "and", left = b, right = a }, ctx)
    
    return result1 == result2
  end)
  
  lqc.property("double negation is identity", function()
    local a = lqc.bool()
    local ctx = {}
    
    local result = evaluator:evaluate({ 
      op = "not", 
      value = { op = "not", value = a } 
    }, ctx)
    
    return result == a
  end)
end)
```

**Level 5: End-to-End Tests (Target: User journeys)**
Test complete user scenarios including CLI/web interfaces.

```lua
-- tests/e2e/cli_spec.lua
describe("CLI end-to-end", function()
  it("plays a story from file", function()
    local result = os.execute("echo '1\n2\n' | lua bin/whisker tests/fixtures/story.json")
    assert.equals(0, result)
  end)
  
  it("validates story structure", function()
    local handle = io.popen("lua bin/whisker --validate tests/fixtures/story.json 2>&1")
    local output = handle:read("*a")
    handle:close()
    assert.matches("Valid story", output)
  end)
end)
```

#### 0.9.3 Test Infrastructure

**Mock Factory**
Auto-generate mocks from interface definitions:

```lua
-- tests/support/mock_factory.lua
local MockFactory = {}

function MockFactory.from_interface(interface)
  local mock = {
    _calls = {},
    _returns = {}
  }
  
  for method_name, _ in pairs(interface) do
    mock[method_name] = function(self, ...)
      table.insert(self._calls, { method = method_name, args = {...} })
      return self._returns[method_name]
    end
  end
  
  function mock:when(method)
    return {
      returns = function(value)
        mock._returns[method] = value
      end
    }
  end
  
  function mock:verify(method)
    return {
      called = function(times)
        local count = 0
        for _, call in ipairs(mock._calls) do
          if call.method == method then count = count + 1 end
        end
        assert.equals(times, count)
      end,
      called_with = function(...)
        local expected = {...}
        for _, call in ipairs(mock._calls) do
          if call.method == method then
            assert.same(expected, call.args)
            return
          end
        end
        error("Method " .. method .. " was not called")
      end
    }
  end
  
  return mock
end

return MockFactory
```

Usage:
```lua
local MockFactory = require("tests.support.mock_factory")
local IState = require("whisker.interfaces.state")

local mock_state = MockFactory.from_interface(IState)
mock_state:when("get"):returns("test_value")

-- Use mock in test
local result = mock_state:get("key")
assert.equals("test_value", result)
mock_state:verify("get"):called(1)
mock_state:verify("get"):called_with("key")
```

**Test Container**
Isolated DI container for each test:

```lua
-- tests/support/test_container.lua
local Container = require("whisker.kernel.container")
local MockFactory = require("tests.support.mock_factory")

local TestContainer = {}

function TestContainer.new()
  local container = Container.new()
  local mocks = {}
  
  return {
    -- Register real implementation
    register = function(self, ...)
      container:register(...)
    end,
    
    -- Register mock for interface
    mock = function(self, name, interface)
      local mock = MockFactory.from_interface(interface)
      mocks[name] = mock
      container:register(name, function() return mock end, { singleton = true })
      return mock
    end,
    
    -- Get registered mock for verification
    get_mock = function(self, name)
      return mocks[name]
    end,
    
    resolve = function(self, ...)
      return container:resolve(...)
    end
  }
end

return TestContainer
```

**Fixture Management**
Structured test data:

```
tests/
├── fixtures/
│   ├── stories/
│   │   ├── simple.json
│   │   ├── complex_branching.json
│   │   ├── variables_heavy.json
│   │   └── edge_cases/
│   │       ├── empty_passages.json
│   │       ├── circular_links.json
│   │       └── unicode_content.json
│   ├── formats/
│   │   ├── twine/
│   │   │   ├── harlowe_basic.html
│   │   │   ├── sugarcube_macros.html
│   │   │   └── ...
│   │   └── ink/
│   │       ├── simple.ink.json
│   │       └── ...
│   └── scripts/
│       ├── valid.whisker
│       └── syntax_errors/
```

#### 0.9.4 Coverage Requirements

| Component | Line Coverage | Branch Coverage | Notes |
|-----------|--------------|-----------------|-------|
| kernel/* | 95% | 90% | Critical infrastructure |
| interfaces/* | N/A | N/A | Definitions only |
| core/* | 90% | 85% | Core data structures |
| services/* | 85% | 80% | Service implementations |
| formats/* | 80% | 75% | Format handlers |
| script/* | 90% | 85% | Compiler (complex logic) |
| engines/* | 85% | 80% | Runtime engines |
| apps/* | 70% | 65% | CLI/UI (harder to test) |

#### 0.9.5 Continuous Integration Testing

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        lua: ['5.1', '5.2', '5.3', '5.4', 'luajit-2.1']
    steps:
      - uses: actions/checkout@v3
      - uses: leafo/gh-actions-lua@v10
        with:
          luaVersion: ${{ matrix.lua }}
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install busted
      - run: luarocks install luacov
      - name: Run unit tests
        run: busted --coverage tests/unit
      - name: Check coverage
        run: |
          luacov
          lua scripts/check_coverage.lua --min 85

  contract-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v3
      - uses: leafo/gh-actions-lua@v10
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install busted
      - name: Run contract tests
        run: busted tests/contracts

  integration-tests:
    runs-on: ubuntu-latest
    needs: contract-tests
    steps:
      - uses: actions/checkout@v3
      - uses: leafo/gh-actions-lua@v10
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install busted
      - name: Run integration tests
        run: busted tests/integration

  e2e-tests:
    runs-on: ubuntu-latest
    needs: integration-tests
    steps:
      - uses: actions/checkout@v3
      - uses: leafo/gh-actions-lua@v10
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install busted
      - name: Run E2E tests
        run: busted tests/e2e

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: leafo/gh-actions-lua@v10
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install luacheck
      - name: Lint
        run: luacheck lib/ bin/ --config .luacheckrc
```

#### 0.9.6 Test-Driven Development Workflow

For each new module or feature:

1. **Write interface first** (interfaces/*.lua)
2. **Write contract tests** that any implementation must pass
3. **Write unit test stubs** for the specific implementation
4. **Implement** until tests pass
5. **Add edge case tests** discovered during implementation
6. **Run full suite** to ensure no regressions

#### 0.9.7 Testing Each Module Type

| Module Type | Primary Test Type | Mock Strategy |
|-------------|------------------|---------------|
| Atomic (core/*) | Unit tests | No mocks needed (no deps) |
| Services | Unit + Contract | Mock interface dependencies |
| Formats | Contract + Integration | Mock IState, real parsing |
| Engines | Integration | Real services, fixture stories |
| Apps | E2E | Real everything |
| Plugins | Contract + Integration | Mock container, real hooks |

#### 0.9.8 Regression Test Generation

When bugs are fixed, **always** add a regression test:

```lua
-- tests/regression/issue_42_spec.lua
-- Regression test for: https://github.com/writewhisker/whisker-core/issues/42
-- Bug: Passage links with unicode characters were not resolved

describe("Issue #42: Unicode passage links", function()
  it("resolves links with Japanese characters", function()
    local story = load_fixture("regression/issue_42.json")
    local engine = Engine.new(story)
    engine:start()
    
    -- This was throwing "passage not found" before the fix
    assert.has_no_error(function()
      engine:make_choice(1)  -- Choice links to "東京"
    end)
    
    assert.equals("東京", engine:get_current_passage().id)
  end)
end)
```

---

## 1. Gap Analysis

### 1.1 Current State Assessment

Based on repository analysis, whisker-core has the following implemented:

#### ✅ Completed/Functional
| Component | Status | Notes |
|-----------|--------|-------|
| Core Story Primitives | Implemented | Story, Passage, Choice, Variable modules exist |
| Basic Runtime Engine | Implemented | Engine, state, and history management |
| Twine HTML Import | Partial | Basic structure parsing for Harlowe, SugarCube, Chapbook, Snowman |
| JSON Story Format | Implemented | Import/export capability |
| CLI Player | Implemented | Basic command-line interface |
| Web Player | Implemented | Browser-based story player |
| Basic Validator | Implemented | Story structure validation |
| Test Framework | Implemented | Busted-based test suite |
| LuaRocks Package | Configured | Rockspec available |
| Documentation | Partial | API reference started, architecture guide exists |

#### ⚠️ Partially Implemented
| Component | Status | Gaps |
|-----------|--------|------|
| Twine Format Support | ~60% | Macro interpretation incomplete; format-specific features lacking |
| Developer Tools | ~50% | Debugger/profiler exist but lack polish |
| Compact Format | ~40% | Specification exists but implementation incomplete |
| Variable System | ~70% | Basic variables work; complex types need work |
| Plugin Architecture | ~30% | Hooks exist but no formal plugin API |
| **Test Suite** | ~40% | Basic tests exist; lacks contract tests, mocks, coverage enforcement |

#### ❌ Missing/Not Implemented
| Component | Priority | Complexity |
|-----------|----------|------------|
| **Ink Format Support** | HIGH | HIGH |
| Multi-Format Export | HIGH | MEDIUM |
| Whisker Script Language | HIGH | HIGH |
| **Test Infrastructure** | HIGH | MEDIUM |
| **Contract Test Suites** | HIGH | MEDIUM |
| Advanced Conditional Logic | MEDIUM | MEDIUM |
| Collaboration Features | LOW | HIGH |
| Native Embedding Support | MEDIUM | MEDIUM |
| Comprehensive Error Messages | MEDIUM | LOW |
| Performance Optimization | LOW | MEDIUM |

### 1.2 Critical Missing Capabilities

#### 1.2.1 Ink Format Support (CRITICAL GAP)
The goal explicitly requires Ink compatibility. Current state: **Not implemented.**

**What's needed:**
- Ink JSON runtime (good news: "tinta" exists as MIT-licensed Lua port at https://github.com/smwhr/tinta)
- Ink-to-Whisker conversion layer
- Whisker-to-Ink export capability
- Integration with inklecate compiler (external tool)

**Recommendation:** Integrate or adapt the "tinta" library (36 stars, actively maintained, MIT license) rather than building from scratch. This provides:
- Complete Ink runtime in Lua
- Save/load support
- Variable observers
- External functions
- Flows support

#### 1.2.2 Whisker Script Language (HIGH PRIORITY GAP)
No dedicated authoring language exists. Authors must write Lua code directly or import from other formats.

**What's needed:**
- Simple, beginner-friendly markup syntax
- Clear documentation and tutorials
- Error messages that guide non-programmers
- IDE/editor support (syntax highlighting)

**Design considerations:**
- Should be learnable in under 30 minutes
- Should map cleanly to Lua concepts without exposing complexity
- Should support gradual complexity (simple stories → advanced features)

#### 1.2.3 Plugin/Extension System (MEDIUM PRIORITY GAP)
Current architecture lacks formal extensibility mechanisms.

**What's needed:**
- Plugin registration and lifecycle management
- Hook system for all major events
- Sandboxed execution for untrusted plugins
- Documentation for plugin developers

#### 1.2.4 Multi-Format Export (HIGH PRIORITY GAP)
Export capabilities are limited.

**What's needed:**
- Export to standalone HTML
- Export to Twine-compatible HTML
- Export to Ink JSON
- Export to plain text/transcript
- Export to other scripting languages (per requirements)

---

## 2. Decision Points

### Decision Point 0: Modularity Granularity
**Options:**
1. **Microkernel with maximum decomposition** (RECOMMENDED)
   - Pros: Maximum flexibility, each piece replaceable, clean testing
   - Cons: More initial complexity, potential performance overhead
   
2. **Layered architecture with plugin system**
   - Pros: Simpler mental model, familiar pattern
   - Cons: Less flexible, harder to swap core components

3. **Monolithic with extension points**
   - Pros: Simplest to implement initially
   - Cons: Does not meet "extreme modularity" requirement

**Recommendation:** Option 1 - The requirement explicitly calls for "extreme modularity." Implement microkernel architecture in Phase 1 as the foundation for everything else.

### Decision Point 1: Ink Integration Strategy
**Options:**
1. **Integrate tinta library directly** (RECOMMENDED)
   - Pros: Immediate Ink runtime support, maintained by community, MIT license compatible
   - Cons: Additional dependency, may need adaptation for Whisker patterns
   
2. **Build native Ink parser/runtime**
   - Pros: Full control, tighter integration
   - Cons: 6-12 months additional work, replicating existing effort

3. **External compilation only**
   - Pros: Simplest approach
   - Cons: Doesn't meet "compatible with Ink" requirement fully

**Recommendation:** Option 1 - Fork or vendor tinta, adapt to Whisker's module structure.

### Decision Point 2: Whisker Script Language Design
**Options:**
1. **Twee-compatible syntax**
   - Pros: Familiar to Twine users, existing tooling
   - Cons: Limited expressiveness, Twine baggage

2. **Ink-inspired syntax**
   - Pros: Proven design, powerful features
   - Cons: Learning curve, parser complexity

3. **New hybrid syntax** (RECOMMENDED)
   - Pros: Best of both worlds, tailored to Whisker
   - Cons: No existing familiarity, documentation burden

4. **Markdown-based with extensions**
   - Pros: Very familiar, excellent tooling
   - Cons: May be limiting for complex logic

**Recommendation:** Option 3 with strong influences from Ink and Twee, plus Markdown for content.

### Decision Point 3: Plugin Architecture
**Options:**
1. **Lua modules with naming convention**
   - Pros: Simple, idiomatic
   - Cons: No isolation, no lifecycle management

2. **Formal plugin registry with hooks** (RECOMMENDED)
   - Pros: Controlled, documented, discoverable
   - Cons: More complex to implement

3. **External process plugins**
   - Pros: Language-agnostic, isolated
   - Cons: Performance overhead, complexity

### Decision Point 4: Performance vs. Features
**Options:**
1. **Feature-complete first, optimize later** (RECOMMENDED)
   - Pros: Faster to usable state, easier to benchmark
   - Cons: May require refactoring

2. **Performance-first architecture**
   - Pros: Solid foundation
   - Cons: Premature optimization risk

---

## 3. Phased Implementation Plan

### Phase 1: Foundation & Modularity Architecture (8-10 weeks)
**Goal:** Establish the microkernel architecture, comprehensive test infrastructure, and ensure core functionality is robust, well-tested, and documented.

**CRITICAL: This phase implements the extreme modularity foundation (Section 0) and testing strategy (Section 0.9).**

#### Tasks

| Task | Dependencies | Effort | Deliverable |
|------|--------------|--------|-------------|
| 1.1 Audit existing code quality | None | 1 week | Code review report, issue list |
| 1.2 **Implement microkernel** | 1.1 | 1.5 weeks | kernel/init.lua, loader.lua |
| 1.3 **Implement DI container** | 1.2 | 1 week | kernel/container.lua |
| 1.4 **Implement event bus** | 1.2 | 0.5 weeks | kernel/events.lua |
| 1.5 **Define all interfaces** | 1.1 | 1 week | interfaces/*.lua |
| 1.6 **Build test infrastructure** | 1.3, 1.5 | 1 week | Mock factory, test container, fixtures |
| 1.7 **Write contract tests for all interfaces** | 1.5, 1.6 | 1 week | Contract test suites |
| 1.8 Refactor existing modules to interfaces | 1.3, 1.4, 1.5 | 1.5 weeks | Refactored modules |
| 1.9 Expand unit test coverage to 85%+ | 1.6, 1.8 | 1 week | Unit test suite |
| 1.10 Complete API documentation | 1.8 | 1 week | API reference docs |
| 1.11 Establish CI/CD pipeline | 1.6 | 0.5 weeks | GitHub Actions workflow |

#### Modularity Deliverables (Section 0 Implementation)
- **Microkernel** with module loader
- **Dependency injection container** with lifecycle management
- **Event bus** for decoupled communication
- **Interface definitions** for all swappable components:
  - IFormat, IState, IEngine, ISerializer, IConditionEvaluator, IPlugin
- **Registry pattern** for format/service discovery
- Existing modules refactored to implement interfaces

#### Testing Deliverables (Section 0.9 Implementation)
- **Mock factory** that generates mocks from interface definitions
- **Test container** for isolated DI in tests
- **Contract test suites** for every interface (IFormat, IState, IEngine, etc.)
- **Fixture structure** with stories, formats, and edge cases
- **CI/CD pipeline** with multi-Lua-version testing
- **Coverage enforcement** at 85%+ for core modules

#### Quality Deliverables
- Complete test suite with 85%+ coverage (raised from 80%)
- Comprehensive API documentation
- CI/CD pipeline for automated testing
- Issue tracker populated with known bugs

#### Success Criteria
- All tests pass on Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT
- Documentation covers all public APIs
- **Any module can be swapped by registering a different implementation**
- **Modules communicate only via events or interface contracts**
- **Each module passes the modularity validation checklist (Section 0.6)**

---

### Phase 2: Ink Integration (6-8 weeks)
**Goal:** Full Ink format compatibility.

#### Tasks

| Task | Dependencies | Effort | Deliverable |
|------|--------------|--------|-------------|
| 2.1 Fork/vendor tinta library | Phase 1 | 2 days | Vendored tinta code |
| 2.2 Adapt tinta to Whisker patterns | 2.1 | 2 weeks | Integrated Ink runtime |
| 2.3 Create Ink-to-Whisker converter | 2.2 | 2 weeks | Conversion utility |
| 2.4 Create Whisker-to-Ink exporter | 2.2 | 2 weeks | Export utility |
| 2.5 Document Ink integration | 2.3, 2.4 | 1 week | Integration guide |
| 2.6 Test with real Ink projects | 2.3, 2.4 | 1 week | Compatibility report |

#### Deliverables
- Ink runtime integrated into whisker-core
- Bi-directional conversion between Ink and Whisker formats
- Compatibility documentation
- Test suite for Ink features

#### Success Criteria
- Can run Ink stories (compiled JSON) natively
- Can convert between formats without data loss
- Passes Ink compliance tests

---

### Phase 3: Whisker Script Language (8-10 weeks)
**Goal:** Create an intuitive authoring language for content creators.

#### Tasks

| Task | Dependencies | Effort | Deliverable |
|------|--------------|--------|-------------|
| 3.1 Language specification draft | Phase 1 | 2 weeks | Language spec document |
| 3.2 Lexer implementation | 3.1 | 2 weeks | Tokenizer module |
| 3.3 Parser implementation | 3.2 | 2 weeks | AST parser module |
| 3.4 Code generator (to Lua) | 3.3 | 2 weeks | Compiler module |
| 3.5 Error message system | 3.3, 3.4 | 1 week | User-friendly errors |
| 3.6 Language tutorial | 3.4 | 1 week | Tutorial documentation |

#### Language Design Principles
```
:: Start                          # Passage declaration
You wake up in a dark cave.       # Narrative text

+ [Look around]                   # Choice (Ink-style)
  -> LookAround
+ [Stay still]
  -> StayStill

:: LookAround
{ $has_torch:                     # Conditional (clean syntax)
  The torch illuminates ancient paintings.
- else:
  It's too dark to see anything.
}

~ gold += 5                       # Variable modification

-> Continue                       # Navigation
```

#### Deliverables
- Whisker Script specification
- Full parser and compiler
- Comprehensive error messages
- Tutorial for beginners
- Editor support (VSCode extension skeleton)

#### Success Criteria
- Non-programmers can write stories in under 1 hour of learning
- Error messages guide users to fixes
- All Whisker Script features compile to valid Lua

---

### Phase 4: Enhanced Twine Support (4-6 weeks)
**Goal:** Complete Twine format compatibility.

#### Tasks

| Task | Dependencies | Effort | Deliverable |
|------|--------------|--------|-------------|
| 4.1 Complete Harlowe macro support | Phase 1 | 2 weeks | Harlowe interpreter |
| 4.2 Complete SugarCube macro support | Phase 1 | 2 weeks | SugarCube interpreter |
| 4.3 Chapbook/Snowman improvements | Phase 1 | 1 week | Format handlers |
| 4.4 Twine export capability | 4.1-4.3 | 1 week | Export module |
| 4.5 Format conversion tests | 4.4 | 1 week | Test suite |

#### Deliverables
- Full macro interpretation for major Twine formats
- Export to Twine HTML
- Conversion quality tests
- Compatibility documentation

#### Success Criteria
- Can import and run complex Twine stories
- Round-trip conversion preserves functionality
- Documented format limitations

---

### Phase 5: Plugin System (3-5 weeks)
**Goal:** Enable extensibility without core modifications.

**Note:** This phase is shorter than originally estimated because the microkernel, DI container, and event bus from Phase 1 provide most of the infrastructure. Phase 5 focuses on the plugin-specific API, lifecycle management, sandboxing, and documentation.

#### Tasks

| Task | Dependencies | Effort | Deliverable |
|------|--------------|--------|-------------|
| 5.1 Design plugin API | Phase 1 | 1 week | API specification |
| 5.2 Implement plugin registry | 5.1 | 1 week | Registry module |
| 5.3 Implement hook system | 5.1 | 2 weeks | Event hooks |
| 5.4 Create example plugins | 5.2, 5.3 | 1 week | Sample plugins |
| 5.5 Plugin developer documentation | 5.4 | 1 week | Developer guide |

#### Plugin Architecture
```lua
-- Plugin structure
return {
  name = "inventory",
  version = "1.0.0",
  
  hooks = {
    on_story_start = function(ctx) ... end,
    on_passage_enter = function(ctx, passage) ... end,
    on_choice_made = function(ctx, choice) ... end,
  },
  
  api = {
    add_item = function(item) ... end,
    remove_item = function(item) ... end,
    has_item = function(item) ... end,
  }
}
```

#### Deliverables
- Plugin registration and lifecycle system
- Comprehensive hook points
- Example plugins (inventory, achievements, analytics)
- Plugin developer documentation

#### Success Criteria
- Plugins can extend without core modification
- Hooks cover all major story events
- Example plugins demonstrate capabilities

---

### Phase 6: Export and Publishing (4-6 weeks)
**Goal:** Multi-format export capabilities.

#### Tasks

| Task | Dependencies | Effort | Deliverable |
|------|--------------|--------|-------------|
| 6.1 Standalone HTML export | Phase 1 | 2 weeks | HTML exporter |
| 6.2 Ink JSON export | Phase 2 | 1 week | Ink exporter |
| 6.3 Plain text/transcript export | Phase 1 | 1 week | Text exporter |
| 6.4 Export CLI integration | 6.1-6.3 | 1 week | CLI commands |
| 6.5 Export documentation | 6.4 | 1 week | Export guide |

#### Deliverables
- Multiple export formats
- CLI commands for export
- Customizable export templates
- Export quality documentation

#### Success Criteria
- Exported formats work standalone
- Export preserves story functionality
- Clear documentation for each format

---

### Phase 7: Performance and Polish (4-6 weeks)
**Goal:** Optimize for large narratives and improve overall quality.

#### Tasks

| Task | Dependencies | Effort | Deliverable |
|------|--------------|--------|-------------|
| 7.1 Performance profiling | Phase 1-6 | 1 week | Performance report |
| 7.2 Optimize hot paths | 7.1 | 2 weeks | Optimized modules |
| 7.3 Memory optimization | 7.1 | 1 week | Memory improvements |
| 7.4 Large story testing | 7.2, 7.3 | 1 week | Scale test results |
| 7.5 Final documentation review | All | 1 week | Complete docs |

#### Performance Targets
- Load time: <100ms for 1000-passage stories
- Memory: <10MB for typical stories
- Choice evaluation: <1ms per choice

#### Deliverables
- Performance benchmarks and results
- Optimized critical paths
- Large-scale story support
- Complete, polished documentation

#### Success Criteria
- Meets performance targets
- Documentation is comprehensive
- Ready for production use

---

## 4. Risk Assessment

### High-Impact Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Tinta integration proves incompatible | Low | High | Early prototype in Phase 2; fallback to native implementation |
| Whisker Script design fails usability testing | Medium | High | User testing in Phase 3; iterative design |
| Twine macro complexity exceeds estimates | Medium | Medium | Scope to most common macros first; document limitations |
| Performance targets unachievable | Low | Medium | Profile early; design for performance from start |
| **Test infrastructure delays implementation** | Medium | High | Build test infrastructure first in Phase 1; parallelize test writing |
| **Inadequate test coverage hides bugs** | Medium | High | Enforce coverage in CI; contract tests catch interface violations |

### Medium-Impact Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Lua version compatibility issues | Low | Medium | Test on all versions in CI/CD |
| Plugin system too complex | Medium | Medium | Start minimal; expand based on feedback |
| Documentation falls behind | High | Medium | Documentation as part of each task definition |
| **Modularity over-engineering** | Medium | Medium | Regular usability checks; pragmatic interfaces; don't split where not needed |

### Low-Impact Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Dependency vulnerabilities | Low | Low | Regular audits; minimal dependencies |
| Community adoption slow | Medium | Low | Focus on quality over speed |

---

## 5. Resource Estimates

### Phase Summary

| Phase | Duration | Primary Skills Needed |
|-------|----------|----------------------|
| Phase 1: Foundation & Modularity | 8-10 weeks | Lua, Architecture, DI patterns, Testing |
| Phase 2: Ink Integration | 6-8 weeks | Lua, Parser integration |
| Phase 3: Whisker Script | 8-10 weeks | Language design, Compiler construction |
| Phase 4: Twine Support | 4-6 weeks | HTML/JS parsing, Lua |
| Phase 5: Plugin System | 3-5 weeks | API design, Lua |
| Phase 6: Export | 4-6 weeks | Template systems, Lua |
| Phase 7: Polish | 4-6 weeks | Performance optimization, Test validation |

**Total Estimated Timeline:** 37-51 weeks (9-13 months)

### Parallel Execution Opportunities
- Phase 4 can begin alongside Phase 3 (different skill sets)
- Phase 5 leverages infrastructure from Phase 1 (may be shorter)
- Documentation tasks span all phases
- Test writing can be parallelized with implementation

**With parallelization:** 26-36 weeks (6-9 months)

---

## 6. Implementation Prompts

The following sections provide detailed prompts for implementing each phase. These are designed to be used with an AI assistant or as task specifications for developers.

### Phase 1 Implementation Prompt

```
## Context
You are implementing Phase 1 of the whisker-core roadmap: Foundation & Modularity Architecture.
Repository: https://github.com/writewhisker/whisker-core

## Objectives
1. Audit existing code for quality issues
2. **Implement microkernel architecture (CRITICAL)**
3. **Implement dependency injection container**
4. **Implement event bus for decoupled communication**
5. **Define interfaces for all swappable components**
6. **Build comprehensive test infrastructure**
7. **Write contract tests for all interfaces**
8. Refactor existing modules to implement interfaces
9. Expand test coverage to 85%+
10. Complete API documentation
11. Establish CI/CD pipeline

## Modularity Architecture Requirements

### Microkernel (lib/whisker/kernel/)
- init.lua: Bootstrap, loads only essential components
- loader.lua: Dynamic module loading with capability detection
- container.lua: Dependency injection with lifecycle management
- events.lua: Pub/sub event bus
- registry.lua: Generic registry pattern

### Interfaces (lib/whisker/interfaces/)
Define these interfaces FIRST, then refactor modules to implement them:

```lua
-- IFormat: Story format handler
{
  can_import = function(self, source) end,
  import = function(self, source) end,
  can_export = function(self, story) end,
  export = function(self, story) end,
}

-- IState: State management
{
  get = function(self, key) end,
  set = function(self, key, value) end,
  has = function(self, key) end,
  snapshot = function(self) end,
  restore = function(self, snapshot) end,
}

-- IEngine: Runtime engine
{
  load = function(self, story) end,
  start = function(self) end,
  get_current_passage = function(self) end,
  get_available_choices = function(self) end,
  make_choice = function(self, index) end,
}

-- IPlugin: Plugin contract
{
  name, version, dependencies,
  init = function(self, container) end,
  destroy = function(self) end,
}
```

### Container API
```lua
-- Registration
container:register(name, implementation, options)
-- options: { singleton, implements, depends, capability }

-- Resolution
container:resolve(name)  -- Returns instance with deps injected
container:resolve_all(interface)  -- All implementations of interface

-- Lifecycle
container:init()  -- Initialize all singletons
container:destroy()  -- Cleanup
```

### Event Bus API
```lua
events:on(event, handler)
events:off(event, handler)
events:emit(event, data)
events:once(event, handler)
```

## Testing Infrastructure Requirements

### Test Directory Structure
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
│   ├── engine_contract.lua
│   └── plugin_contract.lua
├── integration/       # Cross-module tests
├── e2e/              # End-to-end tests
├── regression/       # Bug regression tests
├── fixtures/         # Test data
│   ├── stories/
│   ├── formats/
│   └── edge_cases/
└── support/          # Test utilities
    ├── mock_factory.lua
    ├── test_container.lua
    └── helpers.lua
```

### Mock Factory (tests/support/mock_factory.lua)
Must auto-generate mocks from interface definitions:
- Track all method calls with arguments
- Allow stubbing return values
- Support verification (called N times, called with args)

### Test Container (tests/support/test_container.lua)
Isolated DI container for tests:
- Fresh container per test
- Easy mock registration
- Access to mocks for verification

### Contract Tests
For EACH interface, create a reusable contract test suite:
```lua
-- tests/contracts/format_contract.lua
return function(FormatImpl, fixtures)
  describe("IFormat contract: " .. FormatImpl.name, function()
    -- Tests that ANY IFormat implementation must pass
    it("can_import returns boolean", ...)
    it("import returns Story", ...)
    it("round-trip preserves data", ...)
  end)
end
```

### Coverage Requirements
| Component | Target |
|-----------|--------|
| kernel/* | 95% |
| core/* | 90% |
| services/* | 85% |
| formats/* | 80% |

### CI/CD Pipeline
GitHub Actions workflow must:
- Run tests on Lua 5.1, 5.2, 5.3, 5.4, LuaJIT
- Run unit tests first (fast feedback)
- Run contract tests second
- Run integration tests third
- Enforce coverage minimums
- Run luacheck linting

## Constraints
- Microkernel must be <200 lines total
- No module may directly require another module (use container)
- All cross-module communication via events or interfaces
- Every interface must have a contract test suite
- All tests must be deterministic (no flaky tests)
- Maintain backward compatibility where possible
- Keep individual files under 500 lines

## Modularity Validation
Every module must pass this checklist:
- [ ] No hardcoded dependencies
- [ ] Implements a defined interface
- [ ] Testable in isolation with mocks
- [ ] Uses events for cross-module communication
- [ ] Single responsibility
- [ ] Documented contract
- [ ] Has corresponding contract test (if interface impl)
- [ ] Unit tests at required coverage level

## Deliverables
1. Code review report (ISSUES.md)
2. Microkernel implementation
3. DI container implementation
4. Event bus implementation
5. Interface definitions
6. **Mock factory and test container utilities**
7. **Contract test suites for all interfaces**
8. Refactored existing modules
9. Unit test suite at 85%+ coverage
10. API reference documentation
11. GitHub Actions CI/CD workflow

## Success Criteria
- All tests pass on Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT
- Any module can be swapped by registering different implementation
- Modules communicate only via events or interface contracts
- **Every interface has a passing contract test suite**
- **Mock factory can generate mocks for any interface**
- **Coverage meets or exceeds targets per component**
- Each module passes modularity validation checklist
```

### Phase 2 Implementation Prompt

```
## Context
You are implementing Phase 2 of the whisker-core roadmap: Ink Integration.
Prerequisite: Phase 1 complete
Reference: https://github.com/smwhr/tinta (MIT license)

## Objectives
1. Integrate tinta Ink runtime into whisker-core
2. Create Ink-to-Whisker story converter
3. Create Whisker-to-Ink exporter
4. Document Ink integration
5. **Ensure all Ink components pass contract tests**

## Technical Approach
1. Vendor tinta source into lib/whisker/format/ink/
2. Adapt tinta's Story class to implement Whisker's runtime interface
3. Create converter that maps Ink JSON to Whisker story format
4. Create exporter that generates Ink JSON from Whisker stories

## Testing Requirements

### Contract Tests
The Ink format handler must pass the IFormat contract tests:
```lua
-- tests/contracts/ink_format_spec.lua
local contract = require("tests.contracts.format_contract")
local InkFormat = require("whisker.formats.ink")

contract(InkFormat, {
  valid_source = '{"inkVersion":21,"root":[...]}',
  invalid_source = 'not ink json',
  expected_passage_count = 3
})
```

### Unit Tests (target: 80% coverage)
```
tests/unit/formats/ink/
├── runtime_spec.lua      # Ink runtime tests
├── converter_spec.lua    # Ink-to-Whisker conversion
├── exporter_spec.lua     # Whisker-to-Ink export
└── compatibility_spec.lua # Ink feature support
```

### Integration Tests
```lua
-- tests/integration/ink_playthrough_spec.lua
describe("Ink story playthrough", function()
  it("plays The Intercept sample story", function()
    local story = whisker.load("tests/fixtures/formats/ink/intercept.ink.json")
    local engine = whisker.engine.new(story)
    engine:start()
    -- Verify key story beats work
  end)
end)
```

### Ink-Specific Test Fixtures
```
tests/fixtures/formats/ink/
├── simple.ink.json           # Basic story
├── variables.ink.json        # Variable usage
├── conditionals.ink.json     # Conditional logic
├── functions.ink.json        # External functions
├── flows.ink.json            # Multiple flows
├── intercept.ink.json        # Full sample story
└── edge_cases/
    ├── deep_nesting.ink.json
    ├── unicode.ink.json
    └── large_story.ink.json
```

### Round-Trip Tests
```lua
describe("Ink round-trip", function()
  it("preserves story data through conversion cycle", function()
    local original = load_ink_json("tests/fixtures/formats/ink/variables.ink.json")
    local whisker_story = InkConverter.to_whisker(original)
    local exported = InkExporter.from_whisker(whisker_story)
    local reimported = InkConverter.to_whisker(exported)
    
    -- Compare essential story elements
    assert.same(whisker_story.passages, reimported.passages)
    assert.same(whisker_story.variables, reimported.variables)
  end)
end)
```

## Constraints
- Maintain tinta MIT license attribution
- Support all tinta features (flows, variables, external functions)
- Handle missing features gracefully with clear warnings
- **All new code must have unit tests**
- **Must pass IFormat contract tests**
- **Integration tests with real Ink stories**

## Deliverables
1. Integrated Ink runtime module
2. InkConverter class
3. InkExporter class
4. **Contract test compliance**
5. **Unit test suite (80%+ coverage)**
6. **Integration tests with sample stories**
7. Integration documentation
8. Ink compatibility report (supported/unsupported features)
```

### Phase 3 Implementation Prompt

```
## Context
You are implementing Phase 3 of the whisker-core roadmap: Whisker Script Language.
Prerequisite: Phase 1 complete

## Objectives
1. Design and document Whisker Script language
2. Implement lexer for tokenization
3. Implement parser for AST generation
4. Implement code generator targeting Lua
5. Create user-friendly error system
6. Write tutorial documentation
7. **Comprehensive test coverage for compiler pipeline**

## Language Requirements
- Passage declarations with :: syntax
- Choices with + syntax (Ink-inspired)
- Conditionals with { } syntax
- Variables with $ prefix
- Navigation with -> syntax
- Comments with # syntax
- Support for embedded Lua with ~ prefix

## Example Syntax
:: PassageName
Narrative text here.

{ $condition:
  Conditional text.
- else:
  Alternative text.
}

+ [Choice text] -> TargetPassage
+ { $other_condition } [Conditional choice] -> OtherTarget

~ $variable = value

## Testing Requirements

### Lexer Tests (target: 95% coverage)
Test tokenization of every language construct:
```lua
-- tests/unit/script/lexer_spec.lua
describe("Lexer", function()
  describe("passage declarations", function()
    it("tokenizes basic passage", function()
      local tokens = lexer.tokenize(":: Start")
      assert.equals("PASSAGE_DECL", tokens[1].type)
      assert.equals("Start", tokens[2].value)
    end)
    
    it("handles passage with tags", function()
      local tokens = lexer.tokenize(":: Start [tag1, tag2]")
      -- verify token stream
    end)
  end)
  
  describe("error cases", function()
    it("reports line and column for invalid token", function()
      local ok, err = pcall(function()
        lexer.tokenize(":: Start\n@@@ invalid")
      end)
      assert.is_false(ok)
      assert.matches("line 2, column 1", err)
    end)
  end)
end)
```

### Parser Tests (target: 90% coverage)
Test AST generation for all syntax constructs:
```lua
-- tests/unit/script/parser_spec.lua
describe("Parser", function()
  describe("conditionals", function()
    it("parses if-else blocks", function()
      local ast = parser.parse([[
        { $health > 50:
          You feel strong.
        - else:
          You feel weak.
        }
      ]])
      assert.equals("conditional", ast.nodes[1].type)
      assert.equals(2, #ast.nodes[1].branches)
    end)
  end)
  
  describe("error recovery", function()
    it("continues parsing after syntax error", function()
      local ast, errors = parser.parse([[
        :: Start
        { unclosed conditional
        :: End
        Valid passage text.
      ]])
      assert.equals(1, #errors)
      assert.equals(2, #ast.passages)  -- Both passages parsed
    end)
  end)
end)
```

### Generator Tests (target: 90% coverage)
Test Lua code generation:
```lua
-- tests/unit/script/generator_spec.lua
describe("Generator", function()
  it("generates valid Lua for simple story", function()
    local ast = parser.parse(":: Start\nHello world.")
    local lua_code = generator.generate(ast)
    
    -- Verify it's valid Lua
    local fn, err = load(lua_code)
    assert.is_nil(err)
    
    -- Verify it creates correct story structure
    local story = fn()
    assert.equals("Start", story.start_passage)
  end)
end)
```

### End-to-End Compiler Tests
```lua
-- tests/integration/script_compiler_spec.lua
describe("Whisker Script compilation", function()
  it("compiles and runs example story", function()
    local source = read_file("tests/fixtures/scripts/adventure.whisker")
    local story = whisker.compile(source)
    local engine = whisker.engine.new(story)
    
    engine:start()
    assert.is_not_nil(engine:get_current_passage())
    assert.is_true(#engine:get_available_choices() > 0)
  end)
end)
```

### Error Message Tests
```lua
-- tests/unit/script/errors_spec.lua
describe("Error messages", function()
  it("suggests fix for common mistakes", function()
    local _, errors = parser.parse(":: Start\n-> nonexistent")
    assert.matches("passage 'nonexistent' not found", errors[1].message)
    assert.matches("Did you mean", errors[1].suggestion)
  end)
  
  it("shows context around error", function()
    local _, errors = parser.parse(":: Start\n{ $x\nbroken")
    assert.matches("{ $x", errors[1].context)
    assert.matches("^", errors[1].pointer)  -- Points to error location
  end)
end)
```

### Property-Based Tests for Compiler
```lua
-- tests/property/script_compiler_spec.lua
describe("Compiler properties", function()
  lqc.property("valid syntax always compiles", function()
    local source = generate_valid_whisker_script()
    local story, errors = whisker.compile(source)
    return #errors == 0 and story ~= nil
  end)
  
  lqc.property("compile-decompile roundtrip", function()
    local source = generate_valid_whisker_script()
    local story = whisker.compile(source)
    local decompiled = whisker.decompile(story)
    local recompiled = whisker.compile(decompiled)
    return stories_equivalent(story, recompiled)
  end)
end)
```

### Test Fixtures
```
tests/fixtures/scripts/
├── valid/
│   ├── minimal.whisker         # Simplest valid story
│   ├── choices.whisker         # Choice syntax
│   ├── conditionals.whisker    # Conditional blocks
│   ├── variables.whisker       # Variable operations
│   ├── complex.whisker         # All features combined
│   └── unicode.whisker         # Unicode content
├── invalid/
│   ├── syntax_errors/
│   │   ├── unclosed_conditional.whisker
│   │   ├── invalid_choice.whisker
│   │   └── ...
│   └── semantic_errors/
│       ├── undefined_passage.whisker
│       ├── undefined_variable.whisker
│       └── ...
└── edge_cases/
    ├── empty.whisker
    ├── whitespace_only.whisker
    ├── deeply_nested.whisker
    └── large_story.whisker
```

## Constraints
- Language must be learnable in 30 minutes
- Error messages must suggest fixes
- Must compile to valid Whisker Lua code
- Must handle graceful degradation for unknown constructs
- **Lexer: 95% test coverage**
- **Parser: 90% test coverage**
- **Generator: 90% test coverage**
- **All error paths must be tested**

## Deliverables
1. Language specification document (WHISKER_SCRIPT.md)
2. Lexer module (lib/whisker/script/lexer.lua)
3. Parser module (lib/whisker/script/parser.lua)
4. Generator module (lib/whisker/script/generator.lua)
5. Error handling module (lib/whisker/script/errors.lua)
6. **Comprehensive test suite for each compiler phase**
7. **Property-based tests for compiler correctness**
8. Tutorial (docs/SCRIPT_TUTORIAL.md)
9. Test fixtures covering valid, invalid, and edge cases
```

### Phase 4 Implementation Prompt

```
## Context
You are implementing Phase 4 of the whisker-core roadmap: Enhanced Twine Support.
Prerequisite: Phase 1 complete

## Objectives
1. Complete Harlowe macro interpretation
2. Complete SugarCube macro interpretation
3. Improve Chapbook and Snowman support
4. Implement Twine export capability

## Harlowe Macros to Support
- Conditionals: (if:), (else-if:), (else:)
- Variables: (set:), (put:)
- Display: (print:), (display:)
- Links: (link:), (link-reveal:)
- Hooks: [named hooks]
- Common styling: (text-style:), (text-color:)

## SugarCube Macros to Support
- Conditionals: <<if>>, <<elseif>>, <<else>>
- Variables: <<set>>, <<unset>>
- Display: <<print>>, <<include>>
- Links: <<link>>, <<button>>
- Widgets: <<widget>>
- State: <<run>>, <<script>>

## Constraints
- Gracefully handle unsupported macros with warnings
- Document all supported and unsupported features
- Maintain format detection accuracy

## Deliverables
1. Enhanced Harlowe interpreter
2. Enhanced SugarCube interpreter
3. Improved Chapbook/Snowman handlers
4. Twine HTML export module
5. Format compatibility documentation
6. Test suite with real Twine stories
```

### Phase 5 Implementation Prompt

```
## Context
You are implementing Phase 5 of the whisker-core roadmap: Plugin System.
Prerequisite: Phase 1 complete

## Objectives
1. Design plugin API specification
2. Implement plugin registry
3. Implement event hook system
4. Create example plugins
5. Document plugin development

## Plugin API Design
```lua
-- Plugin registration
whisker.plugins.register({
  name = "plugin-name",
  version = "1.0.0",
  requires = { "whisker-core >= 0.1.0" },
  
  -- Lifecycle hooks
  on_load = function(api) end,
  on_unload = function() end,
  
  -- Story hooks
  hooks = {
    story_start = function(ctx) end,
    story_end = function(ctx) end,
    passage_enter = function(ctx, passage) end,
    passage_exit = function(ctx, passage) end,
    choice_available = function(ctx, choice) end,
    choice_made = function(ctx, choice) end,
    variable_change = function(ctx, name, old, new) end,
    save = function(ctx) return data end,
    load = function(ctx, data) end,
  },
  
  -- Custom API
  api = { }
})
```

## Hook Points Required
- Story lifecycle: start, end, save, load
- Passage: enter, exit, render
- Choice: available, made, filtered
- Variable: read, write, change
- Custom: user-defined events

## Constraints
- Plugins must not break core functionality
- Hooks must be performant (async where needed)
- Clear error handling for plugin failures

## Deliverables
1. Plugin API specification
2. Registry module (lib/whisker/plugins/registry.lua)
3. Hook system (lib/whisker/plugins/hooks.lua)
4. Example: Inventory plugin
5. Example: Achievement plugin
6. Example: Analytics plugin
7. Plugin developer guide
```

### Phase 6 Implementation Prompt

```
## Context
You are implementing Phase 6 of the whisker-core roadmap: Export and Publishing.
Prerequisites: Phases 1, 2 complete

## Objectives
1. Implement standalone HTML export
2. Implement Ink JSON export
3. Implement plain text transcript export
4. Integrate export commands into CLI

## HTML Export Requirements
- Single-file, self-contained HTML
- Embedded story data as JSON
- Minimal, responsive player UI
- Customizable templates
- Works offline

## Export Formats
1. **standalone.html** - Single file, plays in browser
2. **ink.json** - Ink-compatible JSON
3. **transcript.txt** - Plain text story dump
4. **whisker.json** - Native Whisker format
5. **twine.html** - Twine-compatible HTML

## CLI Commands
```bash
whisker export --format html story.whisker -o story.html
whisker export --format ink story.whisker -o story.json
whisker export --format text story.whisker -o story.txt
whisker export --template custom.html story.whisker -o story.html
```

## Constraints
- Exported HTML must work in modern browsers
- Preserve all story functionality
- Support custom styling/theming

## Deliverables
1. HTML exporter with templates
2. Ink JSON exporter
3. Text transcript exporter
4. Export CLI commands
5. Template customization guide
6. Export documentation
```

### Phase 7 Implementation Prompt

```
## Context
You are implementing Phase 7 of the whisker-core roadmap: Performance and Polish.
Prerequisites: Phases 1-6 complete

## Objectives
1. Profile and optimize hot paths
2. Optimize memory usage
3. Test with large stories
4. **Validate complete test coverage across all modules**
5. Complete documentation review

## Performance Targets
- Story load: <100ms for 1000 passages
- Passage render: <10ms
- Choice evaluation: <1ms per choice
- Memory: <10MB for typical stories

## Profiling Approach
1. Identify hot paths with built-in profiler
2. Measure baseline performance
3. Optimize critical paths
4. Verify improvements

## Optimization Areas
- Passage lookup (hash tables)
- Conditional evaluation (lazy evaluation)
- Template rendering (caching)
- Memory allocation (object pooling)

## Large Story Testing
- Create 1000+ passage test stories
- Test deep branching (100+ levels)
- Test wide choices (50+ per passage)
- Test variable-heavy stories (1000+ variables)

## Final Test Validation

### Coverage Audit
Verify all components meet coverage targets:
| Component | Target | Status |
|-----------|--------|--------|
| kernel/* | 95% | Verify |
| core/* | 90% | Verify |
| services/* | 85% | Verify |
| formats/* | 80% | Verify |
| script/* | 90% | Verify |
| engines/* | 85% | Verify |

### Contract Test Audit
Verify every interface has passing contract tests:
- [ ] IFormat (all implementations)
- [ ] IState (all implementations)
- [ ] IEngine (all implementations)
- [ ] ISerializer (all implementations)
- [ ] IConditionEvaluator (all implementations)
- [ ] IPlugin (all implementations)

### Integration Test Audit
- [ ] Full story playthrough tests
- [ ] Format conversion round-trips
- [ ] Save/load cycle tests
- [ ] Plugin lifecycle tests

### Performance Regression Tests
Add performance assertions to CI:
```lua
-- tests/performance/benchmarks_spec.lua
describe("Performance benchmarks", function()
  it("loads 1000-passage story under 100ms", function()
    local start = os.clock()
    local story = whisker.load("tests/fixtures/stories/large_1000.json")
    local elapsed = (os.clock() - start) * 1000
    assert.is_true(elapsed < 100, "Load took " .. elapsed .. "ms")
  end)
  
  it("evaluates choices under 1ms each", function()
    local story = whisker.load("tests/fixtures/stories/choice_heavy.json")
    local engine = whisker.engine.new(story)
    engine:start()
    
    local start = os.clock()
    local choices = engine:get_available_choices()
    local elapsed = (os.clock() - start) * 1000 / #choices
    assert.is_true(elapsed < 1, "Choice eval took " .. elapsed .. "ms each")
  end)
end)
```

### Mutation Testing (Optional)
Run mutation testing to validate test quality:
```bash
# If tooling available
lua-mutant run --config mutant.lua
# Verify mutation score >80%
```

## Constraints
- Maintain code readability
- Don't sacrifice correctness for speed
- Document optimization decisions
- **All coverage targets must be met before release**
- **All contract tests must pass**
- **Performance benchmarks added to CI**

## Deliverables
1. Performance benchmark suite
2. Optimized core modules
3. Large story test suite
4. **Coverage audit report**
5. **Contract test compliance report**
6. **Performance regression tests in CI**
7. Performance documentation
8. Final documentation review
9. Release candidate
```

---

## 7. Appendices

### Appendix A: Existing Related Projects

| Project | Description | Relevance |
|---------|-------------|-----------|
| [tinta](https://github.com/smwhr/tinta) | Lua port of Ink | Direct integration candidate |
| [inkjs](https://github.com/y-lohse/inkjs) | JavaScript Ink runtime | Reference implementation |
| [Twine](https://twinery.org/) | Visual story editor | Compatibility target |
| [Ink](https://www.inklestudios.com/ink/) | Ink language | Compatibility target |
| [Narrator](https://github.com/astrochili/narrator) | Another Lua Ink port | Alternative to tinta |

### Appendix B: File Structure Target

```
whisker-core/
├── lib/whisker/
│   ├── core/
│   │   ├── story.lua
│   │   ├── passage.lua
│   │   ├── choice.lua
│   │   ├── variable.lua
│   │   └── init.lua
│   ├── runtime/
│   │   ├── engine.lua
│   │   ├── state.lua
│   │   ├── history.lua
│   │   └── init.lua
│   ├── format/
│   │   ├── twine/
│   │   │   ├── harlowe.lua
│   │   │   ├── sugarcube.lua
│   │   │   ├── chapbook.lua
│   │   │   ├── snowman.lua
│   │   │   └── init.lua
│   │   ├── ink/
│   │   │   ├── runtime/          # Vendored tinta
│   │   │   ├── converter.lua
│   │   │   ├── exporter.lua
│   │   │   └── init.lua
│   │   ├── json.lua
│   │   ├── compact.lua
│   │   └── init.lua
│   ├── script/
│   │   ├── lexer.lua
│   │   ├── parser.lua
│   │   ├── generator.lua
│   │   ├── errors.lua
│   │   └── init.lua
│   ├── export/
│   │   ├── html.lua
│   │   ├── text.lua
│   │   ├── templates/
│   │   └── init.lua
│   ├── plugins/
│   │   ├── registry.lua
│   │   ├── hooks.lua
│   │   └── init.lua
│   ├── tools/
│   │   ├── validator.lua
│   │   ├── debugger.lua
│   │   ├── profiler.lua
│   │   └── init.lua
│   ├── utils/
│   │   └── helpers.lua
│   └── init.lua
├── bin/
│   └── whisker
├── docs/
│   ├── API_REFERENCE.md
│   ├── ARCHITECTURE.md
│   ├── WHISKER_SCRIPT.md
│   ├── SCRIPT_TUTORIAL.md
│   ├── PLUGIN_GUIDE.md
│   └── EXPORT_GUIDE.md
├── tests/
├── examples/
├── stories/
├── rockspec/
└── README.md
```

### Appendix C: Whisker Script Quick Reference

```whisker
# Comments start with hash

:: PassageName
This is narrative text.
Multiple lines are combined.

:: PassageWithChoices
What do you do?

+ [Look around] -> LookAround
+ [Stay still] -> StayStill
+ { $has_key } [Unlock door] -> Unlocked

:: Variables
~ $name = "Player"
~ $health = 100
~ $has_sword = true
~ $inventory = []

Your name is {$name}.
Health: {$health}

:: Conditionals
{ $health > 50:
    You feel strong.
- $health > 25:
    You're wounded.
- else:
    You're barely alive.
}

:: Inline Conditionals
You have { $gold > 0: {$gold} gold | no gold }.

:: Functions
~ result = roll_dice(6)
You rolled {result}.

:: Includes
>> include "chapter2.whisker"

:: Metadata
@@ title: My Story
@@ author: Writer Name
@@ tags: adventure, fantasy
```

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-15 | Initial roadmap document |

---

*This roadmap is designed to be a living document. Update as implementation progresses and new requirements emerge.*