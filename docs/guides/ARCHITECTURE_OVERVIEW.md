# Whisker-Core Architecture Overview

## Microkernel Design

Whisker-core uses a **microkernel architecture** where the core runtime is minimal and all functionality is implemented as pluggable modules.

### Why Microkernel?

1. **Modularity**: Features can be included or excluded independently
2. **Testability**: Each module can be tested in complete isolation
3. **Flexibility**: Swap implementations without changing dependent code
4. **Maintainability**: Changes to one module don't affect others

## Core Components

### 1. Kernel Layer (`lib/whisker/kernel/`)

The kernel provides infrastructure services:

- **Container** (`container.lua`): Dependency injection and service lifecycle management
- **Events** (`events.lua`): Pub/sub event bus for decoupled communication
- **Loader** (`loader.lua`): Dynamic module loading
- **Registry** (`registry.lua`): Generic registry pattern implementation

### 2. Interface Layer (`lib/whisker/interfaces/`)

Defines contracts that modules implement:

- **IFormat**: Story format import/export
- **IState**: State management
- **IEngine**: Runtime execution
- **ISerializer**: Data serialization
- **IConditionEvaluator**: Conditional logic evaluation
- **IPlugin**: Plugin system

### 3. Core Layer (`lib/whisker/core/`)

Core data structures:

- **Story**: Container for passages, metadata, and story-level configuration
- **Passage**: Individual story nodes with content, choices, and scripts
- **Choice**: Player choices with optional conditions and actions

### 4. Service Layer (`lib/whisker/services/`)

Core services implementing business logic:

- **StateManager**: Key-value state storage implementing IState
- **HistoryService**: Navigation history tracking
- **VariableService**: Game variable management with state backing
- **PersistenceService**: Save/load functionality

### 5. Format Layer (`lib/whisker/formats/`)

Format handlers for different story formats:

- **JsonFormat**: Native JSON story format
- **TwineFormat**: Twine HTML import/export
- **InkFormat**: Ink JSON integration

## Communication Patterns

### Dependency Injection

Services declare dependencies that are injected by the container:

```lua
-- Services receive container in constructor
function MyService.new(container)
  local self = {
    state = container:resolve("state"),      -- Injected
    events = container:resolve("events"),    -- Injected
  }
  return setmetatable(self, { __index = MyService })
end
```

### Event-Driven Communication

Modules communicate through events, not direct calls:

```lua
-- Publisher (doesn't know who listens)
events:emit("passage:entered", { passage = passage })

-- Subscriber (doesn't know who published)
events:on("passage:entered", function(data)
  -- React to event
end)
```

### Interface Contracts

Modules depend on interfaces, not concrete implementations:

```lua
-- Wrong: Direct dependency
local JsonFormat = require("whisker.formats.json")

-- Right: Via container
local format = container:resolve("format.json")
```

## Data Flow

```
Story Definition (JSON/Twine/Code)
         ↓
    Format Handler (IFormat)
         ↓
    Story Object
         ↓
    Engine/Runtime
         ↓
    State Manager ←→ Event Bus
         ↓            ↑
    Variables    History
         ↓
    Persistence (saves via ISerializer)
```

## Service Registration

```lua
local Container = require("whisker.kernel.container")
local container = Container.new()

-- Register with options
container:register("state", StateManager, {
  singleton = true,       -- One instance
  implements = "IState",  -- Interface compliance
})

container:register("variables", VariableService, {
  singleton = true,
  depends = {"state", "events"},  -- Dependencies
})

-- Resolve services
local state = container:resolve("state")
local variables = container:resolve("variables")
```

## Adding New Features

1. **Define Interface** (if needed) in `lib/whisker/interfaces/`
2. **Implement Module** following interface contract
3. **Register with Container** in your bootstrap code
4. **Write Tests** (unit tests, contract tests)
5. **Document API** with LuaDoc comments

### Example: Adding a New Service

```lua
-- lib/whisker/services/my_service/init.lua
local MyService = {}
MyService.__index = MyService

function MyService.new(container)
  local self = {
    _events = container:resolve("events"),
    _state = container:resolve("state"),
  }
  return setmetatable(self, { __index = MyService })
end

function MyService:do_something()
  -- Implementation
  self._events:emit("my_service:action", { data = "value" })
end

return MyService
```

```lua
-- Registration
container:register("my_service", MyService, {
  singleton = true,
  depends = {"events", "state"},
})
```

### Example: Adding a New Format

```lua
-- lib/whisker/formats/my_format/init.lua
local IFormat = require("whisker.interfaces.format")
local MyFormat = {}
setmetatable(MyFormat, { __index = IFormat })

function MyFormat.new(container)
  -- ...
end

function MyFormat:can_import(source)
  -- Check if source is valid for this format
end

function MyFormat:import(source)
  -- Parse and return Story object
end

function MyFormat:can_export(story, options)
  -- Check if story can be exported
end

function MyFormat:export(story, options)
  -- Convert Story to format string
end

function MyFormat:get_name()
  return "my_format"
end

function MyFormat:get_extensions()
  return { ".myf" }
end

function MyFormat:get_mime_type()
  return "application/x-my-format"
end

return MyFormat
```

## Testing Strategy

- **Unit Tests**: Isolated module testing with mocks
- **Contract Tests**: Verify interface compliance
- **Integration Tests**: Test modules working together
- **E2E Tests**: Complete user scenarios

```lua
-- tests/unit/services/my_service_spec.lua
describe("MyService", function()
  local MyService
  local TestContainer = require("tests.helpers.test_container")

  before_each(function()
    MyService = require("whisker.services.my_service")
  end)

  it("creates instance with container", function()
    local container = TestContainer.create()
    local service = MyService.new(container)
    assert.is_not_nil(service)
  end)

  it("does something", function()
    local container = TestContainer.create()
    local service = MyService.new(container)
    -- Test behavior
  end)
end)
```

## Key Design Principles

1. **Loose Coupling**: Modules communicate via events and interfaces
2. **High Cohesion**: Each module has a single responsibility
3. **Dependency Inversion**: Depend on abstractions, not concretions
4. **Open/Closed**: Open for extension, closed for modification
5. **No Direct Requires**: Use DI container for all dependencies

## Directory Structure

```
lib/whisker/
├── kernel/           # Core infrastructure
│   ├── container.lua
│   ├── events.lua
│   ├── loader.lua
│   └── registry.lua
├── interfaces/       # Interface definitions
│   ├── format.lua
│   ├── state.lua
│   └── ...
├── core/             # Core data structures
│   ├── story.lua
│   ├── passage.lua
│   └── choice.lua
├── services/         # Service implementations
│   ├── state/
│   ├── history/
│   ├── variables/
│   └── persistence/
├── formats/          # Format handlers
│   ├── json/
│   ├── twine/
│   └── ink/
└── plugin/           # Plugin system
    ├── registry.lua
    └── sandbox.lua
```

## Further Reading

- [Getting Started Guide](GETTING_STARTED.md)
- [Modularity Guide](../MODULARITY_GUIDE.md) - DI patterns and tools
- [API Reference](../api/index.html)
- [Testing Guide](../testing/TESTING_GUIDE.md)
