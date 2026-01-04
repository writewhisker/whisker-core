--- Import Manager
-- Registry and coordinator for import formats
-- @module whisker.import
-- @author Whisker Core Team
-- @license MIT

local ImportManager = {}
ImportManager.__index = ImportManager

--- Create a new import manager instance
-- @param event_bus table Event bus for emitting events
-- @return ImportManager A new import manager
function ImportManager.new(event_bus)
  local self = setmetatable({}, ImportManager)
  self._importers = {}
  self._event_bus = event_bus
  self._format_detector = nil
  return self
end

--- Register an importer for a format
-- @param format string Format identifier (e.g., "twine", "ink", "harlowe")
-- @param importer table IImporter implementation
function ImportManager:register(format, importer)
  -- Validate implements IImporter interface
  local required_methods = {"can_import", "import", "detect", "metadata"}
  for _, method in ipairs(required_methods) do
    if type(importer[method]) ~= "function" then
      error("Importer for '" .. format .. "' missing method: " .. method)
    end
  end

  self._importers[format] = importer

  if self._event_bus then
    self._event_bus:emit("importer:registered", { format = format })
  end
end

--- Unregister an importer
-- @param format string Format identifier
function ImportManager:unregister(format)
  self._importers[format] = nil

  if self._event_bus then
    self._event_bus:emit("importer:unregistered", { format = format })
  end
end

--- Get importer for a format
-- @param format string Format identifier
-- @return table|nil IImporter implementation or nil
function ImportManager:get_importer(format)
  return self._importers[format]
end

--- Get all registered formats
-- @return table Array of format names
function ImportManager:get_formats()
  local formats = {}
  for format in pairs(self._importers) do
    table.insert(formats, format)
  end
  table.sort(formats)
  return formats
end

--- Check if a format is registered
-- @param format string Format identifier
-- @return boolean True if format is registered
function ImportManager:has_format(format)
  return self._importers[format] ~= nil
end

--- Detect the format of source content
-- @param source string The source content to analyze
-- @return string|nil The detected format name, or nil if unknown
function ImportManager:detect_format(source)
  if type(source) ~= "string" or source == "" then
    return nil
  end

  -- Try each registered importer's detect method
  for format, importer in pairs(self._importers) do
    local detected = importer:detect(source)
    if detected then
      return format
    end
  end

  return nil
end

--- Import source content to WLS Story format
-- @param source string The source content
-- @param format string|nil The format (auto-detected if nil)
-- @param options table|nil Import options
-- @return table Import result with story or error
function ImportManager:import(source, format, options)
  options = options or {}

  -- Auto-detect format if not specified
  if not format then
    format = self:detect_format(source)
    if not format then
      return { error = "Could not detect source format" }
    end
  end

  local importer = self:get_importer(format)
  if not importer then
    return { error = "Unknown import format: " .. format }
  end

  -- Check if importer can handle this source
  local can_import, can_error = importer:can_import(source, options)
  if not can_import then
    return {
      error = can_error or ("Importer '" .. format .. "' cannot import this source")
    }
  end

  -- Emit pre-import event
  if self._event_bus then
    local before_result = self._event_bus:emit("import:before", {
      format = format,
      source_length = #source,
      options = options,
    })

    if before_result and before_result.canceled then
      return { error = "Import cancelled by event handler" }
    end
  end

  -- Perform import
  local ok, story = pcall(function()
    return importer:import(source, options)
  end)

  if not ok then
    return { error = "Import failed: " .. tostring(story) }
  end

  -- Create result bundle
  local result = {
    story = story,
    format = format,
    metadata = importer:metadata(),
    warnings = options.warnings or {},
  }

  -- Emit post-import event
  if self._event_bus then
    self._event_bus:emit("import:after", {
      format = format,
      story = story,
      result = result,
    })
  end

  return result
end

--- Import from file path
-- @param filepath string Path to the file
-- @param format string|nil The format (auto-detected if nil)
-- @param options table|nil Import options
-- @return table Import result with story or error
function ImportManager:import_file(filepath, format, options)
  local file, err = io.open(filepath, "r")
  if not file then
    return { error = "Could not open file: " .. tostring(err) }
  end

  local content = file:read("*a")
  file:close()

  -- Auto-detect format from extension if not specified
  if not format then
    format = self:detect_format_from_extension(filepath)
  end

  return self:import(content, format, options)
end

--- Detect format from file extension
-- @param filepath string Path to the file
-- @return string|nil The format name, or nil if unknown
function ImportManager:detect_format_from_extension(filepath)
  local ext = filepath:match("%.([^%.]+)$")
  if not ext then
    return nil
  end
  ext = ext:lower()

  -- Check each importer for matching extension
  for format, importer in pairs(self._importers) do
    local meta = importer:metadata()
    if meta.extensions then
      for _, importer_ext in ipairs(meta.extensions) do
        if importer_ext:lower() == ext or importer_ext:lower() == "." .. ext then
          return format
        end
      end
    end
  end

  return nil
end

--- Get metadata for all registered importers
-- @return table Map of format -> metadata
function ImportManager:get_all_metadata()
  local metadata = {}
  for format, importer in pairs(self._importers) do
    metadata[format] = importer:metadata()
  end
  return metadata
end

--- Convert imported story to WLS format string
-- @param story table The imported story
-- @param options table|nil Conversion options
-- @return string WLS format source
function ImportManager:to_wls(story, options)
  options = options or {}

  local lines = {}

  -- Add metadata
  if story.metadata then
    if story.metadata.name then
      table.insert(lines, "@TITLE " .. story.metadata.name)
    end
    if story.metadata.author then
      table.insert(lines, "@AUTHOR " .. story.metadata.author)
    end
    if story.metadata.ifid then
      table.insert(lines, "@IFID " .. story.metadata.ifid)
    end
    table.insert(lines, "")
  end

  -- Add variables
  if story.variables then
    for name, var in pairs(story.variables) do
      local value = var
      if type(var) == "table" and var.default ~= nil then
        value = var.default
      end
      if type(value) == "string" then
        table.insert(lines, string.format('VAR %s = "%s"', name, value))
      elseif type(value) == "boolean" then
        table.insert(lines, string.format("VAR %s = %s", name, tostring(value)))
      else
        table.insert(lines, string.format("VAR %s = %s", name, tostring(value)))
      end
    end
    if next(story.variables) then
      table.insert(lines, "")
    end
  end

  -- Add passages
  local passages = story:get_all_passages()
  for _, passage in ipairs(passages) do
    -- Passage header
    local header = ":: " .. (passage.name or passage.id)
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, ", ") .. "]"
    end
    table.insert(lines, header)

    -- Passage content
    if passage.content and passage.content ~= "" then
      table.insert(lines, passage.content)
    end

    -- Choices
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        local choice_line = "+ [" .. (choice.text or "Continue") .. "]"
        if choice.target then
          choice_line = choice_line .. " -> " .. choice.target
        end
        table.insert(lines, choice_line)
      end
    end

    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

return ImportManager
