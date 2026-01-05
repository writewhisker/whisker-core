--- Pure Lua PDF Generator
-- Generates valid PDF 1.4 documents without external dependencies
-- @module whisker.export.pdf.pdf_generator
-- @author Whisker Core Team
-- @license MIT

local PDFGenerator = {}
PDFGenerator.__index = PDFGenerator
PDFGenerator._dependencies = {}

--- Page format specifications (in points, 1 point = 1/72 inch)
PDFGenerator.FORMATS = {
  a4 = { width = 595.28, height = 841.89 },
  letter = { width = 612, height = 792 },
  legal = { width = 612, height = 1008 },
}

--- Standard fonts available in PDF (14 base fonts)
PDFGenerator.FONTS = {
  helvetica = "Helvetica",
  ["helvetica-bold"] = "Helvetica-Bold",
  ["helvetica-italic"] = "Helvetica-Oblique",
  ["helvetica-bolditalic"] = "Helvetica-BoldOblique",
  times = "Times-Roman",
  ["times-bold"] = "Times-Bold",
  ["times-italic"] = "Times-Italic",
  ["times-bolditalic"] = "Times-BoldItalic",
  courier = "Courier",
  ["courier-bold"] = "Courier-Bold",
  ["courier-italic"] = "Courier-Oblique",
  ["courier-bolditalic"] = "Courier-BoldOblique",
}

--- Create a new PDF document
-- @param options table Options: format, orientation
-- @return PDFGenerator New PDF generator instance
function PDFGenerator.new(options)
  options = options or {}

  local self = setmetatable({}, PDFGenerator)

  -- Page dimensions
  local format = PDFGenerator.FORMATS[options.format or "a4"]
  if options.orientation == "landscape" then
    self.page_width = format.height
    self.page_height = format.width
  else
    self.page_width = format.width
    self.page_height = format.height
  end

  -- PDF objects
  self.objects = {}
  self.pages = {}
  self.current_page = nil
  self.object_count = 0

  -- Font state
  self.fonts = {}
  self.current_font = "helvetica"
  self.font_size = 12
  self.line_height = 1.5

  -- Drawing state
  self.x = 0
  self.y = 0

  -- Initialize document structure
  self:_init_document()

  return self
end

--- Initialize PDF document structure
function PDFGenerator:_init_document()
  -- Add catalog (will be object 1)
  self:_add_object({ type = "catalog" })

  -- Add pages container (will be object 2)
  self:_add_object({ type = "pages" })

  -- Register standard fonts
  self:_register_font("helvetica")
  self:_register_font("helvetica-bold")
  self:_register_font("helvetica-italic")
  self:_register_font("times")
end

--- Add an object to the document
-- @param obj table Object data
-- @return number Object ID
function PDFGenerator:_add_object(obj)
  self.object_count = self.object_count + 1
  obj.id = self.object_count
  self.objects[self.object_count] = obj
  return self.object_count
end

--- Register a font for use
-- @param font_name string Font identifier
function PDFGenerator:_register_font(font_name)
  if self.fonts[font_name] then return end

  local pdf_name = PDFGenerator.FONTS[font_name] or "Helvetica"
  local obj_id = self:_add_object({
    type = "font",
    subtype = "Type1",
    name = pdf_name,
    encoding = "WinAnsiEncoding"
  })

  self.fonts[font_name] = {
    id = obj_id,
    name = pdf_name,
    ref = "F" .. #self.fonts + 1
  }
end

--- Add a new page to the document
function PDFGenerator:add_page()
  -- Finalize previous page if exists
  if self.current_page then
    self:_finalize_page()
  end

  -- Create new page
  self.current_page = {
    content = {},
    fonts_used = {},
  }
  table.insert(self.pages, self.current_page)

  -- Reset position to top-left
  self.x = 0
  self.y = self.page_height
end

