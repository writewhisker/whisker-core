--- ClientHooks Unit Tests
-- Comprehensive unit tests for the ClientHooks module
-- @module tests.unit.core.test_client_hooks_spec
-- @author Whisker Core Team

describe("ClientHooks", function()
  local ClientHooks, EventSystem

  before_each(function()
    ClientHooks = require("whisker.core.client_hooks")
    EventSystem = require("whisker.core.event_system")
  end)

  describe("initialization", function()
    it("creates instance without dependencies", function()
      local hooks = ClientHooks.new()

      assert.is_not_nil(hooks)
      assert.is_table(hooks._handlers)
    end)

    it("creates instance with event_bus dependency", function()
      local event_bus = EventSystem.new()
      local hooks = ClientHooks.new({ event_bus = event_bus })

      assert.is_not_nil(hooks)
      assert.equals(event_bus, hooks._event_bus)
    end)

    it("initializes all handler types as nil", function()
      local hooks = ClientHooks.new()

      assert.is_nil(hooks._handlers.renderer)
      assert.is_nil(hooks._handlers.input)
      assert.is_nil(hooks._handlers.audio)
      assert.is_nil(hooks._handlers.effect)
      assert.is_nil(hooks._handlers.dialog)
      assert.is_nil(hooks._handlers.timer)
    end)

    it("provides create factory method for DI", function()
      assert.is_function(ClientHooks.create)
    end)

    it("create method returns instance", function()
      local hooks = ClientHooks.create({})

      assert.is_not_nil(hooks)
    end)

    it("declares _dependencies for DI", function()
      assert.is_table(ClientHooks._dependencies)
      assert.equals("event_bus", ClientHooks._dependencies[1])
    end)
  end)

  describe("renderer handler", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("registers renderer handler", function()
      local handler = function(content, options) return content end
      local result = hooks:register_renderer(handler)

      assert.is_true(result)
      assert.equals(handler, hooks._handlers.renderer)
    end)

    it("throws error for non-function renderer", function()
      assert.has_error(function()
        hooks:register_renderer("not a function")
      end)
    end)

    it("stores handler info", function()
      local handler = function() end
      local info = { name = "test_renderer", version = "1.0" }
      hooks:register_renderer(handler, info)

      assert.same(info, hooks._handler_info.renderer)
    end)

    it("emits HANDLER_REGISTERED event", function()
      local event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
      local event_received = nil

      event_bus:on("HANDLER_REGISTERED", function(event)
        event_received = event
      end)

      hooks:register_renderer(function() end, { name = "test" })

      assert.is_not_nil(event_received)
      assert.equals("renderer", event_received.data.handler_type)
    end)
  end)

  describe("input handler", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("registers input handler", function()
      local handler = function(input_type, options) return "result" end
      local result = hooks:register_input_handler(handler)

      assert.is_true(result)
      assert.equals(handler, hooks._handlers.input)
    end)

    it("throws error for non-function input handler", function()
      assert.has_error(function()
        hooks:register_input_handler(123)
      end)
    end)
  end)

  describe("audio handler", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("registers audio handler", function()
      local handler = function(action, resource, options) end
      local result = hooks:register_audio_handler(handler)

      assert.is_true(result)
      assert.equals(handler, hooks._handlers.audio)
    end)

    it("throws error for non-function audio handler", function()
      assert.has_error(function()
        hooks:register_audio_handler({})
      end)
    end)
  end)

  describe("effect handler", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("registers effect handler", function()
      local handler = function(effect_type, target, options) end
      local result = hooks:register_effect_handler(handler)

      assert.is_true(result)
      assert.equals(handler, hooks._handlers.effect)
    end)

    it("throws error for non-function effect handler", function()
      assert.has_error(function()
        hooks:register_effect_handler(nil)
      end)
    end)
  end)

  describe("dialog handler", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("registers dialog handler", function()
      local handler = function(dialog_type, content, options) end
      local result = hooks:register_dialog_handler(handler)

      assert.is_true(result)
      assert.equals(handler, hooks._handlers.dialog)
    end)

    it("throws error for non-function dialog handler", function()
      assert.has_error(function()
        hooks:register_dialog_handler(true)
      end)
    end)
  end)

  describe("timer handler", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("registers timer handler", function()
      local handler = function(action, duration, callback) return 1 end
      local result = hooks:register_timer_handler(handler)

      assert.is_true(result)
      assert.equals(handler, hooks._handlers.timer)
    end)

    it("throws error for non-function timer handler", function()
      assert.has_error(function()
        hooks:register_timer_handler("timer")
      end)
    end)
  end)

  describe("unregister_handler", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("unregisters existing handler", function()
      hooks:register_renderer(function() end)

      local result = hooks:unregister_handler("renderer")

      assert.is_true(result)
      assert.is_nil(hooks._handlers.renderer)
    end)

    it("returns false for non-existent handler", function()
      local result = hooks:unregister_handler("renderer")

      assert.is_false(result)
    end)

    it("clears handler info", function()
      hooks:register_renderer(function() end, { name = "test" })
      hooks:unregister_handler("renderer")

      assert.is_nil(hooks._handler_info.renderer)
    end)

    it("emits HANDLER_UNREGISTERED event", function()
      local event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
      local event_received = nil

      hooks:register_renderer(function() end)

      event_bus:on("HANDLER_UNREGISTERED", function(event)
        event_received = event
      end)

      hooks:unregister_handler("renderer")

      assert.is_not_nil(event_received)
      assert.equals("renderer", event_received.data.handler_type)
    end)
  end)

  describe("handler queries", function()
    local hooks

    before_each(function()
      hooks = ClientHooks.new()
    end)

    it("has_handler returns true when registered", function()
      hooks:register_renderer(function() end)

      assert.is_true(hooks:has_handler("renderer"))
    end)

    it("has_handler returns false when not registered", function()
      assert.is_false(hooks:has_handler("renderer"))
    end)

    it("get_handler_info returns info when registered", function()
      local info = { name = "test", version = "1.0" }
      hooks:register_renderer(function() end, info)

      assert.same(info, hooks:get_handler_info("renderer"))
    end)

    it("get_handler_info returns nil when not registered", function()
      assert.is_nil(hooks:get_handler_info("renderer"))
    end)

    it("get_registered_handlers returns all registered types", function()
      hooks:register_renderer(function() end)
      hooks:register_input_handler(function() end)

      local registered = hooks:get_registered_handlers()

      assert.equals(2, #registered)
    end)

    it("get_registered_handlers returns empty table when none registered", function()
      local registered = hooks:get_registered_handlers()

      assert.equals(0, #registered)
    end)
  end)

  describe("emit_render", function()
    local hooks, event_bus

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("returns original content when no handler", function()
      local result = hooks:emit_render("Hello World", {})

      assert.equals("Hello World", result)
    end)

    it("returns rendered content from handler", function()
      hooks:register_renderer(function(content, options)
        return "<p>" .. content .. "</p>"
      end)

      local result = hooks:emit_render("Hello", {})

      assert.equals("<p>Hello</p>", result)
    end)

    it("emits RENDER_REQUESTED event", function()
      local event_received = nil
      event_bus:on("RENDER_REQUESTED", function(event)
        event_received = event
      end)

      hooks:emit_render("Test", { passage_name = "Start" })

      assert.is_not_nil(event_received)
      assert.equals("Test", event_received.data.content)
      assert.equals("Start", event_received.data.options.passage_name)
    end)

    it("emits RENDER_COMPLETE event", function()
      local event_received = nil
      event_bus:on("RENDER_COMPLETE", function(event)
        event_received = event
      end)

      hooks:emit_render("Test", {})

      assert.is_not_nil(event_received)
      assert.equals("Test", event_received.data.result)
    end)

    it("handles handler error gracefully", function()
      hooks:register_renderer(function()
        error("Render error")
      end)

      local error_received = nil
      event_bus:on("ERROR_OCCURRED", function(event)
        error_received = event
      end)

      local result = hooks:emit_render("Test", {})

      assert.equals("Test", result)  -- Falls back to original
      assert.is_not_nil(error_received)
      assert.equals("renderer", error_received.data.source)
    end)
  end)

  describe("emit_input_request", function()
    local hooks, event_bus

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("returns nil when no handler", function()
      local result = hooks:emit_input_request("choice", { choices = {} })

      assert.is_nil(result)
    end)

    it("returns result from handler", function()
      hooks:register_input_handler(function(input_type, options)
        return { selected = 1 }
      end)

      local result = hooks:emit_input_request("choice", {})

      assert.same({ selected = 1 }, result)
    end)

    it("emits INPUT_REQUESTED event", function()
      local event_received = nil
      event_bus:on("INPUT_REQUESTED", function(event)
        event_received = event
      end)

      hooks:emit_input_request("text", { prompt = "Name?" })

      assert.is_not_nil(event_received)
      assert.equals("text", event_received.data.input_type)
    end)

    it("emits INPUT_RECEIVED on success", function()
      hooks:register_input_handler(function() return "response" end)

      local event_received = nil
      event_bus:on("INPUT_RECEIVED", function(event)
        event_received = event
      end)

      hooks:emit_input_request("text", {})

      assert.is_not_nil(event_received)
      assert.equals("response", event_received.data.result)
    end)

    it("emits INPUT_CANCELLED on error", function()
      hooks:register_input_handler(function()
        error("Input error")
      end)

      local event_received = nil
      event_bus:on("INPUT_CANCELLED", function(event)
        event_received = event
      end)

      hooks:emit_input_request("text", {})

      assert.is_not_nil(event_received)
    end)
  end)

  describe("emit_audio", function()
    local hooks, event_bus

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("returns nil when no handler", function()
      local result = hooks:emit_audio("play", "music.mp3", {})

      assert.is_nil(result)
    end)

    it("returns result from handler", function()
      hooks:register_audio_handler(function(action, resource, options)
        return { audio_id = 1 }
      end)

      local result = hooks:emit_audio("play", "music.mp3", {})

      assert.same({ audio_id = 1 }, result)
    end)

    it("emits AUDIO_PLAY event for play action", function()
      local event_received = nil
      event_bus:on("AUDIO_PLAY", function(event)
        event_received = event
      end)

      hooks:emit_audio("play", "music.mp3", { volume = 0.5 })

      assert.is_not_nil(event_received)
      assert.equals("music.mp3", event_received.data.resource)
    end)

    it("emits AUDIO_STOP event for stop action", function()
      local event_received = nil
      event_bus:on("AUDIO_STOP", function(event)
        event_received = event
      end)

      hooks:emit_audio("stop", "music.mp3", {})

      assert.is_not_nil(event_received)
    end)
  end)

  describe("emit_effect", function()
    local hooks, event_bus

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("returns nil when no handler", function()
      local result = hooks:emit_effect("fade_in", "element", {})

      assert.is_nil(result)
    end)

    it("returns result from handler", function()
      hooks:register_effect_handler(function(effect_type, target, options)
        return { effect_id = 1 }
      end)

      local result = hooks:emit_effect("typewriter", "text", {})

      assert.same({ effect_id = 1 }, result)
    end)

    it("emits EFFECT_START event", function()
      local event_received = nil
      event_bus:on("EFFECT_START", function(event)
        event_received = event
      end)

      hooks:emit_effect("fade_in", "element", { duration = 500 })

      assert.is_not_nil(event_received)
      assert.equals("fade_in", event_received.data.effect_type)
    end)

    it("emits EFFECT_COMPLETE on success", function()
      hooks:register_effect_handler(function() return true end)

      local event_received = nil
      event_bus:on("EFFECT_COMPLETE", function(event)
        event_received = event
      end)

      hooks:emit_effect("fade_in", "element", {})

      assert.is_not_nil(event_received)
    end)

    it("emits EFFECT_CANCELLED on error", function()
      hooks:register_effect_handler(function()
        error("Effect error")
      end)

      local event_received = nil
      event_bus:on("EFFECT_CANCELLED", function(event)
        event_received = event
      end)

      hooks:emit_effect("fade_in", "element", {})

      assert.is_not_nil(event_received)
    end)
  end)

  describe("emit_dialog", function()
    local hooks, event_bus

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("returns nil when no handler", function()
      local result = hooks:emit_dialog("alert", "Message", {})

      assert.is_nil(result)
    end)

    it("returns result from handler", function()
      hooks:register_dialog_handler(function(dialog_type, content, options)
        return true
      end)

      local result = hooks:emit_dialog("confirm", "Are you sure?", {})

      assert.is_true(result)
    end)

    it("emits DIALOG_OPEN event", function()
      local event_received = nil
      event_bus:on("DIALOG_OPEN", function(event)
        event_received = event
      end)

      hooks:emit_dialog("alert", "Hello", { title = "Info" })

      assert.is_not_nil(event_received)
      assert.equals("alert", event_received.data.dialog_type)
    end)

    it("emits DIALOG_CLOSE event", function()
      local event_received = nil
      event_bus:on("DIALOG_CLOSE", function(event)
        event_received = event
      end)

      hooks:emit_dialog("alert", "Hello", {})

      assert.is_not_nil(event_received)
    end)

    it("emits DIALOG_RESPONSE on success", function()
      hooks:register_dialog_handler(function() return "Yes" end)

      local event_received = nil
      event_bus:on("DIALOG_RESPONSE", function(event)
        event_received = event
      end)

      hooks:emit_dialog("confirm", "Continue?", {})

      assert.is_not_nil(event_received)
      assert.equals("Yes", event_received.data.result)
    end)
  end)

  describe("emit_timer", function()
    local hooks, event_bus

    before_each(function()
      event_bus = EventSystem.new()
      hooks = ClientHooks.new({ event_bus = event_bus })
    end)

    it("returns nil when no handler", function()
      local result = hooks:emit_timer("timeout", 1000, function() end)

      assert.is_nil(result)
    end)

    it("returns timer id from handler", function()
      hooks:register_timer_handler(function(action, duration, callback)
        return 123
      end)

      local result = hooks:emit_timer("timeout", 1000, function() end)

      assert.equals(123, result)
    end)

    it("emits TIMER_CREATED event for timeout", function()
      local event_received = nil
      event_bus:on("TIMER_CREATED", function(event)
        event_received = event
      end)

      hooks:emit_timer("timeout", 1000, function() end)

      assert.is_not_nil(event_received)
      assert.equals(1000, event_received.data.duration)
    end)

    it("emits TIMER_CANCELLED event for clear", function()
      local event_received = nil
      event_bus:on("TIMER_CANCELLED", function(event)
        event_received = event
      end)

      hooks:emit_timer("clear", nil, nil)

      assert.is_not_nil(event_received)
    end)
  end)

  describe("set_event_bus", function()
    it("allows late binding of event bus", function()
      local hooks = ClientHooks.new()
      local event_bus = EventSystem.new()

      hooks:set_event_bus(event_bus)

      assert.equals(event_bus, hooks._event_bus)
    end)

    it("events work after late binding", function()
      local hooks = ClientHooks.new()
      local event_bus = EventSystem.new()
      hooks:set_event_bus(event_bus)

      local event_received = nil
      event_bus:on("RENDER_REQUESTED", function(event)
        event_received = event
      end)

      hooks:emit_render("Test", {})

      assert.is_not_nil(event_received)
    end)
  end)
end)
