-- EPUB Exporter
-- Export stories to EPUB format for e-readers

local M = {}
M._dependencies = {}

--- Create a new EPUB exporter
-- @return table Exporter instance
function M.new(deps)
  deps = deps or {}
  local self = setmetatable({}, {__index = M})
  return self
end

--- Get exporter metadata
-- @return table Metadata
function M:metadata()
  return {
    format = "epub",
    version = "1.0.0",
    description = "EPUB format for e-readers",
    file_extension = ".epub",
  }
end

--- Check if story can be exported
-- @param story table Story data
-- @param options table Export options
-- @return boolean, string Whether export is possible and any error
function M:can_export(story, options)
  if not story then
    return false, "No story provided"
  end
  if not story.passages or #story.passages == 0 then
    return false, "Story has no passages"
  end
  return true
end

--- Escape XML special characters
-- @param text string Text to escape
-- @return string Escaped text
function M:escape_xml(text)
  if not text then return "" end
  return text
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
    :gsub("'", "&apos;")
end

--- Generate UUID
-- @return string UUID
function M:generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

--- Make safe filename from passage name
-- @param name string Passage name
-- @return string Safe filename
function M:make_filename(name)
  return name:lower():gsub("%s+", "_"):gsub("[^%w_]", "") .. ".xhtml"
end

--- Strip format-specific macros and convert links to XHTML
-- @param content string Passage content
-- @param format string Source format
-- @param passages table All passages (for link resolution)
-- @return string XHTML content
function M:convert_content(content, format, passages)
  local text = content

  -- Strip macros based on format
  if format == "harlowe" then
    text = text:gsub("%(%s*set:%s*[^%)]+%)", "")
    text = text:gsub("%(%s*if:%s*[^%)]+%)%[([^%]]+)%]", "%1")
    text = text:gsub("%(%s*print:%s*%$([%w_]+)%s*%)", "<em>%1</em>")
    text = text:gsub("%$([%w_]+)", "<em>%1</em>")
  elseif format == "sugarcube" then
    text = text:gsub("<<%s*set%s+[^>]+>>", "")
    text = text:gsub("<<%s*if%s+[^>]+>>(.-)<</%s*if%s*>>", "%1")
    text = text:gsub("<<%s*print%s+%$([%w_]+)%s*>>", "<em>%1</em>")
    text = text:gsub("%$([%w_]+)", "<em>%1</em>")
  elseif format == "chapbook" then
    text = text:gsub("^[%w_]+:%s*[^\n]+\n%-%-\n?", "")
    text = text:gsub("{([%w_]+)}", "<em>%1</em>")
  elseif format == "snowman" then
    text = text:gsub("<%%%s*[^%%]+%s*%%>", "")
    text = text:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "<em>%1</em>")
  end

  -- Convert links to XHTML links
  if format == "harlowe" or format == "chapbook" then
    text = text:gsub("%[%[([^%]>]+)%->([^%]]+)%]%]", function(link_text, target)
      local filename = self:make_filename(target)
      return '<a href="' .. filename .. '">' .. self:escape_xml(link_text) .. '</a>'
    end)
    text = text:gsub("%[%[([^%]|>]+)%]%]", function(target)
      local filename = self:make_filename(target)
      return '<a href="' .. filename .. '">' .. self:escape_xml(target) .. '</a>'
    end)
  elseif format == "sugarcube" then
    text = text:gsub("%[%[([^%]|]+)%|([^%]]+)%]%]", function(link_text, target)
      local filename = self:make_filename(target)
      return '<a href="' .. filename .. '">' .. self:escape_xml(link_text) .. '</a>'
    end)
    text = text:gsub("%[%[([^%]|]+)%]%]", function(target)
      local filename = self:make_filename(target)
      return '<a href="' .. filename .. '">' .. self:escape_xml(target) .. '</a>'
    end)
  elseif format == "snowman" then
    text = text:gsub("%[([^%]]+)%]%(([^%)]+)%)", function(link_text, target)
      local filename = self:make_filename(target)
      return '<a href="' .. filename .. '">' .. self:escape_xml(link_text) .. '</a>'
    end)
  end

  -- Convert line breaks to paragraphs
  local paragraphs = {}
  for para in (text .. "\n\n"):gmatch("([^\n]+)\n") do
    para = para:match("^%s*(.-)%s*$")
    if #para > 0 then
      table.insert(paragraphs, "<p>" .. para .. "</p>")
    end
  end

  return table.concat(paragraphs, "\n    ")
