#!/usr/bin/env lua
--- Basic Ink Story Player Example
-- Demonstrates basic usage of the Ink engine
-- @module examples.ink.basic_player

-- Setup paths
local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.-)[^/]+$")
package.path = script_dir .. "../../lib/?.lua;" .. package.path

-- Load modules
local Container = require("whisker.kernel.container")
local EventBus = require("whisker.kernel.events")
local InkEngine = require("whisker.formats.ink.engine")

--- Read a file and return its contents
local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "Could not open " .. path
  end
  local content = file:read("*all")
  file:close()
  return content
end

--- Create a test container with basic dependencies
local function create_container()
  local container = Container.new()

  -- Events
  container:register("events", function()
    return EventBus.new()
  end, { singleton = true })

  -- Simple state
  container:register("state", function()
    local data = {}
    return {
      get = function(_, key) return data[key] end,
      set = function(_, key, val) data[key] = val end,
      has = function(_, key) return data[key] ~= nil end,
      delete = function(_, key) data[key] = nil end,
      keys = function()
        local k = {}
        for key in pairs(data) do table.insert(k, key) end
        return k
      end,
    }
  end, { singleton = true })

  -- Logger
  container:register("logger", function()
    return {
      debug = function() end,
      info = print,
      warn = function(...) io.stderr:write("WARN: ", ..., "\n") end,
      error = function(...) io.stderr:write("ERROR: ", ..., "\n") end,
    }
  end)

  return container
end

--- Main function to play a story
local function play_story(json_path)
  -- Create container and engine
  local container = create_container()
  local engine = InkEngine.new({
    events = container:resolve("events"),
    state = container:resolve("state"),
    logger = container:resolve("logger"),
  })

  -- Load story
  local json, err = read_file(json_path)
  if not json then
    print("Error: " .. err)
    return 1
  end

  local ok, load_err = engine:load(json)
  if not ok then
    print("Failed to load story: " .. load_err)
    return 1
  end

  -- Start story
  engine:start()

  print("\n" .. string.rep("=", 50))
  print("STORY PLAYER")
  print(string.rep("=", 50) .. "\n")

  -- Main loop
  while true do
    -- Continue and print text
    while engine:can_continue() do
      local text, tags = engine:continue()

      -- Show tags
      if tags and #tags > 0 then
        local tag_str = table.concat(tags, ", ")
        print("[" .. tag_str .. "]")
      end

      -- Show text
      if text and #text > 0 then
        io.write(text)
      end
    end

    -- Check for end
    if engine:has_ended() then
      print("\n" .. string.rep("=", 50))
      print("THE END")
      print(string.rep("=", 50))
      break
    end

    -- Show choices
    local choices = engine:get_choices()
    if #choices > 0 then
      print()
      for i, choice in ipairs(choices) do
        local line = string.format("%d. %s", i, choice.text)
        if choice.tags and #choice.tags > 0 then
          line = line .. " [" .. table.concat(choice.tags, ", ") .. "]"
        end
        print(line)
      end

      -- Get input
      io.write("\nChoice (1-" .. #choices .. "): ")
      local input = io.read()

      if input == "quit" or input == "q" or input == nil then
        print("Quitting...")
        break
      end

      local num = tonumber(input)
      if num and num >= 1 and num <= #choices then
        engine:make_choice(num)
        print()
      else
        print("Invalid choice. Please enter 1-" .. #choices)
      end
    end
  end

  return 0
end

-- Run if executed directly
if arg then
  if #arg < 1 then
    print("Usage: lua basic_player.lua <story.ink.json>")
    print("")
    print("Example:")
    print("  lua basic_player.lua ../../tests/fixtures/ink/hello_world.ink.json")
    os.exit(1)
  end

  os.exit(play_story(arg[1]))
end

return {
  play_story = play_story,
  create_container = create_container,
}
