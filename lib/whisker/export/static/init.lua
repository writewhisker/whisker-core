--- Static Site Export Module
-- @module whisker.export.static
-- @author Whisker Core Team
-- @license MIT

local StaticExporter = require("whisker.export.static.static_exporter")

return {
  StaticExporter = StaticExporter,
  new = StaticExporter.new,
}
