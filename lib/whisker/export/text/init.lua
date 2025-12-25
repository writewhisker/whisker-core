--- Text Export Module
-- Initializes and registers the text exporter
-- @module whisker.export.text
-- @author Whisker Core Team
-- @license MIT

local TextExporter = require("whisker.export.text.text_exporter")

local M = {}
M._dependencies = {}

--- Initialize text export module
-- @param export_manager table Export manager instance
function M.init(export_manager)
  local text_exporter = TextExporter.new()
  export_manager:register("text", text_exporter)
end

--- Create a new text exporter instance
-- @return TextExporter A new exporter
function M.new(deps)
  deps = deps or {}
  return TextExporter.new()
end

return M
