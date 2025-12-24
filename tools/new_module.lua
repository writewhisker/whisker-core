#!/usr/bin/env lua
--- Module Template Generator
-- Scaffolds new DI-compliant modules with tests
-- Enforces whisker naming conventions
-- @module tools.new_module
-- @author Whisker Core Team

-- Configuration
local CONFIG = {
  EXIT_SUCCESS = 0,
  EXIT_ERROR = 1,
  LIB_DIR = "lib/whisker",
  TEST_DIR = "tests/unit",
}

-- Valid module categories
local CATEGORIES = {
  "core",
  "formats",
  "kernel",
  "media",
  "platform",
  "services",
  "vendor",
}

--- Module template
local MODULE_TEMPLATE = [[--- {title}
-- {description}
-- @module whisker.{module_path}
-- @author Whisker Core Team
-- @license MIT

local {class_name} = {}
{class_name}.__index = {class_name}

--- Dependencies injected via container
{class_name}._dependencies = {dependencies}

--- Create a new {class_name} instance
-- @param deps table Dependencies from container
-- @return {class_name}
function {class_name}.new(deps)
  local self = setmetatable({}, {class_name})

  deps = deps or {}
{dep_assignments}
  return self
end

--- Create via container pattern
-- @param container table DI container
-- @return {class_name}
function {class_name}.create(container)
  local deps = {}
  if container and container.has then
{container_resolves}
  end
  return {class_name}.new(deps)
end

-- Add your methods here

return {class_name}
]]

--- Test template
local TEST_TEMPLATE = [[--- {class_name} Tests
-- Unit tests for {module_path}
-- @module tests.unit.{test_module_path}
-- @author Whisker Core Team
-- @license MIT

describe("{class_name}", function()
  local {class_name}
  local mock_deps

  before_each(function()
    mock_deps = {
{mock_deps}
    }
    {class_name} = require("whisker.{module_path}")
  end)

  describe("new", function()
    it("creates instance with deps", function()
      local instance = {class_name}.new(mock_deps)
      assert.is_not_nil(instance)
    end)

    it("creates instance without deps", function()
      local instance = {class_name}.new()
      assert.is_not_nil(instance)
    end)
  end)

  describe("create", function()
    it("creates via container pattern", function()
      local mock_container = {
        has = function(_, name)
          return mock_deps[name] ~= nil
        end,
        resolve = function(_, name)
          return mock_deps[name]
        end,
      }

      local instance = {class_name}.create(mock_container)
      assert.is_not_nil(instance)
    end)
  end)

  -- Add your test cases here
end)
]]

--- Convert module path to class name
-- @param module_path string e.g., "core.engine"
-- @return string e.g., "Engine"
local function to_class_name(module_path)
  local name = module_path:match("([^%.]+)$")
  if not name then
    return module_path
  end
  -- Convert snake_case to PascalCase
  local result = name:gsub("_(.)", function(c)
    return c:upper()
  end)
  result = result:sub(1, 1):upper() .. result:sub(2)
  return result
end

--- Convert module path to title
-- @param module_path string e.g., "core.engine"
-- @return string e.g., "Core Engine"
local function to_title(module_path)
  local name = module_path:match("([^%.]+)$")
  if not name then
    return module_path
  end
  -- Convert snake_case to Title Case
  local result = name:gsub("_(.)", function(c)
    return " " .. c:upper()
  end)
  result = result:sub(1, 1):upper() .. result:sub(2)
  return result
end

--- Check if string is valid module name
-- @param name string
-- @return boolean, string error message if invalid
local function is_valid_name(name)
  if not name or name == "" then
    return false, "Name cannot be empty"
  end
  if name:match("^%d") then
    return false, "Name cannot start with a number"
  end
  if name:match("[^a-z0-9_]") then
    return false, "Name must be lowercase with underscores only"
  end
  return true
end

--- Check if category is valid
-- @param category string
-- @return boolean
local function is_valid_category(category)
  for _, c in ipairs(CATEGORIES) do
    if c == category then
      return true
    end
  end
  return false
