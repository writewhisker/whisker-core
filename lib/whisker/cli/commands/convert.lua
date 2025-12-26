--- Convert CLI Command
-- Command-line interface for format conversion between Twine formats
-- @module whisker.cli.commands.convert

local ConvertCommand = {}
ConvertCommand._dependencies = {"file_system", "console"}

-- Lazy-loaded dependencies
local _parsers = nil
local _converters = nil
local _json_parser = nil
local _ink_converter = nil

--- Get parsers for each format
local function get_parsers()
  if not _parsers then
    _parsers = {
      harlowe = require("whisker.format.parsers.harlowe"),
      chapbook = require("whisker.format.parsers.chapbook"),
      sugarcube = require("whisker.format.parsers.sugarcube"),
      snowman = require("whisker.format.parsers.snowman"),
    }
  end
  return _parsers
end

--- Get Ink converter
local function get_ink_converter()
  if not _ink_converter then
    _ink_converter = require("whisker.format.converters.ink")
  end
  return _ink_converter
end

--- Get JSON parser
local function get_json_parser()
  if not _json_parser then
    _json_parser = require("whisker.format.parsers.json")
  end
  return _json_parser
end

--- Get converters for each format
local function get_converters()
  if not _converters then
    _converters = {
      harlowe = require("whisker.format.converters.harlowe"),
      chapbook = require("whisker.format.converters.chapbook"),
      sugarcube = require("whisker.format.converters.sugarcube"),
      snowman = require("whisker.format.converters.snowman"),
    }
  end
  return _converters
end

--- Valid Twine formats
local VALID_FORMATS = {
  harlowe = true,
  chapbook = true,
  sugarcube = true,
  snowman = true,
  json = true,
  ink = true,
}

--- Create a new ConvertCommand
-- @param container table|nil DI container
-- @return ConvertCommand instance
function ConvertCommand.new(container)
  local instance = {
    _container = container,
  }
  setmetatable(instance, { __index = ConvertCommand })
  return instance
end

--- Get command name
-- @return string Command name
function ConvertCommand:get_name()
  return "convert"
end

--- Get command description
-- @return string Command description
function ConvertCommand:get_description()
  return "Convert stories between Twine formats"
end

--- Get command options
-- @return table List of option definitions
function ConvertCommand:get_options()
  return {
    {name = "from", short = "f", description = "Source format (harlowe|sugarcube|chapbook|snowman)", required = false},
    {name = "to", short = "t", description = "Target format (harlowe|sugarcube|chapbook|snowman)", required = true},
    {name = "output", short = "o", description = "Output file path"},
    {name = "report", short = "r", description = "Generate conversion report", flag = true},
    {name = "json-report", description = "Save report as JSON file"},
    {name = "quiet", short = "q", description = "Suppress output", flag = true},
    {name = "help", short = "h", description = "Show help", flag = true},
  }
end

--- Parse command-line arguments
-- @param args table Raw arguments
-- @return table Parsed arguments
local function parse_args(args)
  local parsed = {
    positional = {},
    from = nil,
    to = nil,
    output = nil,
    report = false,
    json_report = nil,
    quiet = false,
    help = false,
  }

  local i = 1
  while i <= #args do
    local arg = args[i]

    if arg == "--help" or arg == "-h" then
      parsed.help = true
    elseif arg:match("^%-%-from=") then
      parsed.from = arg:match("^%-%-from=(.+)")
    elseif arg == "--from" or arg == "-f" then
      i = i + 1
      parsed.from = args[i]
    elseif arg:match("^%-%-to=") then
      parsed.to = arg:match("^%-%-to=(.+)")
    elseif arg == "--to" or arg == "-t" then
      i = i + 1
      parsed.to = args[i]
    elseif arg:match("^%-%-output=") then
      parsed.output = arg:match("^%-%-output=(.+)")
    elseif arg == "--output" or arg == "-o" then
      i = i + 1
      parsed.output = args[i]
    elseif arg:match("^%-%-json%-report=") then
      parsed.json_report = arg:match("^%-%-json%-report=(.+)")
    elseif arg == "--json-report" then
      i = i + 1
      parsed.json_report = args[i]
    elseif arg == "--report" or arg == "-r" then
      parsed.report = true
    elseif arg == "--quiet" or arg == "-q" then
      parsed.quiet = true
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
whisker convert - Convert stories between Twine formats

USAGE:
  whisker convert STORY [OPTIONS]

