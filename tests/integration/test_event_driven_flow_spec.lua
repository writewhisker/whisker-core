--- Event-Driven Flow Integration Tests
-- Integration tests for Phase 1 event-driven architecture components
-- @module tests.integration.test_event_driven_flow_spec
-- @author Whisker Core Team

describe("Event-Driven Flow Integration", function()
  local EventSystem, ClientHooks, AsyncEvent, SpecialPassages
  local Story, Passage

  setup(function()
    EventSystem = require("whisker.core.event_system")
    ClientHooks = require("whisker.core.client_hooks")
    AsyncEvent = require("whisker.core.async_event")
    SpecialPassages = require("whisker.core.special_passages")
    Story = require("whisker.core.story")
    Passage = require("whisker.core.passage")
  end)

  describe("ClientHooks and EventSystem integration", function()
    local event_bus, hooks

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("events flow from ClientHooks to EventSystem", function()
      local events_received = {}

      event_bus:on("RENDER_REQUESTED", function(event)
        table.insert(events_received, { type = "RENDER_REQUESTED", data = event.data })
      end)

      event_bus:on("RENDER_COMPLETE", function(event)
        table.insert(events_received, { type = "RENDER_COMPLETE", data = event.data })
      end)

      hooks:emit_render("Test content", { passage_name = "Start" })

      assert.equals(2, #events_received)
      assert.equals("RENDER_REQUESTED", events_received[1].type)
      assert.equals("RENDER_COMPLETE", events_received[2].type)
    end)

    it("render handler modifies content in event flow", function()
      local rendered_content = nil

      hooks:register_renderer(function(content, options)
        return "[[" .. content .. "]]"
      end)

      event_bus:on("RENDER_COMPLETE", function(event)
        rendered_content = event.data.result
      end)

      hooks:emit_render("Hello", {})

      assert.equals("[[Hello]]", rendered_content)
    end)

    it("tracks all handler registrations through events", function()
      local registrations = {}

      event_bus:on("HANDLER_REGISTERED", function(event)
        table.insert(registrations, event.data.handler_type)
      end)

      hooks:register_renderer(function() end)
      hooks:register_input_handler(function() end)
      hooks:register_audio_handler(function() end)

      assert.equals(3, #registrations)
      assert.equals("renderer", registrations[1])
      assert.equals("input", registrations[2])
      assert.equals("audio", registrations[3])
    end)

    it("input flow emits full lifecycle events", function()
      local events = {}

      event_bus:on("INPUT_REQUESTED", function(event)
        table.insert(events, "requested")
      end)

      event_bus:on("INPUT_RECEIVED", function(event)
        table.insert(events, "received:" .. event.data.result)
      end)

      hooks:register_input_handler(function(input_type, options)
        return "user_choice"
      end)

      hooks:emit_input_request("choice", { choices = { "A", "B" } })

      assert.equals(2, #events)
      assert.equals("requested", events[1])
      assert.equals("received:user_choice", events[2])
    end)

    it("error events are emitted on handler failure", function()
      local error_received = nil

      event_bus:on("ERROR_OCCURRED", function(event)
        error_received = event.data
      end)

      hooks:register_renderer(function()
        error("Intentional test error")
      end)

      hooks:emit_render("Content", {})

      assert.is_not_nil(error_received)
      assert.equals("renderer", error_received.source)
    end)
  end)

  describe("AsyncEvent integration with ClientHooks", function()
    local event_bus, hooks

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("async input handling with promise pattern", function()
      -- Create an async input handler
      local pending_input = nil

      hooks:register_input_handler(function(input_type, options)
        -- Create async event for this input request
        pending_input = AsyncEvent.new("input")
        return pending_input
      end)

      -- Start input request
      local result = hooks:emit_input_request("choice", {})

      -- Result is the async event
      assert.equals(pending_input, result)
      assert.is_true(result:is_pending())

      -- Simulate user making choice later
      result:resolve("choice_1")

      assert.is_true(result:is_resolved())
      assert.equals("choice_1", result:get_result())
    end)

    it("multiple async events with all", function()
      local e1 = AsyncEvent.new("load1")
      local e2 = AsyncEvent.new("load2")
      local e3 = AsyncEvent.new("load3")

      local all = AsyncEvent.all({ e1, e2, e3 })
      assert.is_true(all:is_pending())

      e1:resolve("data1")
      assert.is_true(all:is_pending())

      e2:resolve("data2")
      assert.is_true(all:is_pending())

      e3:resolve("data3")
      assert.is_true(all:is_resolved())

      local results = all:get_result()
      assert.equals("data1", results[1])
      assert.equals("data2", results[2])
      assert.equals("data3", results[3])
    end)

    it("async event race for timeout patterns", function()
      local input = AsyncEvent.new("input")
      local timeout = AsyncEvent.new("timeout")

      local race = AsyncEvent.race({ input, timeout })

      -- Simulate timeout winning
      timeout:resolve("timeout_occurred")

      assert.is_true(race:is_resolved())
      assert.equals("timeout_occurred", race:get_result())
      assert.is_true(input:is_pending())  -- Input still pending
    end)

    it("coroutine-based async flow", function()
      local result = nil

      local co = coroutine.create(function()
        local e1 = AsyncEvent.new("step1")
        local e2 = AsyncEvent.new("step2")

        -- Simulate both resolving
        e1:resolve("result1")
        e2:resolve("result2")

        local r1 = e1:await()
        local r2 = e2:await()

        result = r1 .. " + " .. r2
      end)

      coroutine.resume(co)

      assert.equals("result1 + result2", result)
    end)
  end)

  describe("SpecialPassages integration with EventSystem", function()
    local event_bus, special_passages, story

    before_each(function()
      event_bus = EventSystem.new()
      special_passages = SpecialPassages.new({ event_bus = event_bus })
      story = Story.new({ name = "Test Story" })
      special_passages:set_story(story)
    end)

    it("StoryInit execution triggers events", function()
      local events = {}

      event_bus:on("SCRIPT_EXECUTED", function(event)
        table.insert(events, event.data)
      end)

      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = ""
      }))

      special_passages:execute_init()

      assert.equals(1, #events)
      assert.equals("StoryInit", events[1].passage)
      assert.equals("story_init", events[1].phase)
    end)

    it("header and footer execute in correct order", function()
      local execution_order = {}

      event_bus:on("SCRIPT_EXECUTED", function(event)
        table.insert(execution_order, event.data.phase)
      end)

      story:add_passage(Passage.new({
        id = "PassageHeader",
        name = "PassageHeader",
        content = ""
      }))

      story:add_passage(Passage.new({
        id = "PassageFooter",
        name = "PassageFooter",
        content = ""
      }))

      special_passages:execute_header()
      special_passages:execute_footer()

      assert.equals(2, #execution_order)
      assert.equals("header", execution_order[1])
      assert.equals("footer", execution_order[2])
    end)

    it("start passage resolution follows fallback chain", function()
      -- No Start passage, should fall back to first non-special
      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = ""
      }))

      story:add_passage(Passage.new({
        id = "first_regular",
        name = "First Regular",
        content = "Hello"
      }))

      local start = special_passages:get_start_passage()

      -- Should return a non-special passage
      assert.is_not_nil(start)
      assert.is_false(special_passages:is_special(start.name or start.id))
    end)
  end)

  describe("Full event flow integration", function()
    local event_bus, hooks, special_passages, story

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
      special_passages = SpecialPassages.new({ event_bus = event_bus })
      story = Story.new({ name = "Integration Test Story" })
      special_passages:set_story(story)
    end)

    it("simulates complete passage display flow", function()
      local flow_log = {}

      -- Set up story
      story:add_passage(Passage.new({
        id = "StoryInit",
        name = "StoryInit",
        content = ""
      }))

      story:add_passage(Passage.new({
        id = "PassageHeader",
        name = "PassageHeader",
        content = ""
      }))

      story:add_passage(Passage.new({
        id = "Start",
        name = "Start",
        content = "Welcome to the story!"
      }))

      story:add_passage(Passage.new({
        id = "PassageFooter",
        name = "PassageFooter",
        content = ""
      }))

      -- Register handlers
      hooks:register_renderer(function(content, options)
        return "<div>" .. content .. "</div>"
      end)

      -- Track events
      event_bus:on("SCRIPT_EXECUTED", function(event)
        table.insert(flow_log, "script:" .. event.data.phase)
      end)

      event_bus:on("RENDER_REQUESTED", function(event)
        table.insert(flow_log, "render_request")
      end)

      event_bus:on("RENDER_COMPLETE", function(event)
        table.insert(flow_log, "render_complete")
      end)

      -- Execute flow
      special_passages:execute_init()
      special_passages:execute_header()

      local start_passage = special_passages:get_start_passage()
      local rendered = hooks:emit_render(start_passage:get_content(), {
        passage_name = start_passage.name
      })

      special_passages:execute_footer()

      -- Verify flow
      assert.equals("script:story_init", flow_log[1])
      assert.equals("script:header", flow_log[2])
      assert.equals("render_request", flow_log[3])
      assert.equals("render_complete", flow_log[4])
      assert.equals("script:footer", flow_log[5])

      -- Verify rendered content
      assert.equals("<div>Welcome to the story!</div>", rendered)
    end)

    it("handles errors gracefully in flow", function()
      local error_count = 0

      event_bus:on("ERROR_OCCURRED", function(event)
        error_count = error_count + 1
      end)

      -- Register failing handlers
      hooks:register_renderer(function()
        error("Render failed")
      end)

      hooks:register_effect_handler(function()
        error("Effect failed")
      end)

      -- Both should fail gracefully
      hooks:emit_render("content", {})
      hooks:emit_effect("fade", "target", {})

      assert.equals(2, error_count)
    end)

    it("supports multiple event listeners", function()
      local listener_calls = { a = 0, b = 0, c = 0 }

      event_bus:on("RENDER_COMPLETE", function()
        listener_calls.a = listener_calls.a + 1
      end)

      event_bus:on("RENDER_COMPLETE", function()
        listener_calls.b = listener_calls.b + 1
      end)

      event_bus:on("RENDER_COMPLETE", function()
        listener_calls.c = listener_calls.c + 1
      end)

      hooks:emit_render("test", {})

      assert.equals(1, listener_calls.a)
      assert.equals(1, listener_calls.b)
      assert.equals(1, listener_calls.c)
    end)
  end)

  describe("Event statistics and history", function()
    local event_bus, hooks

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("tracks event statistics", function()
      hooks:emit_render("content1", {})
      hooks:emit_render("content2", {})
      hooks:emit_render("content3", {})

      local stats = event_bus:get_stats()

      -- Each emit_render fires 2 events (RENDER_REQUESTED + RENDER_COMPLETE)
      assert.equals(6, stats.events_fired)
    end)

    it("maintains event history", function()
      hooks:emit_render("test", {})

      local history = event_bus:get_history("RENDER_COMPLETE", 1)

      assert.equals(1, #history)
      assert.equals("RENDER_COMPLETE", history[1].type)
    end)

    it("supports event propagation stopping", function()
      local call_count = 0

      event_bus:on("RENDER_COMPLETE", function(event)
        call_count = call_count + 1
        event_bus:stop_propagation(event)
      end)

      event_bus:on("RENDER_COMPLETE", function()
        call_count = call_count + 1
      end)

      hooks:emit_render("test", {})

      assert.equals(1, call_count)
    end)
  end)
end)
