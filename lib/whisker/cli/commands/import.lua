--- Import Command
-- CLI command for importing stories from various formats
-- @module whisker.cli.commands.import
-- @author Whisker Core Team
-- @license MIT

local ImportCommand = {}

--- Command metadata
ImportCommand.name = "import"
ImportCommand.description = "Import a story from another format to WLS"
ImportCommand.usage = "whisker import <input-file> [options]"

--- Command options
ImportCommand.options = {
  {
    name = "output",
    short = "o",
    description = "Output file path (default: <input>.wls)",
    type = "string",
  },
  {
    name = "format",
    short = "f",
    description = "Source format (auto-detect if not specified)",
    type = "string",
    choices = {"twine", "harlowe", "sugarcube", "chapbook", "ink", "json"},
  },
  {
    name = "verbose",
    short = "v",
    description = "Verbose output",
    type = "boolean",
  },
  {
    name = "dry-run",
    short = "n",
    description = "Show what would be done without writing",
    type = "boolean",
  },
  {
    name = "validate",
    description = "Validate the imported story",
    type = "boolean",
    default = true,
  },
}

--- Execute the import command
-- @param args table Command arguments
-- @param options table Command options
-- @return boolean Success
-- @return string|nil Error message
function ImportCommand.run(args, options)
  options = options or {}

  -- Validate input file
  local input_file = args[1]
  if not input_file then
    return false, "No input file specified\nUsage: " .. ImportCommand.usage
  end

  -- Check file exists
  local file = io.open(input_file, "r")
  if not file then
    return false, "Input file not found: " .. input_file
  end

  -- Read content
  local content = file:read("*a")
  file:close()

  if options.verbose then
    print("Reading: " .. input_file .. " (" .. #content .. " bytes)")
  end

  -- Load import manager
  local ok, ImportManager = pcall(require, "whisker.import")
  if not ok then
    return false, "Failed to load import module: " .. tostring(ImportManager)
  end

  local import_manager = ImportManager.new()

  -- Register importers
  local importers = {
    { name = "harlowe", module = "whisker.import.harlowe" },
    { name = "sugarcube", module = "whisker.import.sugarcube" },
    { name = "chapbook", module = "whisker.import.chapbook" },
  }

  for _, imp in ipairs(importers) do
    local importer_ok, importer_module = pcall(require, imp.module)
    if importer_ok then
      local importer = importer_module.new()
      import_manager:register(imp.name, importer)
      if options.verbose then
        print("Registered importer: " .. imp.name)
      end
    end
  end

  -- Detect or use specified format
  local format = options.format
  if not format then
    format = import_manager:detect_format(content)
    if not format then
      -- Try format detector
      local FormatDetector = require("whisker.import.format_detector")
      format = FormatDetector.detect(content)
    end
  end

  if not format then
    return false, "Could not detect source format. Try specifying with --format"
  end

  if options.verbose then
    print("Detected format: " .. format)
  end

  -- Perform import
  local result = import_manager:import(content, format, {
    verbose = options.verbose,
  })

  if result.error then
    return false, "Import failed: " .. result.error
  end

  local story = result.story
  if not story then
    return false, "Import returned no story"
  end

  -- Get passage count
  local passage_count = 0
  if story.passages then
    for _ in pairs(story.passages) do
      passage_count = passage_count + 1
    end
  end

  if options.verbose then
    print("Imported " .. passage_count .. " passages")
  end

  -- Validate if requested
  if options.validate then
    local validate_ok, validators = pcall(require, "whisker.validators")
    if validate_ok and validators.validate then
      local issues = validators.validate(story)
      local error_count = 0
      local warning_count = 0

      for _, issue in ipairs(issues or {}) do
        if issue.severity == "error" then
          error_count = error_count + 1
          if options.verbose then
            print("ERROR: " .. issue.message)
          end
        elseif issue.severity == "warning" then
          warning_count = warning_count + 1
          if options.verbose then
            print("WARNING: " .. issue.message)
          end
        end
      end

      if error_count > 0 then
        print("Validation: " .. error_count .. " errors, " .. warning_count .. " warnings")
      end
    end
  end

  -- Generate output path
  local output_file = options.output
  if not output_file then
    output_file = input_file:gsub("%.%w+$", ".wls")
    if output_file == input_file then
      output_file = input_file .. ".wls"
    end
  end

  -- Convert to WLS format
  local wls_content = import_manager:to_wls(story)

  if options["dry-run"] then
    print("Would write to: " .. output_file)
    print("Output size: " .. #wls_content .. " bytes")
    print("\n--- Preview (first 500 chars) ---")
    print(wls_content:sub(1, 500))
    if #wls_content > 500 then
      print("... [truncated]")
    end
    return true
  end

  -- Write output
  local out_file, out_err = io.open(output_file, "w")
  if not out_file then
    return false, "Failed to write output: " .. tostring(out_err)
  end

  out_file:write(wls_content)
  out_file:close()

  print("Imported: " .. input_file .. " -> " .. output_file)
  print("  Format: " .. format)
  print("  Passages: " .. passage_count)
  print("  Size: " .. #wls_content .. " bytes")

  return true
end

--- Show help for import command
function ImportCommand.help()
  print("Import a story from another format to WLS")
  print("")
  print("Usage: " .. ImportCommand.usage)
  print("")
  print("Supported formats:")
  print("  twine      - Twine HTML archive")
  print("  harlowe    - Harlowe (Twine story format)")
  print("  sugarcube  - SugarCube (Twine story format)")
  print("  chapbook   - Chapbook (Twine story format)")
  print("  ink        - Ink interactive fiction")
  print("  json       - JSON story format")
  print("")
  print("Options:")
  for _, opt in ipairs(ImportCommand.options) do
    local short = opt.short and ("-" .. opt.short .. ", ") or "    "
    local name = "--" .. opt.name
    local desc = opt.description
    if opt.default ~= nil then
      desc = desc .. " (default: " .. tostring(opt.default) .. ")"
    end
    print(string.format("  %s%-15s %s", short, name, desc))
  end
end

return ImportCommand