end

--- Generate module content
-- @param opts table Options
-- @return string Module content
local function generate_module(opts)
  local class_name = opts.class_name
  local module_path = opts.module_path
  local deps = opts.dependencies or { "logger", "event_bus" }
  local description = opts.description or "TODO: Add description"

  -- Format dependencies array
  local deps_str = '{ "' .. table.concat(deps, '", "') .. '" }'

  -- Format dependency assignments
  local assignments = {}
  for _, dep in ipairs(deps) do
    table.insert(assignments, string.format("  self.%s = deps.%s", dep, dep))
  end
  local dep_assignments = table.concat(assignments, "\n")

  -- Format container resolves
  local resolves = {}
  for _, dep in ipairs(deps) do
    table.insert(resolves, string.format('    if container:has("%s") then\n      deps.%s = container:resolve("%s")\n    end', dep, dep, dep))
  end
  local container_resolves = table.concat(resolves, "\n")

  local content = MODULE_TEMPLATE
  content = content:gsub("{title}", to_title(module_path))
  content = content:gsub("{description}", description)
  content = content:gsub("{module_path}", module_path)
  content = content:gsub("{class_name}", class_name)
  content = content:gsub("{dependencies}", deps_str)
  content = content:gsub("{dep_assignments}", dep_assignments)
  content = content:gsub("{container_resolves}", container_resolves)

  return content
end

--- Generate test content
-- @param opts table Options
-- @return string Test content
local function generate_test(opts)
  local class_name = opts.class_name
  local module_path = opts.module_path
  local deps = opts.dependencies or { "logger", "event_bus" }

  -- Format test module path
  local test_module_path = module_path:gsub("%.", "/")

  -- Format mock deps
  local mocks = {}
  for _, dep in ipairs(deps) do
    if dep == "logger" then
      table.insert(mocks, string.format('      %s = { info = function() end, warn = function() end, error = function() end },', dep))
    elseif dep == "event_bus" then
      table.insert(mocks, string.format('      %s = { emit = function() end, on = function() end },', dep))
    else
      table.insert(mocks, string.format('      %s = {},', dep))
    end
  end
  local mock_deps = table.concat(mocks, "\n")

  local content = TEST_TEMPLATE
  content = content:gsub("{class_name}", class_name)
  content = content:gsub("{module_path}", module_path)
  content = content:gsub("{test_module_path}", test_module_path)
  content = content:gsub("{mock_deps}", mock_deps)

  return content
end

--- Create file if it doesn't exist
-- @param path string File path
-- @param content string File content
-- @return boolean, string error if failed
local function create_file(path, content)
  -- Check if file exists
  local existing = io.open(path, "r")
  if existing then
    existing:close()
    return false, "File already exists: " .. path
  end

  -- Create parent directories
  local dir = path:match("(.+)/[^/]+$")
  if dir then
    os.execute('mkdir -p "' .. dir .. '"')
  end

  -- Write file
  local file = io.open(path, "w")
  if not file then
    return false, "Cannot create file: " .. path
  end
  file:write(content)
  file:close()

  return true
end

--- Print usage information
local function print_usage()
  print("Usage: lua tools/new_module.lua [OPTIONS] <category>.<name>")
  print("")
  print("Creates a new DI-compliant module with tests.")
  print("")
  print("Arguments:")
  print("  category.name    Module path (e.g., core.my_feature)")
  print("")
  print("Options:")
  print("  --deps=a,b,c     Dependencies to inject (default: logger,event_bus)")
  print("  --desc=TEXT      Module description")
  print("  --dry-run        Show what would be created without creating")
  print("  --help           Show this help message")
  print("")
  print("Categories:")
  for _, c in ipairs(CATEGORIES) do
    print("  " .. c)
  end
  print("")
  print("Examples:")
  print("  lua tools/new_module.lua core.my_feature")
  print("  lua tools/new_module.lua --deps=logger,event_bus,state media.player")
  print("  lua tools/new_module.lua --dry-run services.analytics")
