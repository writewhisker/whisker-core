-- spec/services/history_spec.lua
-- Unit tests for History service

describe("History Service", function()
  local History

  before_each(function()
    package.loaded["whisker.services.history"] = nil
    History = require("whisker.services.history")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(History._whisker)
      assert.are.equal("History", History._whisker.name)
      assert.is_string(History._whisker.version)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #History._whisker.depends)
    end)
  end)

  describe("new", function()
    it("should create with empty stack", function()
      local h = History.new()
      assert.is_true(h:is_empty())
      assert.are.equal(0, h:size())
    end)

    it("should accept max_entries option", function()
      local h = History.new({max_entries = 5})
      assert.are.equal(5, h._max_entries)
    end)

    it("should accept state option", function()
      local state = {}
      local h = History.new({state = state})
      assert.are.equal(state, h:get_state_service())
    end)
  end)

  describe("push", function()
    it("should add entry to stack", function()
      local h = History.new()
      h:push("passage_1")
      assert.are.equal(1, h:size())
    end)

    it("should store passage_id", function()
      local h = History.new()
      h:push("passage_1")
      local entry = h:peek()
      assert.are.equal("passage_1", entry.passage_id)
    end)

    it("should store metadata", function()
      local h = History.new()
      h:push("passage_1", {custom = "value"})
      local entry = h:peek()
      assert.are.equal("value", entry.metadata.custom)
    end)

    it("should set timestamp", function()
      local h = History.new()
      h:push("passage_1")
      local entry = h:peek()
      assert.is_number(entry.timestamp)
    end)

    it("should capture state snapshot if available", function()
      local snapshot_called = false
      local state = {
        snapshot = function()
          snapshot_called = true
          return {test = "data"}
        end
      }
      local h = History.new({state = state})
      h:push("passage_1")
      assert.is_true(snapshot_called)
      assert.are.same({test = "data"}, h:peek().state_snapshot)
    end)

    it("should trim to max entries", function()
      local h = History.new({max_entries = 3})
      h:push("p1")
      h:push("p2")
      h:push("p3")
      h:push("p4")
      assert.are.equal(3, h:size())
      assert.are.equal("p2", h:get(1).passage_id)
    end)

    it("should emit history:pushed event", function()
      local h = History.new()
      local emitted = nil
      h:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      h:push("passage_1")
      assert.are.equal("history:pushed", emitted.event)
      assert.are.equal(1, emitted.data.stack_size)
    end)
  end)

  describe("pop", function()
    it("should remove and return last entry", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      local entry = h:pop()
      assert.are.equal("p2", entry.passage_id)
      assert.are.equal(1, h:size())
    end)

    it("should return nil when empty", function()
      local h = History.new()
      assert.is_nil(h:pop())
    end)

    it("should emit history:popped event", function()
      local h = History.new()
      h:push("p1")
      local emitted = nil
      h:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      h:pop()
      assert.are.equal("history:popped", emitted.event)
    end)
  end)

  describe("peek", function()
    it("should return last entry without removing", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      local entry = h:peek()
      assert.are.equal("p2", entry.passage_id)
      assert.are.equal(2, h:size())
    end)

    it("should return nil when empty", function()
      local h = History.new()
      assert.is_nil(h:peek())
    end)
  end)

  describe("back", function()
    it("should return previous entry", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      local entry, err = h:back()
      assert.is_nil(err)
      assert.are.equal("p1", entry.passage_id)
    end)

    it("should restore state snapshot", function()
      local restored_data = nil
      local state = {
        snapshot = function()
          return {test = "snapshot"}
        end,
        restore = function(_, data)
          restored_data = data
        end
      }
      local h = History.new({state = state})
      h:push("p1")
      h:push("p2")
      h:back()
      assert.are.same({test = "snapshot"}, restored_data)
    end)

    it("should error when less than 2 entries", function()
      local h = History.new()
      h:push("p1")
      local entry, err = h:back()
      assert.is_nil(entry)
      assert.is_string(err)
    end)

    it("should emit history:back event", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      local emitted = nil
      h:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      h:back()
      assert.are.equal("history:back", emitted.event)
    end)
  end)

  describe("can_go_back", function()
    it("should return false when empty", function()
      local h = History.new()
      assert.is_false(h:can_go_back())
    end)

    it("should return false with one entry", function()
      local h = History.new()
      h:push("p1")
      assert.is_false(h:can_go_back())
    end)

    it("should return true with two or more entries", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      assert.is_true(h:can_go_back())
    end)
  end)

  describe("clear", function()
    it("should remove all entries", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      h:clear()
      assert.is_true(h:is_empty())
    end)

    it("should emit history:cleared event", function()
      local h = History.new()
      h:push("p1")
      local emitted = nil
      h:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      h:clear()
      assert.are.equal("history:cleared", emitted.event)
      assert.are.equal(1, emitted.data.cleared_count)
    end)

    it("should not emit when already empty", function()
      local h = History.new()
      local emit_called = false
      h:set_event_emitter({
        emit = function() emit_called = true end
      })
      h:clear()
      assert.is_false(emit_called)
    end)
  end)

  describe("get_all", function()
    it("should return copy of stack", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      local all = h:get_all()
      assert.are.equal(2, #all)
      -- Modifying copy should not affect original
      all[1] = nil
      assert.are.equal(2, h:size())
    end)
  end)

  describe("get", function()
    it("should return entry at index", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      assert.are.equal("p1", h:get(1).passage_id)
      assert.are.equal("p2", h:get(2).passage_id)
    end)

    it("should return nil for invalid index", function()
      local h = History.new()
      assert.is_nil(h:get(1))
    end)
  end)

  describe("get_recent", function()
    it("should return most recent N entries", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      h:push("p3")
      local recent = h:get_recent(2)
      assert.are.equal(2, #recent)
      assert.are.equal("p3", recent[1].passage_id)
      assert.are.equal("p2", recent[2].passage_id)
    end)
  end)

  describe("on_passage_entered", function()
    it("should push passage from event with passage_id", function()
      local h = History.new()
      h:on_passage_entered({passage_id = "test"})
      assert.are.equal(1, h:size())
      assert.are.equal("test", h:peek().passage_id)
    end)

    it("should push passage from event with passage.id", function()
      local h = History.new()
      h:on_passage_entered({passage = {id = "test2"}})
      assert.are.equal("test2", h:peek().passage_id)
    end)

    it("should not push for nil event", function()
      local h = History.new()
      h:on_passage_entered(nil)
      assert.is_true(h:is_empty())
    end)
  end)

  describe("serialize/deserialize", function()
    it("should serialize stack", function()
      local h = History.new()
      h:push("p1")
      h:push("p2")
      local data = h:serialize()
      assert.is_table(data.stack)
      assert.are.equal(2, #data.stack)
    end)

    it("should deserialize stack", function()
      local h = History.new()
      h:deserialize({
        stack = {
          {passage_id = "p1", timestamp = 100},
          {passage_id = "p2", timestamp = 200}
        }
      })
      assert.are.equal(2, h:size())
      assert.are.equal("p2", h:peek().passage_id)
    end)
  end)

  describe("dependency injection", function()
    it("should set state service", function()
      local h = History.new()
      local state = {}
      h:set_state_service(state)
      assert.are.equal(state, h:get_state_service())
    end)

    it("should set event emitter", function()
      local h = History.new()
      local emitter = {}
      h:set_event_emitter(emitter)
      assert.are.equal(emitter, h:get_event_emitter())
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      package.loaded["whisker.services.history"] = nil
      local ok, result = pcall(require, "whisker.services.history")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)
