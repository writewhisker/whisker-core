--- Export CLI Command
-- Command-line interface for story export
-- @module whisker.cli.commands.export
-- @author Whisker Core Team
-- @license MIT

local compat = require("whisker.compat")

local ExportCommand = {}
ExportCommand._dependencies = {}

-- Dependencies (lazily loaded)
local _export_utils = nil
local _export_manager_class = nil

--- Initialize dependencies (lazy load)
local function get_export_utils()
  if not _export_utils then
    local ok, utils = pcall(require, "whisker.export.utils")
    if ok then _export_utils = utils end
  end
  return _export_utils
end

local function get_export_manager_class()
  if not _export_manager_class then
    local ok, mgr = pcall(require, "whisker.export.init")
    if ok then _export_manager_class = mgr end
  end
  return _export_manager_class
end

--- Create a new ExportCommand with optional container
-- @param container table|nil DI container for resolving dependencies
-- @return table ExportCommand instance
function ExportCommand.new(container)
  local instance = {
    _container = container,
    _export_manager = nil,
  }
  setmetatable(instance, { __index = ExportCommand })

  -- If container provided, try to resolve export_manager
  if container and container:has("export_manager") then
    instance._export_manager = container:resolve("export_manager")
  end

  return instance
end

--- Parse command-line arguments
-- @param args table Raw arguments array
-- @return table Parsed arguments
local function parse_args(args)
  local parsed = {
    positional = {},
    format = "html",
    output = nil,
    minify = false,
    inline = true,
    template = nil,
    asset_path = nil,
    pretty = false,
    help = false,
  }

  local i = 1
  while i <= #args do
    local arg = args[i]

    if arg == "--help" or arg == "-h" then
      parsed.help = true
    elseif arg:match("^%-%-format=") then
      parsed.format = arg:match("^%-%-format=(.+)")
    elseif arg == "--format" or arg == "-f" then
      i = i + 1
      parsed.format = args[i]
    elseif arg:match("^%-%-output=") then
      parsed.output = arg:match("^%-%-output=(.+)")
    elseif arg == "--output" or arg == "-o" then
      i = i + 1
      parsed.output = args[i]
    elseif arg:match("^%-%-template=") then
      parsed.template = arg:match("^%-%-template=(.+)")
    elseif arg == "--template" or arg == "-t" then
      i = i + 1
      parsed.template = args[i]
    elseif arg:match("^%-%-asset%-path=") then
      parsed.asset_path = arg:match("^%-%-asset%-path=(.+)")
    elseif arg == "--minify" then
      parsed.minify = true
    elseif arg == "--no-inline" then
      parsed.inline = false
    elseif arg == "--pretty" then
      parsed.pretty = true
    elseif not arg:match("^%-") then
      table.insert(parsed.positional, arg)
    end

    i = i + 1
  end

  return parsed
end

--- Show help text
-- @return number Exit code
local function show_help()
  print([[
whisker export - Export stories to distributable formats

USAGE:
  whisker export STORY [OPTIONS]

ARGUMENTS:
  STORY                 Path to story file (.whisker, .json, .lua)

OPTIONS:
  -f, --format=FORMAT   Export format (html, ink, text) [default: html]
  -o, --output=FILE     Output file path [default: story.FORMAT]
  -t, --template=FILE   Custom template file (HTML only)
  --minify              Minify output (HTML, CSS, JS)
  --no-inline           Don't inline assets (HTML only)
  --pretty              Pretty-print output (Ink JSON)
  --asset-path=DIR      Path to asset directory
  -h, --help            Show this help message

EXAMPLES:
  whisker export story.whisker
  whisker export story.whisker --format=ink --output=story.json
  whisker export story.whisker --format=html --template=custom.html --minify

FORMATS:
  html    Standalone HTML with embedded runtime
  ink     Ink JSON for game engines (Unity, Unreal)
  text    Plain text transcript for accessibility/testing
]])

  return 0
end

--- Load story from file
-- @param path string Path to story file
-- @return table|nil Story data
-- @return string|nil Error message
local function load_story(path)
  local export_utils = get_export_utils()
  if not export_utils then
    return nil, "Export utils not available"
  end

  local content = export_utils.read_file(path)
  if not content then
    return nil, "Cannot read file: " .. path
  end

  -- Try to determine format and parse
  local ext = path:match("%.([^.]+)$") or ""
  ext = ext:lower()

  if ext == "lua" then
    -- Lua story file
    local chunk, err = compat.loadstring(content)
    if not chunk then
      return nil, "Lua parse error: " .. tostring(err)
    end
    local ok, result = pcall(chunk)
    if not ok then
      return nil, "Lua execution error: " .. tostring(result)
    end
    return result
  elseif ext == "json" then
    -- JSON story - need a JSON parser
    return nil, "JSON parsing not yet implemented (use .lua format)"
  elseif ext == "whisker" or ext == "ws" then
    -- Whisker script format - would need compiler
    return nil, "Whisker script parsing not yet implemented (use .lua format)"
  else
    -- Try as Lua
    local chunk, err = compat.loadstring(content)
    if chunk then
      local ok, result = pcall(chunk)
      if ok then
        return result
      end
    end
    return nil, "Unknown story format: " .. ext
  end
