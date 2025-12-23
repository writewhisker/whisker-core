--- IFormat Interface
-- Interface for story format handlers (import/export)
-- @module whisker.interfaces.format
-- @author Whisker Core Team
-- @license MIT

local IFormat = {}

--- Check if this format can import the given data
-- @param data string The raw data to check
-- @return boolean True if this format can import the data
function IFormat:can_import(data)
  error("IFormat:can_import must be implemented")
end

--- Import story data from this format
-- @param data string The raw data to import
-- @return Story The imported story object
-- @return string|nil Error message if import failed
function IFormat:import(data)
  error("IFormat:import must be implemented")
end

--- Check if this format can export to the given options
-- @param story Story The story to export
-- @param options table|nil Export options
-- @return boolean True if this format can export
function IFormat:can_export(story, options)
  error("IFormat:can_export must be implemented")
end

--- Export story to this format
-- @param story Story The story to export
-- @param options table|nil Export options
-- @return string The exported data
-- @return string|nil Error message if export failed
function IFormat:export(story, options)
  error("IFormat:export must be implemented")
end

--- Get the format name
-- @return string The format name (e.g., "json", "compact", "twine")
function IFormat:get_name()
  error("IFormat:get_name must be implemented")
end

--- Get supported file extensions
-- @return table Array of supported file extensions (e.g., {".json", ".whisker"})
function IFormat:get_extensions()
  error("IFormat:get_extensions must be implemented")
end

--- Get the MIME type for this format
-- @return string The MIME type (e.g., "application/json")
function IFormat:get_mime_type()
  error("IFormat:get_mime_type must be implemented")
end

return IFormat