ARGUMENTS:
  STORY                 Path to story file (.tw, .twee, .json)

OPTIONS:
  -f, --from=FORMAT     Source format (auto-detected if not specified)
  -t, --to=FORMAT       Target format (required)
  -o, --output=FILE     Output file path [default: story_TARGET.tw]
  -r, --report          Show conversion report
  --json-report=FILE    Save report as JSON file
  -q, --quiet           Suppress output
  -h, --help            Show this help message

FORMATS:
  harlowe     Harlowe format (Twine default)
  sugarcube   SugarCube format
  chapbook    Chapbook format
  snowman     Snowman format
  json        JSON story format (for import/export)
  ink         Ink narrative scripting language

EXAMPLES:
  whisker convert story.tw --from harlowe --to sugarcube
  whisker convert story.tw -t chapbook --report
  whisker convert story.tw -t snowman -o output.tw --json-report report.json
  whisker convert story.json -t harlowe -o story.tw
  whisker convert story.tw -f harlowe -t json -o story.json
  whisker convert story.ink -t harlowe -o story.tw
  whisker convert story.tw -f harlowe -t ink -o story.ink

NOTES:
  - Format is auto-detected from file content if --from is not specified
  - JSON files are automatically detected by .json extension
  - The conversion report shows which features were converted, approximated, or lost
  - Quality score indicates conversion fidelity (100 = perfect, 0 = all features lost)
]])

  return 0
end

--- Validate format name
-- @param format string Format name
-- @return boolean True if valid
function ConvertCommand:validate_format(format)
  if not format then return false end
  return VALID_FORMATS[format:lower()] == true
end