--- Finalize the current page (internal)
function PDFGenerator:_finalize_page()
  if not self.current_page then return end

  -- Create content stream object
  local content_str = table.concat(self.current_page.content, "\n")
  local content_id = self:_add_object({
    type = "stream",
    content = content_str
  })
  self.current_page.content_id = content_id

  -- Create page object
  local page_id = self:_add_object({
    type = "page",
    width = self.page_width,
    height = self.page_height,
    content_id = content_id,
    fonts_used = self.current_page.fonts_used
  })
  self.current_page.page_id = page_id
end

--- Set the current font
-- @param font_name string Font identifier
-- @param size number Font size in points
function PDFGenerator:set_font(font_name, size)
  font_name = font_name or self.current_font
  size = size or self.font_size

  -- Ensure font is registered
  if not self.fonts[font_name] then
    self:_register_font(font_name)
  end

  self.current_font = font_name
  self.font_size = size

  -- Track font usage on current page
  if self.current_page then
    self.current_page.fonts_used[font_name] = true
  end
end

--- Set font size
-- @param size number Font size in points
function PDFGenerator:set_font_size(size)
  self.font_size = size
end

--- Set line height factor
-- @param factor number Line height multiplier
function PDFGenerator:set_line_height(factor)
  self.line_height = factor
end

--- Get the current Y position
-- @return number Current Y position
function PDFGenerator:get_y()
  return self.y
end

--- Set the Y position
-- @param y number New Y position
function PDFGenerator:set_y(y)
  self.y = y
end

--- Get page dimensions
-- @return number, number Width and height
function PDFGenerator:get_page_size()
  return self.page_width, self.page_height
end

--- Escape special PDF string characters
-- @param str string Input string
-- @return string Escaped string
function PDFGenerator:_escape_string(str)
  if not str then return "" end
  return str
    :gsub("\\", "\\\\")
    :gsub("%(", "\\(")
    :gsub("%)", "\\)")
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
end

--- Split text into lines that fit within a given width
-- @param text string Text to split
-- @param max_width number Maximum width in points
-- @return table Array of lines
function PDFGenerator:split_text_to_size(text, max_width)
  if not text or text == "" then return {} end

  local lines = {}
  local avg_char_width = self.font_size * 0.5 -- Rough estimate for Helvetica
  local chars_per_line = math.floor(max_width / avg_char_width)

  -- Split by existing line breaks first
  for paragraph in text:gmatch("[^\n]+") do
    local words = {}
    for word in paragraph:gmatch("%S+") do
      table.insert(words, word)
    end

    local current_line = ""
    for _, word in ipairs(words) do
      local test_line = current_line == "" and word or (current_line .. " " .. word)
      if #test_line <= chars_per_line then
        current_line = test_line
      else
        if current_line ~= "" then
          table.insert(lines, current_line)
        end
        current_line = word
      end
    end
    if current_line ~= "" then
      table.insert(lines, current_line)
    end
  end

  return lines
end

--- Draw text at a position
-- @param text string Text to draw
-- @param x number X position
-- @param y number Y position
-- @param options table Options: align, maxWidth
function PDFGenerator:text(text, x, y, options)
  if not self.current_page then
    self:add_page()
  end

  options = options or {}

  -- Handle text splitting for multi-line
  local lines
  if type(text) == "table" then
    lines = text
  else
    lines = { text }
  end

  -- Get font reference
  local font = self.fonts[self.current_font]
  if not font then
    self:set_font("helvetica")
    font = self.fonts["helvetica"]
  end

  -- Handle alignment
  local actual_x = x
  if options.align == "center" then
    -- For center alignment, estimate text width
    actual_x = x -- Will be centered by caller
  elseif options.align == "right" then
    -- For right alignment
    actual_x = x
  end

  -- Build PDF content stream commands
  local stream = {}
  table.insert(stream, "BT") -- Begin text
  table.insert(stream, string.format("/%s %d Tf", font.ref, math.floor(self.font_size)))

  -- PDF Y coordinates are from bottom, so we need to flip
  local pdf_y = y
  for _, line in ipairs(lines) do
    local escaped = self:_escape_string(line)
    table.insert(stream, string.format("%.0f %.0f Td", actual_x, pdf_y))
    table.insert(stream, string.format("(%s) Tj", escaped))
    pdf_y = pdf_y - (self.font_size * self.line_height)
  end

  table.insert(stream, "ET") -- End text

  table.insert(self.current_page.content, table.concat(stream, " "))

  -- Update current position
  self.x = x
  self.y = pdf_y

  -- Track font usage
  self.current_page.fonts_used[self.current_font] = true
