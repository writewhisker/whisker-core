--- Modularity Violation Detection Tests
-- Tests that fail if modularity violations are introduced
-- @module tests.unit.modularity.test_violation_detection
-- @author Whisker Core Team

describe("Modularity Validation", function()
  -- Patterns that indicate cross-module requires (violations)
  local violation_patterns = {
    -- Core modules requiring other modules directly
    'require%("whisker%.core%.story"%)',
    'require%("whisker%.core%.passage"%)',
    'require%("whisker%.core%.choice"%)',

    -- Format modules requiring other modules directly
    'require%("whisker%.format%.whisker_loader"%)',

    -- Infrastructure requiring other modules directly
    'require%("whisker%.infrastructure%.save_system"%)',
  }

  -- Patterns that are allowed (DI patterns, kernel, interfaces)
  local allowed_patterns = {
    "whisker%.kernel",
    "whisker%.interfaces",
    "whisker%.vendor",
    "pcall%(require",  -- Lazy loading is OK
    "container:resolve",  -- DI resolution is OK
    "function.*require",  -- Function wrapping is OK
  }

  -- Scan a file for violations
  local function scan_file(path)
    local violations = {}
    local file = io.open(path, "r")
    if not file then
      return violations
    end

    local line_num = 0
    for line in file:lines() do
      line_num = line_num + 1

      -- Skip comments
      if line:match("^%s*%-%-") then
        goto continue
      end

      -- Check for require statements
      if line:match('require%("whisker%.') or line:match("require%('whisker%.") then
        -- Check if it's an allowed pattern
        local is_allowed = false
        for _, allowed in ipairs(allowed_patterns) do
          if line:match(allowed) then
            is_allowed = true
            break
          end
        end

        -- Check if it's a known violation pattern
        if not is_allowed then
          for _, pattern in ipairs(violation_patterns) do
            if line:match(pattern) then
              table.insert(violations, {
                path = path,
                line = line_num,
                content = line:gsub("^%s+", ""),
              })
              break
            end
          end
        end
      end

      ::continue::
    end

    file:close()
    return violations
  end

  -- List all Lua files in a directory recursively
  local function list_lua_files(dir)
    local files = {}
    local handle = io.popen('ls -1 "' .. dir .. '"/*.lua 2>/dev/null')
    if handle then
      for file in handle:lines() do
        table.insert(files, file)
      end
      handle:close()
    end
    return files
  end

  describe("lib/whisker/cli/", function()
    it("should have no cross-module violations", function()
      local files = list_lua_files("lib/whisker/cli")
      local all_violations = {}

      for _, file in ipairs(files) do
        local violations = scan_file(file)
        for _, v in ipairs(violations) do
          table.insert(all_violations, v)
        end
      end

      assert.equals(0, #all_violations,
        "Found violations in CLI: " .. #all_violations)
    end)
  end)

  describe("lib/whisker/formats/", function()
    it("should have no cross-module violations", function()
      local files = list_lua_files("lib/whisker/formats")
      local all_violations = {}

      for _, file in ipairs(files) do
        local violations = scan_file(file)
        for _, v in ipairs(violations) do
          table.insert(all_violations, v)
        end
      end

      assert.equals(0, #all_violations,
        "Found violations in formats: " .. #all_violations)
    end)
  end)

  describe("lib/whisker/infrastructure/", function()
    it("should have no cross-module violations", function()
      local files = list_lua_files("lib/whisker/infrastructure")
      local all_violations = {}

      for _, file in ipairs(files) do
        local violations = scan_file(file)
        for _, v in ipairs(violations) do
          table.insert(all_violations, v)
        end
      end

      assert.equals(0, #all_violations,
        "Found violations in infrastructure: " .. #all_violations)
    end)
  end)

  describe("DI patterns", function()
    it("should use container:resolve for dependencies", function()
      -- This test validates the pattern is being used
      local Bootstrap = require("whisker.kernel.bootstrap")
      local kernel = Bootstrap.create()

      -- All services should be resolvable through container
      assert.is_true(kernel.container:has("story_factory"))
      assert.is_true(kernel.container:has("passage_factory"))
      assert.is_true(kernel.container:has("choice_factory"))
      assert.is_true(kernel.container:has("engine_factory"))
    end)

    it("should inject dependencies rather than require them", function()
      -- Check that passage_factory gets choice_factory injected
      local Bootstrap = require("whisker.kernel.bootstrap")
      local kernel = Bootstrap.create()

      local pf = kernel.container:resolve("passage_factory")
      assert.is_not_nil(pf:get_choice_factory())
    end)
  end)

  describe("validation tool integration", function()
    it("validate_modularity.lua should report 0 violations", function()
      local handle = io.popen("lua tools/validate_modularity.lua 2>&1")
      if not handle then
        pending("Could not run validate_modularity.lua")
        return
      end

      local output = handle:read("*a")
      handle:close()

      -- The tool should report PASSED
      local passed = output:match("PASSED") ~= nil
      assert.is_true(passed, "validate_modularity.lua should pass: " .. output:sub(1, 200))
    end)
  end)
end)
