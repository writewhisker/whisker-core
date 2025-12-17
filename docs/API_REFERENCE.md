# whisker API Reference

Complete API documentation for the whisker Interactive Fiction Engine.

## Table of Contents

- [Architecture](#architecture)
  - [Kernel](#kernel)
  - [Interfaces](#interfaces)
  - [Services](#services)
- [Core Classes](#core-classes)
  - [Story](#story)
  - [Passage](#passage)
  - [Choice](#choice)
  - [Variable](#variable)
  - [GameState](#gamestate)
  - [Engine](#engine)
- [UI and Platform](#ui-and-platform)
- [Tools](#tools)
- [Utilities](#utilities)

---

## Architecture

whisker-core uses a microkernel architecture with dependency injection for maximum modularity and testability.

### Kernel

The kernel provides the core infrastructure for module management, dependency injection, and event-based communication.

#### Container

The dependency injection container manages component registration, lifecycle, and dependency resolution.

```lua
local Container = require("whisker.kernel.container")

local container = Container.new(options)
```

**Options:**
- `interfaces` (table, optional) - Interfaces module for validation
- `capabilities` (table, optional) - Capabilities module

##### `container:register(name, factory, options)`

Registers a component with the container.

**Parameters:**
- `name` (string) - Component identifier
- `factory` (function|table) - Factory function or module table
- `options` (table) - Registration options:
  - `singleton` (boolean) - Reuse single instance (default: false)
  - `implements` (string) - Interface name to validate against
  - `depends` (table) - Array of dependency names
  - `capability` (string) - Register as capability when resolved
  - `init` (string) - Method name to call after creation
  - `destroy` (string) - Method name to call on container:destroy()

**Returns:** `Container` - Self for chaining

**Example:**
```lua
container:register("StateService", function(deps)
  return State.new()
end, {
  singleton = true,
  implements = "IState",
  capability = "services.state"
})
```

##### `container:resolve(name, args)`

Resolves a component by name.

**Parameters:**
- `name` (string) - Component identifier
- `args` (table, optional) - Arguments to pass to factory

**Returns:** `any` - The resolved component instance

**Example:**
```lua
local state = container:resolve("StateService")
```

##### `container:resolve_interface(interface_name)`

Resolves the first component implementing an interface.

**Parameters:**
- `interface_name` (string) - Interface name

**Returns:** `any` - The resolved component

##### `container:resolve_all(interface_name)`

Resolves all components implementing an interface.

**Parameters:**
- `interface_name` (string) - Interface name

**Returns:** `table` - Array of resolved components

##### `container:has(name)`

Checks if a component is registered.

**Parameters:**
- `name` (string) - Component identifier

**Returns:** `boolean` - True if registered

##### `container:destroy()`

Destroys the container and calls destroy methods on singletons.

##### `container:clear()`

Clears all registrations and instances.

#### Events

The event bus provides pub/sub messaging with namespaced events.

```lua
local Events = require("whisker.kernel.events")

local events = Events.new(options)
```

**Options:**
- `debug` (boolean) - Enable debug logging
- `debug_handler` (function) - Custom debug handler

##### `events:on(event, callback, options)`

Subscribes to an event.

**Parameters:**
- `event` (string) - Event name (e.g., "passage:entered")
- `callback` (function) - Handler function(data)
- `options` (table) - Optional:
  - `priority` (number) - Higher runs first (default: 0)
  - `once` (boolean) - Unsubscribe after first call

**Returns:** `function` - Unsubscribe function

**Example:**
```lua
local unsubscribe = events:on("passage:entered", function(data)
  print("Entered passage: " .. data.passage_id)
end)

-- Later:
unsubscribe()
```

##### `events:once(event, callback, options)`

Subscribes to an event for a single emission.

##### `events:off(event, callback)`

Unsubscribes from an event.

**Parameters:**
- `event` (string) - Event name
- `callback` (function, optional) - Specific handler to remove (removes all if nil)

##### `events:emit(event, data)`

Emits an event to all subscribers.

**Parameters:**
- `event` (string) - Event name
- `data` (any) - Data to pass to handlers

**Example:**
```lua
events:emit("passage:entered", {
  passage_id = "start",
  timestamp = os.time()
})
```

**Wildcard Support:**
- `"passage:*"` - Matches all events in the "passage" namespace
- `"*"` - Matches all events

##### `events:has_listeners(event)`

Checks if an event has any listeners.

##### `events:listener_count(event)`

Gets the count of listeners for an event.

##### `events:list_events()`

Lists all events with listeners.

##### `events:clear()`

Clears all listeners.

---

### Interfaces

Interfaces define contracts that components must implement. They enable interface-based type checking and dependency injection.

#### IState

State management interface for game variables.

```lua
local IState = require("whisker.interfaces.state")
```

**Required Methods:**
- `get(self, key) -> any` - Get a value by key
- `set(self, key, value)` - Set a value by key
- `has(self, key) -> boolean` - Check if a key exists
- `clear(self)` - Clear all state
- `snapshot(self) -> table` - Create a state snapshot
- `restore(self, snapshot)` - Restore from a snapshot

**Optional Methods:**
- `delete(self, key)` - Delete a key
- `keys(self)` - Get all keys
- `values(self)` - Get all values

#### IEngine

Runtime engine interface for story execution.

```lua
local IEngine = require("whisker.interfaces.engine")
```

**Required Methods:**
- `load(self, story)` - Load a story
- `start(self)` - Start the story
- `get_current_passage(self) -> Passage` - Get current passage
- `get_available_choices(self) -> table` - Get available choices
- `make_choice(self, index) -> Passage` - Make a choice
- `can_continue(self) -> boolean` - Check if story can continue

**Optional Methods:**
- `reset(self)` - Reset the engine
- `get_state(self)` - Get state service
- `set_state(self, state)` - Set state service

#### IConditionEvaluator

Condition evaluation interface.

```lua
local IConditionEvaluator = require("whisker.interfaces.condition")
```

**Required Methods:**
- `evaluate(self, condition, context) -> boolean` - Evaluate a condition

**Optional Methods:**
- `register_operator(self, name, fn)` - Register custom operator

#### IFormat

Story format handler interface.

```lua
local IFormat = require("whisker.interfaces.format")
```

**Required Methods:**
- `can_import(self, source) -> boolean` - Check if can import
- `import(self, source) -> Story` - Import to Story
- `can_export(self, story) -> boolean` - Check if can export
- `export(self, story) -> string` - Export story

#### ISerializer

Data serialization interface.

```lua
local ISerializer = require("whisker.interfaces.serializer")
```

**Required Methods:**
- `serialize(self, data) -> string` - Serialize to string
- `deserialize(self, str) -> table` - Deserialize to table

#### IPlugin

Plugin contract interface.

```lua
local IPlugin = require("whisker.interfaces.plugin")
```

**Required Members:**
- `name` (string) - Plugin identifier
- `version` (string) - Semantic version
- `init(self, container)` - Initialize plugin

**Optional Members:**
- `description` (string) - Plugin description
- `dependencies` (table) - Required plugins
- `destroy(self)` - Cleanup function

---

### Services

Services implement interfaces and provide reusable functionality.

#### State Service

Implements `IState` for game variable management.

```lua
local State = require("whisker.services.state")

local state = State.new(options)
```

**Options:**
- `initial` (table) - Initial state values

**Example:**
```lua
local state = State.new({
  initial = { health = 100, gold = 0 }
})

state:set("health", 80)
local health = state:get("health")  -- 80

local snapshot = state:snapshot()
state:set("health", 0)
state:restore(snapshot)
local restored = state:get("health")  -- 80
```

#### History Service

Tracks navigation history with undo support.

```lua
local History = require("whisker.services.history")

local history = History.new(options)
```

**Options:**
- `state` (IState) - State service for snapshots
- `max_entries` (number) - Maximum history entries (default: 100)

**Methods:**
- `push(passage_id, state_snapshot)` - Add entry
- `pop() -> entry` - Remove and return last entry
- `peek() -> entry` - Get last entry without removing
- `back() -> entry` - Go back one entry (pops current, returns previous)
- `can_go_back() -> boolean` - Check if back is possible
- `clear()` - Clear all history
- `get_all() -> table` - Get all entries
- `on_passage_entered(passage_id)` - Convenience method

#### Condition Evaluator

Implements `IConditionEvaluator` for condition evaluation.

```lua
local ConditionEvaluator = require("whisker.services.conditions")

local evaluator = ConditionEvaluator.new(options)
```

**Options:**
- `state` (IState) - State service for variable resolution

**String Conditions:**
```lua
evaluator:evaluate("health > 50", { health = 100 })  -- true
evaluator:evaluate("has_key and has_sword", { has_key = true, has_sword = false })  -- false
evaluator:evaluate("not is_dead", { is_dead = false })  -- true
evaluator:evaluate("name == 'Alice'", { name = "Alice" })  -- true
```

**Table Conditions:**
```lua
evaluator:evaluate({ var = "health", op = ">", value = 50 }, context)
evaluator:evaluate({ all = { cond1, cond2 } }, context)  -- AND
evaluator:evaluate({ any = { cond1, cond2 } }, context)  -- OR
evaluator:evaluate({ ["not"] = condition }, context)     -- NOT
```

**Supported Operators:**
- `==`, `!=`, `~=` (equality)
- `<`, `>`, `<=`, `>=` (comparison)
- `and`, `or`, `not` (logical)

**Custom Operators:**
```lua
evaluator:register_operator("contains", function(a, b)
  return type(a) == "string" and a:find(b, 1, true) ~= nil
end)
```

#### Default Engine

Implements `IEngine` for story execution.

```lua
local DefaultEngine = require("whisker.engines.default")

local engine = DefaultEngine.new(options)
```

**Options:**
- `state` (IState) - State service
- `condition_evaluator` (IConditionEvaluator) - Condition evaluator
- `code_executor` (function) - Code execution function
- `event_emitter` (Events) - Event bus

**Example:**
```lua
local engine = DefaultEngine.new({
  state = State.new(),
  condition_evaluator = ConditionEvaluator.new()
})

engine:load(story)
engine:start()

local passage = engine:get_current_passage()
local choices = engine:get_available_choices()
engine:make_choice(1)
```

---

## Core Classes

### Story

The main container for your interactive fiction.

#### Constructor

```lua
local Story = require("whisker.core.story")

local story = Story.new(metadata)
```

**Parameters:**
- `metadata` (table) - Story metadata
  - `title` (string) - Story title
  - `author` (string, optional) - Author name
  - `ifid` (string, optional) - Interactive Fiction ID
  - `version` (string, optional) - Version number
  - `description` (string, optional) - Story description

**Example:**
```lua
local story = Story.new({
    title = "The Dark Forest",
    author = "Jane Doe",
    ifid = "12345678-1234-1234-1234-123456789012",
    version = "1.0",
    description = "A mysterious adventure in an enchanted forest"
})
```

#### Methods

##### `story:add_passage(passage)`

Adds a passage to the story.

**Parameters:**
- `passage` (Passage) - The passage to add

**Returns:** `void`

**Example:**
```lua
local passage = Passage.new({id = "start", content = "..."})
story:add_passage(passage)
```

##### `story:get_passage(passage_id)`

Retrieves a passage by its ID.

**Parameters:**
- `passage_id` (string) - The passage ID

**Returns:** `Passage` or `nil`

**Example:**
```lua
local start = story:get_passage("start")
```

##### `story:get_all_passages()`

Gets all passages in the story.

**Returns:** `table` - Array of Passage objects

**Example:**
```lua
local passages = story:get_all_passages()
for _, passage in ipairs(passages) do
    print(passage.id)
end
```

##### `story:set_start_passage(passage_id)`

Sets the starting passage for the story.

**Parameters:**
- `passage_id` (string) - The ID of the start passage

**Returns:** `void`

**Example:**
```lua
story:set_start_passage("intro")
```

##### `story:get_start_passage()`

Gets the starting passage ID.

**Returns:** `string` - The start passage ID

##### `story:add_asset(asset)`

Adds an asset to the story.

**Parameters:**
- `asset` (table) - The asset object with id, name, path, mimeType, size, and optional metadata

**Returns:** `void`

**Example:**
```lua
story:add_asset({
    id = "hero_image",
    name = "Hero Portrait",
    path = "assets/images/hero.png",
    mimeType = "image/png",
    size = 45678,
    metadata = {
        width = 512,
        height = 512,
        artist = "Jane Doe"
    }
})
```

##### `story:get_asset(asset_id)`

Gets an asset by its ID.

**Parameters:**
- `asset_id` (string) - The asset ID

**Returns:** `table` or `nil` - The asset object

**Example:**
```lua
local asset = story:get_asset("hero_image")
if asset then
    print(asset.path)
end
```

##### `story:remove_asset(asset_id)`

Removes an asset from the story.

**Parameters:**
- `asset_id` (string) - The asset ID to remove

**Returns:** `void`

**Example:**
```lua
story:remove_asset("old_image")
```

##### `story:list_assets()`

Gets all assets in the story.

**Returns:** `table` - Array of asset objects

**Example:**
```lua
local assets = story:list_assets()
for _, asset in ipairs(assets) do
    print(asset.id, asset.name)
end
```

##### `story:has_asset(asset_id)`

Checks if an asset exists.

**Parameters:**
- `asset_id` (string) - The asset ID

**Returns:** `boolean` - True if asset exists

**Example:**
```lua
if story:has_asset("background_music") then
    print("Music asset is loaded")
end
```

##### `story:get_asset_references(asset_id)`

Finds all passages that reference an asset.

**Parameters:**
- `asset_id` (string) - The asset ID to search for

**Returns:** `table` - Array of reference objects with `type`, `passage_id`, and `passage_name`

**Example:**
```lua
local refs = story:get_asset_references("hero_image")
for _, ref in ipairs(refs) do
    print(string.format("%s in passage %s (%s)",
        ref.type, ref.passage_id, ref.passage_name))
end
```

##### `story:add_tag(tag)`

Adds a tag to the story (story-level categorization).

**Parameters:**
- `tag` (string) - Tag name to add

**Returns:** `void`

**Example:**
```lua
story:add_tag("fantasy")
story:add_tag("adventure")
story:add_tag("short")
```

##### `story:remove_tag(tag)`

Removes a tag from the story.

**Parameters:**
- `tag` (string) - Tag name to remove

**Returns:** `void`

**Example:**
```lua
story:remove_tag("outdated")
```

##### `story:has_tag(tag)`

Checks if the story has a specific tag.

**Parameters:**
- `tag` (string) - Tag name to check

**Returns:** `boolean`

**Example:**
```lua
if story:has_tag("mature_content") then
    print("Warning: Mature content")
end
```

##### `story:get_all_tags()`

Gets all story tags in sorted order.

**Returns:** `table` - Array of tag strings

**Example:**
```lua
local tags = story:get_all_tags()
for _, tag in ipairs(tags) do
    print("Tag: " .. tag)
end
```

##### `story:clear_tags()`

Removes all tags from the story.

**Returns:** `void`

**Example:**
```lua
story:clear_tags()
```

##### `story:set_setting(key, value)`

Sets a story-level setting (configuration value).

**Parameters:**
- `key` (string) - Setting name
- `value` (any) - Setting value

**Returns:** `void`

**Example:**
```lua
story:set_setting("difficulty", "hard")
story:set_setting("music_volume", 0.7)
story:set_setting("enable_hints", true)
```

##### `story:get_setting(key, default)`

Gets a story setting with optional default value.

**Parameters:**
- `key` (string) - Setting name
- `default` (any, optional) - Default value if setting not found

**Returns:** Setting value or default

**Example:**
```lua
local difficulty = story:get_setting("difficulty", "normal")
local volume = story:get_setting("music_volume", 0.5)
```

##### `story:has_setting(key)`

Checks if a story setting exists.

**Parameters:**
- `key` (string) - Setting name

**Returns:** `boolean`

**Example:**
```lua
if story:has_setting("custom_theme") then
    local theme = story:get_setting("custom_theme")
end
```

##### `story:delete_setting(key)`

Deletes a story setting.

**Parameters:**
- `key` (string) - Setting name

**Returns:** `boolean` - `true` if setting was deleted, `false` if it didn't exist

**Example:**
```lua
local deleted = story:delete_setting("temp_setting")
```

##### `story:get_all_settings()`

Gets a copy of all story settings.

**Returns:** `table` - Copy of settings dictionary

**Example:**
```lua
local settings = story:get_all_settings()
for key, value in pairs(settings) do
    print(string.format("%s = %s", key, tostring(value)))
end
```

##### `story:clear_settings()`

Removes all story settings.

**Returns:** `void`

**Example:**
```lua
story:clear_settings()
```

##### `story:get_variable_usage(variable_name)`

Finds all passages where a variable is used.

**Parameters:**
- `variable_name` (string) - Name of variable to search for

**Returns:** `table` - Array of usage objects with `passage_id`, `passage_name`, and `locations`

**Example:**
```lua
local usage = story:get_variable_usage("health")
for _, use in ipairs(usage) do
    print(string.format("Variable 'health' used in %s at: %s",
        use.passage_name, table.concat(use.locations, ", ")))
end
-- Output: Variable 'health' used in Battle Scene at: content, on_enter_script
```

##### `story:get_all_variable_usage()`

Gets usage information for all variables in the story.

**Returns:** `table` - Dictionary mapping variable names to usage arrays

**Example:**
```lua
local all_usage = story:get_all_variable_usage()
for var_name, usage in pairs(all_usage) do
    print(string.format("%s: used in %d passages", var_name, #usage))
end
```

##### `story:get_unused_variables()`

Gets a list of variables that are never referenced in any passage.

**Returns:** `table` - Array of unused variable names (sorted)

**Example:**
```lua
local unused = story:get_unused_variables()
if #unused > 0 then
    print("Warning: The following variables are never used:")
    for _, var in ipairs(unused) do
        print("  - " .. var)
    end
end
```

#### Properties

- `story.title` (string) - Story title
- `story.author` (string) - Author name
- `story.ifid` (string) - Interactive Fiction ID
- `story.version` (string) - Version number
- `story.description` (string) - Story description
- `story.variables` (table) - Default variable values
- `story.assets` (table) - Asset dictionary indexed by asset ID
- `story.tags` (table) - Story-level tags dictionary
- `story.settings` (table) - Story-level settings dictionary

---

### Passage

Represents a single scene or moment in your story.

#### Constructor

```lua
local Passage = require("whisker.core.passage")

local passage = Passage.new(config)
```

**Parameters:**
- `config` (table) - Passage configuration
  - `id` (string) - Unique passage identifier
  - `content` (string) - Passage text content
  - `choices` (table, optional) - Array of Choice objects
  - `tags` (table, optional) - Array of tag strings
  - `on_enter` (string, optional) - Lua code to run on entry
  - `on_exit` (string, optional) - Lua code to run on exit

**Example:**
```lua
local passage = Passage.new({
    id = "forest_entrance",
    content = [[
        You stand at the edge of a dark forest.
        The trees loom overhead, blocking out the sun.

        **What do you do?**
    ]],
    tags = {"outdoor", "important"},
    on_enter = [[
        game_state:set_variable("visited_forest", true)
    ]]
})
```

#### Methods

##### `passage:add_choice(choice)`

Adds a choice to the passage.

**Parameters:**
- `choice` (Choice) - The choice to add

**Returns:** `void`

**Example:**
```lua
passage:add_choice(Choice.new({
    text = "Enter the forest",
    target = "deep_forest"
}))
```

##### `passage:get_choices()`

Gets all choices for this passage.

**Returns:** `table` - Array of Choice objects

##### `passage:get_content()`

Gets the passage content.

**Returns:** `string` - The passage text

##### `passage:get_id()`

Gets the passage ID.

**Returns:** `string` - The passage ID

##### `passage:set_metadata(key, value)`

Sets a metadata value.

**Parameters:**
- `key` (string) - Metadata key
- `value` (any) - Metadata value

**Returns:** `void`

**Example:**
```lua
passage:set_metadata("difficulty", "hard")
passage:set_metadata("background_music", "dungeon_theme.mp3")
```

##### `passage:get_metadata(key, default)`

Gets a metadata value with optional default.

**Parameters:**
- `key` (string) - Metadata key
- `default` (any, optional) - Default value if key not found

**Returns:** `any` - The metadata value or default

**Example:**
```lua
local difficulty = passage:get_metadata("difficulty", "normal")
local music = passage:get_metadata("background_music")
```

##### `passage:has_metadata(key)`

Checks if metadata key exists.

**Parameters:**
- `key` (string) - Metadata key

**Returns:** `boolean` - True if key exists

**Example:**
```lua
if passage:has_metadata("boss_fight") then
    print("This is a boss fight passage!")
end
```

##### `passage:delete_metadata(key)`

Deletes a metadata key.

**Parameters:**
- `key` (string) - Metadata key to delete

**Returns:** `boolean` - True if key was deleted, false if it didn't exist

**Example:**
```lua
local deleted = passage:delete_metadata("temporary_flag")
```

##### `passage:clear_metadata()`

Clears all metadata.

**Returns:** `void`

**Example:**
```lua
passage:clear_metadata()  -- Remove all metadata
```

##### `passage:get_all_metadata()`

Gets a copy of all metadata.

**Returns:** `table` - Copy of metadata table

**Example:**
```lua
local metadata = passage:get_all_metadata()
for key, value in pairs(metadata) do
    print(key, value)
end
```

#### Properties

- `passage.id` (string) - Passage identifier
- `passage.content` (string) - Passage text
- `passage.choices` (table) - Array of choices
- `passage.tags` (table) - Array of tags
- `passage.on_enter` (string) - Entry script
- `passage.on_exit` (string) - Exit script
- `passage.metadata` (table) - Custom metadata key-value pairs
- `passage.position` (table) - Position in editor `{x, y}`
- `passage.size` (table) - Size in editor `{width, height}`

---

### Choice

Represents a player choice that links passages.

#### Constructor

```lua
local Choice = require("whisker.core.choice")

local choice = Choice.new(config)
```

**Parameters:**
- `config` (table) - Choice configuration
  - `text` (string) - Choice text displayed to player
  - `target` (string) - ID of target passage
  - `condition` (string, optional) - Lua expression that must be true
  - `action` (string, optional) - Lua code to run when selected
  - `visible` (boolean, optional) - Whether choice is visible (default: true)
  - `enabled` (boolean, optional) - Whether choice is selectable (default: true)

**Example:**
```lua
local choice = Choice.new({
    text = "Buy the sword (50 gold)",
    target = "blacksmith_purchase",
    condition = "gold >= 50",
    action = [[
        local gold = game_state:get_variable("gold")
        game_state:set_variable("gold", gold - 50)
        game_state:set_variable("has_sword", true)
    ]],
    visible = true,
    enabled = true
})
```

#### Methods

##### `choice:get_text()`

Gets the choice text.

**Returns:** `string` - The choice text

##### `choice:get_target()`

Gets the target passage ID.

**Returns:** `string` - The target passage ID

##### `choice:get_condition()`

Gets the condition expression.

**Returns:** `string` or `nil` - The condition

##### `choice:get_action()`

Gets the action script.

**Returns:** `string` or `nil` - The action script

##### `choice:is_visible()`

Checks if the choice is visible.

**Returns:** `boolean` - True if visible

##### `choice:is_enabled()`

Checks if the choice is enabled.

**Returns:** `boolean` - True if enabled

##### `choice:set_metadata(key, value)`

Sets a metadata value on the choice.

**Parameters:**
- `key` (string) - Metadata key
- `value` (any) - Metadata value

**Returns:** `void`

**Example:**
```lua
choice:set_metadata("points", 50)
choice:set_metadata("difficulty", "hard")
choice:set_metadata("icon", "⚔️")
```

##### `choice:get_metadata(key, default)`

Gets a metadata value with optional default.

**Parameters:**
- `key` (string) - Metadata key
- `default` (any, optional) - Default value if key not found

**Returns:** `any` - The metadata value or default

**Example:**
```lua
local points = choice:get_metadata("points", 0)
local icon = choice:get_metadata("icon", "➡️")
```

##### `choice:has_metadata(key)`

Checks if metadata key exists.

**Parameters:**
- `key` (string) - Metadata key

**Returns:** `boolean` - True if key exists

**Example:**
```lua
if choice:has_metadata("achievement") then
    print("This choice unlocks an achievement!")
end
```

##### `choice:delete_metadata(key)`

Deletes a metadata key.

**Parameters:**
- `key` (string) - Metadata key to delete

**Returns:** `boolean` - True if key was deleted, false if it didn't exist

**Example:**
```lua
local deleted = choice:delete_metadata("temporary_flag")
```

##### `choice:clear_metadata()`

Clears all metadata.

**Returns:** `void`

**Example:**
```lua
choice:clear_metadata()  -- Remove all metadata
```

##### `choice:get_all_metadata()`

Gets a copy of all metadata.

**Returns:** `table` - Copy of metadata table

**Example:**
```lua
local metadata = choice:get_all_metadata()
for key, value in pairs(metadata) do
    print(key, value)
end
```

#### Properties

- `choice.id` (string) - Unique choice identifier
- `choice.text` (string) - Choice text
- `choice.target` (string) - Target passage ID
- `choice.condition` (string) - Condition expression
- `choice.action` (string) - Action script
- `choice.visible` (boolean) - Visibility flag
- `choice.enabled` (boolean) - Enabled flag
- `choice.metadata` (table) - Custom metadata key-value pairs

---

### Variable

Represents a typed story variable with metadata.

#### Constructor

```lua
local Variable = require("whisker.core.variable")

local variable = Variable.new(config)
```

**Parameters:**
- `config` (table) - Variable configuration
  - `name` (string) - Variable name
  - `value` (any) - Initial value
  - `type` (string, optional) - Type hint ("string", "number", "boolean", "table")
  - `description` (string, optional) - Variable description
  - `default` (any, optional) - Default value for reset

**Example:**
```lua
local health = Variable.new({
    name = "health",
    value = 100,
    type = "number",
    description = "Player health points",
    default = 100
})

local has_key = Variable.new({
    name = "has_key",
    value = false,
    type = "boolean"
})
```

#### Methods

##### `variable:get_name()`

Gets the variable name.

**Returns:** `string` - The variable name

##### `variable:get_value()`

Gets the current value.

**Returns:** `any` - The current value

##### `variable:set_value(value)`

Sets the current value.

**Parameters:**
- `value` (any) - New value

##### `variable:get_type()`

Gets the type hint.

**Returns:** `string` or `nil` - The type hint

##### `variable:get_description()`

Gets the description.

**Returns:** `string` or `nil` - The description

##### `variable:get_default()`

Gets the default value.

**Returns:** `any` - The default value

##### `variable:reset()`

Resets the value to the default.

##### `variable:serialize()`

Serializes the variable to a table.

**Returns:** `table` - Serializable representation

##### `Variable.from_table(data)`

Creates a Variable from a serialized table.

**Parameters:**
- `data` (table) - Serialized variable data

**Returns:** `Variable` - New Variable instance

#### Properties

- `variable.name` (string) - Variable name
- `variable.value` (any) - Current value
- `variable.type` (string) - Type hint
- `variable.description` (string) - Description
- `variable.default` (any) - Default value

---

### GameState

Manages game state, variables, and history.

#### Constructor

```lua
local GameState = require("whisker.core.game_state")

local game_state = GameState.new()
```

#### Methods

##### `game_state:set_variable(name, value)`

Sets a variable value.

**Parameters:**
- `name` (string) - Variable name
- `value` (any) - Variable value

**Returns:** `void`

**Example:**
```lua
game_state:set_variable("health", 100)
game_state:set_variable("player_name", "Alice")
game_state:set_variable("inventory", {"sword", "shield"})
```

##### `game_state:get_variable(name)`

Gets a variable value.

**Parameters:**
- `name` (string) - Variable name

**Returns:** `any` - The variable value, or `nil` if not set

**Example:**
```lua
local health = game_state:get_variable("health")
local name = game_state:get_variable("player_name")
```

##### `game_state:get_all_variables()`

Gets all variables.

**Returns:** `table` - Table of all variables

**Example:**
```lua
local vars = game_state:get_all_variables()
for name, value in pairs(vars) do
    print(name, value)
end
```

##### `game_state:set_current_passage(passage_id)`

Sets the current passage.

**Parameters:**
- `passage_id` (string) - The passage ID

**Returns:** `void`

##### `game_state:get_current_passage()`

Gets the current passage ID.

**Returns:** `string` - The current passage ID

##### `game_state:get_passage_history()`

Gets the passage visit history.

**Returns:** `table` - Array of passage IDs

##### `game_state:can_undo()`

Checks if undo is possible.

**Returns:** `boolean` - True if undo is available

##### `game_state:undo()`

Undoes the last action.

**Returns:** `boolean` - True if undo succeeded

##### `game_state:reset()`

Resets the game state to initial values.

**Returns:** `void`

---

### Engine

The main story execution engine.

#### Constructor

```lua
local Engine = require("whisker.core.engine")

local engine = Engine.new(story, game_state)
```

**Parameters:**
- `story` (Story) - The story to run
- `game_state` (GameState) - The game state manager

**Example:**
```lua
local story = Story.new({title = "My Story"})
local game_state = GameState.new()
local engine = Engine.new(story, game_state)
```

#### Methods

##### `engine:start_story()`

Starts the story from the beginning.

**Returns:** `table` - Initial content object

**Example:**
```lua
local content = engine:start_story()
print(content.passage.content)
```

##### `engine:make_choice(choice_index)`

Makes a choice and progresses the story.

**Parameters:**
- `choice_index` (number) - The 1-based index of the choice

**Returns:** `table` - New content object

**Example:**
```lua
local content = engine:make_choice(1)  -- Select first choice
```

##### `engine:navigate_to_passage(passage_id)`

Navigates directly to a specific passage.

**Parameters:**
- `passage_id` (string) - The target passage ID

**Returns:** `table` - Content object

##### `engine:undo()`

Undoes the last action.

**Returns:** `table` - Previous content object

##### `engine:get_current_content()`

Gets the current content object.

**Returns:** `table` - Current content object

**Content Object Structure:**
```lua
{
    passage = Passage,        -- Current passage
    passage_id = string,      -- Passage ID
    content = string,         -- Rendered content
    choices = {Choice, ...},  -- Available choices
    can_undo = boolean,       -- Whether undo is available
    metadata = {              -- Additional metadata
        visit_count = number,
        is_first_visit = boolean
    }
}
```

---

## UI and Platform

### UIFramework

Provides user interface functionality.

```lua
local UIFramework = require("whisker.ui.ui_framework")

local ui = UIFramework.new(platform, config)
```

**Platforms:**
- `"console"` - Terminal/console interface
- `"web"` - Web browser interface
- `"love2d"` - LÖVE2D game framework

**Methods:**
- `ui:display_passage(passage, game_state)` - Display passage
- `ui:get_user_input()` - Get player input
- `ui:show_message(message, type)` - Show a message
- `ui:show_help()` - Display help information
- `ui:confirm_action(message)` - Get yes/no confirmation

### InputHandler

Handles player input across platforms.

```lua
local InputHandler = require("whisker.platform.input_handler")

local input = InputHandler.new(platform)
```

**Methods:**
- `input:get_input(type, options)` - Get input
- `input:parse_command(input_string)` - Parse command

### AssetManager

Manages multimedia assets.

```lua
local AssetManager = require("whisker.platform.asset_manager")

local assets = AssetManager.new(config)
```

**Methods:**
- `assets:load(path, type, options)` - Load asset
- `assets:preload(asset_list, callback)` - Preload multiple
- `assets:get(path)` - Get loaded asset
- `assets:unload(path)` - Unload asset

---

## Tools

### Validator

Validates story structure.

```lua
local Validator = require("whisker.tools.validator")

local validator = Validator.new()
local results = validator:validate_story(story)
```

**Methods:**
- `validator:validate_story(story)` - Validate complete story
- `validator:generate_report(format)` - Generate report
- `validator:get_issues_by_category(category)` - Get specific issues

### Profiler

Profiles story performance.

```lua
local Profiler = require("whisker.tools.profiler")

local profiler = Profiler.new(engine, game_state)
profiler:start(Profiler.ProfileMode.FULL)
-- Run story...
profiler:stop()
print(profiler:generate_report())
```

**Methods:**
- `profiler:start(mode)` - Start profiling
- `profiler:stop()` - Stop profiling
- `profiler:analyze()` - Analyze metrics
- `profiler:generate_report(format)` - Generate report

### Debugger

Runtime debugger with breakpoints.

```lua
local Debugger = require("whisker.tools.debugger")

local debugger = Debugger.new(engine, game_state)
debugger:enable(Debugger.DebugMode.BREAKPOINT)
debugger:add_breakpoint(Debugger.BreakpointType.PASSAGE, "boss_fight")
```

**Methods:**
- `debugger:enable(mode)` - Enable debugging
- `debugger:add_breakpoint(type, target, condition)` - Add breakpoint
- `debugger:add_watch(variable_name)` - Watch variable
- `debugger:continue()` - Continue execution
- `debugger:step()` - Step to next passage

---

## Utilities

### Renderer

Text rendering with markdown support.

```lua
local Renderer = require("whisker.runtime.renderer")

local renderer = Renderer.new(platform)
renderer:set_interpreter(interpreter)

local rendered = renderer:render_passage(passage, game_state)
```

**Markdown Syntax:**
- `**text**` - Bold
- `*text*` - Italic
- `__text__` - Underline
- `` `text` `` - Code
- `{{variable}}` - Variable substitution

### SaveSystem

Save and load game states.

```lua
local SaveSystem = require("whisker.system.save_system")

local save_system = SaveSystem.new(config)
```

**Methods:**
- `save_system:save_game(state, story, slot, name)` - Save game
- `save_system:load_game(slot)` - Load game
- `save_system:quick_save(state, story)` - Quick save
- `save_system:quick_load()` - Quick load
- `save_system:autosave(state, story)` - Autosave
- `save_system:list_saves()` - List all saves

---

## Complete Example

Here's a complete example using all major APIs:

```lua
-- Load required modules
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")
local Engine = require("whisker.core.engine")
local GameState = require("whisker.core.game_state")
local UIFramework = require("whisker.ui.ui_framework")
local SaveSystem = require("whisker.system.save_system")

-- Create story
local story = Story.new({
    title = "Complete Example",
    author = "API Demo"
})

-- Initialize variables
story.variables = {
    health = 100,
    gold = 0
}

-- Create passages
local start = Passage.new({
    id = "start",
    content = "Health: {{health}}\nGold: {{gold}}\n\nWhat do you do?",
    on_enter = [[
        local visits = game_state:get_variable("start_visits") or 0
        game_state:set_variable("start_visits", visits + 1)
    ]]
})

start:add_choice(Choice.new({
    text = "Find gold",
    target = "find_gold",
    action = [[
        local gold = game_state:get_variable("gold")
        game_state:set_variable("gold", gold + 10)
    ]]
}))

local find_gold = Passage.new({
    id = "find_gold",
    content = "You found 10 gold!\n\nTotal: {{gold}}"
})

find_gold:add_choice(Choice.new({
    text = "Continue",
    target = "start"
}))

-- Add passages
story:add_passage(start)
story:add_passage(find_gold)
story:set_start_passage("start")

-- Create engine components
local game_state = GameState.new()
local engine = Engine.new(story, game_state)
local ui = UIFramework.new("console")
local save_system = SaveSystem.new()

-- Start and play
local content = engine:start_story()
local running = true

while running do
    -- Display passage
    ui:display_passage(content.passage, game_state)

    -- Get input
    local input = ui:get_user_input()

    -- Handle input
    if input.type == "choice" then
        content = engine:make_choice(input.choice)
    elseif input.type == "command" then
        if input.command == "quit" then
            running = false
        elseif input.command == "save" then
            save_system:quick_save(game_state, story)
            ui:show_message("Game saved!", "success")
        end
    end
end
```

---

## Type Definitions

For reference, here are the main type definitions:

```lua
-- Story metadata
{
    title = string,
    author = string?,
    ifid = string?,
    version = string?,
    description = string?
}

-- Passage config
{
    id = string,
    content = string,
    choices = Choice[]?,
    tags = string[]?,
    on_enter = string?,
    on_exit = string?
}

-- Choice config
{
    text = string,
    target = string,
    condition = string?,
    action = string?,
    visible = boolean?,
    enabled = boolean?
}

-- Content object
{
    passage = Passage,
    passage_id = string,
    content = string,
    choices = Choice[],
    can_undo = boolean,
    metadata = {
        visit_count = number,
        is_first_visit = boolean
    }
}
```

---

## Best Practices

### Variable Naming
```lua
-- Good ✅
player_health
gold_collected
has_magic_sword

-- Bad ❌
ph
g
sword
```

### Error Handling
```lua
-- Always check returns
local passage = story:get_passage("unknown")
if not passage then
    error("Passage not found!")
end
```

### Performance
```lua
-- Cache frequent lookups
local health = game_state:get_variable("health")
for i = 1, 100 do
    -- Use cached value
    if health > 0 then
        -- ...
    end
end
```

### Code Organization
```lua
-- Group related passages
local function create_village_passages()
    local passages = {}
    -- Create passages...
    return passages
end

for _, p in ipairs(create_village_passages()) do
    story:add_passage(p)
end
```

---

For more examples, see the [examples/](../examples/) directory.