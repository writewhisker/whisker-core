--- HTML Export Module
-- Initializes and registers the HTML exporter
-- @module whisker.export.html
-- @author Whisker Core Team
-- @license MIT

local HTMLExporter = require("whisker.export.html.html_exporter")

local M = {}
M._dependencies = {}

--- Initialize HTML export module
-- @param export_manager table Export manager instance
function M.init(export_manager)
  local html_exporter = HTMLExporter.new()
  export_manager:register("html", html_exporter)
end

--- Create a new HTML exporter instance
-- @return HTMLExporter A new exporter
function M.new(deps)
  deps = deps or {}
  return HTMLExporter.new()
end

return M
