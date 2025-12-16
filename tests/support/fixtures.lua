-- tests/support/fixtures.lua
-- Fixture loading utilities for tests

local json = require("whisker.utils.json")

local Fixtures = {}

-- Base path for fixtures
Fixtures.BASE_PATH = "tests/fixtures"

-- Load a fixture file by path
-- @param path string - Path relative to tests/fixtures/
-- @return table - Parsed fixture data
function Fixtures.load(path)
  local full_path = Fixtures.BASE_PATH .. "/" .. path
  local file = io.open(full_path, "r")
  if not file then
    error(string.format("Fixture not found: %s", full_path), 2)
  end
  local content = file:read("*a")
  file:close()
  return json.decode(content)
end

-- Load a story fixture by name
-- @param name string - Story name (without .json extension)
-- @return table - Parsed story data
function Fixtures.load_story(name)
  return Fixtures.load("stories/" .. name .. ".json")
end

-- Load an edge case fixture by name
-- @param name string - Edge case name (without .json extension)
-- @return table - Parsed fixture data
function Fixtures.load_edge_case(name)
  return Fixtures.load("edge_cases/" .. name .. ".json")
end

-- Get raw fixture content as string
-- @param path string - Path relative to tests/fixtures/
-- @return string - Raw file content
function Fixtures.load_raw(path)
  local full_path = Fixtures.BASE_PATH .. "/" .. path
  local file = io.open(full_path, "r")
  if not file then
    error(string.format("Fixture not found: %s", full_path), 2)
  end
  local content = file:read("*a")
  file:close()
  return content
end

-- Check if a fixture exists
-- @param path string - Path relative to tests/fixtures/
-- @return boolean
function Fixtures.exists(path)
  local full_path = Fixtures.BASE_PATH .. "/" .. path
  local file = io.open(full_path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

-- List all fixture files in a directory
-- @param dir string - Directory relative to tests/fixtures/
-- @return table - Array of file names
function Fixtures.list(dir)
  local path = Fixtures.BASE_PATH .. "/" .. dir
  local files = {}
  local handle = io.popen('ls "' .. path .. '" 2>/dev/null')
  if handle then
    for file in handle:lines() do
      if file:match("%.json$") then
        table.insert(files, file:gsub("%.json$", ""))
      end
    end
    handle:close()
  end
  return files
end

return Fixtures
