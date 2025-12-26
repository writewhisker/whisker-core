--- Batch Conversion Command
-- Convert multiple stories in batch
-- @module whisker.cli.commands.batch
-- @author Whisker Core Team
-- @license MIT

local M = {}
M._dependencies = {"file_system", "console"}

--- Create a new batch command
-- @param deps table Dependencies
-- @return BatchCommand
function M.new(deps)
  local self = setmetatable({}, {__index = M})
  self._fs = deps.file_system or {
    read = function(_, path)
      local f = io.open(path, "r")
      if not f then return nil, "Cannot open file" end
      local content = f:read("*a")
      f:close()
      return content
    end,
    write = function(_, path, content)
      local f = io.open(path, "w")
      if not f then return nil, "Cannot open file for writing" end
      f:write(content)
      f:close()
      return true
    end,
    mkdir = function(_, path)
      os.execute("mkdir -p '" .. path .. "'")
      return true
    end
  }
  self._console = deps.console or {
    print = function(_, text) print(text) end,
    write = function(_, text) io.write(text) end,
    error = function(_, text) io.stderr:write(text .. "\n") end
  }
  return self
end

--- Get command name
-- @return string
function M:get_name()
  return "batch"
end

--- Get command description
-- @return string
function M:get_description()
  return "Convert multiple stories in batch"
end

--- Get command options
-- @return table Array of option definitions
function M:get_options()
  return {
    {name = "from", short = "f", description = "Source format", required = true},
    {name = "to", short = "t", description = "Target format", required = true},
    {name = "output-dir", short = "o", description = "Output directory"},
    {name = "pattern", short = "p", description = "File pattern (default: *.tw)"},
    {name = "recursive", short = "r", description = "Search recursively", flag = true},
    {name = "dry-run", description = "Show what would be done", flag = true},
    {name = "report", description = "Generate conversion reports", flag = true},
    {name = "continue-on-error", description = "Continue if a file fails", flag = true},
    {name = "quiet", short = "q", description = "Suppress output", flag = true},
    {name = "json-summary", description = "Save summary to JSON file"},
    {name = "no-progress", description = "Disable progress bar", flag = true},
  }
end

--- Get usage help
-- @return string
function M:get_usage()
  return [[
Usage: whisker batch [OPTIONS] [DIRECTORY]

Arguments:
  DIRECTORY  Directory containing stories to convert (default: current directory)

Options:
  -f, --from FORMAT      Source format (required)
  -t, --to FORMAT        Target format (required)
  -o, --output-dir DIR   Output directory (default: same as input)
  -p, --pattern PATTERN  File pattern to match (default: *.tw)
  -r, --recursive        Search directories recursively
      --dry-run          Show what would be done without converting
      --report           Generate conversion reports for each file
      --continue-on-error Continue processing if a file fails
  -q, --quiet            Suppress output except errors
      --json-summary FILE Save summary to JSON file
      --no-progress      Disable progress bar

Examples:
  whisker batch -f harlowe -t chapbook ./stories
  whisker batch -f harlowe -t sugarcube -r --pattern "*.twee" ./
  whisker batch -f harlowe -t ink -o ./converted --report ./stories
  whisker batch -f harlowe -t json --dry-run ./stories
]]
end

