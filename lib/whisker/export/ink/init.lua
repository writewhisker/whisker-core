--- Ink Export Module
-- Initializes and registers the Ink exporter
-- @module whisker.export.ink
-- @author Whisker Core Team
-- @license MIT

local InkExporter = require("whisker.export.ink.ink_exporter")

local M = {}
M._dependencies = {}

--- Initialize Ink export module
-- @param export_manager table Export manager instance
function M.init(export_manager)
  local ink_exporter = InkExporter.new()
  export_manager:register("ink", ink_exporter)
end

--- Create a new Ink exporter instance
-- @return InkExporter A new exporter
function M.new(deps)
  deps = deps or {}
  return InkExporter.new()
end

return M
