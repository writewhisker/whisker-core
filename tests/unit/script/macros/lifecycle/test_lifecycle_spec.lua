--- Lifecycle & System Macros Unit Tests
-- Tests for timing, events, and system utility macros
-- @module tests.unit.script.macros.lifecycle.test_lifecycle_spec

describe("Lifecycle Macros", function()
  local Macros, Lifecycle, Context

  setup(function()
    Macros = require("whisker.script.macros")
    Lifecycle = require("whisker.script.macros.lifecycle")
    Context = Macros.Context
  end)

  describe("module structure", function()
    it("exports VERSION", function()
      assert.is_string(Lifecycle.VERSION)
      assert.matches("^%d+%.%d+%.%d+$", Lifecycle.VERSION)
    end)

    it("exports timing/event macros", function()
      assert.is_table(Lifecycle.live_macro)
      assert.is_table(Lifecycle.stop_macro)
      assert.is_table(Lifecycle.after_macro)
      assert.is_table(Lifecycle.event_macro)
      assert.is_table(Lifecycle.timeout_macro)
      assert.is_table(Lifecycle.interval_macro)
      assert.is_table(Lifecycle.clearinterval_macro)
    end)

    it("exports passage lifecycle macros", function()
      assert.is_table(Lifecycle.passagestart_macro)
      assert.is_table(Lifecycle.passageend_macro)
      assert.is_table(Lifecycle.storyready_macro)
    end)

    it("exports system utility macros", function()
      assert.is_table(Lifecycle.random_macro)
      assert.is_table(Lifecycle.either_macro)
      assert.is_table(Lifecycle.time_macro)
      assert.is_table(Lifecycle.date_macro)
      assert.is_table(Lifecycle.now_macro)
      assert.is_table(Lifecycle.visited_macro)
      assert.is_table(Lifecycle.visitedtag_macro)
      assert.is_table(Lifecycle.turns_macro)
    end)

    it("exports script/code macros", function()
      assert.is_table(Lifecycle.script_macro)
      assert.is_table(Lifecycle.run_macro)
      assert.is_table(Lifecycle.do_macro)
    end)

    it("exports navigation macros", function()
      assert.is_table(Lifecycle.previous_macro)
      assert.is_table(Lifecycle.passage_macro)
      assert.is_table(Lifecycle.tags_macro)
      assert.is_table(Lifecycle.hastag_macro)
      assert.is_table(Lifecycle.passages_macro)
    end)

    it("exports logging macros", function()
      assert.is_table(Lifecycle.log_macro)
      assert.is_table(Lifecycle.assert_macro)
    end)

    it("exports register_all function", function()
      assert.is_function(Lifecycle.register_all)
    end)
  end)

  describe("live macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates live data with default interval", function()
      local result = Lifecycle.live_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("live", result._type)
      assert.equals(1000, result.interval_ms)
    end)

    it("parses seconds", function()
      local result = Lifecycle.live_macro.handler(ctx, { "2s" })
      assert.equals(2000, result.interval_ms)
    end)

    it("parses milliseconds", function()
      local result = Lifecycle.live_macro.handler(ctx, { "500ms" })
      assert.equals(500, result.interval_ms)
    end)

    it("accepts numeric interval", function()
      local result = Lifecycle.live_macro.handler(ctx, { 3000 })
      assert.equals(3000, result.interval_ms)
    end)

    it("stores content", function()
      local result = Lifecycle.live_macro.handler(ctx, { "1s", "content here" })
      assert.equals("content here", result.content)
    end)

    it("is lifecycle category", function()
      assert.equals("lifecycle", Lifecycle.live_macro.category)
    end)
  end)

  describe("stop macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates stop data", function()
      local result = Lifecycle.stop_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals("stop", result._type)
    end)

    it("accepts target", function()
      local result = Lifecycle.stop_macro.handler(ctx, { "timer1" })
      assert.equals("timer1", result.target)
    end)
  end)

  describe("after macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates after data", function()
      local result = Lifecycle.after_macro.handler(ctx, { "2s", "delayed content" })
      assert.is_table(result)
      assert.equals("after", result._type)
      assert.equals(2000, result.delay_ms)
      assert.equals("delayed content", result.content)
    end)

    it("is async", function()
      assert.is_true(Lifecycle.after_macro.async)
    end)
  end)

  describe("event macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates event handler data", function()
      local result = Lifecycle.event_macro.handler(ctx, { "click", "handler code" })
      assert.is_table(result)
      assert.equals("event_handler", result._type)
      assert.equals("click", result.event)
      assert.equals("handler code", result.handler)
    end)

    it("accepts once option", function()
      local result = Lifecycle.event_macro.handler(ctx, { "submit", nil, { once = true } })
      assert.is_true(result.once)
    end)
  end)

  describe("timeout macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates timeout data", function()
      local result = Lifecycle.timeout_macro.handler(ctx, { "5s" })
      assert.is_table(result)
      assert.equals("timeout", result._type)
      assert.equals(5000, result.delay_ms)
    end)

    it("has unique id", function()
      local result1 = Lifecycle.timeout_macro.handler(ctx, { "1s" })
      local result2 = Lifecycle.timeout_macro.handler(ctx, { "1s" })
      assert.is_string(result1.id)
      assert.is_string(result2.id)
    end)

    it("is async", function()
      assert.is_true(Lifecycle.timeout_macro.async)
    end)
  end)

  describe("interval macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates interval data", function()
      local result = Lifecycle.interval_macro.handler(ctx, { "1s" })
      assert.is_table(result)
      assert.equals("interval", result._type)
      assert.equals(1000, result.period_ms)
    end)

    it("accepts max count option", function()
      local result = Lifecycle.interval_macro.handler(ctx, { "500ms", nil, { max = 5 } })
      assert.equals(5, result.max_count)
    end)

    it("initializes current count to 0", function()
      local result = Lifecycle.interval_macro.handler(ctx, { "1s" })
      assert.equals(0, result.current_count)
    end)
  end)

  describe("clearinterval macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates clear data", function()
      local result = Lifecycle.clearinterval_macro.handler(ctx, { "timer123" })
      assert.is_table(result)
      assert.equals("clear_interval", result._type)
      assert.equals("timer123", result.id)
    end)
  end)

  describe("passagestart macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates lifecycle handler data", function()
      local result = Lifecycle.passagestart_macro.handler(ctx, { "handler" })
      assert.is_table(result)
      assert.equals("lifecycle_handler", result._type)
      assert.equals("passage_start", result.lifecycle)
    end)
  end)

  describe("passageend macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates lifecycle handler data", function()
      local result = Lifecycle.passageend_macro.handler(ctx, { "handler" })
      assert.is_table(result)
      assert.equals("lifecycle_handler", result._type)
      assert.equals("passage_end", result.lifecycle)
    end)
  end)

  describe("storyready macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates lifecycle handler data", function()
      local result = Lifecycle.storyready_macro.handler(ctx, { "handler" })
      assert.is_table(result)
      assert.equals("lifecycle_handler", result._type)
      assert.equals("story_ready", result.lifecycle)
    end)
  end)

  describe("random macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("generates number in range", function()
      for _ = 1, 100 do
        local result = Lifecycle.random_macro.handler(ctx, { 1, 6 })
        assert.is_true(result >= 1 and result <= 6)
      end
    end)

    it("handles single argument as 0 to n", function()
      for _ = 1, 100 do
        local result = Lifecycle.random_macro.handler(ctx, { 10 })
        assert.is_true(result >= 0 and result <= 10)
      end
    end)

    it("handles reversed range", function()
      for _ = 1, 100 do
        local result = Lifecycle.random_macro.handler(ctx, { 10, 5 })
        assert.is_true(result >= 5 and result <= 10)
      end
    end)

    it("returns integers", function()
      for _ = 1, 100 do
        local result = Lifecycle.random_macro.handler(ctx, { 1, 100 })
        assert.equals(math.floor(result), result)
      end
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.random_macro.pure)
    end)

    it("is utility category", function()
      assert.equals("utility", Lifecycle.random_macro.category)
    end)
  end)

  describe("either macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns one of the options", function()
      local options = { "a", "b", "c" }
      for _ = 1, 100 do
        local result = Lifecycle.either_macro.handler(ctx, options)
        assert.is_true(result == "a" or result == "b" or result == "c")
      end
    end)

    it("returns nil for empty args", function()
      local result = Lifecycle.either_macro.handler(ctx, {})
      assert.is_nil(result)
    end)

    it("works with single option", function()
      local result = Lifecycle.either_macro.handler(ctx, { "only" })
      assert.equals("only", result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.either_macro.pure)
    end)
  end)

  describe("time macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns current time", function()
      local result = Lifecycle.time_macro.handler(ctx, {})
      assert.is_string(result)
      assert.matches("^%d%d:%d%d:%d%d$", result)
    end)

    it("accepts format string", function()
      local result = Lifecycle.time_macro.handler(ctx, { "%H" })
      assert.is_string(result)
      assert.matches("^%d%d$", result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.time_macro.pure)
    end)
  end)

  describe("date macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns current date", function()
      local result = Lifecycle.date_macro.handler(ctx, {})
      assert.is_string(result)
      assert.matches("^%d%d%d%d%-%d%d%-%d%d$", result)
    end)

    it("accepts format string", function()
      local result = Lifecycle.date_macro.handler(ctx, { "%Y" })
      assert.is_string(result)
      assert.matches("^%d%d%d%d$", result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.date_macro.pure)
    end)
  end)

  describe("now macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns Unix timestamp", function()
      local result = Lifecycle.now_macro.handler(ctx, {})
      assert.is_number(result)
      assert.is_true(result > 0)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.now_macro.pure)
    end)
  end)

  describe("visited macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_visits", {
        intro = 3,
        ending = 1,
      })
      ctx:set("_current_passage", "intro")
    end)

    it("returns visit count for passage", function()
      local result = Lifecycle.visited_macro.handler(ctx, { "intro" })
      assert.equals(3, result)
    end)

    it("returns 0 for unvisited passage", function()
      local result = Lifecycle.visited_macro.handler(ctx, { "never_visited" })
      assert.equals(0, result)
    end)

    it("defaults to current passage", function()
      local result = Lifecycle.visited_macro.handler(ctx, {})
      assert.equals(3, result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.visited_macro.pure)
    end)
  end)

  describe("visitedtag macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_tag_visits", {
        combat = 5,
        peaceful = 10,
      })
    end)

    it("returns visit count for tag", function()
      local result = Lifecycle.visitedtag_macro.handler(ctx, { "combat" })
      assert.equals(5, result)
    end)

    it("returns 0 for unvisited tag", function()
      local result = Lifecycle.visitedtag_macro.handler(ctx, { "unknown" })
      assert.equals(0, result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.visitedtag_macro.pure)
    end)
  end)

  describe("turns macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_turns", 42)
    end)

    it("returns turn count", function()
      local result = Lifecycle.turns_macro.handler(ctx, {})
      assert.equals(42, result)
    end)

    it("returns 0 when not set", function()
      ctx:delete("_turns")
      local result = Lifecycle.turns_macro.handler(ctx, {})
      assert.equals(0, result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.turns_macro.pure)
    end)
  end)

  describe("script macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates script data", function()
      local result = Lifecycle.script_macro.handler(ctx, { "code here" })
      assert.is_table(result)
      assert.equals("script", result._type)
      assert.equals("code here", result.code)
    end)
  end)

  describe("run macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns nil for silent execution", function()
      local result = Lifecycle.run_macro.handler(ctx, { "silent code" })
      assert.is_nil(result)
    end)
  end)

  describe("do macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("executes function action", function()
      local called = false
      local action = function(c)
        called = true
        return "result"
      end
      local result = Lifecycle.do_macro.handler(ctx, { action })
      assert.is_true(called)
      assert.equals("result", result)
    end)

    it("returns non-function values directly", function()
      local result = Lifecycle.do_macro.handler(ctx, { "just a value" })
      assert.equals("just a value", result)
    end)
  end)

  describe("previous macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_passage_history", { "intro", "chapter1", "chapter2" })
    end)

    it("returns previous passage", function()
      local result = Lifecycle.previous_macro.handler(ctx, {})
      assert.equals("chapter1", result)
    end)

    it("returns nil when no history", function()
      ctx:set("_passage_history", { "only" })
      local result = Lifecycle.previous_macro.handler(ctx, {})
      assert.is_nil(result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.previous_macro.pure)
    end)
  end)

  describe("passage macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_current_passage", "current_chapter")
    end)

    it("returns current passage", function()
      local result = Lifecycle.passage_macro.handler(ctx, {})
      assert.equals("current_chapter", result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.passage_macro.pure)
    end)
  end)

  describe("tags macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_current_passage", "battle")
      ctx:set("_passage_tags", {
        battle = { "combat", "action" },
        intro = { "peaceful" },
      })
    end)

    it("returns current passage tags", function()
      local result = Lifecycle.tags_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals(2, #result)
    end)

    it("returns specified passage tags", function()
      local result = Lifecycle.tags_macro.handler(ctx, { "intro" })
      assert.equals(1, #result)
      assert.equals("peaceful", result[1])
    end)

    it("returns empty table for untagged passage", function()
      local result = Lifecycle.tags_macro.handler(ctx, { "unknown" })
      assert.is_table(result)
      assert.equals(0, #result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.tags_macro.pure)
    end)
  end)

  describe("hastag macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_current_passage", "battle")
      ctx:set("_passage_tags", {
        battle = { "combat", "action" },
      })
    end)

    it("returns true when tag exists", function()
      local result = Lifecycle.hastag_macro.handler(ctx, { "combat" })
      assert.is_true(result)
    end)

    it("returns false when tag missing", function()
      local result = Lifecycle.hastag_macro.handler(ctx, { "peaceful" })
      assert.is_false(result)
    end)

    it("checks specified passage", function()
      ctx:set("_passage_tags", {
        battle = { "combat" },
        intro = { "peaceful" },
      })
      local result = Lifecycle.hastag_macro.handler(ctx, { "peaceful", "intro" })
      assert.is_true(result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.hastag_macro.pure)
    end)
  end)

  describe("passages macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
      ctx:set("_all_passages", { "intro", "chapter1", "chapter2", "ending" })
      ctx:set("_passage_tags", {
        intro = { "beginning" },
        ending = { "ending" },
      })
    end)

    it("returns all passages", function()
      local result = Lifecycle.passages_macro.handler(ctx, {})
      assert.is_table(result)
      assert.equals(4, #result)
    end)

    it("filters by tag", function()
      local result = Lifecycle.passages_macro.handler(ctx, { "ending" })
      assert.equals(1, #result)
      assert.equals("ending", result[1])
    end)

    it("returns empty for unknown tag", function()
      local result = Lifecycle.passages_macro.handler(ctx, { "nonexistent" })
      assert.equals(0, #result)
    end)

    it("is pure", function()
      assert.is_true(Lifecycle.passages_macro.pure)
    end)
  end)

  describe("log macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("creates log data", function()
      local result = Lifecycle.log_macro.handler(ctx, { "test message" })
      assert.is_table(result)
      assert.equals("log", result._type)
      assert.equals("test message", result.message)
      assert.equals("info", result.level)
    end)

    it("accepts log level", function()
      local result = Lifecycle.log_macro.handler(ctx, { "error!", "error" })
      assert.equals("error", result.level)
    end)

    it("includes timestamp", function()
      local result = Lifecycle.log_macro.handler(ctx, { "msg" })
      assert.is_number(result.timestamp)
    end)
  end)

  describe("assert macro", function()
    local ctx

    before_each(function()
      ctx = Context.new()
    end)

    it("returns true on success", function()
      local result = Lifecycle.assert_macro.handler(ctx, { true })
      assert.is_true(result)
    end)

    it("returns error on failure", function()
      local result, err = Lifecycle.assert_macro.handler(ctx, { false })
      assert.is_nil(result)
      assert.equals("Assertion failed", err)
    end)

    it("uses custom message", function()
      local result, err = Lifecycle.assert_macro.handler(ctx, { false, "Custom error" })
      assert.equals("Custom error", err)
    end)

    it("treats truthy values as success", function()
      local result = Lifecycle.assert_macro.handler(ctx, { "truthy" })
      assert.is_true(result)
    end)
  end)

  describe("register_all", function()
    local Registry

    setup(function()
      Registry = Macros.Registry
    end)

    it("registers all macros", function()
      local registry = Registry.new()
      local count = Lifecycle.register_all(registry)

      assert.is_true(count >= 25)
    end)

    it("registers macros under correct names", function()
      local registry = Registry.new()
      Lifecycle.register_all(registry)

      assert.is_not_nil(registry:get("live"))
      assert.is_not_nil(registry:get("after"))
      assert.is_not_nil(registry:get("random"))
      assert.is_not_nil(registry:get("either"))
      assert.is_not_nil(registry:get("visited"))
      assert.is_not_nil(registry:get("passage"))
    end)

    it("lifecycle macros have lifecycle category", function()
      local registry = Registry.new()
      Lifecycle.register_all(registry)

      local macro = registry:get("live")
      assert.equals("lifecycle", macro.category)
    end)

    it("utility macros have utility category", function()
      local registry = Registry.new()
      Lifecycle.register_all(registry)

      local macro = registry:get("random")
      assert.equals("utility", macro.category)
    end)
  end)
end)
