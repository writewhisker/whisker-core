-- tests/integration/script/examples_spec.lua
-- Tests that example stories parse and compile correctly

describe("Example Stories", function()
  local Compiler
  local lfs_ok, lfs

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script"] = nil
    package.loaded["whisker.script.init"] = nil

    local script = require("whisker.script")
    Compiler = script.Compiler

    -- Try to load lfs for file reading
    lfs_ok, lfs = pcall(require, "lfs")
  end)

  local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
  end

  local function get_examples_dir()
    -- Try different relative paths
    local paths = {
      "examples/script",
      "../examples/script",
      "../../examples/script",
    }

    for _, path in ipairs(paths) do
      local content = read_file(path .. "/hello.wsk")
      if content then
        return path
      end
    end

    return nil
  end

  describe("hello.wsk", function()
    it("should parse without errors", function()
      local dir = get_examples_dir()
      if not dir then
        pending("Could not find examples directory")
        return
      end

      local source = read_file(dir .. "/hello.wsk")
      assert.is_not_nil(source, "Could not read hello.wsk")

      local compiler = Compiler.new()
      local result = compiler:compile(source)

      assert.is_table(result)
      assert.is_table(result.story, "Expected story object")

      -- Count actual errors (not warnings)
      local error_count = 0
      for _, diag in ipairs(result.diagnostics or {}) do
        if diag.severity == "error" then
          error_count = error_count + 1
        end
      end
      assert.are.equal(0, error_count, "Expected no errors")
    end)

    it("should have Start and End passages", function()
      local dir = get_examples_dir()
      if not dir then
        pending("Could not find examples directory")
        return
      end

      local source = read_file(dir .. "/hello.wsk")
      local compiler = Compiler.new()
      local result = compiler:compile(source)

      assert.is_not_nil(result.story)

      -- Check for passages
      local has_start = false
      local has_end = false

      for name, _ in pairs(result.story.passages or {}) do
        if name == "Start" then has_start = true end
        if name == "End" then has_end = true end
      end

      assert.is_true(has_start, "Expected Start passage")
      assert.is_true(has_end, "Expected End passage")
    end)
  end)

  describe("tutorial.wsk", function()
    it("should parse without errors", function()
      local dir = get_examples_dir()
      if not dir then
        pending("Could not find examples directory")
        return
      end

      local source = read_file(dir .. "/tutorial.wsk")
      assert.is_not_nil(source, "Could not read tutorial.wsk")

      local compiler = Compiler.new()
      local result = compiler:compile(source)

      assert.is_table(result)
      assert.is_table(result.story, "Expected story object")
      -- May have warnings for undefined passages in tutorial
      local error_count = 0
      for _, diag in ipairs(result.diagnostics or {}) do
        if diag.severity == "error" then
          error_count = error_count + 1
        end
      end
      assert.are.equal(0, error_count, "Expected no errors (warnings ok)")
    end)

    it("should have multiple passages", function()
      local dir = get_examples_dir()
      if not dir then
        pending("Could not find examples directory")
        return
      end

      local source = read_file(dir .. "/tutorial.wsk")
      local compiler = Compiler.new()
      local result = compiler:compile(source)

      assert.is_table(result.story, "Expected story object")

      local passage_count = 0
      for _ in pairs(result.story.passages or {}) do
        passage_count = passage_count + 1
      end

      assert.is_true(passage_count >= 5, "Expected at least 5 passages, got " .. passage_count)
    end)
  end)

  describe("advanced.wsk", function()
    it("should parse without errors", function()
      local dir = get_examples_dir()
      if not dir then
        pending("Could not find examples directory")
        return
      end

      local source = read_file(dir .. "/advanced.wsk")
      assert.is_not_nil(source, "Could not read advanced.wsk")

      local compiler = Compiler.new()
      local result = compiler:compile(source)

      assert.is_table(result)
      assert.is_table(result.story, "Expected story object")
      -- May have warnings for undefined passages
      local error_count = 0
      for _, diag in ipairs(result.diagnostics or {}) do
        if diag.severity == "error" then
          error_count = error_count + 1
        end
      end
      assert.are.equal(0, error_count, "Expected no errors (warnings ok)")
    end)

    it("should have many passages", function()
      local dir = get_examples_dir()
      if not dir then
        pending("Could not find examples directory")
        return
      end

      local source = read_file(dir .. "/advanced.wsk")
      local compiler = Compiler.new()
      local result = compiler:compile(source)

      assert.is_table(result.story, "Expected story object")

      local passage_count = 0
      for _ in pairs(result.story.passages or {}) do
        passage_count = passage_count + 1
      end

      assert.is_true(passage_count >= 15, "Expected at least 15 passages, got " .. passage_count)
    end)

    it("should have metadata", function()
      local dir = get_examples_dir()
      if not dir then
        pending("Could not find examples directory")
        return
      end

      local source = read_file(dir .. "/advanced.wsk")
      local compiler = Compiler.new()
      local result = compiler:compile(source)

      assert.is_table(result.story, "Expected story object")
      assert.is_table(result.story.metadata, "Expected metadata")
      assert.is_not_nil(result.story.metadata.title or result.story.metadata.name)
    end)
  end)
end)
