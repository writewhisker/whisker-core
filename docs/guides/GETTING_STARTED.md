# Getting Started with Whisker-Core

This guide walks through creating a simple interactive story with whisker-core.

## Installation

```bash
# Using LuaRocks
luarocks install whisker-core

# Or clone the repository
git clone https://github.com/writewhisker/whisker-core.git
cd whisker-core
```

## Your First Story

### 1. Create a Story Structure

```lua
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")

-- Create a new story
local story = Story.create({
  title = "My First Adventure",
  author = "Your Name",
  version = "1.0.0"
})

-- Create the first passage
local start = Passage.create({
  id = "beginning",
  name = "The Beginning",
  content = [[
You wake up in a dark forest. Mist swirls around ancient trees.
A narrow path leads north, while you hear water flowing to the east.
]]
})

-- Add choices
local choice1 = Choice.create({
  text = "Follow the path north",
  target = "north_path"
})

local choice2 = Choice.create({
  text = "Head toward the water",
  target = "river"
})

start:add_choice(choice1)
start:add_choice(choice2)

-- Add passage to story
story:add_passage(start)
story.start_passage = "beginning"

-- Create additional passages
local north = Passage.create({
  id = "north_path",
  name = "The Northern Path",
  content = "The path winds deeper into the forest..."
})
story:add_passage(north)

local river = Passage.create({
  id = "river",
  name = "The River",
  content = "You find a peaceful stream..."
})
story:add_passage(river)
```

### 2. Set Up the Runtime

```lua
local Container = require("whisker.kernel.container")
local EventBus = require("whisker.kernel.events")

-- Create and configure container
local container = Container.new()

-- Register core services
local events = EventBus.new()
container:register("events", events, { singleton = true })

-- Register services (optional)
local ServiceLoader = require("whisker.services")
ServiceLoader.register_all(container)

-- Register format handlers (optional)
local FormatLoader = require("whisker.formats")
FormatLoader.register_all(container)
```

### 3. Play the Story

```lua
-- Simple text-based player
local current_passage = story:get_passage(story.start_passage)

while current_passage do
  -- Display passage
  print("\n" .. current_passage.name)
  print(string.rep("-", 40))
  print(current_passage.content)

  -- Get choices
  local choices = current_passage:get_choices()

  if #choices == 0 then
    print("\nThe End")
    break
  end

  -- Show choices
  print("\nWhat do you do?")
  for i, choice in ipairs(choices) do
    print(i .. ". " .. choice.text)
  end

  -- Get player input
  io.write("\n> ")
  local input = tonumber(io.read())

  if input and input >= 1 and input <= #choices then
    local target = choices[input].target
    current_passage = story:get_passage(target)
  else
    print("Invalid choice")
  end
end
```

## Loading Stories from Files

### JSON Format

```lua
local JsonFormat = require("whisker.formats.json")
local format = JsonFormat.new()

-- Load from file
local file = io.open("story.json", "r")
local source = file:read("*all")
file:close()

-- Import
local story = format:import(source)

-- Play the story...
```

### Twine HTML Format

```lua
local TwineFormat = require("whisker.formats.twine")
local format = TwineFormat.new()

-- Load Twine HTML
local file = io.open("story.html", "r")
local source = file:read("*all")
file:close()

-- Import
local story = format:import(source)
```

## Using Variables

```lua
local VariableService = require("whisker.services.variables")
local variables = VariableService.new(container)

-- Set variables
variables:set("player_name", "Alice")
variables:set("gold", 100)
variables:set("has_sword", true)

-- Get variables
local name = variables:get("player_name")
local gold = variables:get("gold")

-- Check existence
if variables:has("has_sword") then
  print("You have a sword!")
end

-- Numeric operations
variables:increment("gold", 50)  -- Add 50 gold
variables:decrement("health", 10)  -- Subtract 10 health
variables:toggle("is_visible")  -- Toggle boolean

-- Delete variable
variables:delete("temporary_flag")
```

## Saving and Loading

```lua
local StateManager = require("whisker.services.state")
local PersistenceService = require("whisker.services.persistence")

-- Register state first
container:register("state", StateManager, { singleton = true })
local persistence = PersistenceService.new(container)

-- Save current state
persistence:save("slot1", { description = "Forest entrance" })

-- Later...
persistence:load("slot1")
-- State is restored

-- Quick save/load
persistence:quick_save()
persistence:quick_load()

-- List all saves
local saves = persistence:list_saves()
for _, save in ipairs(saves) do
  print(save.slot .. " - " .. (save.metadata and save.metadata.description or ""))
end
```

## Tracking History

```lua
local HistoryService = require("whisker.services.history")
local history = HistoryService.new(container)

-- History is automatically tracked via events
-- Or manually push passages
history:push("current_passage_id")

-- Go back
if history:can_back() then
  local previous = history:go_back()
  print("Going back to: " .. previous.passage_id)
end

-- Get full history
local all_visited = history:get_all()
```

## Event System

```lua
local events = container:resolve("events")

-- Subscribe to events
events:on("passage:entered", function(data)
  print("Entered passage: " .. data.passage.name)
end)

events:on("variable:changed", function(data)
  print(data.name .. " changed from " .. tostring(data.old_value)
        .. " to " .. tostring(data.new_value))
end)

-- Emit custom events
events:emit("custom:event", { custom = "data" })

-- One-time listeners
events:once("game:started", function()
  print("Game has started!")
end)
```

## Next Steps

- Read the [API Reference](../api/index.html) for detailed documentation
- Explore [Format Handlers](FORMATS.md) for different story formats
- Learn about the [Architecture](ARCHITECTURE_OVERVIEW.md)
- See [Examples](../../examples/) for more complex scenarios
