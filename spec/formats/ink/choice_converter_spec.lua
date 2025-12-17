-- spec/formats/ink/choice_converter_spec.lua
-- Tests for choice conversion

describe("ChoiceTransformer", function()
  local ChoiceTransformer
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.core") then
        package.loaded[k] = nil
      end
    end

    ChoiceTransformer = require("whisker.formats.ink.transformers.choice")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(ChoiceTransformer._whisker)
      assert.are.equal("ChoiceTransformer", ChoiceTransformer._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.transformers.choice", ChoiceTransformer._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = ChoiceTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("_extract_text", function()
    local transformer

    before_each(function()
      transformer = ChoiceTransformer.new()
    end)

    it("should extract text from text field", function()
      local choice_data = { text = "Go north" }
      local text = transformer:_extract_text(choice_data)
      assert.are.equal("Go north", text)
    end)

    it("should extract text from array format", function()
      local choice_data = { "^Go south" }
      local text = transformer:_extract_text(choice_data)
      assert.are.equal("Go south", text)
    end)

    it("should return empty string for nil", function()
      local text = transformer:_extract_text(nil)
      assert.are.equal("", text)
    end)

    it("should return empty string for empty table", function()
      local text = transformer:_extract_text({})
      assert.are.equal("", text)
    end)
  end)

  describe("_extract_target", function()
    local transformer

    before_each(function()
      transformer = ChoiceTransformer.new()
    end)

    it("should extract target from pathStringOnChoice", function()
      local choice_data = { pathStringOnChoice = "forest.clearing" }
      local target = transformer:_extract_target(choice_data)
      assert.are.equal("forest.clearing", target)
    end)

    it("should extract target from targetPath", function()
      local choice_data = { targetPath = "cave.entrance" }
      local target = transformer:_extract_target(choice_data)
      assert.are.equal("cave.entrance", target)
    end)

    it("should return nil for no target", function()
      local target = transformer:_extract_target({})
      assert.is_nil(target)
    end)
  end)

  describe("_is_sticky", function()
    local transformer

    before_each(function()
      transformer = ChoiceTransformer.new()
    end)

    it("should return false for once-only choice (flag 1)", function()
      local choice_data = { flags = 1 }
      assert.is_false(transformer:_is_sticky(choice_data))
    end)

    it("should return true for sticky choice (flag 0)", function()
      local choice_data = { flags = 0 }
      assert.is_true(transformer:_is_sticky(choice_data))
    end)

    it("should return true for sticky choice (flag 2)", function()
      local choice_data = { flags = 2 }
      assert.is_true(transformer:_is_sticky(choice_data))
    end)

    it("should return false for no flags", function()
      local choice_data = {}
      assert.is_false(transformer:_is_sticky(choice_data))
    end)
  end)

  describe("_is_fallback", function()
    local transformer

    before_each(function()
      transformer = ChoiceTransformer.new()
    end)

    it("should return true for fallback choice (flag 4)", function()
      local choice_data = { flags = 4 }
      assert.is_true(transformer:_is_fallback(choice_data))
    end)

    it("should return true for fallback with other flags (flag 5)", function()
      local choice_data = { flags = 5 }
      assert.is_true(transformer:_is_fallback(choice_data))
    end)

    it("should return false for non-fallback (flag 1)", function()
      local choice_data = { flags = 1 }
      assert.is_false(transformer:_is_fallback(choice_data))
    end)

    it("should return false for no flags", function()
      local choice_data = {}
      assert.is_false(transformer:_is_fallback(choice_data))
    end)
  end)

  describe("transform", function()
    local transformer

    before_each(function()
      transformer = ChoiceTransformer.new()
    end)

    it("should create choice with text and target", function()
      local choice_data = {
        text = "Go to the forest",
        pathStringOnChoice = "forest"
      }

      local choice = transformer:transform(choice_data, "start", {})

      assert.are.equal("Go to the forest", choice:get_text())
      assert.are.equal("forest", choice:get_target())
    end)

    it("should set sticky metadata", function()
      local choice_data = {
        text = "Repeat action",
        flags = 0
      }

      local choice = transformer:transform(choice_data, "start", {})

      assert.is_true(choice.metadata.sticky)
    end)

    it("should set fallback metadata", function()
      local choice_data = {
        text = "Default choice",
        flags = 4
      }

      local choice = transformer:transform(choice_data, "start", {})

      assert.is_true(choice.metadata.fallback)
    end)

    it("should preserve ink parent path", function()
      local choice_data = { text = "Choice" }

      local choice = transformer:transform(choice_data, "my_knot.stitch", { preserve_ink_paths = true })

      assert.are.equal("my_knot.stitch", choice.metadata.ink_parent)
    end)

    it("should preserve original choice index", function()
      local choice_data = {
        text = "Choice",
        originalChoiceIndex = 2
      }

      local choice = transformer:transform(choice_data, "start", {})

      assert.are.equal(2, choice.metadata.ink_choice_index)
    end)
  end)

  describe("find_choices", function()
    local transformer

    before_each(function()
      transformer = ChoiceTransformer.new()
    end)

    it("should find choice points with * marker", function()
      local container = {
        "^Some text",
        { ["*"] = true, text = "Choice 1" },
        { ["*"] = true, text = "Choice 2" }
      }

      local choices = transformer:find_choices(container)

      assert.are.equal(2, #choices)
    end)

    it("should find choice containers with c field", function()
      local container = {
        { c = { "^Choice text" }, text = "Display" }
      }

      local choices = transformer:find_choices(container)

      assert.are.equal(1, #choices)
    end)

    it("should return empty for no choices", function()
      local container = { "^Just text", "\n" }

      local choices = transformer:find_choices(container)

      assert.are.same({}, choices)
    end)

    it("should search recursively", function()
      local container = {
        {
          { ["*"] = true, text = "Nested choice" }
        }
      }

      local choices = transformer:find_choices(container)

      assert.are.equal(1, #choices)
    end)
  end)

  describe("transform_all", function()
    local transformer

    before_each(function()
      transformer = ChoiceTransformer.new()
    end)

    it("should transform all found choices", function()
      local container = {
        { ["*"] = true, text = "Choice A" },
        { ["*"] = true, text = "Choice B" }
      }

      local choices = transformer:transform_all(container, "parent", {})

      assert.are.equal(2, #choices)
      assert.are.equal("Choice A", choices[1]:get_text())
      assert.are.equal("Choice B", choices[2]:get_text())
    end)
  end)
end)

describe("Converter choice integration", function()
  local InkConverter
  local transformers

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.core") then
        package.loaded[k] = nil
      end
    end

    InkConverter = require("whisker.formats.ink.converter")
    transformers = require("whisker.formats.ink.transformers")
  end)

  describe("transformers registry", function()
    it("should include choice transformer", function()
      local list = transformers.list()
      local has_choice = false
      for _, name in ipairs(list) do
        if name == "choice" then
          has_choice = true
          break
        end
      end
      assert.is_true(has_choice)
    end)

    it("should create choice transformer", function()
      local choice = transformers.create("choice")
      assert.is_table(choice)
      assert.is_function(choice.transform)
    end)
  end)

  describe("converter with choice transformer", function()
    it("should load choice transformer by default", function()
      local converter = InkConverter.new()
      assert.is_not_nil(converter:get_transformer("choice"))
    end)
  end)
end)
