-- whisker/vendor/tinta/init.lua
-- Entry point for vendored tinta Ink runtime
-- Adapted from https://github.com/smwhr/tinta

local tinta = {}

-- Base path for all tinta modules
local BASE = "whisker.vendor.tinta"

-- Convert tinta's import path (e.g., "../engine/story") to require path
-- The import paths are relative to the tinta source root
local function tinta_import(path)
  -- Remove leading ../ sequences (they're all relative to source/)
  path = path:gsub("^%.%./", "")
  path = path:gsub("^%.%./", "")
  path = path:gsub("^%.%./", "")

  -- Convert / to .
  path = path:gsub("/", ".")

  -- Build full require path
  local full_path = BASE .. "." .. path
  return require(full_path)
end

-- Initialize tinta globals
local function init_globals()
  -- Set up global import function if not present
  if not rawget(_G, "import") then
    rawset(_G, "import", tinta_import)
  end

  -- Set up compatibility layer
  if not rawget(_G, "compat") then
    if _VERSION == "Lua 5.1" then
      rawset(_G, "compat", require(BASE .. ".compat.lua51"))
    else
      rawset(_G, "compat", require(BASE .. ".compat.lua54"))
    end
  end

  -- Load dump utility if needed
  if not rawget(_G, "dump") then
    rawset(_G, "dump", require(BASE .. ".libs.dump"))
  end
end

-- Get Story constructor
function tinta.Story()
  init_globals()
  return require(BASE .. ".engine.story")
end

-- Get the initialized Story class
function tinta.get_story_class()
  return tinta.Story()
end

-- Create a new story from a definition table
function tinta.create_story(story_definition)
  local Story = tinta.Story()
  return Story(story_definition)
end

-- Clean up globals (optional, for testing)
function tinta.cleanup()
  rawset(_G, "import", nil)
  rawset(_G, "compat", nil)
  rawset(_G, "dump", nil)
  rawset(_G, "classic", nil)
  rawset(_G, "lume", nil)
  rawset(_G, "inkutils", nil)
  rawset(_G, "PRNG", nil)
  rawset(_G, "serialization", nil)
  rawset(_G, "DelegateUtils", nil)
  -- Note: Many more globals are set by ink_header.lua
end

-- Module metadata
tinta._whisker = {
  name = "tinta",
  version = "1.0.0",
  description = "Vendored tinta Ink runtime",
  source = "https://github.com/smwhr/tinta",
  commit = "20ed9cde9007d777da7963135283f788fd83542e"
}

return tinta
