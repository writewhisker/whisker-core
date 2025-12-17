-- spec/formats/ink/stitch_converter_spec.lua
-- Tests for stitch and gather conversion

describe("StitchTransformer", function()
  local StitchTransformer
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.core") then
        package.loaded[k] = nil
      end
    end

    StitchTransformer = require("whisker.formats.ink.transformers.stitch")
    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(StitchTransformer._whisker)
      assert.are.equal("StitchTransformer", StitchTransformer._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.transformers.stitch", StitchTransformer._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = StitchTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("_path_to_title", function()
    local transformer

    before_each(function()
      transformer = StitchTransformer.new()
    end)

    it("should convert snake_case to Title Case", function()
      local title = transformer:_path_to_title("my_stitch_name")
      assert.are.equal("My Stitch Name", title)
    end)

    it("should convert camelCase to Title Case", function()
      local title = transformer:_path_to_title("myStitchName")
      assert.are.equal("My Stitch Name", title)
    end)
  end)

  describe("transform", function()
    local transformer
    local ink_story

    before_each(function()
      transformer = StitchTransformer.new()
      ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")
    end)

    it("should create passage with dot notation ID", function()
      local stitch_data = { "^Test content", "\n" }
      local passage = transformer:transform(ink_story, "my_knot", "my_stitch", stitch_data, {})

      assert.are.equal("my_knot.my_stitch", passage.id)
    end)

    it("should set parent knot in metadata", function()
      local stitch_data = { "^Test content", "\n" }
      local passage = transformer:transform(ink_story, "my_knot", "my_stitch", stitch_data, {})

      assert.are.equal("my_knot", passage:get_metadata("parent_knot"))
    end)

    it("should preserve ink path when enabled", function()
      local stitch_data = { "^Test content", "\n" }
      local passage = transformer:transform(ink_story, "my_knot", "my_stitch", stitch_data, { preserve_ink_paths = true })

      assert.are.equal("my_knot.my_stitch", passage:get_metadata("ink_path"))
    end)

    it("should extract content from stitch data", function()
      local stitch_data = { "^Hello ", "^world!", "\n" }
      local passage = transformer:transform(ink_story, "knot", "stitch", stitch_data, {})

      assert.are.equal("Hello world!\n", passage:get_content())
    end)

    it("should extract tags from stitch data", function()
      local stitch_data = { { ["#"] = "my_tag" }, "^Content", "\n" }
      local passage = transformer:transform(ink_story, "knot", "stitch", stitch_data, {})

      assert.is_true(passage:has_tag("my_tag"))
    end)
  end)

  describe("find_stitches", function()
    local transformer

    before_each(function()
      transformer = StitchTransformer.new()
    end)

    it("should find stitches in knot container", function()
      local knot_data = {
        "^Knot content",
        "\n",
        {
          stitch_a = { "^Stitch A", "\n" },
          stitch_b = { "^Stitch B", "\n" }
        }
      }

      local stitches = transformer:find_stitches(knot_data)

      assert.is_table(stitches.stitch_a)
      assert.is_table(stitches.stitch_b)
    end)

    it("should return empty table for no stitches", function()
      local knot_data = { "^Knot content", "\n" }

      local stitches = transformer:find_stitches(knot_data)

      assert.are.same({}, stitches)
    end)
  end)
end)

describe("GatherTransformer", function()
  local GatherTransformer
  local InkStory

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") or k:match("^whisker%.core") then
        package.loaded[k] = nil
      end
    end

    GatherTransformer = require("whisker.formats.ink.transformers.gather")
    InkStory = require("whisker.formats.ink.story")

    -- Reset counter for consistent test results
    GatherTransformer.reset_counter()
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(GatherTransformer._whisker)
      assert.are.equal("GatherTransformer", GatherTransformer._whisker.name)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = GatherTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("transform", function()
    local transformer
    local ink_story

    before_each(function()
      transformer = GatherTransformer.new()
      ink_story = InkStory.from_file("test/fixtures/ink/minimal.json")
    end)

    it("should create named gather passage", function()
      local gather_data = { "^Gather content", "\n" }
      local passage = transformer:transform(ink_story, "my_knot", "my_gather", gather_data, {})

      assert.are.equal("my_knot.my_gather", passage.id)
    end)

    it("should create anonymous gather passage", function()
      GatherTransformer.reset_counter()
      local gather_data = { "^Anonymous gather", "\n" }
      local passage = transformer:transform(ink_story, "my_knot", nil, gather_data, {})

      assert.are.equal("my_knot._gather_1", passage.id)
      assert.is_true(passage:get_metadata("is_anonymous"))
    end)

    it("should set is_gather metadata", function()
      local gather_data = { "^Content", "\n" }
      local passage = transformer:transform(ink_story, "knot", "gather", gather_data, {})

      assert.is_true(passage:get_metadata("is_gather"))
    end)

    it("should set parent path metadata", function()
      local gather_data = { "^Content", "\n" }
      local passage = transformer:transform(ink_story, "knot.stitch", "gather", gather_data, {})

      assert.are.equal("knot.stitch", passage:get_metadata("parent_path"))
    end)

    it("should extract content", function()
      local gather_data = { "^Hello ", "^world!", "\n" }
      local passage = transformer:transform(ink_story, "knot", "gather", gather_data, {})

      assert.are.equal("Hello world!\n", passage:get_content())
    end)
  end)
end)

describe("Converter stitch integration", function()
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
    it("should include stitch transformer", function()
      local list = transformers.list()
      local has_stitch = false
      for _, name in ipairs(list) do
        if name == "stitch" then
          has_stitch = true
          break
        end
      end
      assert.is_true(has_stitch)
    end)

    it("should include gather transformer", function()
      local list = transformers.list()
      local has_gather = false
      for _, name in ipairs(list) do
        if name == "gather" then
          has_gather = true
          break
        end
      end
      assert.is_true(has_gather)
    end)

    it("should create stitch transformer", function()
      local stitch = transformers.create("stitch")
      assert.is_table(stitch)
      assert.is_function(stitch.transform)
    end)

    it("should create gather transformer", function()
      local gather = transformers.create("gather")
      assert.is_table(gather)
      assert.is_function(gather.transform)
    end)
  end)

  describe("converter with stitch transformers", function()
    it("should load stitch transformer by default", function()
      local converter = InkConverter.new()
      assert.is_not_nil(converter:get_transformer("stitch"))
    end)

    it("should load gather transformer by default", function()
      local converter = InkConverter.new()
      assert.is_not_nil(converter:get_transformer("gather"))
    end)
  end)
end)