end

--- Generate container.xml
-- @return string Container XML content
function M:generate_container()
  return [[<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>]]
end

--- Generate content.opf
-- @param story table Story data
-- @param uuid string UUID for the book
-- @return string OPF content
function M:generate_opf(story, uuid)
  local title = self:escape_xml(story.name or "Untitled")
  local author = self:escape_xml(story.author or "Unknown Author")

  local manifest_items = {}
  local spine_items = {}

  -- Add nav
  table.insert(manifest_items, '    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>')

  -- Add passages
  for i, passage in ipairs(story.passages) do
    local id = "passage" .. i
    local filename = self:make_filename(passage.name)
    table.insert(manifest_items, '    <item id="' .. id .. '" href="' .. filename .. '" media-type="application/xhtml+xml"/>')
    table.insert(spine_items, '    <itemref idref="' .. id .. '"/>')
  end

  return [[<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:uuid:]] .. uuid .. [[</dc:identifier>
    <dc:title>]] .. title .. [[</dc:title>
    <dc:creator>]] .. author .. [[</dc:creator>
    <dc:language>en</dc:language>
    <meta property="dcterms:modified">]] .. os.date("%Y-%m-%dT%H:%M:%SZ") .. [[</meta>
  </metadata>
  <manifest>
]] .. table.concat(manifest_items, "\n") .. [[

  </manifest>
  <spine>
]] .. table.concat(spine_items, "\n") .. [[

  </spine>
</package>]]
end

--- Generate nav.xhtml (table of contents)
-- @param story table Story data
-- @return string Navigation XHTML
function M:generate_nav(story)
  local title = self:escape_xml(story.name or "Untitled")
  local nav_items = {}

  for i, passage in ipairs(story.passages) do
    local filename = self:make_filename(passage.name)
    table.insert(nav_items, '      <li><a href="' .. filename .. '">' .. self:escape_xml(passage.name) .. '</a></li>')
  end

  return [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head>
  <title>]] .. title .. [[</title>
</head>
<body>
  <nav epub:type="toc">
    <h1>Table of Contents</h1>
    <ol>
]] .. table.concat(nav_items, "\n") .. [[

    </ol>
  </nav>
</body>
</html>]]
end

--- Generate passage XHTML
-- @param passage table Passage data
-- @param story table Story data
-- @return string Passage XHTML
function M:generate_passage_xhtml(passage, story)
  local title = self:escape_xml(passage.name)
  local content = self:convert_content(passage.content, story.format, story.passages)

  return [[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>]] .. title .. [[</title>
</head>
<body>
  <h1>]] .. title .. [[</h1>
  <div class="passage">
    ]] .. content .. [[

  </div>
</body>
</html>]]
end

--- Export story to EPUB structure
-- @param story table Story data
-- @param options table Export options
-- @return table Export bundle with files for EPUB
function M:export(story, options)
  options = options or {}

  local uuid = self:generate_uuid()
  local files = {}

  -- mimetype (must be first, uncompressed)
  files["mimetype"] = "application/epub+zip"

  -- META-INF/container.xml
  files["META-INF/container.xml"] = self:generate_container()

  -- OEBPS/content.opf
  files["OEBPS/content.opf"] = self:generate_opf(story, uuid)

  -- OEBPS/nav.xhtml
  files["OEBPS/nav.xhtml"] = self:generate_nav(story)

  -- OEBPS/[passage].xhtml
  for _, passage in ipairs(story.passages) do
    local filename = "OEBPS/" .. self:make_filename(passage.name)
    files[filename] = self:generate_passage_xhtml(passage, story)
  end

  return {
    content = nil,  -- EPUB is multi-file
    files = files,
    assets = {},
    manifest = {
      format = "epub",
      story_name = story.name or "Untitled",
      passage_count = #story.passages,
      uuid = uuid,
      exported_at = os.time(),
    }
  }
end

--- Validate export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function M:validate(bundle)
  local errors = {}
  local warnings = {}

  if not bundle.files then
    table.insert(errors, {message = "No files in bundle", severity = "error"})
    return {valid = false, errors = errors, warnings = warnings}
  end

  -- Check required files
  local required = {"mimetype", "META-INF/container.xml", "OEBPS/content.opf", "OEBPS/nav.xhtml"}
  for _, file in ipairs(required) do
    if not bundle.files[file] then
      table.insert(errors, {message = "Missing required file: " .. file, severity = "error"})
    end
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

return M
