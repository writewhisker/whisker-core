# Tutorial 5: Testing Plugins

## Goal

Learn to write comprehensive tests for your plugins using busted.

## Prerequisites

- Completed [Tutorial 4: Public API](04-public-api.md)
- busted test framework installed

## Test Structure

```
my-plugin/
  init.lua
  tests/
    my_plugin_spec.lua
```

## Step 1: Basic Test Setup

```lua
-- tests/my_plugin_spec.lua
describe("My Plugin", function()
  local plugin

  before_each(function()
    -- Clear module cache for fresh load
    package.loaded["my-plugin.init"] = nil
    plugin = require("my-plugin.init")
  end)

  it("has required metadata", function()
    assert.equal("my-plugin", plugin.name)
    assert.equal("1.0.0", plugin.version)
  end)
end)
```

## Step 2: Mock Plugin Context

```lua
describe("My Plugin", function()
  local plugin
  local mock_ctx

  before_each(function()
    -- Create mock context
    mock_ctx = {
      name = "my-plugin",
      version = "1.0.0",

      log = {
        debug = function() end,
        info = function() end,
        warn = function() end,
        error = function() end,
      },

      storage = {
        _data = {},
        get = function(key)
          return mock_ctx.storage._data[key]
        end,
        set = function(key, value)
          mock_ctx.storage._data[key] = value
        end,
      },

      state = {
        _data = {},
        get = function(key)
          return mock_ctx.state._data[key]
        end,
        set = function(key, value)
          mock_ctx.state._data[key] = value
        end,
      },
    }

    package.loaded["my-plugin.init"] = nil
    plugin = require("my-plugin.init")

    -- Initialize plugin
    if plugin.on_init then
      plugin.on_init(mock_ctx)
    end
  end)
end)
```

## Step 3: Test API Functions

```lua
describe("API", function()
  describe("add_item()", function()
    it("adds item to inventory", function()
      local success = plugin.api.add_item({
        id = "sword",
        name = "Iron Sword",
      })

      assert.is_true(success)
      assert.is_true(plugin.api.has_item("sword"))
    end)

    it("rejects invalid item", function()
      local success, err = plugin.api.add_item(nil)

      assert.is_false(success)
      assert.is_not_nil(err)
    end)

    it("requires id field", function()
      local success, err = plugin.api.add_item({
        name = "No ID",
      })

      assert.is_false(success)
      assert.is_true(err:match("id") ~= nil)
    end)
  end)
end)
```

## Step 4: Test Hooks

```lua
describe("Hooks", function()
  describe("on_passage_enter", function()
    it("tracks passage visits", function()
      local passage = {name = "intro", content = "Welcome"}

      plugin.hooks.on_passage_enter(mock_ctx, passage)

      local count = plugin.api.get_visit_count("intro")
      assert.equal(1, count)
    end)

    it("increments count on repeated visits", function()
      local passage = {name = "intro"}

      plugin.hooks.on_passage_enter(mock_ctx, passage)
      plugin.hooks.on_passage_enter(mock_ctx, passage)
      plugin.hooks.on_passage_enter(mock_ctx, passage)

      assert.equal(3, plugin.api.get_visit_count("intro"))
    end)
  end)

  describe("on_save/on_load", function()
    it("persists data across save/load", function()
      -- Set up state
      plugin.api.add_item({id = "sword", name = "Sword"})

      -- Save
      local save_data = {}
      save_data = plugin.hooks.on_save(save_data, mock_ctx)

      -- Clear state
      plugin.api.clear()
      assert.is_false(plugin.api.has_item("sword"))

      -- Load
      plugin.hooks.on_load(save_data, mock_ctx)

      -- Verify restored
      assert.is_true(plugin.api.has_item("sword"))
    end)
  end)
end)
```

## Step 5: Test Edge Cases

```lua
describe("Edge Cases", function()
  it("handles nil context gracefully", function()
    -- Some API functions should work without context
    local result = plugin.api.validate_item({
      id = "test",
      name = "Test",
    })

    assert.is_true(result)
  end)

  it("handles empty storage", function()
    mock_ctx.storage._data = {}

    local items = plugin.api.get_all_items()

    assert.equal(0, #items)
  end)

  it("handles invalid input types", function()
    local success = plugin.api.add_item("not a table")
    assert.is_false(success)

    success = plugin.api.add_item(123)
    assert.is_false(success)
  end)
end)
```