end

--- Get or create export manager
-- @param self table ExportCommand instance
-- @return table ExportManager instance
local function get_or_create_export_manager(self)
  if self._export_manager then
    return self._export_manager
  end

  -- Create a new export manager
  local ExportManagerClass = get_export_manager_class()
  if not ExportManagerClass then
    return nil
  end

  -- Create with event bus (from container or new)
  local event_bus
  if self._container and self._container:has("events") then
    event_bus = self._container:resolve("events")
  else
    local EventBus = require("whisker.kernel.events")
    event_bus = EventBus.new()
  end

  local export_manager = ExportManagerClass.new(event_bus)

  -- Register exporters (lazy load)
  local ok, HTMLExporter = pcall(require, "whisker.export.html.html_exporter")
  if ok then export_manager:register("html", HTMLExporter.new()) end

  ok, InkExporter = pcall(require, "whisker.export.ink.ink_exporter")
  if ok then export_manager:register("ink", InkExporter.new()) end

  ok, TextExporter = pcall(require, "whisker.export.text.text_exporter")
  if ok then export_manager:register("text", TextExporter.new()) end

  self._export_manager = export_manager
  return export_manager
end

--- Execute export command
-- @param args table Command-line arguments
-- @param whisker table|nil Whisker instance (optional)
-- @return number Exit code
function ExportCommand.execute(args, whisker)
  -- Support both static and instance-based calls
  local self = ExportCommand.new(whisker and whisker.container)
  return self:run(args)
end

--- Run the export command (instance method)
-- @param args table Command-line arguments
-- @return number Exit code
function ExportCommand:run(args)
  local parsed = parse_args(args)

  if parsed.help then
    return show_help()
  end

  -- Get story path
  local story_path = parsed.positional[1]
  if not story_path then
    print("Error: Story file required")
    print("Usage: whisker export STORY [OPTIONS]")
    print("Run 'whisker export --help' for more information")
    return 1
  end

  -- Load story
  local story, load_err = load_story(story_path)
  if not story then
    print("Error: " .. load_err)
    return 1
  end

  -- Get export manager
  local export_manager = get_or_create_export_manager(self)
  if not export_manager then
    print("Error: Export manager not available")
    return 1
  end

  -- Check format exists
  if not export_manager:has_format(parsed.format) then
    print("Error: Unknown format: " .. parsed.format)
    print("Available formats: " .. table.concat(export_manager:get_formats(), ", "))
    return 1
  end

  -- Build export options
  local options = {
    minify = parsed.minify,
    inline_assets = parsed.inline,
    template = parsed.template,
    asset_path = parsed.asset_path,
    pretty = parsed.pretty,
  }

  -- Export
  local title = story.title or "Untitled"
  print(string.format("Exporting '%s' to %s...", title, parsed.format))

  local bundle = export_manager:export(story, parsed.format, options)

  if bundle.error then
    print("Export failed: " .. bundle.error)
    return 1
  end

  -- Check validation
  if bundle.validation and not bundle.validation.valid then
    print("Warning: Export validation failed:")
    for _, err in ipairs(bundle.validation.errors or {}) do
      print("  - " .. err.message)
    end
  end

  -- Determine output path
  local export_utils = get_export_utils()
  local output_path = parsed.output
  if not output_path and export_utils then
    local exporter = export_manager:get_exporter(parsed.format)
    local ext = exporter:metadata().file_extension
    output_path = export_utils.stem(story_path) .. ext
  end

  -- Write output
  if not export_utils then
    print("Error: Export utils not available")
    return 1
  end

  local success = export_utils.write_file(output_path, bundle.content)

  if not success then
    print("Error: Cannot write output file: " .. output_path)
    return 1
  end

  -- Success message
  local size_kb = #bundle.content / 1024
  print(string.format("Success! Exported to: %s", output_path))
  print(string.format("  Size: %.2f KB", size_kb))

  if bundle.assets and #bundle.assets > 0 then
    print(string.format("  Assets: %d files", #bundle.assets))
  end

  if bundle.validation and bundle.validation.warnings then
    for _, warn in ipairs(bundle.validation.warnings) do
      print("  Warning: " .. warn.message)
    end
  end

  return 0
end

--- Get command help text (for CLI integration)
-- @return string Help text
function ExportCommand.help()
  return "Export stories to distributable formats (html, ink, text)"
end

--- Get command name
-- @return string Command name
function ExportCommand.name()
  return "export"
end

return ExportCommand
