--- Dependency Graph Generator Tests
-- Tests for the dependency_graph tool
-- @module tests.tools.dependency_graph_spec
-- @author Whisker Core Team
-- @license MIT

describe("dependency_graph", function()
  local graph

  setup(function()
    -- Add tools to package path
    package.path = "tools/?.lua;" .. package.path
    graph = require("dependency_graph")
  end)

  describe("CONFIG", function()
    it("defines exit codes", function()
      assert.equal(0, graph.CONFIG.EXIT_SUCCESS)
      assert.equal(1, graph.CONFIG.EXIT_ERROR)
    end)

    it("defines output formats", function()
      assert.equal("dot", graph.CONFIG.FORMAT_DOT)
      assert.equal("text", graph.CONFIG.FORMAT_TEXT)
      assert.equal("json", graph.CONFIG.FORMAT_JSON)
    end)
  end)

  describe("path_to_module", function()
    it("converts simple file path", function()
      local result = graph.path_to_module("lib/whisker/core/engine.lua")
      assert.equal("whisker.core.engine", result)
    end)

    it("handles init.lua", function()
      local result = graph.path_to_module("lib/whisker/core/init.lua")
      assert.equal("whisker.core", result)
    end)

    it("handles nested paths", function()
      local result = graph.path_to_module("lib/whisker/formats/ink/engine.lua")
      assert.equal("whisker.formats.ink.engine", result)
    end)

    it("handles single file", function()
      local result = graph.path_to_module("lib/whisker/init.lua")
      assert.equal("whisker", result)
    end)
  end)

  describe("short_name", function()
    it("removes whisker prefix", function()
      local result = graph.short_name("lib/whisker/core/engine.lua")
      assert.equal("core.engine", result)
    end)

    it("handles init files", function()
      local result = graph.short_name("lib/whisker/core/init.lua")
      assert.equal("core", result)
    end)
  end)

  describe("parse_dependencies", function()
    local temp_file = os.tmpname() .. ".lua"

    after_each(function()
      os.remove(temp_file)
    end)

    it("finds require statements", function()
      local file = io.open(temp_file, "w")
      file:write('local Engine = require("whisker.core.engine")\n')
      file:write('local State = require("whisker.core.state")\n')
      file:write('return {}\n')
      file:close()

      local deps = graph.parse_dependencies(temp_file)
      assert.equal(2, #deps)
      assert.equal("whisker.core.engine", deps[1])
      assert.equal("whisker.core.state", deps[2])
    end)

    it("ignores non-whisker requires", function()
      local file = io.open(temp_file, "w")
      file:write('local json = require("cjson")\n')
      file:write('local lfs = require("lfs")\n')
      file:write('return {}\n')
      file:close()

      local deps = graph.parse_dependencies(temp_file)
      assert.equal(0, #deps)
    end)

    it("handles mixed requires", function()
      local file = io.open(temp_file, "w")
      file:write('local json = require("cjson")\n')
      file:write('local Engine = require("whisker.core.engine")\n')
      file:write('return {}\n')
      file:close()

      local deps = graph.parse_dependencies(temp_file)
      assert.equal(1, #deps)
      assert.equal("whisker.core.engine", deps[1])
    end)

    it("returns empty for non-existent file", function()
      local deps = graph.parse_dependencies("/non/existent/file.lua")
      assert.equal(0, #deps)
    end)
  end)

  describe("format_text", function()
    it("generates text output", function()
      -- Reset internal state
      for k in pairs(graph._modules) do graph._modules[k] = nil end
      for k in pairs(graph._dependencies) do graph._dependencies[k] = nil end
      for i = 1, #graph._cycles do graph._cycles[i] = nil end

      -- Add test data
      graph._modules["whisker.core.engine"] = { name = "core.engine", path = "lib/whisker/core/engine.lua" }
      graph._modules["whisker.core.state"] = { name = "core.state", path = "lib/whisker/core/state.lua" }
      graph._dependencies["whisker.core.engine"] = { "whisker.core.state" }
      graph._dependencies["whisker.core.state"] = {}

      local output = graph.format_text()
      assert.is_string(output)
      assert.is_truthy(output:match("Modules: 2"))
      assert.is_truthy(output:match("Dependencies: 1"))
      assert.is_truthy(output:match("Cycles: 0"))
    end)
  end)

  describe("format_dot", function()
    it("generates DOT output", function()
      -- Reset internal state
      for k in pairs(graph._modules) do graph._modules[k] = nil end
      for k in pairs(graph._dependencies) do graph._dependencies[k] = nil end
      for i = 1, #graph._cycles do graph._cycles[i] = nil end

      -- Add test data
      graph._modules["whisker.core.engine"] = { name = "core.engine", path = "lib/whisker/core/engine.lua" }
      graph._dependencies["whisker.core.engine"] = {}

      local output = graph.format_dot()
      assert.is_string(output)
      assert.is_truthy(output:match("digraph"))
      assert.is_truthy(output:match("whisker%.core%.engine"))
    end)

    it("shows edges between modules", function()
      -- Reset internal state
      for k in pairs(graph._modules) do graph._modules[k] = nil end
      for k in pairs(graph._dependencies) do graph._dependencies[k] = nil end
      for i = 1, #graph._cycles do graph._cycles[i] = nil end

      graph._modules["whisker.core.a"] = { name = "core.a", path = "lib/whisker/core/a.lua" }
      graph._modules["whisker.core.b"] = { name = "core.b", path = "lib/whisker/core/b.lua" }
      graph._dependencies["whisker.core.a"] = { "whisker.core.b" }
      graph._dependencies["whisker.core.b"] = {}

      local output = graph.format_dot()
      assert.is_truthy(output:match('"%s*whisker%.core%.a%s*"%s*%->%s*"%s*whisker%.core%.b%s*"'))
    end)
  end)

  describe("format_json", function()
    it("generates JSON output", function()
      -- Reset internal state
      for k in pairs(graph._modules) do graph._modules[k] = nil end
      for k in pairs(graph._dependencies) do graph._dependencies[k] = nil end
      for i = 1, #graph._cycles do graph._cycles[i] = nil end

      graph._modules["whisker.core.engine"] = { name = "core.engine", path = "lib/whisker/core/engine.lua" }
      graph._dependencies["whisker.core.engine"] = {}

      local output = graph.format_json()
      assert.is_string(output)
      assert.is_truthy(output:match('"modules"'))
      assert.is_truthy(output:match('"dependencies"'))
      assert.is_truthy(output:match('"cycles"'))
    end)
  end)

  describe("cycle detection", function()
    before_each(function()
      -- Reset internal state
      for k in pairs(graph._modules) do graph._modules[k] = nil end
      for k in pairs(graph._dependencies) do graph._dependencies[k] = nil end
      for i = 1, #graph._cycles do graph._cycles[i] = nil end
    end)

    it("detects no cycles in acyclic graph", function()
      graph._modules["a"] = { name = "a" }
      graph._modules["b"] = { name = "b" }
      graph._modules["c"] = { name = "c" }
      graph._dependencies["a"] = { "b" }
      graph._dependencies["b"] = { "c" }
      graph._dependencies["c"] = {}

      graph.find_cycles()
      assert.equal(0, #graph._cycles)
    end)

    it("detects simple cycle", function()
      graph._modules["a"] = { name = "a" }
      graph._modules["b"] = { name = "b" }
      graph._dependencies["a"] = { "b" }
      graph._dependencies["b"] = { "a" }

      graph.find_cycles()
      assert.is_truthy(#graph._cycles > 0)
    end)

    it("detects self-reference cycle", function()
      graph._modules["a"] = { name = "a" }
      graph._dependencies["a"] = { "a" }

      graph.find_cycles()
      assert.is_truthy(#graph._cycles > 0)
    end)
  end)
end)
