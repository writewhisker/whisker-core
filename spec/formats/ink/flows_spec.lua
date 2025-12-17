-- spec/formats/ink/flows_spec.lua
-- Tests for InkFlows manager

describe("InkFlows", function()
  local InkFlows
  local InkEngine
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.vendor%.tinta") then
        package.loaded[k] = nil
      end
    end
    -- Clear tinta globals
    rawset(_G, "import", nil)
    rawset(_G, "compat", nil)
    rawset(_G, "dump", nil)
    rawset(_G, "classic", nil)

    InkFlows = require("whisker.formats.ink.flows")
    InkEngine = require("whisker.formats.ink.engine")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkFlows._whisker)
      assert.are.equal("InkFlows", InkFlows._whisker.name)
    end)

    it("should have version", function()
      assert.is_string(InkFlows._whisker.version)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.flows", InkFlows._whisker.capability)
    end)
  end)

  describe("constants", function()
    it("should define DEFAULT_FLOW", function()
      assert.are.equal("DEFAULT_FLOW", InkFlows.DEFAULT_FLOW)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.is_table(flows)
    end)

    it("should store engine reference", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.are.equal(engine, flows:get_engine())
    end)
  end)

  describe("before story starts", function()
    it("should return nil for get_current", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.is_nil(flows:get_current())
    end)

    it("should return true for is_default", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.is_true(flows:is_default())
    end)

    it("should return default flow in list", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      local list = flows:list()
      assert.are.same({ InkFlows.DEFAULT_FLOW }, list)
    end)

    it("should error on create without story", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.has_error(function()
        flows:create("new_flow")
      end, "Cannot create flow: story not started")
    end)

    it("should error on switch without story", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.has_error(function()
        flows:switch("new_flow")
      end, "Cannot switch flow: story not started")
    end)

    it("should error on remove without story", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.has_error(function()
        flows:remove("new_flow")
      end, "Cannot remove flow: story not started")
    end)
  end)

  describe("validation", function()
    it("should error on empty name for create", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.has_error(function()
        flows:create("")
      end)
    end)

    it("should error on nil name for switch", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      assert.has_error(function()
        flows:switch(nil)
      end)
    end)

    it("should error on removing default flow", function()
      local engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      engine:start()
      local flows = engine:get_flows()

      assert.has_error(function()
        flows:remove(InkFlows.DEFAULT_FLOW)
      end, "Cannot remove the default flow")
    end)
  end)

  describe("engine integration", function()
    it("should get flows from engine", function()
      local engine = InkEngine.new()
      local flows = engine:get_flows()
      assert.is_table(flows)
      assert.are.equal(engine, flows:get_engine())
    end)

    it("should return same flows instance", function()
      local engine = InkEngine.new()
      local flows1 = engine:get_flows()
      local flows2 = engine:get_flows()
      assert.are.equal(flows1, flows2)
    end)
  end)

  describe("set_event_emitter", function()
    it("should set event emitter", function()
      local engine = InkEngine.new()
      local flows = InkFlows.new(engine)
      local emitter = { emit = function() end }

      flows:set_event_emitter(emitter)
      -- Should not error
    end)
  end)

  describe("with started engine", function()
    local engine
    local flows

    before_each(function()
      engine = InkEngine.new()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      engine:load(story)
      engine:start()
      flows = engine:get_flows()
    end)

    describe("get_current", function()
      it("should return current flow name", function()
        local current = flows:get_current()
        assert.is_string(current)
        assert.are.equal("DEFAULT_FLOW", current)
      end)
    end)

    describe("is_default", function()
      it("should return true initially", function()
        assert.is_true(flows:is_default())
      end)
    end)

    describe("list", function()
      it("should list active flows", function()
        local list = flows:list()
        assert.is_table(list)
        assert.is_true(#list >= 1)
      end)

      it("should include default flow", function()
        local list = flows:list()
        local has_default = false
        for _, name in ipairs(list) do
          if name == InkFlows.DEFAULT_FLOW then
            has_default = true
            break
          end
        end
        assert.is_true(has_default)
      end)
    end)

    describe("exists", function()
      it("should return true for default flow", function()
        assert.is_true(flows:exists(InkFlows.DEFAULT_FLOW))
      end)

      it("should return false for non-existent flow", function()
        assert.is_false(flows:exists("nonexistent_flow"))
      end)
    end)

    describe("create", function()
      it("should create new flow", function()
        flows:create("my_flow")
        assert.is_true(flows:exists("my_flow"))
      end)

      it("should switch to new flow after create", function()
        flows:create("my_flow")
        assert.are.equal("my_flow", flows:get_current())
      end)
    end)

    describe("switch", function()
      it("should switch between flows", function()
        flows:create("flow_a")
        flows:create("flow_b")

        assert.are.equal("flow_b", flows:get_current())

        flows:switch("flow_a")
        assert.are.equal("flow_a", flows:get_current())
      end)
    end)

    describe("switch_to_default", function()
      it("should switch to default flow", function()
        flows:create("other_flow")
        assert.is_false(flows:is_default())

        flows:switch_to_default()
        assert.is_true(flows:is_default())
      end)
    end)

    describe("remove", function()
      it("should remove a flow", function()
        flows:create("temp_flow")
        assert.is_true(flows:exists("temp_flow"))

        -- Switch away first
        flows:switch_to_default()
        flows:remove("temp_flow")

        assert.is_false(flows:exists("temp_flow"))
      end)
    end)

    describe("events", function()
      it("should emit flow.created event", function()
        local emitted = false
        local emitter = {
          emit = function(self, event, data)
            if event == "ink.flow.created" then
              emitted = true
              assert.are.equal("event_test_flow", data.name)
            end
          end
        }
        flows:set_event_emitter(emitter)

        flows:create("event_test_flow")
        assert.is_true(emitted)
      end)

      it("should emit flow.switched event", function()
        local emitted = false
        local emitter = {
          emit = function(self, event, data)
            if event == "ink.flow.switched" then
              emitted = true
            end
          end
        }

        flows:create("switch_test")
        flows:set_event_emitter(emitter)
        flows:switch_to_default()

        assert.is_true(emitted)
      end)

      it("should emit flow.removed event", function()
        local emitted = false
        local emitter = {
          emit = function(self, event, data)
            if event == "ink.flow.removed" then
              emitted = true
              assert.are.equal("remove_test", data.name)
            end
          end
        }

        flows:create("remove_test")
        flows:switch_to_default()
        flows:set_event_emitter(emitter)
        flows:remove("remove_test")

        assert.is_true(emitted)
      end)
    end)
  end)
end)
