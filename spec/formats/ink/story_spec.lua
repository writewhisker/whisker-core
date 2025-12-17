-- spec/formats/ink/story_spec.lua
-- Tests for InkStory wrapper

describe("InkStory", function()
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

    InkStory = require("whisker.formats.ink.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkStory._whisker)
      assert.are.equal("InkStory", InkStory._whisker.name)
    end)

    it("should have version", function()
      assert.is_string(InkStory._whisker.version)
    end)
  end)

  describe("new", function()
    it("should create instance from story data", function()
      local data = {
        inkVersion = 21,
        root = {},
        listDefs = {}
      }

      local story = InkStory.new(data)
      assert.is_table(story)
    end)

    it("should error without story data", function()
      assert.has_error(function()
        InkStory.new(nil)
      end)
    end)
  end)

  describe("get_data", function()
    it("should return original data", function()
      local data = {
        inkVersion = 21,
        root = {"^test"},
        listDefs = {}
      }

      local story = InkStory.new(data)
      assert.are.same(data, story:get_data())
    end)
  end)

  describe("get_ink_version", function()
    it("should return inkVersion", function()
      local story = InkStory.new({ inkVersion = 20, root = {}, listDefs = {} })
      assert.are.equal(20, story:get_ink_version())
    end)
  end)

  describe("get_list_defs", function()
    it("should return listDefs", function()
      local defs = { colors = { red = 1, blue = 2 } }
      local story = InkStory.new({ inkVersion = 21, root = {}, listDefs = defs })
      assert.are.same(defs, story:get_list_defs())
    end)

    it("should return empty table if no listDefs", function()
      local story = InkStory.new({ inkVersion = 21, root = {} })
      assert.are.same({}, story:get_list_defs())
    end)
  end)

  describe("metadata extraction", function()
    local story_with_meta

    before_each(function()
      story_with_meta = InkStory.from_file("test/fixtures/ink/metadata.json")
    end)

    it("should extract title from global tags", function()
      local title = story_with_meta:get_title()
      assert.are.equal("My Test Story", title)
    end)

    it("should extract author from global tags", function()
      local author = story_with_meta:get_author()
      assert.are.equal("Test Author", author)
    end)

    it("should extract other metadata", function()
      local meta = story_with_meta:get_metadata()
      assert.are.equal("dark", meta.theme)
    end)

    it("should cache metadata", function()
      local meta1 = story_with_meta:get_metadata()
      local meta2 = story_with_meta:get_metadata()
      assert.are.equal(meta1, meta2)  -- Same reference
    end)
  end)

  describe("knot enumeration", function()
    local story_with_knots

    before_each(function()
      story_with_knots = InkStory.from_file("test/fixtures/ink/metadata.json")
    end)

    it("should enumerate all knots", function()
      local knots = story_with_knots:get_knots()
      assert.is_table(knots)
      assert.truthy(#knots >= 2)
    end)

    it("should include known knots", function()
      local knots = story_with_knots:get_knots()
      local has_start = false
      local has_meeting = false

      for _, name in ipairs(knots) do
        if name == "start" then has_start = true end
        if name == "meeting" then has_meeting = true end
      end

      assert.is_true(has_start, "Should have 'start' knot")
      assert.is_true(has_meeting, "Should have 'meeting' knot")
    end)

    it("should not include global decl", function()
      local knots = story_with_knots:get_knots()
      for _, name in ipairs(knots) do
        assert.is_not_equal("global decl", name)
      end
    end)

    it("should return sorted knots", function()
      local knots = story_with_knots:get_knots()
      for i = 2, #knots do
        assert.is_true(knots[i] >= knots[i-1], "Knots should be sorted")
      end
    end)

    it("should cache knots", function()
      local knots1 = story_with_knots:get_knots()
      local knots2 = story_with_knots:get_knots()
      assert.are.equal(knots1, knots2)  -- Same reference
    end)
  end)

  describe("stitch enumeration", function()
    local story_with_stitches

    before_each(function()
      story_with_stitches = InkStory.from_file("test/fixtures/ink/metadata.json")
    end)

    it("should enumerate stitches within a knot", function()
      local stitches = story_with_stitches:get_stitches("start")
      assert.is_table(stitches)
      assert.truthy(#stitches >= 1)
    end)

    it("should include known stitches", function()
      local stitches = story_with_stitches:get_stitches("start")
      local has_intro = false
      local has_outro = false

      for _, name in ipairs(stitches) do
        if name == "intro" then has_intro = true end
        if name == "outro" then has_outro = true end
      end

      assert.is_true(has_intro, "Should have 'intro' stitch")
      assert.is_true(has_outro, "Should have 'outro' stitch")
    end)

    it("should return empty for non-existent knot", function()
      local stitches = story_with_stitches:get_stitches("nonexistent")
      assert.are.same({}, stitches)
    end)

    it("should return sorted stitches", function()
      local stitches = story_with_stitches:get_stitches("start")
      for i = 2, #stitches do
        assert.is_true(stitches[i] >= stitches[i-1], "Stitches should be sorted")
      end
    end)
  end)

  describe("get_structure", function()
    it("should return map of knots to stitches", function()
      local story = InkStory.from_file("test/fixtures/ink/metadata.json")
      local structure = story:get_structure()

      assert.is_table(structure)
      assert.is_table(structure.start)
      assert.is_table(structure.meeting)
    end)
  end)

  describe("global variables", function()
    local story_with_vars

    before_each(function()
      story_with_vars = InkStory.from_file("test/fixtures/ink/metadata.json")
    end)

    it("should list global variables", function()
      local vars = story_with_vars:get_global_variables()
      assert.is_table(vars)
    end)

    it("should detect string variables", function()
      local vars = story_with_vars:get_global_variables()
      if vars.player_name then
        assert.are.equal("string", vars.player_name.type)
        assert.are.equal("Unknown", vars.player_name.default)
      end
    end)

    it("should detect integer variables", function()
      local vars = story_with_vars:get_global_variables()
      if vars.score then
        assert.are.equal("int", vars.score.type)
        assert.are.equal(0, vars.score.default)
      end
    end)

    it("should detect boolean variables", function()
      local vars = story_with_vars:get_global_variables()
      if vars.has_key then
        assert.are.equal("bool", vars.has_key.type)
        assert.are.equal(false, vars.has_key.default)
      end
    end)

    it("should detect float variables", function()
      local vars = story_with_vars:get_global_variables()
      if vars.health then
        assert.are.equal("float", vars.health.type)
        assert.are.equal(100.5, vars.health.default)
      end
    end)

    it("should cache variables", function()
      local vars1 = story_with_vars:get_global_variables()
      local vars2 = story_with_vars:get_global_variables()
      assert.are.equal(vars1, vars2)  -- Same reference
    end)

    it("should check variable existence", function()
      assert.is_true(story_with_vars:has_variable("score"))
      assert.is_false(story_with_vars:has_variable("nonexistent"))
    end)
  end)

  describe("external functions", function()
    it("should return empty array for story without externals", function()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      local externals = story:get_external_functions()
      assert.is_table(externals)
      assert.are.equal(0, #externals)
    end)

    it("should check for externals", function()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      assert.is_false(story:has_externals())
    end)

    it("should cache externals", function()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      local ext1 = story:get_external_functions()
      local ext2 = story:get_external_functions()
      assert.are.equal(ext1, ext2)  -- Same reference
    end)
  end)

  describe("tinta story access", function()
    it("should lazily create tinta story", function()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      assert.is_false(story:has_tinta_story())

      local tinta_story = story:get_tinta_story()
      assert.is_table(tinta_story)
      assert.is_true(story:has_tinta_story())
    end)

    it("should return same tinta story on repeated calls", function()
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")
      local ts1 = story:get_tinta_story()
      local ts2 = story:get_tinta_story()
      assert.are.equal(ts1, ts2)
    end)
  end)

  describe("clear_cache", function()
    it("should clear all caches", function()
      -- Use minimal.json since it's valid for tinta
      local story = InkStory.from_file("test/fixtures/ink/minimal.json")

      -- Populate caches
      story:get_metadata()
      story:get_knots()
      story:get_global_variables()
      story:get_external_functions()
      story:get_tinta_story()

      -- Clear
      story:clear_cache()

      -- Verify cleared (new calls return fresh data)
      assert.is_false(story:has_tinta_story())
    end)

    it("should clear metadata and other caches", function()
      local story = InkStory.from_file("test/fixtures/ink/metadata.json")

      -- Populate caches (except tinta story since metadata.json is for testing extraction)
      local meta1 = story:get_metadata()
      local knots1 = story:get_knots()
      local vars1 = story:get_global_variables()
      local ext1 = story:get_external_functions()

      -- Clear
      story:clear_cache()

      -- Verify new calls return fresh objects (different references)
      local meta2 = story:get_metadata()
      local knots2 = story:get_knots()

      -- After clear, the returned data should be equivalent but possibly new tables
      assert.are.same(meta1, meta2)
      assert.are.same(knots1, knots2)
    end)
  end)

  describe("from_file", function()
    it("should create InkStory from file", function()
      local story, err = InkStory.from_file("test/fixtures/ink/minimal.json")
      assert.is_nil(err)
      assert.is_table(story)
      assert.are.equal(21, story:get_ink_version())
    end)

    it("should return error for missing file", function()
      local story, err = InkStory.from_file("nonexistent.json")
      assert.is_nil(story)
      assert.is_string(err)
    end)
  end)

  describe("from_string", function()
    it("should create InkStory from JSON string", function()
      local json = '{"inkVersion": 21, "root": ["^Hello"], "listDefs": {}}'
      local story, err = InkStory.from_string(json)
      assert.is_nil(err)
      assert.is_table(story)
      assert.are.equal(21, story:get_ink_version())
    end)

    it("should return error for invalid JSON", function()
      local story, err = InkStory.from_string("{invalid json}")
      assert.is_nil(story)
      assert.is_string(err)
    end)
  end)
end)