end

--- Main entry point
local function main(args)
  local opts = {
    dry_run = false,
    dependencies = { "logger", "event_bus" },
    description = nil,
    module_path = nil,
  }

  -- Parse arguments
  for _, arg in ipairs(args) do
    if arg == "--help" or arg == "-h" then
      print_usage()
      return CONFIG.EXIT_SUCCESS
    elseif arg == "--dry-run" then
      opts.dry_run = true
    elseif arg:match("^--deps=") then
      local deps_str = arg:match("^--deps=(.+)$")
      opts.dependencies = {}
      for dep in deps_str:gmatch("[^,]+") do
        table.insert(opts.dependencies, dep:match("^%s*(.-)%s*$"))
      end
    elseif arg:match("^--desc=") then
      opts.description = arg:match("^--desc=(.+)$")
    elseif not arg:match("^%-") then
      opts.module_path = arg
    end
  end

  -- Validate module path
  if not opts.module_path then
    io.stderr:write("Error: Module path required\n\n")
    print_usage()
    return CONFIG.EXIT_ERROR
  end

  -- Parse category and name
  local category, name = opts.module_path:match("^([^%.]+)%.(.+)$")
  if not category or not name then
    io.stderr:write("Error: Module path must be category.name (e.g., core.my_feature)\n")
    return CONFIG.EXIT_ERROR
  end

  -- Validate category
  if not is_valid_category(category) then
    io.stderr:write("Error: Invalid category '" .. category .. "'\n")
    io.stderr:write("Valid categories: " .. table.concat(CATEGORIES, ", ") .. "\n")
    return CONFIG.EXIT_ERROR
  end

  -- Validate name
  local valid, err = is_valid_name(name)
  if not valid then
    io.stderr:write("Error: " .. err .. "\n")
    return CONFIG.EXIT_ERROR
  end

  -- Generate paths
  local module_file = CONFIG.LIB_DIR .. "/" .. opts.module_path:gsub("%.", "/") .. ".lua"
  local test_file = CONFIG.TEST_DIR .. "/" .. opts.module_path:gsub("%.", "/") .. "_spec.lua"

  opts.class_name = to_class_name(name)

  -- Generate content
  local module_content = generate_module(opts)
  local test_content = generate_test(opts)

  if opts.dry_run then
    print("Would create:")
    print("  " .. module_file)
    print("  " .. test_file)
    print("")
    print("Module content:")
    print("---------------")
    print(module_content)
    print("")
    print("Test content:")
    print("-------------")
    print(test_content)
    return CONFIG.EXIT_SUCCESS
  end

  -- Create files
  local ok, err1 = create_file(module_file, module_content)
  if not ok then
    io.stderr:write("Error: " .. err1 .. "\n")
    return CONFIG.EXIT_ERROR
  end
  print("Created: " .. module_file)

  ok, err1 = create_file(test_file, test_content)
  if not ok then
    io.stderr:write("Error: " .. err1 .. "\n")
    return CONFIG.EXIT_ERROR
  end
  print("Created: " .. test_file)

  print("")
  print("Next steps:")
  print("  1. Edit " .. module_file .. " to add your implementation")
  print("  2. Edit " .. test_file .. " to add your tests")
  print("  3. Run: busted " .. test_file)

  return CONFIG.EXIT_SUCCESS
end

-- Export for testing
local M = {
  CONFIG = CONFIG,
  CATEGORIES = CATEGORIES,
  to_class_name = to_class_name,
  to_title = to_title,
  is_valid_name = is_valid_name,
  is_valid_category = is_valid_category,
  generate_module = generate_module,
  generate_test = generate_test,
  create_file = create_file,
  main = main,
}

-- Run if executed directly
if arg and arg[0] and arg[0]:match("new_module%.lua$") then
  os.exit(main(arg))
end

return M
