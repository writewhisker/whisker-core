--- PDF Export Module
-- @module whisker.export.pdf
-- @author Whisker Core Team
-- @license MIT

local PDFExporter = require("whisker.export.pdf.pdf_exporter")
local PDFGenerator = require("whisker.export.pdf.pdf_generator")

return {
  PDFExporter = PDFExporter,
  PDFGenerator = PDFGenerator,
  new = PDFExporter.new,
}
