--- Counter Plugin Example
-- A simple plugin demonstrating state management and API exposure
-- @module examples.counter-plugin

local plugin = {
  ctx = nil,
  count = 0,
}

return {
  name = "counter",
  version = "1.0.0",
  author = "whisker-core",
  description = "Simple counter plugin example",
  license = "MIT",

  capabilities = {
    "persistence:read",
    "persistence:write",
  },

  -- Initialize plugin
  on_init = function(ctx)
    plugin.ctx = ctx
    plugin.count = ctx.storage.get("count") or 0
    ctx.log.debug("Counter initialized with value: " .. plugin.count)
  end,

  -- Story event hooks
  hooks = {
    on_story_start = function(ctx)
      -- Reset counter on new story
      plugin.count = 0
      ctx.storage.set("count", plugin.count)
    end,

    on_save = function(save_data, ctx)
      save_data.counter = {
        count = plugin.count,
      }
      return save_data
    end,

    on_load = function(save_data, ctx)
      if save_data.counter then
        plugin.count = save_data.counter.count or 0
        ctx.storage.set("count", plugin.count)
      end
      return save_data
    end,
  },

  -- Public API
  api = {
    --- Increment the counter
    -- @param amount number Amount to increment (default 1)
    -- @return number New count value
    increment = function(amount)
      amount = amount or 1
      plugin.count = plugin.count + amount
      plugin.ctx.storage.set("count", plugin.count)
      return plugin.count
    end,

    --- Decrement the counter
    -- @param amount number Amount to decrement (default 1)
    -- @return number New count value
    decrement = function(amount)
      amount = amount or 1
      plugin.count = plugin.count - amount
      plugin.ctx.storage.set("count", plugin.count)
      return plugin.count
    end,

    --- Get current count
    -- @return number Current count value
    get = function()
      return plugin.count
    end,

    --- Reset counter to zero
    reset = function()
      plugin.count = 0
      plugin.ctx.storage.set("count", plugin.count)
    end,

    --- Set counter to specific value
    -- @param value number Value to set
    -- @return boolean success
    set = function(value)
      if type(value) ~= "number" then
        return false, "value must be a number"
      end
      plugin.count = value
      plugin.ctx.storage.set("count", plugin.count)
      return true
    end,
  },
}

--[[
Usage in story:

-- Increment counter
whisker.plugin.counter.increment()
whisker.plugin.counter.increment(5)

-- Get value
local count = whisker.plugin.counter.get()
print("Count: " .. count)

-- Decrement
whisker.plugin.counter.decrement()

-- Reset
whisker.plugin.counter.reset()

-- Set specific value
whisker.plugin.counter.set(100)
]]
