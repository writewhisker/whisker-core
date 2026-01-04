--- IImporter Interface
-- Base interface for all format importers
-- @module whisker.import.importer
-- @author Whisker Core Team
-- @license MIT

local IImporter = {}
IImporter.__index = IImporter

--- Create a new base importer (abstract)
-- @return IImporter
function IImporter.new()
  local self = setmetatable({}, IImporter)
  return self
end

--- Check if this importer can handle the given source
-- @param source string The source content
-- @param options table|nil Import options
-- @return boolean can_import True if can import
-- @return string|nil error Error message if cannot import
function IImporter:can_import(source, options)
  error("IImporter:can_import must be implemented by subclass")
end

--- Detect if source matches this format
-- @param source string The source content
-- @return boolean True if source appears to be this format
function IImporter:detect(source)
  error("IImporter:detect must be implemented by subclass")
end

--- Import source content into a Story structure
-- @param source string The source content
-- @param options table|nil Import options
-- @return Story The imported story
function IImporter:import(source, options)
  error("IImporter:import must be implemented by subclass")
end

--- Get importer metadata
-- @return table Metadata including name, version, extensions
function IImporter:metadata()
  return {
    name = "base",
    version = "1.0.0",
    description = "Base importer interface",
    extensions = {},
    mime_types = {},
  }
end

--- Validate the imported result
-- @param story Story The imported story
-- @return table Validation result with errors and warnings
function IImporter:validate(story)
  local result = {
    valid = true,
    errors = {},
    warnings = {},
  }

  -- Basic validation
  if not story then
    result.valid = false
    table.insert(result.errors, "Story is nil")
    return result
  end

  if not story.passages or type(story.passages) ~= "table" then
    result.valid = false
    table.insert(result.errors, "Story has no passages")
  end

  return result
end

return IImporter
