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

  -- Link and image tracking
  self.link_destinations = {} -- Named destinations for internal links
  self.images = {} -- Embedded images
  self.page_numbering = {
    enabled = false,
    start_page = 1,
    format = "Page %d",
    position = "bottom", -- "top" or "bottom"
    align = "center", -- "left", "center", "right"
    margin = 30,
  }

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

  -- Add page number if enabled
  local page_index = #self.pages
  local page_num_stream = self:_add_page_number(page_index)
  if page_num_stream then
    table.insert(self.current_page.content, page_num_stream)
    self.current_page.fonts_used["helvetica"] = true
  end

  -- Create content stream object
  local content_str = table.concat(self.current_page.content, "\n")
  local content_id = self:_add_object({
    type = "stream",
    content = content_str
  })
  self.current_page.content_id = content_id

  -- Create annotation objects if any
  local annot_ids = {}
  if self.current_page.annotations then
    for _, annot in ipairs(self.current_page.annotations) do
      local annot_id = self:_add_object({
        type = "annotation",
        annot_type = annot.type,
        x = annot.x,
        y = annot.y,
        width = annot.width,
        height = annot.height,
        destination = annot.destination,
        url = annot.url,
      })
      table.insert(annot_ids, annot_id)
    end
  end

  -- Create page object
  local page_id = self:_add_object({
    type = "page",
    width = self.page_width,
    height = self.page_height,
    content_id = content_id,
    fonts_used = self.current_page.fonts_used,
    images_used = self.current_page.images_used,
    annot_ids = annot_ids,
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

--- Enable page numbering
-- @param options table Options: start_page, format, position, align, margin
function PDFGenerator:enable_page_numbering(options)
  options = options or {}
  self.page_numbering.enabled = true
  self.page_numbering.start_page = options.start_page or 1
  self.page_numbering.format = options.format or "Page %d"
  self.page_numbering.position = options.position or "bottom"
  self.page_numbering.align = options.align or "center"
  self.page_numbering.margin = options.margin or 30
end

--- Add a named destination for internal linking
-- @param name string Destination name
-- @param page_index number Page index (1-based)
-- @param y number Y position on page
function PDFGenerator:add_destination(name, page_index, y)
  self.link_destinations[name] = {
    page_index = page_index or #self.pages,
    y = y or self.page_height,
  }
end

--- Add an internal link annotation
-- @param x number X position
-- @param y number Y position
-- @param width number Link width
-- @param height number Link height
-- @param destination string Destination name
function PDFGenerator:add_link(x, y, width, height, destination)
  if not self.current_page then
    self:add_page()
  end

  -- Initialize annotations array if needed
  if not self.current_page.annotations then
    self.current_page.annotations = {}
  end

  table.insert(self.current_page.annotations, {
    type = "link",
    x = x,
    y = y,
    width = width,
    height = height,
    destination = destination,
  })
end

--- Add an external URL link annotation
-- @param x number X position
-- @param y number Y position
-- @param width number Link width
-- @param height number Link height
-- @param url string External URL
function PDFGenerator:add_url_link(x, y, width, height, url)
  if not self.current_page then
    self:add_page()
  end

  if not self.current_page.annotations then
    self.current_page.annotations = {}
  end

  table.insert(self.current_page.annotations, {
    type = "url",
    x = x,
    y = y,
    width = width,
    height = height,
    url = url,
  })
end

--- Draw text with an internal link
-- @param text string Text to draw
-- @param x number X position
-- @param y number Y position
-- @param destination string Destination name
function PDFGenerator:text_link(text, x, y, destination)
  -- Draw the text
  self:text(text, x, y)

  -- Estimate text width for link area
  local text_width = #text * self.font_size * 0.5
  local text_height = self.font_size

  -- Add link annotation
  self:add_link(x, y - text_height, text_width, text_height, destination)
end

--- Embed an image (PNG or JPEG)
-- @param image_data string Raw image data
-- @param format string Image format ("png" or "jpeg")
-- @param x number X position
-- @param y number Y position
-- @param width number Display width
-- @param height number Display height
-- @return boolean Success
function PDFGenerator:add_image(image_data, format, x, y, width, height)
  if not self.current_page then
    self:add_page()
  end

  format = format or "jpeg"

  -- Parse image dimensions from data (simplified)
  local img_width, img_height = self:_parse_image_dimensions(image_data, format)

  -- Create image XObject
  local image_id = self:_add_object({
    type = "image",
    format = format,
    data = image_data,
    width = img_width or width,
    height = img_height or height,
  })

  -- Store image reference
  local img_ref = "Im" .. #self.images + 1
  table.insert(self.images, {
    id = image_id,
    ref = img_ref,
  })

  -- Track image usage on current page
  if not self.current_page.images_used then
    self.current_page.images_used = {}
  end
  self.current_page.images_used[img_ref] = image_id

  -- Add image drawing command to content stream
  local stream = string.format(
    "q %.2f 0 0 %.2f %.2f %.2f cm /%s Do Q",
    width, height, x, y - height, img_ref
  )
  table.insert(self.current_page.content, stream)

  return true
end

--- Parse image dimensions from raw data
-- @param data string Image data
-- @param format string Image format
-- @return number, number Width and height
function PDFGenerator:_parse_image_dimensions(data, format)
  if format == "png" then
    -- PNG: dimensions at bytes 16-23
    if #data >= 24 and data:sub(1, 8) == "\137PNG\r\n\26\n" then
      local w1, w2, w3, w4 = data:byte(17, 20)
      local h1, h2, h3, h4 = data:byte(21, 24)
      local width = w1 * 16777216 + w2 * 65536 + w3 * 256 + w4
      local height = h1 * 16777216 + h2 * 65536 + h3 * 256 + h4
      return width, height
    end
  elseif format == "jpeg" then
    -- JPEG: search for SOF0 marker (0xFFC0)
    local i = 1
    while i < #data - 10 do
      if data:byte(i) == 0xFF then
        local marker = data:byte(i + 1)
        if marker >= 0xC0 and marker <= 0xCF and marker ~= 0xC4 and marker ~= 0xC8 and marker ~= 0xCC then
          local height = data:byte(i + 5) * 256 + data:byte(i + 6)
          local width = data:byte(i + 7) * 256 + data:byte(i + 8)
          return width, height
        end
        local len = data:byte(i + 2) * 256 + data:byte(i + 3)
        i = i + len + 2
      else
        i = i + 1
      end
    end
  end
  return 100, 100 -- Default fallback
end

--- Add page number to a page
-- @param page_index number Page index (1-based)
function PDFGenerator:_add_page_number(page_index)
  if not self.page_numbering.enabled then return end
  if page_index < self.page_numbering.start_page then return end

  local page_num = page_index - self.page_numbering.start_page + 1
  local text = string.format(self.page_numbering.format, page_num)

  -- Calculate position
  local y
  if self.page_numbering.position == "top" then
    y = self.page_height - self.page_numbering.margin
  else
    y = self.page_numbering.margin
  end

  local x
  local text_width = #text * self.font_size * 0.5
  if self.page_numbering.align == "left" then
    x = self.page_numbering.margin
  elseif self.page_numbering.align == "right" then
    x = self.page_width - self.page_numbering.margin - text_width
  else -- center
    x = (self.page_width - text_width) / 2
  end

  -- Build page number text command
  local font = self.fonts["helvetica"]
  local stream = string.format(
    "BT /%s %d Tf %.0f %.0f Td (%s) Tj ET",
    font.ref, 10, x, y, self:_escape_string(text)
  )

  return stream
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
    -- Add destinations if any
    local dests_str = ""
    if next(self.link_destinations) then
      local dests = {}
      for name, dest in pairs(self.link_destinations) do
        local page_id = page_ids[dest.page_index] or page_ids[1]
        table.insert(dests, string.format(
          "/%s [%d 0 R /XYZ 0 %.2f null]",
          self:_escape_name(name), page_id, dest.y
        ))
      end
      dests_str = " /Dests << " .. table.concat(dests, " ") .. " >>"
    end
    table.insert(parts, "<< /Type /Catalog /Pages 2 0 R" .. dests_str .. " >>\n")

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

    -- Build image resources
    local xobject_dict = ""
    if obj.images_used and next(obj.images_used) then
      local img_refs = {}
      for ref, id in pairs(obj.images_used) do
        table.insert(img_refs, string.format("/%s %d 0 R", ref, id))
      end
      xobject_dict = " /XObject <<" .. table.concat(img_refs, " ") .. ">>"
    end

    -- Build annotations reference
    local annots_str = ""
    if obj.annot_ids and #obj.annot_ids > 0 then
      local annot_refs = {}
      for _, aid in ipairs(obj.annot_ids) do
        table.insert(annot_refs, string.format("%d 0 R", aid))
      end
      annots_str = " /Annots [" .. table.concat(annot_refs, " ") .. "]"
    end

    table.insert(parts, string.format(
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] " ..
      "/Contents %d 0 R /Resources << /Font %s%s >>%s >>\n",
      obj.width, obj.height,
      obj.content_id,
      fonts_dict, xobject_dict, annots_str
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

  elseif obj.type == "annotation" then
    local rect = string.format("[%.2f %.2f %.2f %.2f]",
      obj.x, obj.y, obj.x + obj.width, obj.y + obj.height)

    if obj.annot_type == "link" and obj.destination then
      -- Internal link
      table.insert(parts, string.format(
        "<< /Type /Annot /Subtype /Link /Rect %s /Border [0 0 0] " ..
        "/Dest /%s >>\n",
        rect, self:_escape_name(obj.destination)
      ))
    elseif obj.annot_type == "url" and obj.url then
      -- External URL link
      table.insert(parts, string.format(
        "<< /Type /Annot /Subtype /Link /Rect %s /Border [0 0 0] " ..
        "/A << /Type /Action /S /URI /URI (%s) >> >>\n",
        rect, self:_escape_string(obj.url)
      ))
    else
      table.insert(parts, "<< /Type /Annot /Subtype /Link /Rect [0 0 0 0] >>\n")
    end

  elseif obj.type == "image" then
    -- Simplified image XObject (DCTDecode for JPEG, FlateDecode for others)
    local filter = obj.format == "jpeg" and "/DCTDecode" or "/FlateDecode"
    local colorspace = "/DeviceRGB"
    local data = obj.data or ""

    table.insert(parts, string.format(
      "<< /Type /XObject /Subtype /Image /Width %d /Height %d " ..
      "/ColorSpace %s /BitsPerComponent 8 /Filter %s /Length %d >>\n" ..
      "stream\n%s\nendstream\n",
      obj.width, obj.height, colorspace, filter, #data, data
    ))
  end

  table.insert(parts, "endobj\n")

  return table.concat(parts)
end

--- Escape a name for PDF (remove spaces, special chars)
-- @param name string Input name
-- @return string Escaped name
function PDFGenerator:_escape_name(name)
  if not name then return "unnamed" end
  return name:gsub("[^%w_]", "_")
end

return PDFGenerator
