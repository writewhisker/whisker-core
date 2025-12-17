-- spec/formats/ink/converter_spec.lua
-- Tests for InkConverter

describe("InkConverter", function()
  local InkConverter
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.vendor%.tinta") or k:match("^whisker%.core") then
        package.loaded[k] = nil
      end
    end
    -- Clear tinta globals
    rawset(_G, "import", nil)
    rawset(_G, "compat", nil)
    rawset(_G, "dump", nil)
    rawset(_G, "classic", nil)

    InkConverter = require("whisker.formats.ink.converter")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkConverter._whisker)
      assert.are.equal("InkConverter", InkConverter._whisker.name)
    end)

    it("should have version", function()
      assert.is_string(InkConverter._whisker.version)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.converter", InkConverter._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local converter = InkConverter.new()
      assert.is_table(converter)
    end)

    it("should accept options", function()
      local converter = InkConverter.new({
        preserve_ink_paths = true
      })
      assert.is_table(converter)
    end)

    it("should load default transformers", function()
      local converter = InkConverter.new()
      assert.is_not_nil(converter:get_transformer("knot"))
    end)
  end)

  describe("register_transformer", function()
    it("should register a custom transformer", function()
      local converter = InkConverter.new()
      local custom = { transform = function() end }

      converter:register_transformer("custom", custom)
      assert.are.equal(custom, converter:get_transformer("custom"))
    end)
  end)

  describe("convert", function()
    it("should error without ink_story", function()
      local converter = InkConverter.new()
      assert.has_error(function()
        converter:convert(nil)
      end)
    end)

    it("should convert minimal story", function()
      local ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")
      local converter = InkConverter.new()

      local story = converter:convert(ink_story)

      assert.is_table(story)
      assert.are.equal("ink", story:get_metadata("format"))
    end)

    it("should preserve ink version in settings", function()
      local ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")
      local converter = InkConverter.new()

      local story = converter:convert(ink_story)

      assert.is_not_nil(story:get_setting("ink_version"))
      assert.are.equal("ink", story:get_setting("converted_from"))
    end)

    it("should create passages from knots", function()
      local ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")
      local converter = InkConverter.new()

      local story = converter:convert(ink_story)
      local passages = story:get_all_passages()

      -- Minimal story has knots, should create passages
      assert.is_table(passages)
    end)

    it("should set start passage", function()
      local ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")
      local converter = InkConverter.new()

      local story = converter:convert(ink_story)
      local passages = story:get_all_passages()

      -- If there are passages, start should be set
      if #passages > 0 then
        assert.is_not_nil(story:get_start_passage())
      end
    end)
  end)

  describe("convert_from_file", function()
    it("should convert from file path", function()
      local converter = InkConverter.new()

      local story = converter:convert_from_file("test/fixtures/ink/minimal.json")

      assert.is_table(story)
      assert.are.equal("ink", story:get_metadata("format"))
    end)
  end)

  describe("to_whisker static method", function()
    it("should convert using static method", function()
      local ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")

      local story = InkConverter.to_whisker(ink_story)

      assert.is_table(story)
      assert.are.equal("ink", story:get_metadata("format"))
    end)
  end)
end)

describe("InkTransformers", function()
  local transformers

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.transformers") then
        package.loaded[k] = nil
      end
    end

    transformers = require("whisker.formats.ink.transformers")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(transformers._whisker)
      assert.are.equal("InkTransformers", transformers._whisker.name)
    end)
  end)

  describe("list", function()
    it("should list available transformers", function()
      local list = transformers.list()
      assert.is_table(list)
      assert.is_true(#list >= 1)
    end)

    it("should include knot transformer", function()
      local list = transformers.list()
      local has_knot = false
      for _, name in ipairs(list) do
        if name == "knot" then
          has_knot = true
          break
        end
      end
      assert.is_true(has_knot)
    end)
  end)

  describe("create", function()
    it("should create knot transformer", function()
      local knot = transformers.create("knot")
      assert.is_table(knot)
      assert.is_function(knot.transform)
    end)

    it("should return nil for unknown transformer", function()
      local unknown = transformers.create("nonexistent")
      assert.is_nil(unknown)
    end)
  end)
end)

describe("KnotTransformer", function()
  local KnotTransformer
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.core") then
        package.loaded[k] = nil
      end
    end

    KnotTransformer = require("whisker.formats.ink.transformers.knot")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(KnotTransformer._whisker)
      assert.are.equal("KnotTransformer", KnotTransformer._whisker.name)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = KnotTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("_path_to_title", function()
    local transformer

    before_each(function()
      transformer = KnotTransformer.new()
    end)

    it("should convert snake_case to Title Case", function()
      local title = transformer:_path_to_title("my_knot_name")
      assert.are.equal("My Knot Name", title)
    end)

    it("should convert camelCase to Title Case", function()
      local title = transformer:_path_to_title("myKnotName")
      assert.are.equal("My Knot Name", title)
    end)

    it("should handle simple names", function()
      local title = transformer:_path_to_title("intro")
      assert.are.equal("Intro", title)
    end)
  end)

  describe("transform", function()
    local transformer
    local ink_story

    before_each(function()
      transformer = KnotTransformer.new()
      ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")
    end)

    it("should create passage from knot path", function()
      local knots = ink_story:get_knots()
      if #knots > 0 then
        local passage = transformer:transform(ink_story, knots[1], {})
        assert.is_table(passage)
        assert.is_string(passage.id)
      end
    end)

    it("should set passage id from knot path", function()
      local knots = ink_story:get_knots()
      if #knots > 0 then
        local passage = transformer:transform(ink_story, knots[1], {})
        assert.are.equal(knots[1], passage.id)
      end
    end)

    it("should preserve ink path in metadata when enabled", function()
      local knots = ink_story:get_knots()
      if #knots > 0 then
        local passage = transformer:transform(ink_story, knots[1], { preserve_ink_paths = true })
        assert.are.equal(knots[1], passage:get_metadata("ink_path"))
      end
    end)

    it("should generate title from path", function()
      local knots = ink_story:get_knots()
      if #knots > 0 then
        local passage = transformer:transform(ink_story, knots[1], {})
        assert.is_string(passage.title)
        -- Title should not be empty
        assert.is_true(#passage.title > 0)
      end
    end)
  end)
end)