## Step 6: Integration Tests

```lua
describe("Integration", function()
  it("tracks full story session", function()
    -- Start story
    plugin.hooks.on_story_start(mock_ctx)

    -- Navigate passages
    plugin.hooks.on_passage_enter(mock_ctx, {name = "intro"})
    plugin.hooks.on_passage_enter(mock_ctx, {name = "choice"})

    -- Make choice
    plugin.hooks.on_choice_select(mock_ctx, {
      text = "Go left",
      target = "left_path",
    })

    plugin.hooks.on_passage_enter(mock_ctx, {name = "left_path"})

    -- Verify tracking
    assert.equal(3, plugin.api.get_passage_count())
    assert.equal(1, plugin.api.get_choice_count())

    -- End story
    plugin.hooks.on_story_end(mock_ctx)

    -- Check stats
    local stats = plugin.api.get_statistics()
    assert.equal(3, stats.passages)
    assert.equal(1, stats.choices)
  end)
end)
```

## Running Tests

```bash
# Run all plugin tests
busted tests/

# Run specific test file
busted tests/my_plugin_spec.lua

# Verbose output
busted tests/ --verbose

# With coverage
busted tests/ --coverage
```

## Complete Test Example

```lua
-- tests/counter_plugin_spec.lua
describe("Counter Plugin", function()
  local Counter
  local mock_ctx

  before_each(function()
    package.loaded["counter.init"] = nil

    mock_ctx = {
      log = {
        debug = function() end,
        info = function() end,
      },
      storage = {
        _data = {},
        get = function(key) return mock_ctx.storage._data[key] end,
        set = function(key, value) mock_ctx.storage._data[key] = value end,
      },
    }

    Counter = require("counter.init")
    Counter.on_init(mock_ctx)
  end)

  describe("Plugin Definition", function()
    it("has required metadata", function()
      assert.equal("counter", Counter.name)
      assert.equal("1.0.0", Counter.version)
    end)

    it("has lifecycle hooks", function()
      assert.is_function(Counter.on_init)
    end)

    it("has API", function()
      assert.is_not_nil(Counter.api)
      assert.is_function(Counter.api.increment)
      assert.is_function(Counter.api.decrement)
      assert.is_function(Counter.api.get)
      assert.is_function(Counter.api.reset)
    end)
  end)

  describe("increment()", function()
    it("starts at zero", function()
      assert.equal(0, Counter.api.get())
    end)

    it("increments by 1", function()
      Counter.api.increment()
      assert.equal(1, Counter.api.get())
    end)

    it("increments multiple times", function()
      Counter.api.increment()
      Counter.api.increment()
      Counter.api.increment()
      assert.equal(3, Counter.api.get())
    end)

    it("increments by custom amount", function()
      Counter.api.increment(5)
      assert.equal(5, Counter.api.get())
    end)
  end)

  describe("decrement()", function()
    it("decrements by 1", function()
      Counter.api.increment(10)
      Counter.api.decrement()
      assert.equal(9, Counter.api.get())
    end)

    it("allows negative values", function()
      Counter.api.decrement()
      assert.equal(-1, Counter.api.get())
    end)
  end)

  describe("reset()", function()
    it("resets to zero", function()
      Counter.api.increment(100)
      Counter.api.reset()
      assert.equal(0, Counter.api.get())
    end)
  end)

  describe("Persistence", function()
    it("saves state", function()
      Counter.api.increment(42)

      local save_data = {}
      save_data = Counter.hooks.on_save(save_data, mock_ctx)

      assert.equal(42, save_data.counter.value)
    end)

    it("loads state", function()
      local save_data = {counter = {value = 99}}

      Counter.hooks.on_load(save_data, mock_ctx)

      assert.equal(99, Counter.api.get())
    end)
  end)
end)
```

## Best Practices

1. **Isolate tests** - Reset state in `before_each`
2. **Test edge cases** - nil, empty, invalid inputs
3. **Test error paths** - Verify error messages
4. **Mock dependencies** - Don't rely on real context
5. **Name tests clearly** - Describe expected behavior

## What's Next?

- [Reference: IPlugin Interface](../reference/iplugin-interface.md)
- [Guides: Best Practices](../guides/best-practices.md)
