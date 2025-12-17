-- spec/core/choice_spec.lua
-- Unit tests for Choice module

describe("Choice", function()
  local Choice

  before_each(function()
    package.loaded["whisker.core.choice"] = nil
    Choice = require("whisker.core.choice")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Choice._whisker)
      assert.are.equal("Choice", Choice._whisker.name)
      assert.is_string(Choice._whisker.version)
      assert.is_table(Choice._whisker.depends)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #Choice._whisker.depends)
    end)
  end)

  describe("new", function()
    it("should create with options table", function()
      local c = Choice.new({
        text = "Go north",
        target = "north_room"
      })
      assert.are.equal("Go north", c.text)
      assert.are.equal("north_room", c:get_target())
    end)

    it("should create with positional arguments", function()
      local c = Choice.new("Go south", "south_room")
      assert.are.equal("Go south", c.text)
      assert.are.equal("south_room", c:get_target())
    end)

    it("should auto-generate id if not provided", function()
      local c = Choice.new({text = "Test", target = "test"})
      assert.is_string(c.id)
      assert.is_truthy(c.id:match("^ch_"))
    end)

    it("should preserve provided id", function()
      local c = Choice.new({id = "custom_id", text = "Test", target = "test"})
      assert.are.equal("custom_id", c.id)
    end)

    it("should set defaults", function()
      local c = Choice.new({target = "test"})
      assert.are.equal("", c.text)
      assert.is_nil(c.condition)
      assert.is_nil(c.action)
      assert.are.same({}, c.metadata)
    end)

    it("should accept target_passage as alias", function()
      local c = Choice.new({text = "Test", target_passage = "room_a"})
      assert.are.equal("room_a", c:get_target())
    end)
  end)

  describe("text", function()
    it("should set and get text", function()
      local c = Choice.new({target = "test"})
      c:set_text("New text")
      assert.are.equal("New text", c:get_text())
    end)
  end)

  describe("target", function()
    it("should set and get target", function()
      local c = Choice.new({text = "Test", target = "old"})
      c:set_target("new_target")
      assert.are.equal("new_target", c:get_target())
    end)

    it("should keep target_passage alias in sync", function()
      local c = Choice.new({text = "Test", target = "old"})
      c:set_target("new_target")
      assert.are.equal("new_target", c.target_passage)
    end)

    it("should use string IDs not object references", function()
      local c = Choice.new({text = "Test", target = "room_id"})
      assert.is_string(c:get_target())
    end)
  end)

  describe("condition", function()
    it("should set and get condition", function()
      local c = Choice.new({text = "Test", target = "test"})
      c:set_condition("has_key == true")
      assert.are.equal("has_key == true", c:get_condition())
    end)

    it("should detect when condition exists", function()
      local c = Choice.new({text = "Test", target = "test"})
      assert.is_false(c:has_condition())
      c:set_condition("health > 0")
      assert.is_true(c:has_condition())
    end)

    it("should treat empty string as no condition", function()
      local c = Choice.new({text = "Test", target = "test", condition = ""})
      assert.is_false(c:has_condition())
    end)

    it("should clear condition", function()
      local c = Choice.new({text = "Test", target = "test", condition = "x > 0"})
      assert.is_true(c:has_condition())
      c:clear_condition()
      assert.is_false(c:has_condition())
    end)
  end)

  describe("action", function()
    it("should set and get action", function()
      local c = Choice.new({text = "Test", target = "test"})
      c:set_action("gold = gold + 10")
      assert.are.equal("gold = gold + 10", c:get_action())
    end)

    it("should detect when action exists", function()
      local c = Choice.new({text = "Test", target = "test"})
      assert.is_false(c:has_action())
      c:set_action("score = score + 1")
      assert.is_true(c:has_action())
    end)

    it("should treat empty string as no action", function()
      local c = Choice.new({text = "Test", target = "test", action = ""})
      assert.is_false(c:has_action())
    end)

    it("should clear action", function()
      local c = Choice.new({text = "Test", target = "test", action = "x = 1"})
      assert.is_true(c:has_action())
      c:clear_action()
      assert.is_false(c:has_action())
    end)
  end)

  describe("metadata", function()
    it("should set and get metadata", function()
      local c = Choice.new({text = "Test", target = "test"})
      c:set_metadata("tooltip", "Click to proceed")
      assert.are.equal("Click to proceed", c:get_metadata("tooltip"))
    end)

    it("should return default for missing metadata", function()
      local c = Choice.new({text = "Test", target = "test"})
      assert.are.equal("default", c:get_metadata("missing", "default"))
    end)

    it("should check for metadata existence", function()
      local c = Choice.new({text = "Test", target = "test"})
      c:set_metadata("exists", "value")
      assert.is_true(c:has_metadata("exists"))
      assert.is_false(c:has_metadata("missing"))
    end)

    it("should delete metadata", function()
      local c = Choice.new({text = "Test", target = "test"})
      c:set_metadata("key", "value")
      assert.is_true(c:delete_metadata("key"))
      assert.is_false(c:has_metadata("key"))
    end)

    it("should return false when deleting non-existent metadata", function()
      local c = Choice.new({text = "Test", target = "test"})
      assert.is_false(c:delete_metadata("nonexistent"))
    end)

    it("should clear all metadata", function()
      local c = Choice.new({text = "Test", target = "test"})
      c:set_metadata("a", 1)
      c:set_metadata("b", 2)
      c:clear_metadata()
      assert.is_false(c:has_metadata("a"))
      assert.is_false(c:has_metadata("b"))
    end)

    it("should return copy of all metadata", function()
      local c = Choice.new({text = "Test", target = "test"})
      c:set_metadata("key", "value")
      local all = c:get_all_metadata()
      assert.are.equal("value", all.key)
      -- Modifying copy shouldn't affect original
      all.key = "modified"
      assert.are.equal("value", c:get_metadata("key"))
    end)
  end)

  describe("validate", function()
    it("should pass for valid choice", function()
      local c = Choice.new({text = "Go", target = "room"})
      local valid, err = c:validate()
      assert.is_true(valid)
    end)

    it("should fail for empty text", function()
      local c = Choice.new({text = "", target = "room"})
      local valid, err = c:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("text"))
    end)

    it("should fail for missing target", function()
      local c = Choice.new({text = "Go"})
      local valid, err = c:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("target"))
    end)
  end)

  describe("serialize", function()
    it("should return plain table", function()
      local c = Choice.new({
        id = "choice_1",
        text = "Go north",
        target = "north_room",
        condition = "has_key",
        action = "took_key = true"
      })
      local data = c:serialize()
      assert.are.equal("choice_1", data.id)
      assert.are.equal("Go north", data.text)
      assert.are.equal("north_room", data.target)
      assert.are.equal("has_key", data.condition)
      assert.are.equal("took_key = true", data.action)
    end)

    it("should include target_passage alias", function()
      local c = Choice.new({text = "Go", target = "room"})
      local data = c:serialize()
      assert.are.equal("room", data.target_passage)
    end)
  end)

  describe("deserialize", function()
    it("should restore choice from data", function()
      local c = Choice.new({text = "temp", target = "temp"})
      c:deserialize({
        id = "restored_id",
        text = "Restored text",
        target = "restored_target"
      })
      assert.are.equal("restored_id", c.id)
      assert.are.equal("Restored text", c.text)
      assert.are.equal("restored_target", c:get_target())
    end)

    it("should generate id if not in data", function()
      local c = Choice.new({text = "temp", target = "temp"})
      c:deserialize({text = "No ID", target = "test"})
      assert.is_truthy(c.id:match("^ch_"))
    end)

    it("should accept target_passage alias", function()
      local c = Choice.new({text = "temp", target = "temp"})
      c:deserialize({text = "Test", target_passage = "from_alias"})
      assert.are.equal("from_alias", c:get_target())
    end)
  end)

  describe("restore_metatable", function()
    it("should restore metatable to plain table", function()
      local data = {id = "test", text = "Test", target = "room"}
      local restored = Choice.restore_metatable(data)
      assert.are.equal(Choice, getmetatable(restored))
      assert.are.equal("Test", restored:get_text())
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Choice.restore_metatable(nil))
    end)

    it("should return as-is if already has metatable", function()
      local c = Choice.new({text = "Test", target = "room"})
      local restored = Choice.restore_metatable(c)
      assert.are.equal(c, restored)
    end)

    it("should set target alias", function()
      local data = {text = "Test", target_passage = "room"}
      local restored = Choice.restore_metatable(data)
      assert.are.equal("room", restored.target)
    end)
  end)

  describe("from_table", function()
    it("should create new choice from table", function()
      local c = Choice.from_table({
        id = "from_table",
        text = "From Table",
        target = "table_room"
      })
      assert.are.equal(Choice, getmetatable(c))
      assert.are.equal("from_table", c.id)
      assert.are.equal("From Table", c:get_text())
      assert.are.equal("table_room", c:get_target())
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Choice.from_table(nil))
    end)

    it("should accept target_passage alias", function()
      local c = Choice.from_table({text = "Test", target_passage = "alias_room"})
      assert.are.equal("alias_room", c:get_target())
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      -- Check that the module can be loaded independently
      package.loaded["whisker.core.choice"] = nil
      local ok, result = pcall(require, "whisker.core.choice")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)