end

--- Generate the complete PDF content
-- @return string PDF document as string
function PDFGenerator:output()
  -- Finalize last page
  if self.current_page then
    self:_finalize_page()
  end

  local parts = {}
  local offsets = {}
  local offset = 0

  -- PDF Header
  local header = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n"
  table.insert(parts, header)
  offset = offset + #header

  -- Collect page object IDs
  local page_ids = {}
  for _, page in ipairs(self.pages) do
    table.insert(page_ids, page.page_id)
  end

  -- Write all objects
  for i = 1, self.object_count do
    local obj = self.objects[i]
    offsets[i] = offset

    local obj_str = self:_render_object(obj, page_ids)
    table.insert(parts, obj_str)
    offset = offset + #obj_str
  end

  -- Cross-reference table
  local xref_offset = offset
  local xref = "xref\n"
  xref = xref .. string.format("0 %d\n", self.object_count + 1)
  xref = xref .. "0000000000 65535 f \n"
  for i = 1, self.object_count do
    xref = xref .. string.format("%010d 00000 n \n", offsets[i])
  end
  table.insert(parts, xref)

  -- Trailer
  local trailer = "trailer\n"
  trailer = trailer .. string.format("<< /Size %d /Root 1 0 R >>\n", self.object_count + 1)
  trailer = trailer .. "startxref\n"
  trailer = trailer .. tostring(xref_offset) .. "\n"
  trailer = trailer .. "%%EOF\n"
  table.insert(parts, trailer)

  return table.concat(parts)
end

--- Render a PDF object to string
-- @param obj table Object data
-- @param page_ids table Array of page object IDs
-- @return string Object string
function PDFGenerator:_render_object(obj, page_ids)
  local parts = {}

  table.insert(parts, string.format("%d 0 obj\n", obj.id))

  if obj.type == "catalog" then
    table.insert(parts, "<< /Type /Catalog /Pages 2 0 R >>\n")

  elseif obj.type == "pages" then
    local kids = {}
    for _, pid in ipairs(page_ids) do
      table.insert(kids, string.format("%d 0 R", pid))
    end
    table.insert(parts, string.format(
      "<< /Type /Pages /Kids [%s] /Count %d >>\n",
      table.concat(kids, " "),
      #page_ids
    ))

  elseif obj.type == "page" then
    -- Build font resources
    local font_refs = {}
    for font_name in pairs(obj.fonts_used or {}) do
      local font = self.fonts[font_name]
      if font then
        table.insert(font_refs, string.format("/%s %d 0 R", font.ref, font.id))
      end
    end
    local fonts_dict = "<<" .. table.concat(font_refs, " ") .. ">>"

    table.insert(parts, string.format(
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] " ..
      "/Contents %d 0 R /Resources << /Font %s >> >>\n",
      obj.width, obj.height,
      obj.content_id,
      fonts_dict
    ))

  elseif obj.type == "font" then
    table.insert(parts, string.format(
      "<< /Type /Font /Subtype /%s /BaseFont /%s /Encoding /%s >>\n",
      obj.subtype, obj.name, obj.encoding
    ))

  elseif obj.type == "stream" then
    local content = obj.content or ""
    local len = #content
    table.insert(parts, string.format(
      "<< /Length %d >>\nstream\n%s\nendstream\n",
      len, content
    ))
  end

  table.insert(parts, "endobj\n")

  return table.concat(parts)
end

return PDFGenerator
