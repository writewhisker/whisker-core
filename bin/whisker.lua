#!/usr/bin/env lua
--[[
  Whisker CLI
  
  Command-line interface for whisker-core.
  
  Usage: lua bin/whisker.lua <command> [options]
]]

-- Add lib to path
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

local TwineImporter = require("whisker.import.twine")
local HTMLExporter = require("whisker.export.html")
local Story = require("whisker.core.story")

local CLI = {}

function CLI.help()
  print([[
Whisker CLI - Interactive Fiction Engine

Commands:
  import <file>         Import from Twine HTML
  export html [opts]    Export to HTML
  validate <file>       Validate story
  help                  Show this help
  version               Show version

Examples:
  lua bin/whisker.lua import story.html
  lua bin/whisker.lua export html -i story.json -o output.html
  lua bin/whisker.lua validate mystory.json
]])
end

function CLI.import(args)
  local filepath = args[1]
  if not filepath then
    print("Error: No input file specified")
    return 1
  end
  
  print("Importing: " .. filepath)
  
  local importer = TwineImporter.new()
  local story, err = importer:import_from_file(filepath)
  
  if not story then
    print("Error: " .. (err or "Import failed"))
    return 1
  end
  
  local stats = importer:get_stats()
  print(string.format("✓ Success! Passages: %d, Links: %d", 
    stats.passages_imported, stats.links_found))
  
  -- Save
  local output = filepath:gsub('%.html$', '.json')
  local json = require("cjson")
  local file = io.open(output, "w")
  if file then
    file:write(json.encode({
      metadata = story.metadata,
      passages = story.passages,
      start_passage = story.start_passage
    }))
    file:close()
    print("Saved: " .. output)
  end
  
  return 0
end

function CLI.export(args)
  local input, output
  
  for i = 2, #args do
    if args[i] == "-i" then input = args[i + 1]
    elseif args[i] == "-o" then output = args[i + 1] end
  end
  
  if not input then
    print("Error: Use -i to specify input file")
    return 1
  end
  
  -- Load
  local file = io.open(input, "r")
  if not file then
    print("Error: Cannot open: " .. input)
    return 1
  end
  
  local json = require("cjson")
  local story = Story.from_table(json.decode(file:read("*all")))
  file:close()
  
  -- Export
  output = output or input:gsub('%.json$', '.html')
  local exporter = HTMLExporter.new()
  local success, err = exporter:export_to_file(story, output)
  
  if success then
    print("✓ Exported: " .. output)
    return 0
  else
    print("Error: " .. err)
    return 1
  end
end

function CLI.validate(args)
  local filepath = args[1]
  if not filepath then
    print("Error: No file specified")
    return 1
  end
  
  local file = io.open(filepath, "r")
  if not file then
    print("Error: Cannot open: " .. filepath)
    return 1
  end
  
  local json = require("cjson")
  local story = Story.from_table(json.decode(file:read("*all")))
  file:close()
  
  local errors = {}
  
  -- Check start passage
  if not story:get_passage(story.start_passage) then
    table.insert(errors, "Start passage not found: " .. story.start_passage)
  end
  
  -- Check links
  for _, passage in ipairs(story.passages) do
    for _, choice in ipairs(passage.choices or {}) do
      if not story:get_passage(choice.target) then
        table.insert(errors, string.format(
          "Broken link in '%s': '%s' not found",
          passage.id, choice.target))
      end
    end
  end
  
  if #errors > 0 then
    print("✗ Validation failed:")
    for _, err in ipairs(errors) do
      print("  - " .. err)
    end
    return 1
  else
    print("✓ Validation passed (" .. #story.passages .. " passages)")
    return 0
  end
end

function CLI.version()
  print("Whisker CLI v2.0")
end

function CLI.main(args)
  local command = args[1]
  
  if not command or command == "help" then
    CLI.help()
    return 0
  end
  
  local cmd_args = {}
  for i = 2, #args do table.insert(cmd_args, args[i]) end
  
  if command == "import" then return CLI.import(cmd_args)
  elseif command == "export" then return CLI.export(cmd_args)
  elseif command == "validate" then return CLI.validate(cmd_args)
  elseif command == "version" then CLI.version(); return 0
  else
    print("Unknown command: " .. command)
    return 1
  end
end

if arg then os.exit(CLI.main(arg)) end
return CLI
