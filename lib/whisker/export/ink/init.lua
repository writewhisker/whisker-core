--- Ink Export Module
-- Initializes and registers the Ink exporter
-- @module whisker.export.ink
-- @author Whisker Core Team
-- @license MIT

local InkExporter = require("whisker.export.ink.ink_exporter")

local M = {}

--- Initialize Ink export module
-- @param export_manager table Export manager instance
function M.init(export_manager)
  local ink_exporter = InkExporter.new()
  export_manager:register("ink", ink_exporter)
end

--- Create a new Ink exporter instance
-- @return InkExporter A new exporter
function M.new()
  return InkExporter.new()
end

return M
