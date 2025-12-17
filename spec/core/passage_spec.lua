-- spec/core/passage_spec.lua
-- Unit tests for Passage module

describe("Passage", function()
  local Passage

  before_each(function()
    package.loaded["whisker.core.passage"] = nil
    Passage = require("whisker.core.passage")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Passage._whisker)
      assert.are.equal("Passage", Passage._whisker.name)
      assert.is_string(Passage._whisker.version)
      assert.is_table(Passage._whisker.depends)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #Passage._whisker.depends)
    end)
  end)

  describe("new", function()
    it("should create with options table", function()
      local p = Passage.new({
        id = "test_id",
        name = "Test Name",
        content = "Test content"
      })
      assert.are.equal("test_id", p.id)
      assert.are.equal("Test Name", p.name)
      assert.are.equal("Test content", p.content)
    end)

    it("should create with positional arguments", function()
      local p = Passage.new("my_id", "My Name")
      assert.are.equal("my_id", p.id)
      assert.are.equal("My Name", p.name)
    end)

    it("should set defaults", function()
      local p = Passage.new({id = "test"})
      assert.are.equal("test", p.id)
      assert.are.equal("test", p.name)
      assert.are.equal("", p.content)
      assert.are.same({}, p.tags)
      assert.are.same({}, p.choices)
      assert.are.same({x = 0, y = 0}, p.position)
    end)

    it("should include title field", function()
      local p = Passage.new({id = "test", title = "Test Title"})
      assert.are.equal("Test Title", p.title)
    end)
  end)

  describe("content", function()
    it("should set and get content", function()
      local p = Passage.new({id = "test"})
      p:set_content("Hello, world!")
      assert.are.equal("Hello, world!", p:get_content())
    end)
  end)

  describe("choices", function()
    it("should add choices", function()
      local p = Passage.new({id = "test"})
      local choice = {target = "next", text = "Go next"}
      p:add_choice(choice)
      assert.are.equal(1, #p:get_choices())
    end)

    it("should remove choices by index", function()
      local p = Passage.new({id = "test"})
      p:add_choice({target = "a"})
      p:add_choice({target = "b"})
      p:add_choice({target = "c"})
      p:remove_choice(2)
      local choices = p:get_choices()
      assert.are.equal(2, #choices)
      assert.are.equal("a", choices[1].target)
      assert.are.equal("c", choices[2].target)
    end)

    it("should clear all choices", function()
      local p = Passage.new({id = "test"})
      p:add_choice({target = "a"})
      p:add_choice({target = "b"})
      p:clear_choices()
      assert.are.equal(0, #p:get_choices())
    end)
  end)

  describe("tags", function()
    it("should add tags", function()
      local p = Passage.new({id = "test"})
      p:add_tag("important")
      assert.is_true(p:has_tag("important"))
    end)

    it("should check for non-existent tags", function()
      local p = Passage.new({id = "test"})
      assert.is_false(p:has_tag("nonexistent"))
    end)

    it("should get all tags", function()
      local p = Passage.new({id = "test"})
      p:add_tag("a")
      p:add_tag("b")
      assert.are.same({"a", "b"}, p:get_tags())
    end)

    it("should remove tags", function()
      local p = Passage.new({id = "test"})
      p:add_tag("remove_me")
      assert.is_true(p:has_tag("remove_me"))
      p:remove_tag("remove_me")
      assert.is_false(p:has_tag("remove_me"))
    end)
  end)

  describe("position", function()
    it("should set and get position", function()
      local p = Passage.new({id = "test"})
      p:set_position(100, 200)
      local x, y = p:get_position()
      assert.are.equal(100, x)
      assert.are.equal(200, y)
    end)
  end)

  describe("metadata", function()
    it("should set and get metadata", function()
      local p = Passage.new({id = "test"})
      p:set_metadata("author", "Test Author")
      assert.are.equal("Test Author", p:get_metadata("author"))
    end)

    it("should return default for missing metadata", function()
      local p = Passage.new({id = "test"})
      assert.are.equal("default", p:get_metadata("missing", "default"))
    end)

    it("should check for metadata existence", function()
      local p = Passage.new({id = "test"})
      p:set_metadata("exists", "value")
      assert.is_true(p:has_metadata("exists"))
      assert.is_false(p:has_metadata("missing"))
    end)

    it("should delete metadata", function()
      local p = Passage.new({id = "test"})
      p:set_metadata("key", "value")
      assert.is_true(p:delete_metadata("key"))
      assert.is_false(p:has_metadata("key"))
    end)

    it("should return false when deleting non-existent metadata", function()
      local p = Passage.new({id = "test"})
      assert.is_false(p:delete_metadata("nonexistent"))
    end)

    it("should clear all metadata", function()
      local p = Passage.new({id = "test"})
      p:set_metadata("a", 1)
      p:set_metadata("b", 2)
      p:clear_metadata()
      assert.is_false(p:has_metadata("a"))
      assert.is_false(p:has_metadata("b"))
    end)

    it("should return copy of all metadata", function()
      local p = Passage.new({id = "test"})
      p:set_metadata("key", "value")
      local all = p:get_all_metadata()
      assert.are.equal("value", all.key)
      -- Modifying copy shouldn't affect original
      all.key = "modified"
      assert.are.equal("value", p:get_metadata("key"))
    end)
  end)

  describe("scripts", function()
    it("should set and get on_enter script", function()
      local p = Passage.new({id = "test"})
      p:set_on_enter_script("print('enter')")
      assert.are.equal("print('enter')", p:get_on_enter_script())
    end)

    it("should set and get on_exit script", function()
      local p = Passage.new({id = "test"})
      p:set_on_exit_script("print('exit')")
      assert.are.equal("print('exit')", p:get_on_exit_script())
    end)
  end)

  describe("validate", function()
    it("should pass for valid passage", function()
      local p = Passage.new({id = "test", name = "Test"})
      local valid, err = p:validate()
      assert.is_true(valid)
    end)

    it("should fail for empty id", function()
      local p = Passage.new({id = "", name = "Test"})
      local valid, err = p:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("ID"))
    end)

    it("should validate choices with validate method", function()
      local p = Passage.new({id = "test"})
      p:add_choice({
        target = "next",
        validate = function() return true end
      })
      local valid = p:validate()
      assert.is_true(valid)
    end)

    it("should fail when choice validation fails", function()
      local p = Passage.new({id = "test"})
      p:add_choice({
        target = "next",
        validate = function() return false, "Invalid choice" end
      })
      local valid, err = p:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("Choice"))
    end)
  end)

  describe("serialize", function()
    it("should return plain table", function()
      local p = Passage.new({
        id = "test",
        name = "Test",
        content = "Content here"
      })
      local data = p:serialize()
      assert.are.equal("test", data.id)
      assert.are.equal("Test", data.name)
      assert.are.equal("Content here", data.content)
    end)

    it("should serialize choices with serialize method", function()
      local p = Passage.new({id = "test"})
      p:add_choice({
        target = "next",
        serialize = function(self) return {target = self.target, serialized = true} end
      })
      local data = p:serialize()
      assert.is_true(data.choices[1].serialized)
    end)
  end)

  describe("deserialize", function()
    it("should restore passage from data", function()
      local p = Passage.new({id = "temp"})
      p:deserialize({
        id = "restored",
        name = "Restored Name",
        content = "Restored content"
      })
      assert.are.equal("restored", p.id)
      assert.are.equal("Restored Name", p.name)
      assert.are.equal("Restored content", p.content)
    end)

    it("should use choice_restorer when provided", function()
      local p = Passage.new({id = "temp"})
      local restorer_called = false
      p:deserialize({
        id = "test",
        choices = {{target = "a"}}
      }, function(choice_data)
        restorer_called = true
        return {target = choice_data.target, restored = true}
      end)
      assert.is_true(restorer_called)
      assert.is_true(p.choices[1].restored)
    end)
  end)

  describe("restore_metatable", function()
    it("should restore metatable to plain table", function()
      local data = {id = "test", name = "Test", content = "Content"}
      local restored = Passage.restore_metatable(data)
      assert.are.equal(Passage, getmetatable(restored))
      assert.are.equal("Content", restored:get_content())
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Passage.restore_metatable(nil))
    end)

    it("should return as-is if already has metatable", function()
      local p = Passage.new({id = "test"})
      local restored = Passage.restore_metatable(p)
      assert.are.equal(p, restored)
    end)

    it("should use choice_restorer when provided", function()
      local data = {
        id = "test",
        choices = {{target = "a"}}
      }
      local restored = Passage.restore_metatable(data, function(choice)
        return {target = choice.target, restored = true}
      end)
      assert.is_true(restored.choices[1].restored)
    end)
  end)

  describe("from_table", function()
    it("should create new passage from table", function()
      local p = Passage.from_table({
        id = "from_table",
        name = "From Table",
        content = "Table content"
      })
      assert.are.equal(Passage, getmetatable(p))
      assert.are.equal("from_table", p.id)
      assert.are.equal("Table content", p:get_content())
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Passage.from_table(nil))
    end)

    it("should use choice_restorer when provided", function()
      local p = Passage.from_table({
        id = "test",
        choices = {{target = "a"}}
      }, function(choice_data)
        return {target = choice_data.target, restored = true}
      end)
      assert.is_true(p.choices[1].restored)
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      -- Check that the module can be loaded independently
      package.loaded["whisker.core.passage"] = nil
      local ok, result = pcall(require, "whisker.core.passage")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)
