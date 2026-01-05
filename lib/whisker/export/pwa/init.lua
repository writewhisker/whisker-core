--- PWA Export Module
-- @module whisker.export.pwa
-- @author Whisker Core Team
-- @license MIT

local PWAExporter = require("whisker.export.pwa.pwa_exporter")

return {
  PWAExporter = PWAExporter,
  new = PWAExporter.new,
}
