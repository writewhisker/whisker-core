--- Modularity Validator Tests
-- Tests for the validate_modularity tool
-- @module tests.tools.validate_modularity_spec
-- @author Whisker Core Team
-- @license MIT

describe("validate_modularity", function()
  local validator

  setup(function()
    -- Add tools to package path
    package.path = "tools/?.lua;" .. package.path
    validator = require("validate_modularity")
  end)

  describe("RULES", function()
    it("has defined rules", function()
      assert.is_table(validator.RULES)
      assert.is_truthy(#validator.RULES > 0)
    end)

    it("each rule has required fields", function()
      for _, rule in ipairs(validator.RULES) do
        assert.is_string(rule.id, "Rule missing id")
        assert.is_string(rule.name, "Rule missing name")
        assert.is_string(rule.description, "Rule missing description")
        assert.is_string(rule.severity, "Rule missing severity")
      end
    end)

    it("severity values are valid", function()
      for _, rule in ipairs(validator.RULES) do
        local valid = rule.severity == validator.SEVERITY.ERROR or
                     rule.severity == validator.SEVERITY.WARNING or
                     rule.severity == validator.SEVERITY.INFO
        assert.is_true(valid, "Invalid severity for rule " .. rule.id)
      end
    end)
  end)

  describe("SEVERITY", function()
    it("defines error level", function()
      assert.equal("error", validator.SEVERITY.ERROR)
    end)

    it("defines warning level", function()
      assert.equal("warning", validator.SEVERITY.WARNING)
    end)

    it("defines info level", function()
      assert.equal("info", validator.SEVERITY.INFO)
    end)
  end)

  describe("CONFIG", function()
    it("defines exit codes", function()
      assert.equal(0, validator.CONFIG.EXIT_SUCCESS)
      assert.equal(1, validator.CONFIG.EXIT_VIOLATIONS)
      assert.equal(2, validator.CONFIG.EXIT_ERROR)
    end)

    it("defines output formats", function()
      assert.equal("text", validator.CONFIG.FORMAT_TEXT)
      assert.equal("json", validator.CONFIG.FORMAT_JSON)
      assert.equal("ci", validator.CONFIG.FORMAT_CI)
    end)
  end)

  describe("is_file_allowed", function()
    it("returns false when no allowed_files", function()
      assert.is_false(validator.is_file_allowed("test.lua", nil))
    end)

    it("returns false for non-matching file", function()
      local allowed = { "init%.lua$" }
      assert.is_false(validator.is_file_allowed("engine.lua", allowed))
    end)

    it("returns true for matching file", function()
      local allowed = { "init%.lua$" }
      assert.is_true(validator.is_file_allowed("path/to/init.lua", allowed))
    end)

    it("matches multiple patterns", function()
      local allowed = { "spec%.lua$", "init%.lua$" }
      assert.is_true(validator.is_file_allowed("test_spec.lua", allowed))
      assert.is_true(validator.is_file_allowed("init.lua", allowed))
      assert.is_false(validator.is_file_allowed("engine.lua", allowed))
    end)
  end)

  describe("is_require_allowed", function()
    it("returns false when no allowed_requires", function()
      assert.is_false(validator.is_require_allowed("whisker.core", nil))
    end)

    it("returns false for non-matching require", function()
      local allowed = { "interfaces" }
      assert.is_false(validator.is_require_allowed("core.engine", allowed))
    end)

    it("returns true for matching require", function()
      local allowed = { "interfaces" }
      assert.is_true(validator.is_require_allowed("interfaces", allowed))
    end)

    it("matches pattern-based requires", function()
      local allowed = { "interfaces%..*" }
      assert.is_true(validator.is_require_allowed("interfaces.engine", allowed))
      assert.is_true(validator.is_require_allowed("interfaces.state", allowed))
    end)

    it("matches vendor patterns", function()
      local allowed = { "vendor%..*" }
      assert.is_true(validator.is_require_allowed("vendor.codecs.json_codec", allowed))
      assert.is_true(validator.is_require_allowed("vendor.runtimes.ink_runtime", allowed))
    end)
  end)

  describe("check_file", function()
    -- Create a temporary test file for testing
    local temp_file = os.tmpname() .. ".lua"

    after_each(function()
      os.remove(temp_file)
    end)

    it("returns empty for non-existent file", function()
      local issues = validator.check_file("/non/existent/file.lua")
      assert.is_table(issues)
      assert.equal(0, #issues)
    end)

    it("detects direct require violation", function()
      local file = io.open(temp_file, "w")
      file:write('local M = require("whisker.formats.something")\n')
      file:write('return M\n')
      file:close()

      local issues = validator.check_file(temp_file)
      assert.is_true(#issues > 0)

      local found_violation = false
      for _, issue in ipairs(issues) do
        if issue.rule_id == "DIRECT_REQUIRE" then
          found_violation = true
          break
        end
      end
      assert.is_true(found_violation, "Should detect DIRECT_REQUIRE violation")
    end)

    it("allows interface requires", function()
      local file = io.open(temp_file, "w")
      file:write('local I = require("whisker.interfaces")\n')
      file:write('return {}\n')
      file:close()

      local issues = validator.check_file(temp_file)
      local found_violation = false
      for _, issue in ipairs(issues) do
        if issue.rule_id == "DIRECT_REQUIRE" and issue.detail:match("interfaces") then
          found_violation = true
          break
        end
      end
      assert.is_false(found_violation, "Should not flag interface requires")
    end)

    it("detects direct vendor require", function()
      local file = io.open(temp_file, "w")
      file:write('local json = require("cjson")\n')
      file:write('return {}\n')
      file:close()

      local issues = validator.check_file(temp_file)
      local found_violation = false
      for _, issue in ipairs(issues) do
        if issue.rule_id == "DIRECT_VENDOR" then
          found_violation = true
          break
        end
      end
      assert.is_true(found_violation, "Should detect DIRECT_VENDOR violation")
    end)

    it("skips comments", function()
      local file = io.open(temp_file, "w")
      file:write('-- local M = require("whisker.formats.something")\n')
      file:write('return {}\n')
      file:close()

      local issues = validator.check_file(temp_file)
      local found_violation = false
      for _, issue in ipairs(issues) do
        if issue.rule_id == "DIRECT_REQUIRE" then
          found_violation = true
          break
        end
      end
      assert.is_false(found_violation, "Should skip commented lines")
    end)
  end)

  describe("rule: DIRECT_REQUIRE", function()
    it("has correct id", function()
      local rule = validator.RULES[1]
      assert.equal("DIRECT_REQUIRE", rule.id)
    end)

    it("has error severity", function()
      local rule = validator.RULES[1]
      assert.equal(validator.SEVERITY.ERROR, rule.severity)
    end)

    it("has allowed_requires", function()
      local rule = validator.RULES[1]
      assert.is_table(rule.allowed_requires)
      assert.is_truthy(#rule.allowed_requires > 0)
    end)
  end)

  describe("rule: DIRECT_VENDOR", function()
    local rule

    setup(function()
      for _, r in ipairs(validator.RULES) do
        if r.id == "DIRECT_VENDOR" then
          rule = r
          break
        end
      end
    end)

    it("exists", function()
      assert.is_not_nil(rule)
    end)

    it("has error severity", function()
      assert.equal(validator.SEVERITY.ERROR, rule.severity)
    end)

    it("has patterns for vendor requires", function()
      assert.is_table(rule.patterns)
      assert.is_truthy(#rule.patterns > 0)
    end)

    it("allows vendor abstraction files", function()
      assert.is_table(rule.allowed_files)
      local found_codecs = false
      for _, pattern in ipairs(rule.allowed_files) do
        if pattern:match("codecs") then
          found_codecs = true
          break
        end
      end
      assert.is_true(found_codecs)
    end)
  end)

  describe("rule: MISSING_DEPENDENCIES", function()
    local rule

    setup(function()
      for _, r in ipairs(validator.RULES) do
        if r.id == "MISSING_DEPENDENCIES" then
          rule = r
          break
        end
      end
    end)

    it("exists", function()
      assert.is_not_nil(rule)
    end)

    it("has warning severity", function()
      assert.equal(validator.SEVERITY.WARNING, rule.severity)
    end)

    it("has check function", function()
      assert.is_function(rule.check)
    end)

    it("check detects missing _dependencies", function()
      local content = [[
local M = {}
function M.new(deps)
  return {}
end
return M
]]
      local is_violation = rule.check(content, "test.lua")
      assert.is_true(is_violation)
    end)

    it("check passes when _dependencies present", function()
      local content = [[
local M = {}
M._dependencies = {"logger"}
function M.new(deps)
  return {}
end
return M
]]
      local is_violation = rule.check(content, "test.lua")
      assert.is_false(is_violation)
    end)
  end)
end)
