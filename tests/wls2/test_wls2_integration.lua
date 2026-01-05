--- Tests for WLS 2.0 Integration Module
-- @module tests.wls2.test_wls2_integration

describe("WLS 2.0 Integration", function()
  local wls2_integration
  local thread_scheduler

  setup(function()
    wls2_integration = require("whisker.wls2.wls2_integration")
    thread_scheduler = require("whisker.wls2.thread_scheduler")
  end)

  describe("creation", function()
    it("creates a new integration instance", function()
      local integration = wls2_integration.new()
      assert.is_not_nil(integration)
    end)

    it("creates with custom options", function()
      local integration = wls2_integration.new({
        max_threads = 5,
        default_priority = 10,
        tick_rate = 32,
      })
      assert.is_not_nil(integration)
    end)

    it("initializes all component managers", function()
      local integration = wls2_integration.new()
      local components = integration:get_components()
      assert.is_not_nil(components.scheduler)
      assert.is_not_nil(components.timers)
      assert.is_not_nil(components.effects)
      assert.is_not_nil(components.externals)
    end)
  end)

  describe("initialization", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
    end)

    it("initializes with a story", function()
      local story = {
        passages = {
          start = { name = "start", content = {} },
        },
      }
      assert.has_no.errors(function()
        integration:initialize(story)
      end)
    end)

    it("processes audio declarations", function()
      local story = {
        passages = {},
        audio_declarations = {
          bgm = { source = "music.mp3", loop = true },
        },
      }
      integration:initialize(story)
      -- Audio declarations are registered as preload functions
      local externals = integration:get_components().externals
      assert.is_true(externals:has("audio.preload_bgm"))
    end)

    it("registers placeholder for external declarations", function()
      local story = {
        passages = {},
        external_declarations = {
          saveGame = { params = { "slot" } },
        },
      }
      integration:initialize(story)
      local externals = integration:get_components().externals
      assert.is_true(externals:has("saveGame"))
    end)
  end)

  describe("external function registration", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
    end)

    it("registers external functions", function()
      integration:register_externals({
        saveGame = function(slot) return true end,
        loadGame = function(slot) return {} end,
      })
      local externals = integration:get_components().externals
      assert.is_true(externals:has("saveGame"))
      assert.is_true(externals:has("loadGame"))
    end)

    it("calls external functions", function()
      integration:register_externals({
        add = function(a, b) return a + b end,
      })
      local result = integration:call_external("add", 2, 3)
      assert.equals(5, result)
    end)
  end)

  describe("thread management", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
    end)

    it("starts with main thread", function()
      local main_id = integration:start("start_passage")
      assert.is_string(main_id)

      local main = integration:get_main_thread()
      assert.is_not_nil(main)
      assert.is_true(main.is_main)
    end)

    it("spawns child threads", function()
      local main_id = integration:start("main")
      local child_id = integration:spawn_thread("side_passage", main_id)

      local child = integration:get_thread(child_id)
      assert.is_not_nil(child)
      assert.equals(main_id, child.parent_id)
    end)

    it("awaits thread completion", function()
      local main_id = integration:start("main")
      local other_id = integration:spawn_thread("other")

      integration:await_thread(main_id, other_id)

      local main = integration:get_thread(main_id)
      assert.equals(thread_scheduler.STATUS.WAITING, main.status)
    end)

    it("completes threads", function()
      local main_id = integration:start("main")
      integration:complete_thread(main_id)

      local main = integration:get_thread(main_id)
      assert.equals(thread_scheduler.STATUS.COMPLETED, main.status)
    end)

    it("gets active threads", function()
      integration:start("main")
      integration:spawn_thread("side1")
      integration:spawn_thread("side2")

      local active = integration:get_active_threads()
      assert.equals(3, #active)
    end)
  end)

  describe("timed content", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
      integration:start("main")
    end)

    it("schedules delayed content", function()
      local content = { { type = "text", text = "delayed" } }
      local timer_id = integration:schedule_content(1000, content)
      assert.is_string(timer_id)
    end)

    it("schedules repeating content", function()
      local content = { { type = "text" } }
      local timer_id = integration:schedule_repeat(500, content)

      local timers = integration:get_components().timers
      local timer = timers:get_timer(timer_id)
      assert.is_true(timer.is_repeat)
    end)

    it("fires timers on tick", function()
      local content = { { type = "text", text = "fired" } }
      integration:schedule_content(100, content)

      local results = integration:tick(100)
      assert.equals(1, #results.timer_content)
    end)
  end)

  describe("text effects", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
      integration:start("main")
    end)

    it("applies text effects", function()
      local effect_id = integration:apply_effect("Hello", "typewriter")
      assert.is_string(effect_id)
      assert.matches("^effect_", effect_id)
    end)

    it("updates effects on tick", function()
      local effect_id = integration:apply_effect("AB", "typewriter", { speed = 50 })

      local results = integration:tick(50)
      assert.is_not_nil(results.effect_states[effect_id])
    end)
  end)

  describe("tick and execution", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
    end)

    it("returns empty results when not running", function()
      local results = integration:tick(16)
      assert.equals(0, #results.thread_outputs)
    end)

    it("returns empty results when paused", function()
      integration:start("main")
      integration:pause()

      local results = integration:tick(16)
      assert.equals(0, #results.thread_outputs)
    end)

    it("executes with passage executor", function()
      integration:start("main")

      -- Set up a passage executor
      local executed = false
      local story = { passages = { main = { content = {} } } }
      integration:initialize(story, function(thread)
        executed = true
        return { { type = "text", text = "content" } }
      end)

      integration:tick(16)
      -- Note: The passage_executor is set during initialize
    end)

    it("tracks current time", function()
      integration:start("main")
      integration:tick(100)
      integration:tick(200)

      local results = integration:tick(0)
      assert.equals(300, results.current_time)
    end)
  end)

  describe("run_until_blocked", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
    end)

    it("runs until all threads complete", function()
      integration:start("main")

      -- Complete the main thread immediately via executor
      local story = { passages = {} }
      integration:initialize(story, function(thread)
        integration:complete_thread(thread.id)
        return {}
      end)

      local results = integration:run_until_blocked(100)
      assert.is_true(integration:is_complete())
    end)

    it("respects max_ticks limit", function()
      integration:start("main")

      -- Never complete the thread
      local story = { passages = {} }
      integration:initialize(story, function()
        return { { type = "text" } }
      end)

      local results = integration:run_until_blocked(10)
      assert.equals(10, results.tick_count)
    end)

    it("accumulates all outputs", function()
      integration:start("main")
      integration:schedule_content(32, { { type = "timer_content" } })

      local story = { passages = {} }
      integration:initialize(story, function(thread)
        integration:complete_thread(thread.id)
        return { { type = "thread_content" } }
      end)

      local results = integration:run_until_blocked(10)
      assert.is_true(#results.thread_outputs > 0 or #results.timer_content > 0)
    end)
  end)

  describe("pause and resume", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
      integration:start("main")
    end)

    it("pauses execution", function()
      integration:pause()
      assert.is_true(integration:is_paused())
    end)

    it("resumes execution", function()
      integration:pause()
      integration:resume()
      assert.is_false(integration:is_paused())
    end)

    it("pauses timers when integration pauses", function()
      integration:schedule_content(1000, { { type = "text" } })
      integration:pause()

      local timers = integration:get_components().timers
      assert.is_true(timers:is_paused())
    end)
  end)

  describe("completion checking", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
    end)

    it("checks if all threads complete", function()
      local main_id = integration:start("main")
      assert.is_false(integration:is_complete())

      integration:complete_thread(main_id)
      assert.is_true(integration:is_complete())
    end)

    it("checks if main thread complete", function()
      local main_id = integration:start("main")
      integration:spawn_thread("side")

      assert.is_false(integration:is_main_complete())

      integration:complete_thread(main_id)
      assert.is_true(integration:is_main_complete())
    end)
  end)

  describe("statistics", function()
    local integration

    before_each(function()
      integration = wls2_integration.new()
    end)

    it("returns comprehensive stats", function()
      integration:start("main")
      integration:spawn_thread("side")
      integration:schedule_content(1000, { {} })
      integration:apply_effect("text", "typewriter")
      integration:register_externals({ fn = function() end })

      local stats = integration:get_stats()

      assert.is_not_nil(stats.scheduler)
      assert.is_not_nil(stats.timers)
      assert.is_not_nil(stats.effects)
      assert.is_not_nil(stats.externals)
      assert.is_true(stats.running)
      assert.is_false(stats.paused)
    end)

    it("includes scheduler stats", function()
      integration:start("main")
      integration:spawn_thread("side")

      local stats = integration:get_stats()
      assert.equals(2, stats.scheduler.total_threads)
    end)
  end)

  describe("events", function()
    local integration
    local events

    before_each(function()
      integration = wls2_integration.new()
      events = {}
      integration:on(function(event, data)
        table.insert(events, { event = event, data = data })
      end)
    end)

    it("emits INITIALIZED event", function()
      integration:initialize({ passages = {} })

      local has_init = false
      for _, e in ipairs(events) do
        if e.event == wls2_integration.EVENTS.INITIALIZED then
          has_init = true
          break
        end
      end
      assert.is_true(has_init)
    end)

    it("emits TIMER_FIRED event", function()
      integration:start("main")
      integration:schedule_content(50, { { type = "text" } })
      integration:tick(50)

      local has_fired = false
      for _, e in ipairs(events) do
        if e.event == wls2_integration.EVENTS.TIMER_FIRED then
          has_fired = true
          break
        end
      end
      assert.is_true(has_fired)
    end)

    it("emits EFFECT_UPDATED event", function()
      integration:start("main")
      integration:apply_effect("text", "typewriter")
      integration:tick(50)

      local has_updated = false
      for _, e in ipairs(events) do
        if e.event == wls2_integration.EVENTS.EFFECT_UPDATED then
          has_updated = true
          break
        end
      end
      assert.is_true(has_updated)
    end)

    it("emits TICK event", function()
      integration:start("main")
      integration:tick(16)

      local has_tick = false
      for _, e in ipairs(events) do
        if e.event == wls2_integration.EVENTS.TICK then
          has_tick = true
          break
        end
      end
      assert.is_true(has_tick)
    end)

    it("removes listeners with off()", function()
      local callback = function() end
      integration:on(callback)
      integration:off(callback)
      -- Verify no errors
    end)
  end)

  describe("reset", function()
    it("clears all state", function()
      local integration = wls2_integration.new()
      integration:start("main")
      integration:spawn_thread("side")
      integration:schedule_content(1000, { {} })
      integration:apply_effect("text", "typewriter")
      integration:tick(100)

      integration:reset()

      assert.is_false(integration:is_paused())
      assert.equals(0, #integration:get_active_threads())
    end)
  end)

  describe("convenience functions", function()
    it("parses time strings", function()
      assert.equals(1000, wls2_integration.parse_time_string("1s"))
      assert.equals(500, wls2_integration.parse_time_string("500ms"))
    end)

    it("parses effect declarations", function()
      local result = wls2_integration.parse_effect_declaration("shake 500ms")
      assert.equals("shake", result.name)
      assert.equals(500, result.duration)
    end)

    it("exports thread status constants", function()
      assert.equals("running", wls2_integration.THREAD_STATUS.RUNNING)
      assert.equals("completed", wls2_integration.THREAD_STATUS.COMPLETED)
    end)

    it("exports effect type constants", function()
      assert.equals("typewriter", wls2_integration.EFFECT_TYPES.TYPEWRITER)
      assert.equals("fade-in", wls2_integration.EFFECT_TYPES.FADE_IN)
    end)
  end)
end)
