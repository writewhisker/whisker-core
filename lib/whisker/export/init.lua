--- Export Manager
-- Registry and coordinator for export formats
-- @module whisker.export
-- @author Whisker Core Team
-- @license MIT

local ExportManager = {}
ExportManager.__index = ExportManager

--- Create a new export manager instance
-- @param event_bus table Event bus for emitting events
-- @return ExportManager A new export manager
function ExportManager.new(event_bus)
  local self = setmetatable({}, ExportManager)
  self._exporters = {}
  self._event_bus = event_bus
  return self
end

--- Register an exporter for a format
-- @param format string Format identifier (e.g., "html", "ink", "text")
-- @param exporter table IExporter implementation
function ExportManager:register(format, exporter)
  -- Validate implements IExporter
  local required_methods = {"can_export", "export", "validate", "metadata"}
  for _, method in ipairs(required_methods) do
    if type(exporter[method]) ~= "function" then
      error("Exporter for '" .. format .. "' missing method: " .. method)
    end
  end

  self._exporters[format] = exporter

  if self._event_bus then
    self._event_bus:emit("exporter:registered", { format = format })
  end
end

--- Unregister an exporter
-- @param format string Format identifier
function ExportManager:unregister(format)
  self._exporters[format] = nil

  if self._event_bus then
    self._event_bus:emit("exporter:unregistered", { format = format })
  end
end

--- Get exporter for a format
-- @param format string Format identifier
-- @return table|nil IExporter implementation or nil
function ExportManager:get_exporter(format)
  return self._exporters[format]
end

--- Get all registered formats
-- @return table Array of format names
function ExportManager:get_formats()
  local formats = {}
  for format in pairs(self._exporters) do
    table.insert(formats, format)
  end
  table.sort(formats)
  return formats
end

--- Check if a format is registered
-- @param format string Format identifier
-- @return boolean True if format is registered
function ExportManager:has_format(format)
  return self._exporters[format] ~= nil
end

--- Export a story to the specified format
-- @param story table Story data structure
-- @param format string Target format
-- @param options table Export options
-- @return table Export bundle or error
function ExportManager:export(story, format, options)
  options = options or {}

  local exporter = self:get_exporter(format)
  if not exporter then
    return { error = "Unknown export format: " .. format }
  end

  -- Check if exporter can handle this story
  local can_export, can_error = exporter:can_export(story, options)
  if not can_export then
    return {
      error = can_error or ("Exporter '" .. format .. "' cannot export this story")
    }
  end

  -- Emit pre-export event (allows plugins to modify story/options)
  if self._event_bus then
    local before_result = self._event_bus:emit("export:before", {
      story = story,
      format = format,
      options = options,
    })

    -- Check if export was cancelled
    if before_result.canceled then
      return { error = "Export cancelled by event handler" }
    end
  end

  -- Perform export
  local ok, bundle = pcall(function()
    return exporter:export(story, options)
  end)

  if not ok then
    return { error = "Export failed: " .. tostring(bundle) }
  end

  -- Validate export
  local validation = exporter:validate(bundle)
  bundle.validation = validation

  -- Emit post-export event
  if self._event_bus then
    self._event_bus:emit("export:after", {
      format = format,
      bundle = bundle,
      validation = validation,
    })
  end

  return bundle
end

--- Export a story to multiple formats
-- @param story table Story data structure
-- @param formats table Array of format names
-- @param options table Export options (can include format-specific sub-tables)
-- @return table Map of format -> bundle
function ExportManager:export_all(story, formats, options)
  options = options or {}
  local results = {}

  for _, format in ipairs(formats) do
    -- Get format-specific options
    local format_options = options[format] or options
    results[format] = self:export(story, format, format_options)
  end

  return results
end

--- Get metadata for all registered exporters
-- @return table Map of format -> metadata
function ExportManager:get_all_metadata()
  local metadata = {}
  for format, exporter in pairs(self._exporters) do
    metadata[format] = exporter:metadata()
  end
  return metadata
end

return ExportManager