--- Detect format from file content
-- @param content string File content
-- @return string|nil Detected format name
function ConvertCommand:detect_format_from_content(content)
  -- Check for JSON format (starts with { or has JSON story markers)
  local json_parser = get_json_parser()
  if json_parser.is_json_story(content) then
    return "json"
  end

  -- Check for Ink patterns: === knots ===, VAR, ->, * choices
  if content:match("^%s*===%s*[%w_]+%s*===") or
     content:match("\n%s*===%s*[%w_]+%s*===") or
     content:match("^VAR%s+") or
     content:match("^%s*%*%s*%[") then
    return "ink"
  end

  -- Check for Harlowe patterns: (set:, (if:, (print:
  if content:match("%(set:") or content:match("%(if:") or content:match("%(print:") then
    return "harlowe"
  end

  -- Check for SugarCube patterns: <<set, <<if, <<print
  if content:match("<<set") or content:match("<<if") or content:match("<<print") then
    return "sugarcube"
  end

  -- Check for Chapbook patterns: vars section with --
  if content:match("\n[%w_]+:%s*[^\n]+\n%-%-") or content:match("^[%w_]+:%s*[^\n]+\n%-%-") then
    return "chapbook"
  end

  -- Check for Snowman patterns: <% and <%=
  if content:match("<%%") or content:match("<%%= s%.") then
    return "snowman"
  end

  return nil
end

--- Read file content
-- @param path string File path
-- @return string|nil Content
-- @return string|nil Error
local function read_file(path)
  local file, err = io.open(path, "r")
  if not file then
    return nil, "Cannot open file: " .. tostring(err)
  end
  local content = file:read("*all")
  file:close()
  return content
end

--- Write file content
-- @param path string File path
-- @param content string Content to write
-- @return boolean Success
-- @return string|nil Error
local function write_file(path, content)
  local file, err = io.open(path, "w")
  if not file then
    return false, "Cannot write file: " .. tostring(err)
  end
  file:write(content)
  file:close()
  return true
end

--- Get default output path
-- @param input_path string Input file path
-- @param target_format string Target format
-- @return string Output path
local function get_default_output(input_path, target_format)
  local base = input_path:match("^(.+)%.[^.]+$") or input_path
  return base .. "_" .. target_format .. ".tw"
end

--- Print conversion report
-- @param report table Conversion report
-- @param quiet boolean Whether to suppress output
local function print_report(report, quiet)
  if quiet then return end

  local summary = report:get_summary()

  print("")
  print("Conversion Report: " .. report.source_format .. " -> " .. report.target_format)
  print(string.rep("-", 50))
  print("  Passages processed:   " .. summary.passage_count)
  print("  Features converted:   " .. summary.converted)
  print("  Features approximated: " .. summary.approximated)
  print("  Features lost:        " .. summary.lost)
  print("  Quality score:        " .. report:get_quality_score() .. "%")

  -- Show details for approximated and lost features
  local approx = report:get_details("approximated")
  local lost = report:get_details("lost")

  if #approx > 0 then
    print("")
    print("Approximations:")
    for _, entry in ipairs(approx) do
      print(string.format("  [APPROX] %s in %s", entry.feature, entry.passage))
      if entry.notes then
        print("           " .. entry.notes)
      end
    end
  end

  if #lost > 0 then
    print("")
    print("Lost Features:")
    for _, entry in ipairs(lost) do
      print(string.format("  [LOST] %s in %s", entry.feature, entry.passage))
      if entry.reason then
        print("         " .. entry.reason)
      end
    end
  end

  print("")
end

--- Execute the convert command
-- @param args table Command arguments
-- @return number Exit code
function ConvertCommand:execute(args)
  local parsed = parse_args(args)

  if parsed.help then
    return show_help()
  end

  -- Check for input file
  if #parsed.positional == 0 then
    print("Error: No input file specified")
    print("Use 'whisker convert --help' for usage information")
    return 1
  end

  local input_path = parsed.positional[1]

  -- Check target format
  if not parsed.to then
    print("Error: Target format not specified")
    print("Use --to FORMAT to specify target format")
    return 1
  end

  local target_format = parsed.to:lower()
  if not self:validate_format(target_format) then
    print("Error: Invalid target format: " .. parsed.to)
    print("Valid formats: harlowe, sugarcube, chapbook, snowman, json, ink")
    return 1
  end

  -- Read input file
  local content, err = read_file(input_path)
  if not content then
    print("Error: " .. err)
    return 1
  end

  -- Determine source format
  local source_format = parsed.from
  if source_format then
    source_format = source_format:lower()
    if not self:validate_format(source_format) then
      print("Error: Invalid source format: " .. parsed.from)
      print("Valid formats: harlowe, sugarcube, chapbook, snowman, json, ink")
      return 1
    end
  else
    -- Auto-detect
    source_format = self:detect_format_from_content(content)
    if not source_format then
      print("Error: Cannot auto-detect source format")
      print("Please specify source format with --from FORMAT")
      return 1
    end
    if not parsed.quiet then
      print("Auto-detected format: " .. source_format)
    end
  end

  -- Check for same format
  if source_format == target_format then
    print("Error: Source and target formats are the same")
    return 1
  end

  -- Get parsers and converters
  local parsers = get_parsers()
  local converters = get_converters()
  local json_parser = get_json_parser()

  local result, report
  local parsed_story

  -- Handle JSON source format
  if source_format == "json" then
    local story, parse_err = json_parser.parse(content)
    if not story then
      print("Error: " .. parse_err)
      return 1
    end

    -- Get the internal format from JSON
    local internal_format = story.format or "harlowe"

    if target_format == "json" then
      print("Error: Source and target formats are the same")
      return 1
    end

    -- Convert JSON to Twee, then convert to target
    local twee_content = json_parser.to_twee(story)

    -- Parse as internal format
    local internal_parser = parsers[internal_format]
    if not internal_parser then
      print("Error: No parser for internal format: " .. internal_format)
      return 1
    end

    parsed_story = internal_parser.parse(twee_content)
    if not parsed_story then
      print("Error: Failed to parse story content")
      return 1
    end

    -- If target is different from internal format, convert
    if target_format ~= internal_format then
      local converter = converters[internal_format]
      if not converter then
        print("Error: No converter for format: " .. internal_format)
        return 1
      end

      local convert_fn_name = "to_" .. target_format .. "_with_report"
      local convert_fn = converter[convert_fn_name]
      if not convert_fn then
        convert_fn_name = "to_" .. target_format
        convert_fn = converter[convert_fn_name]
      end

      if not convert_fn then
        print("Error: No conversion from " .. internal_format .. " to " .. target_format)
        return 1
      end

      if convert_fn_name:match("_with_report$") then
        result, report = convert_fn(parsed_story)
      else
        result = convert_fn(parsed_story)
      end
    else
      -- Target is same as internal format, just use twee
      result = twee_content
    end

  -- Handle JSON target format
  elseif target_format == "json" then
    -- Parse source format
    local parser = parsers[source_format]
    if not parser then
      print("Error: No parser available for format: " .. source_format)
      return 1
    end

    parsed_story = parser.parse(content)
    if not parsed_story then
      print("Error: Failed to parse story")
      return 1
    end

    -- Build story object for JSON
    local story = {
      name = "Converted Story",
      format = source_format,
      start = "Start",
      passages = parsed_story.passages,
      metadata = {
        converted = os.date("%Y-%m-%dT%H:%M:%S"),
        sourceFormat = source_format,
      }
    }

    -- Try to find story name from StoryTitle passage
    for _, passage in ipairs(parsed_story.passages) do
      if passage.name == "StoryTitle" then
        story.name = passage.content:match("^%s*(.-)%s*$") or "Converted Story"
        break
      end
    end

    result = json_parser.to_json(story, {pretty = true, validate = false})

  -- Handle Ink source format
  elseif source_format == "ink" then
    local ink_converter = get_ink_converter()

    -- Parse Ink content
    parsed_story = ink_converter.parse(content)
    if not parsed_story then
      print("Error: Failed to parse Ink story")
      return 1
    end

    -- Convert to target format
    local convert_fn_name = "to_" .. target_format .. "_with_report"
    local convert_fn = ink_converter[convert_fn_name]
    if not convert_fn then
      convert_fn_name = "to_" .. target_format
      convert_fn = ink_converter[convert_fn_name]
    end

    if not convert_fn then
      print("Error: No conversion from ink to " .. target_format)
      return 1
    end

    if convert_fn_name:match("_with_report$") then
      result, report = convert_fn(parsed_story)
    else
      result = convert_fn(parsed_story)
    end

  -- Handle Ink target format
  elseif target_format == "ink" then
    local parser = parsers[source_format]
    local converter = converters[source_format]

    if not parser then
      print("Error: No parser available for format: " .. source_format)
      return 1
    end

    if not converter then
      print("Error: No converter available for format: " .. source_format)
      return 1
    end

    -- Parse the story
    parsed_story = parser.parse(content)
    if not parsed_story then
      print("Error: Failed to parse story")
      return 1
    end

    -- Convert to Ink
    local convert_fn_name = "to_ink_with_report"
    local convert_fn = converter[convert_fn_name]
    if not convert_fn then
      convert_fn_name = "to_ink"
      convert_fn = converter[convert_fn_name]
    end

    if not convert_fn then
      print("Error: No conversion from " .. source_format .. " to ink")
      return 1
    end

    if convert_fn_name:match("_with_report$") then
      result, report = convert_fn(parsed_story)
    else
      result = convert_fn(parsed_story)
    end

  -- Handle normal Twine format to Twine format conversion
  else
    local parser = parsers[source_format]
    local converter = converters[source_format]

    if not parser then
      print("Error: No parser available for format: " .. source_format)
      return 1
    end

    if not converter then
      print("Error: No converter available for format: " .. source_format)
      return 1
    end

    -- Parse the story
    parsed_story = parser.parse(content)
    if not parsed_story then
      print("Error: Failed to parse story")
      return 1
    end

    -- Perform conversion
    local convert_fn_name = "to_" .. target_format .. "_with_report"
    local convert_fn = converter[convert_fn_name]

    if not convert_fn then
      -- Fall back to non-report version
      convert_fn_name = "to_" .. target_format
      convert_fn = converter[convert_fn_name]
      if not convert_fn then
        print("Error: No conversion available from " .. source_format .. " to " .. target_format)
        return 1
      end
    end

    if convert_fn_name:match("_with_report$") then
      result, report = convert_fn(parsed_story)
    else
      result = convert_fn(parsed_story)
    end
  end

  if not result then
    print("Error: Conversion failed")
    return 1
  end

  -- Determine output path
  local output_path = parsed.output or get_default_output(input_path, target_format)

  -- Write output
  local success, write_err = write_file(output_path, result)
  if not success then
    print("Error: " .. write_err)
    return 1
  end

  if not parsed.quiet then
    print("Converted: " .. input_path .. " -> " .. output_path)
  end

  -- Show report if requested
  if parsed.report and report then
    print_report(report, parsed.quiet)
  end

  -- Save JSON report if requested
  if parsed.json_report and report then
    local json_content = report:to_json(true)
    local json_success, json_err = write_file(parsed.json_report, json_content)
    if not json_success then
      print("Warning: Could not save JSON report: " .. json_err)
    elseif not parsed.quiet then
      print("Report saved: " .. parsed.json_report)
    end
  end

  return 0
end

return ConvertCommand
