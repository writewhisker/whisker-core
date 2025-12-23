--- IExporter Interface
-- Interface for story export formats
-- @module whisker.interfaces.i_exporter
-- @author Whisker Core Team
-- @license MIT

--- IExporter interface definition
-- Every export format (HTML, Ink JSON, text, etc.) must implement this interface.
-- The export manager uses this interface to work with exporters polymorphically.
-- @type IExporter
local IExporter = {}

--- Checks if this exporter can export the given story
-- @param story table Story data structure
-- @param options table Export options (format-specific)
-- @return boolean True if export is possible
function IExporter:can_export(story, options)
  error("IExporter:can_export() must be implemented")
end

--- Export story to target format
-- @param story table Story data structure
-- @param options table Export options:
--   - output_path: string (optional) - Path to write output file
--   - template: string (optional) - Template to use for rendering
--   - minify: boolean - Whether to minify output
--   - inline_assets: boolean - Whether to inline assets
--   - ... format-specific options
-- @return table Export bundle:
--   {
--     content = "string or bytes",
--     assets = { {path="...", content="...", type="..."}, ... },
--     manifest = { format="...", version="...", created_at="..." },
--   }
function IExporter:export(story, options)
  error("IExporter:export() must be implemented")
end

--- Validate exported output
-- @param export_bundle table Result from export()
-- @return table Validation result:
--   {
--     valid = true/false,
--     errors = { {message="...", severity="error|warning"}, ... },
--   }
function IExporter:validate(export_bundle)
  error("IExporter:validate() must be implemented")
end

--- Get exporter metadata
-- @return table Metadata:
--   {
--     format = "html|ink|text|...",
--     version = "1.0.0",
--     description = "...",
--     file_extension = ".html|.json|.txt",
--   }
function IExporter:metadata()
  error("IExporter:metadata() must be implemented")
end

return IExporter
