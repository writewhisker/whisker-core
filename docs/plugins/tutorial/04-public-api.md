# Tutorial 4: Public API Design

## Goal

Learn to design and expose public APIs that story scripts can use.

## Prerequisites

- Completed [Tutorial 3: State Management](03-state-management.md)
- Understanding of API design principles

## Basic API Structure

```lua
return {
  name = "my-plugin",
  version = "1.0.0",

  api = {
    function_name = function(arg1, arg2)
      -- Implementation
      return result
    end,
  },
}
```

Story scripts access via:

```lua
whisker.plugin.my_plugin.function_name(arg1, arg2)
```

## Step 1: Input Validation

Always validate inputs:

```lua
api = {
  add_item = function(item)
    -- Type check
    if type(item) ~= "table" then
      return false, "item must be a table"
    end

    -- Required field check
    if not item.id then
      return false, "item.id is required"
    end

    if not item.name then
      return false, "item.name is required"
    end

    -- Implementation
    return true
  end,
}
```

## Step 2: Return Patterns

Use consistent return patterns:

### Success/Error Pattern

```lua
api = {
  do_something = function(input)
    if not validate(input) then
      return false, "Invalid input"
    end

    local result = process(input)
    return true, result
  end,
}

-- Usage
local success, result = whisker.plugin.my_plugin.do_something(data)
if success then
  print("Result:", result)
else
  print("Error:", result)
end
```

### Value/Nil Pattern

```lua
api = {
  get_item = function(id)
    return items[id]  -- Returns item or nil
  end,
}

-- Usage
local item = whisker.plugin.inventory.get_item("sword")
if item then
  print("Found:", item.name)
end
```

### Boolean Pattern

```lua
api = {
  has_item = function(id, quantity)
    quantity = quantity or 1
    local item = items[id]
    return item and item.quantity >= quantity
  end,
}

-- Usage
if whisker.plugin.inventory.has_item("key") then
  print("Door opens")
end
```

## Step 3: Naming Conventions

Use consistent verb_noun pattern:

```lua
api = {
  -- CRUD operations
  add_item = function(item) end,
  remove_item = function(id) end,
  get_item = function(id) end,
  update_item = function(id, changes) end,

  -- Queries
  has_item = function(id) end,
  find_items = function(filter) end,
  count_items = function() end,

  -- Actions
  clear_inventory = function() end,
  sort_inventory = function() end,
}
```

## Step 4: Optional Parameters

Handle optional parameters with defaults:

```lua
api = {
  find_items = function(options)
    options = options or {}

    local tag = options.tag or nil
    local min_quantity = options.min_quantity or 1
    local sort_by = options.sort_by or "name"

    -- Implementation using options
  end,
}

-- Usage
local weapons = whisker.plugin.inventory.find_items({
  tag = "weapon",
  min_quantity = 1,
})
```

## Step 5: Chaining APIs

Design for method chaining where appropriate:

```lua
local plugin = {}

return {
  name = "dialogue",
  version = "1.0.0",

  api = {
    create_message = function()
      plugin.current = {
        text = "",
        speaker = nil,
        emotion = "neutral",
      }
      return whisker.plugin.dialogue
    end,

    set_text = function(text)
      plugin.current.text = text
      return whisker.plugin.dialogue
    end,

    set_speaker = function(speaker)
      plugin.current.speaker = speaker
      return whisker.plugin.dialogue
    end,

    set_emotion = function(emotion)
      plugin.current.emotion = emotion
      return whisker.plugin.dialogue
    end,

    show = function()
      display_message(plugin.current)
      plugin.current = nil
    end,
  },
}

-- Usage
whisker.plugin.dialogue
  .create_message()
  .set_speaker("Alice")
  .set_emotion("happy")
  .set_text("Hello, world!")
  .show()
```

## Complete Example

```lua
-- quest-plugin.lua
local plugin = {
  quests = {},
  active = {},
  completed = {},
}

return {
  name = "quest",
  version = "1.0.0",
  description = "Quest tracking system",

  capabilities = {
    "persistence:read",
    "persistence:write",
  },

  on_init = function(ctx)
    plugin.ctx = ctx
  end,

  hooks = {
    on_save = function(save_data, ctx)
      save_data.quests = {
        quests = plugin.quests,
        active = plugin.active,
        completed = plugin.completed,
      }
      return save_data
    end,

    on_load = function(save_data, ctx)
      if save_data.quests then
        plugin.quests = save_data.quests.quests or {}
        plugin.active = save_data.quests.active or {}
        plugin.completed = save_data.quests.completed or {}
      end
      return save_data
    end,
  },

  api = {
    --- Define a new quest
    -- @param quest table {id, name, description, objectives}
    -- @return boolean success
    -- @return string|nil error
    define = function(quest)
      if type(quest) ~= "table" then
        return false, "quest must be a table"
      end

      if not quest.id then
        return false, "quest.id is required"
      end

      if not quest.name then
        return false, "quest.name is required"
      end

      plugin.quests[quest.id] = {
        id = quest.id,
        name = quest.name,
        description = quest.description or "",
        objectives = quest.objectives or {},
      }

      return true
    end,

    --- Start a quest
    -- @param quest_id string
    -- @return boolean success
    start = function(quest_id)
      if not plugin.quests[quest_id] then
        return false, "Unknown quest: " .. tostring(quest_id)
      end

      if plugin.active[quest_id] then
        return false, "Quest already active"
      end

      if plugin.completed[quest_id] then
        return false, "Quest already completed"
      end

      plugin.active[quest_id] = {
        started_at = os.time(),
        progress = {},
      }

      plugin.ctx.log.info("Quest started: " .. quest_id)
      return true
    end,

    --- Complete a quest
    -- @param quest_id string
    -- @return boolean success
    complete = function(quest_id)
      if not plugin.active[quest_id] then
        return false, "Quest not active"
      end

      plugin.completed[quest_id] = {
        completed_at = os.time(),
      }
      plugin.active[quest_id] = nil

      plugin.ctx.log.info("Quest completed: " .. quest_id)
      return true
    end,

    --- Check if quest is active
    -- @param quest_id string
    -- @return boolean
    is_active = function(quest_id)
      return plugin.active[quest_id] ~= nil
    end,

    --- Check if quest is completed
    -- @param quest_id string
    -- @return boolean
    is_completed = function(quest_id)
      return plugin.completed[quest_id] ~= nil
    end,

    --- Get quest details
    -- @param quest_id string
    -- @return table|nil
    get = function(quest_id)
      return plugin.quests[quest_id]
    end,

    --- Get all active quests
    -- @return table[]
    get_active = function()
      local result = {}
      for id in pairs(plugin.active) do
        table.insert(result, plugin.quests[id])
      end
      return result
    end,

    --- Get all completed quests
    -- @return table[]
    get_completed = function()
      local result = {}
      for id in pairs(plugin.completed) do
        table.insert(result, plugin.quests[id])
      end
      return result
    end,
  },
}
```

## What's Next?

- [Tutorial 5: Testing](05-testing.md) - Write plugin tests
- [Reference: API Patterns](../reference/api-patterns.md) - Common patterns