--- Execute the batch command
-- @param args table Positional arguments
-- @param options table Parsed options
-- @return number Exit code
function M:execute(args, options)
  local input_dir = args[1] or "."
  local pattern = options.pattern or "*.tw"
  local output_dir = options["output-dir"] or input_dir

  -- Find matching files
  local files = self:find_files(input_dir, pattern, options.recursive)

  if #files == 0 then
    self._console:print("No matching files found.")
    return 0
  end

  self._console:print(string.format("Found %d file(s) to convert", #files))

  if options["dry-run"] then
    self:show_dry_run(files, options)
    return 0
  end

  -- Create output directory if needed
  if output_dir ~= input_dir then
    self._fs:mkdir(output_dir)
  end

  -- Create progress bar
  local Progress = require("whisker.cli.progress")
  local progress = nil
  if not options.quiet and not options["no-progress"] and #files > 1 then
    progress = Progress.new({console = self._console}, #files, {
      show_eta = true
    })
  end

  -- Process files
  local results = {
    success = 0,
    failed = 0,
    skipped = 0,
    errors = {},
    files = {},
    start_time = os.time(),
    end_time = nil
  }

  for i, file in ipairs(files) do
    local file_result = self:convert_file(file, options)
    file_result.file = file
    file_result.index = i
    table.insert(results.files, file_result)

    if file_result.success then
      results.success = results.success + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, {file = file, error = file_result.error})
    end

    if progress then
      progress:update(i, file_result.success and "OK" or "FAIL")
    elseif not options.quiet then
      local status = file_result.success and "OK" or "FAIL"
      local msg = file_result.success and "" or (" - " .. tostring(file_result.error))
      self._console:print(string.format("[%d/%d] %s: %s%s", i, #files, status, file, msg))
    end

    if not file_result.success and not options["continue-on-error"] then
      if not options.quiet then
        self._console:error("Stopping due to error. Use --continue-on-error to proceed.")
      end
      break
    end
  end

  results.end_time = os.time()

  if progress then
    progress:finish()
  end

  -- Generate summary
  if not options.quiet then
    self:print_summary(results, options)
  end

  -- Save JSON summary if requested
  if options["json-summary"] then
    self:save_json_summary(results, options["json-summary"])
  end

  return results.failed > 0 and 1 or 0
end

--- Find files matching pattern
-- @param dir string Directory to search
-- @param pattern string Glob pattern
-- @param recursive boolean Search recursively
-- @return table Array of file paths
function M:find_files(dir, pattern, recursive)
  local files = {}

  -- Use find or ls
  local cmd
  if recursive then
    cmd = string.format("find '%s' -name '%s' -type f 2>/dev/null", dir, pattern)
  else
    cmd = string.format("ls -1 '%s'/%s 2>/dev/null", dir, pattern)
  end

  local handle = io.popen(cmd)
  if handle then
    for line in handle:lines() do
      table.insert(files, line)
    end
    handle:close()
  end

  table.sort(files)
  return files
end

--- Convert a single file
-- @param file_path string Path to file
-- @param options table Conversion options
-- @return table Result {success, error, output, report}
function M:convert_file(file_path, options)
  local result = {success = false, error = nil}

  -- Read file
  local content, err = self._fs:read(file_path)
  if not content then
    result.error = "Cannot read file: " .. tostring(err)
    return result
  end

  -- Parse
  local ok, parser = pcall(require, "whisker.format.parsers." .. options.from)
  if not ok then
    result.error = "Unknown source format: " .. options.from
    return result
  end

  local story
  ok, err = pcall(function()
    story = parser.parse(content)
  end)

  if not ok or not story then
    result.error = "Parse error: " .. tostring(err)
    return result
  end

  -- Convert
  local converter
  ok, converter = pcall(require, "whisker.format.converters." .. options.from)
  if not ok then
    result.error = "No converter for format: " .. options.from
    return result
  end

  local convert_fn = "to_" .. options.to
  local report_fn = convert_fn .. "_with_report"

  local converted, report
  ok, err = pcall(function()
    if options.report and converter[report_fn] then
      converted, report = converter[report_fn](story)
      result.report = report
    elseif converter[convert_fn] then
      converted = converter[convert_fn](story)
    else
      error("No conversion function: " .. convert_fn)
    end
  end)

  if not ok or not converted then
    result.error = "Convert error: " .. tostring(err)
    return result
  end

  -- Write output
  local output_path = self:get_output_path(file_path, options)

  ok, err = self._fs:write(output_path, converted)
  if not ok then
    result.error = "Write error: " .. tostring(err)
    return result
  end

  -- Write report if requested
  if report and options.report and report.to_json then
    local report_path = output_path:gsub("%.[^.]+$", "") .. "_report.json"
    self._fs:write(report_path, report:to_json())
  end

  result.success = true
  result.output = output_path
  return result
end

--- Get output path for a file
-- @param input_path string Input file path
-- @param options table Options with output-dir and to format
-- @return string Output file path
function M:get_output_path(input_path, options)
  local basename = input_path:match("([^/]+)$")
  local name = basename:match("(.+)%.[^.]+$") or basename

  local output_dir = options["output-dir"] or input_path:match("(.+)/[^/]+$") or "."
  local ext = self:get_extension(options.to)

  return string.format("%s/%s_%s.%s", output_dir, name, options.to, ext)
end

--- Get file extension for a format
-- @param format string Format name
-- @return string File extension
function M:get_extension(format)
  local extensions = {
    harlowe = "tw",
    sugarcube = "tw",
    chapbook = "tw",
    snowman = "tw",
    ink = "ink",
    json = "json",
  }
  return extensions[format] or "txt"
end

--- Show dry run output
-- @param files table Array of file paths
-- @param options table Options
function M:show_dry_run(files, options)
  self._console:print("")
  self._console:print("Dry run - would convert:")
  for _, file in ipairs(files) do
    local output = self:get_output_path(file, options)
    self._console:print(string.format("  %s -> %s", file, output))
  end
end

--- Print summary of batch operation
-- @param results table Results from batch processing
-- @param options table Options
function M:print_summary(results, options)
  local elapsed = (results.end_time or os.time()) - results.start_time

  self._console:print("")
  self._console:print("===========================================")
  self._console:print("         Batch Conversion Summary          ")
  self._console:print("===========================================")
  self._console:print("")

  self._console:print(string.format("  Total files:    %d", #results.files))
  self._console:print(string.format("  Successful:     %d", results.success))
  self._console:print(string.format("  Failed:         %d", results.failed))
  self._console:print(string.format("  Time elapsed:   %ds", elapsed))

  if #results.files > 0 and elapsed > 0 then
    local rate = #results.files / elapsed
    self._console:print(string.format("  Rate:           %.1f files/sec", rate))
  end

  self._console:print("")

  if #results.errors > 0 then
    self._console:print("  Errors:")
    for _, err in ipairs(results.errors) do
      self._console:print(string.format("    - %s", err.file))
      self._console:print(string.format("      %s", err.error))
    end
    self._console:print("")
  end

  -- Conversion statistics if reports were generated
  if options.report then
    local total_converted = 0
    local total_lost = 0
    for _, file_result in ipairs(results.files) do
      if file_result.report and file_result.report.get_summary then
        local summary = file_result.report:get_summary()
        total_converted = total_converted + (summary.converted or 0)
        total_lost = total_lost + (summary.lost or 0)
      end
    end

    if total_converted > 0 or total_lost > 0 then
      self._console:print("  Conversion Statistics:")
      self._console:print(string.format("    Features converted: %d", total_converted))
      self._console:print(string.format("    Features lost:      %d", total_lost))
      self._console:print("")
    end
  end

  local status = results.failed == 0 and "SUCCESS" or "COMPLETED WITH ERRORS"
  self._console:print(string.format("  Status: %s", status))
  self._console:print("===========================================")
end

--- Save JSON summary to file
-- @param results table Results from batch processing
-- @param path string Output path for JSON
function M:save_json_summary(results, path)
  local summary = {
    total = #results.files,
    success = results.success,
    failed = results.failed,
    elapsed_seconds = (results.end_time or os.time()) - results.start_time,
    files = {},
    errors = results.errors
  }

  for _, file_result in ipairs(results.files) do
    table.insert(summary.files, {
      file = file_result.file,
      success = file_result.success,
      output = file_result.output,
      error = file_result.error
    })
  end

  -- Simple JSON encoding
  local function encode_value(v)
    if type(v) == "string" then
      return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif type(v) == "number" then
      return tostring(v)
    elseif type(v) == "boolean" then
      return v and "true" or "false"
    elseif type(v) == "nil" then
      return "null"
    elseif type(v) == "table" then
      if #v > 0 then
        local items = {}
        for _, item in ipairs(v) do
          table.insert(items, encode_value(item))
        end
        return "[" .. table.concat(items, ",") .. "]"
      else
        local items = {}
        for k, val in pairs(v) do
          table.insert(items, '"' .. k .. '":' .. encode_value(val))
        end
        return "{" .. table.concat(items, ",") .. "}"
      end
    end
    return "null"
  end

  local json = encode_value(summary)
  self._fs:write(path, json)
  self._console:print("Summary saved to: " .. path)
end

return M
