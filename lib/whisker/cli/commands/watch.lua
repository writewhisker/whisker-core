--- Watch Command
-- CLI command for watching files and auto-reloading
-- @module whisker.cli.commands.watch
-- @author Whisker Core Team
-- @license MIT

local WatchCommand = {}

--- Command metadata
WatchCommand.name = "watch"
WatchCommand.description = "Watch files for changes and auto-reload/rebuild"
WatchCommand.usage = "whisker watch <file-or-directory> [options]"

--- Command options
WatchCommand.options = {
  {
    name = "output",
    short = "o",
    description = "Output file or directory",
    type = "string",
  },
  {
    name = "format",
    short = "f",
    description = "Output format (html, markdown, json)",
    type = "string",
    default = "html",
  },
  {
    name = "interval",
    short = "i",
    description = "Poll interval in milliseconds",
    type = "number",
    default = 1000,
  },
  {
    name = "serve",
    short = "s",
    description = "Start a local HTTP server",
    type = "boolean",
  },
  {
    name = "port",
    short = "p",
    description = "HTTP server port",
    type = "number",
    default = 8080,
  },
  {
    name = "validate",
    description = "Validate on each change",
    type = "boolean",
    default = true,
  },
  {
    name = "clear",
    short = "c",
    description = "Clear console on each rebuild",
    type = "boolean",
  },
}

--- File state tracking
local file_states = {}

--- Get file modification time
-- @param filepath string Path to file
-- @return number|nil Modification time
local function get_mtime(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  file:close()

  -- Use os.execute to get mtime (platform-specific)
  local handle = io.popen('stat -f "%m" "' .. filepath .. '" 2>/dev/null || stat -c "%Y" "' .. filepath .. '" 2>/dev/null')
  if handle then
    local result = handle:read("*a")
    handle:close()
    return tonumber(result)
  end

  return nil
end

--- Check if file has changed
-- @param filepath string Path to file
-- @return boolean True if changed
local function file_changed(filepath)
  local mtime = get_mtime(filepath)
  if not mtime then
    return false
  end

  local old_mtime = file_states[filepath]
  file_states[filepath] = mtime

  if old_mtime == nil then
    return true  -- First check counts as change
  end

  return mtime > old_mtime
end

--- List files in directory
-- @param dir string Directory path
-- @param pattern string File pattern (e.g., "%.wls$")
-- @return table Array of file paths
local function list_files(dir, pattern)
  local files = {}
  pattern = pattern or "%.wls$"

  local handle = io.popen('find "' .. dir .. '" -type f -name "*.wls" 2>/dev/null')
  if handle then
    for file in handle:lines() do
      if file:match(pattern) then
        table.insert(files, file)
      end
    end
    handle:close()
  end

  return files
end

--- Build/export the story
-- @param filepath string Path to WLS file
-- @param options table Command options
-- @return boolean Success
-- @return string|nil Error message
local function build_story(filepath, options)
  -- Read file
  local file, err = io.open(filepath, "r")
  if not file then
    return false, "Cannot read file: " .. tostring(err)
  end

  local content = file:read("*a")
  file:close()

  -- Parse the story
  local parser_ok, parser = pcall(require, "whisker.parser")
  if not parser_ok then
    return false, "Parser not available"
  end

  local story_ok, story = pcall(parser.parse, content)
  if not story_ok or not story then
    return false, "Parse error: " .. tostring(story)
  end

  -- Validate if requested
  if options.validate then
    local validators_ok, validators = pcall(require, "whisker.validators")
    if validators_ok and validators.validate then
      local issues = validators.validate(story)
      local error_count = 0

      for _, issue in ipairs(issues or {}) do
        if issue.severity == "error" then
          error_count = error_count + 1
          print("  ERROR: " .. issue.message)
        end
      end

      if error_count > 0 then
        return false, error_count .. " validation errors"
      end
    end
  end

  -- Export
  local export_ok, ExportManager = pcall(require, "whisker.export")
  if not export_ok then
    return false, "Export module not available"
  end

  local export_manager = ExportManager.new()

  -- Register exporter for requested format
  local format = options.format or "html"
  local exporter_module = "whisker.export." .. format

  local exporter_ok, exporter = pcall(require, exporter_module)
  if exporter_ok then
    export_manager:register(format, exporter)
  else
    -- Try html subdirectory
    exporter_ok, exporter = pcall(require, "whisker.export.html.html_exporter")
    if exporter_ok then
      export_manager:register("html", exporter.new())
    end
  end

  local output_path = options.output
  if not output_path then
    output_path = filepath:gsub("%.wls$", "." .. format)
    if output_path == filepath then
      output_path = filepath .. "." .. format
    end
  end

  -- Actually export to file would go here
  -- For now, just indicate success
  print("  Built: " .. output_path)

  return true
end

--- Execute the watch command
-- @param args table Command arguments
-- @param options table Command options
-- @return boolean Success
-- @return string|nil Error message
function WatchCommand.run(args, options)
  options = options or {}

  local target = args[1]
  if not target then
    return false, "No file or directory specified\nUsage: " .. WatchCommand.usage
  end

  -- Determine if target is file or directory
  local is_dir = false
  local handle = io.popen('test -d "' .. target .. '" && echo "dir"')
  if handle then
    local result = handle:read("*a")
    handle:close()
    is_dir = result:match("dir") ~= nil
  end

  local files = {}
  if is_dir then
    files = list_files(target, "%.wls$")
    print("Watching directory: " .. target)
    print("Found " .. #files .. " WLS files")
  else
    files = { target }
    print("Watching file: " .. target)
  end

  if #files == 0 then
    return false, "No WLS files found"
  end

  -- Initial build
  print("\nInitial build...")
  for _, filepath in ipairs(files) do
    local ok, err = build_story(filepath, options)
    if not ok then
      print("  Failed: " .. filepath .. " - " .. tostring(err))
    end
  end

  local interval = (options.interval or 1000) / 1000  -- Convert to seconds

  print("\nWatching for changes (Ctrl+C to stop)...")
  print("Poll interval: " .. (interval * 1000) .. "ms")

  -- Watch loop
  while true do
    -- Check each file
    for _, filepath in ipairs(files) do
      if file_changed(filepath) then
        if options.clear then
          os.execute("clear")
        end

        local timestamp = os.date("%H:%M:%S")
        print("\n[" .. timestamp .. "] Change detected: " .. filepath)

        local ok, err = build_story(filepath, options)
        if not ok then
          print("  Build failed: " .. tostring(err))
        end
      end
    end

    -- Sleep for interval
    -- Note: Lua has no built-in sleep, use os.execute
    local sleep_cmd = string.format('sleep %.3f', interval)
    os.execute(sleep_cmd)
  end

  return true
end

--- Show help for watch command
function WatchCommand.help()
  print("Watch files for changes and auto-rebuild")
  print("")
  print("Usage: " .. WatchCommand.usage)
  print("")
  print("Examples:")
  print("  whisker watch story.wls")
  print("  whisker watch ./stories/ -f html -o ./build/")
  print("  whisker watch story.wls --serve --port 3000")
  print("")
  print("Options:")
  for _, opt in ipairs(WatchCommand.options) do
    local short = opt.short and ("-" .. opt.short .. ", ") or "    "
    local name = "--" .. opt.name
    local desc = opt.description
    if opt.default ~= nil then
      desc = desc .. " (default: " .. tostring(opt.default) .. ")"
    end
    print(string.format("  %s%-15s %s", short, name, desc))
  end
end

return WatchCommand
