--- PDF Exporter
-- Export stories as PDF documents with multiple formats
-- @module whisker.export.pdf.pdf_exporter
-- @author Whisker Core Team
-- @license MIT
--
-- Exports stories as PDF documents with three modes:
-- - Playable: Interactive playthrough format (default)
-- - Manuscript: Printable text format for reading/editing
-- - Outline: Story structure and statistics

local PDFGenerator = require("whisker.export.pdf.pdf_generator")
local ExportUtils = require("whisker.export.utils")

local PDFExporter = {}
PDFExporter.__index = PDFExporter
PDFExporter._dependencies = {}

--- Create a new PDF exporter instance
-- @param deps table Optional dependencies
-- @return PDFExporter A new exporter
function PDFExporter.new(deps)
  deps = deps or {}
  local self = setmetatable({}, PDFExporter)
  return self
end

--- Get exporter metadata
-- @return table Metadata
function PDFExporter:metadata()
  return {
    format = "pdf",
    version = "1.0.0",
    description = "PDF export with playable, manuscript, and outline modes",
    file_extension = ".pdf",
    mime_type = "application/pdf",
  }
end

--- Check if story can be exported
-- @param story table Story data
-- @param options table Export options
-- @return boolean, string Whether export is possible and any error
function PDFExporter:can_export(story, options)
  if not story then
    return false, "No story provided"
  end
  if not story.passages or #story.passages == 0 then
    return false, "Story has no passages"
  end
  return true
end

--- Export story to PDF
-- @param story table Story data
-- @param options table Export options:
--   - mode: string ("playable", "manuscript", "outline") default "playable"
--   - format: string ("a4", "letter", "legal") default "a4"
--   - orientation: string ("portrait", "landscape") default "portrait"
--   - include_toc: boolean (include table of contents) default true
--   - include_graph: boolean (include graph visualization) default false
--   - font_size: number (font size in points) default 11
--   - line_height: number (line height multiplier) default 1.5
--   - margin: number (margin in points) default 56 (~20mm)
-- @return table Export bundle with content, assets, manifest
function PDFExporter:export(story, options)
  options = options or {}
  local mode = options.mode or "playable"
  local format = options.format or "a4"
  local orientation = options.orientation or "portrait"
  local include_toc = options.include_toc ~= false
  local font_size = options.font_size or 11
  local line_height = options.line_height or 1.5
  local margin = options.margin or 56 -- ~20mm in points

  local warnings = {}

  -- Create PDF document
  local pdf = PDFGenerator.new({
    format = format,
    orientation = orientation,
  })

  pdf:set_font_size(font_size)
  pdf:set_line_height(line_height)

  -- Add cover page
  pdf:add_page()
  self:_add_cover_page(pdf, story, margin)

  -- Add table of contents if requested
  if include_toc and mode ~= "outline" then
    pdf:add_page()
    self:_add_table_of_contents(pdf, story, margin, font_size)
  end

  -- Add content based on mode
  pdf:add_page()
  if mode == "manuscript" then
    self:_add_manuscript_content(pdf, story, margin, font_size, line_height)
  elseif mode == "outline" then
    self:_add_outline_content(pdf, story, margin, font_size)
  else
    self:_add_playable_content(pdf, story, margin, font_size, line_height)
  end

  -- Note about graph visualization
  if options.include_graph and mode == "outline" then
    table.insert(warnings, "Graph visualization in PDF requires external rendering (not yet implemented)")
  end

  -- Generate PDF output
  local pdf_content = pdf:output()

  -- Generate filename
  local timestamp = os.date("%Y-%m-%d")
  local story_name = (story.name or story.title or "untitled"):lower():gsub("[^%w]", "_")
  local filename = string.format("%s_%s_%s.pdf", story_name, mode, timestamp)

  return {
    content = pdf_content,
    assets = {},
    manifest = {
      format = "pdf",
      mode = mode,
      story_name = story.name or story.title or "Untitled",
      passage_count = #story.passages,
      exported_at = os.time(),
      page_format = format,
      orientation = orientation,
      filename = filename,
    },
    warnings = #warnings > 0 and warnings or nil,
  }
end

--- Add cover page with story metadata
-- @param pdf PDFGenerator PDF document
-- @param story table Story data
-- @param margin number Page margin
function PDFExporter:_add_cover_page(pdf, story, margin)
  local page_width, page_height = pdf:get_page_size()
  local center_x = page_width / 2

  -- Title
  pdf:set_font("helvetica-bold", 24)
  local title = story.name or story.title or "Untitled"
  local title_y = page_height / 3
  pdf:text(title, center_x - (#title * 7), title_y)

  -- Author
  local author = story.author
  if author then
    pdf:set_font("helvetica", 16)
    local author_text = "by " .. author
    pdf:text(author_text, center_x - (#author_text * 4), title_y - 25)
  end

  -- Description
  local description = story.description
  if description then
    pdf:set_font("helvetica-italic", 12)
    local desc_width = page_width - (margin * 2)
    local desc_lines = pdf:split_text_to_size(description, desc_width)
    local desc_y = title_y - 55
    for _, line in ipairs(desc_lines) do
      pdf:text(line, margin, desc_y)
      desc_y = desc_y - 18
    end
  end

  -- Footer with metadata
  pdf:set_font("helvetica", 10)
  local footer_y = margin + 20

  local passage_count = story.passages and #story.passages or 0
  local created = story.created or os.time()
  local created_str = type(created) == "number" and os.date("%Y-%m-%d", created) or tostring(created)
  local exported_str = os.date("%Y-%m-%d")

  local footer_text = string.format(
    "Passages: %d | Created: %s | Exported: %s",
    passage_count, created_str, exported_str
  )
  pdf:text(footer_text, center_x - (#footer_text * 2.5), footer_y)
end

--- Add table of contents
-- @param pdf PDFGenerator PDF document
-- @param story table Story data
-- @param margin number Page margin
-- @param font_size number Base font size
function PDFExporter:_add_table_of_contents(pdf, story, margin, font_size)
  local page_width, page_height = pdf:get_page_size()
  local y_pos = page_height - margin

  -- Title
  pdf:set_font("helvetica-bold", font_size + 4)
  pdf:text("Table of Contents", margin, y_pos)
  y_pos = y_pos - 25

  -- Reset font
  pdf:set_font("helvetica", font_size)

  -- Sort passages by name
  local passages = {}
  for _, p in ipairs(story.passages) do
    table.insert(passages, p)
  end
  table.sort(passages, function(a, b)
    return (a.name or "") < (b.name or "")
  end)

  -- Find start passage
  local start_name = story.start_passage or story.start or "Start"

  -- Add each passage to TOC
  for _, passage in ipairs(passages) do
    -- Check if we need a new page
    if y_pos < margin + 20 then
      pdf:add_page()
      y_pos = page_height - margin
    end

    local name = passage.name or passage.id or "Unnamed"
    local is_start = name == start_name or passage.name == start_name

    local display_name = is_start and (name .. " (Start)") or name
    pdf:text(display_name, margin, y_pos)
    y_pos = y_pos - (font_size * 1.5)
  end
end

--- Add playable content (interactive playthrough format)
-- @param pdf PDFGenerator PDF document
-- @param story table Story data
-- @param margin number Page margin
-- @param font_size number Base font size
-- @param line_height number Line height multiplier
function PDFExporter:_add_playable_content(pdf, story, margin, font_size, line_height)
  local page_width, page_height = pdf:get_page_size()
  local max_width = page_width - (margin * 2)
  local y_pos = page_height - margin

  -- Find start passage
  local start_name = story.start_passage or story.start or "Start"
  local start_passage = nil
  local passage_map = {}

  for _, passage in ipairs(story.passages) do
    local name = passage.name or passage.id
    passage_map[name] = passage
    if name == start_name then
      start_passage = passage
    end
  end

  if not start_passage then
    pdf:text("No start passage defined", margin, y_pos)
    return
  end

  -- Build playthrough order (breadth-first traversal)
  local visited = {}
  local queue = { start_passage }
  local playthrough_order = {}

  while #queue > 0 do
    local passage = table.remove(queue, 1)
    local name = passage.name or passage.id

    if not visited[name] then
      visited[name] = true
      table.insert(playthrough_order, passage)

      -- Add linked passages to queue
      local choices = passage.choices or passage.links or {}
      for _, choice in ipairs(choices) do
        local target_name = choice.target or choice.passage or choice.link
        if target_name and passage_map[target_name] and not visited[target_name] then
          table.insert(queue, passage_map[target_name])
        end
      end
    end
  end

  -- Add each passage in playthrough order
  for i, passage in ipairs(playthrough_order) do
    -- Check if we need a new page
    if y_pos < margin + 60 then
      pdf:add_page()
      y_pos = page_height - margin
    end

    -- Passage header
    pdf:set_font("helvetica-bold", font_size + 2)
    local name = passage.name or passage.id or "Unnamed"
    local header = i == 1 and (name .. " (Start)") or name
    pdf:text(header, margin, y_pos)
    y_pos = y_pos - (font_size * 1.8)

    -- Passage content
    pdf:set_font("helvetica", font_size)
    local content = passage.text or passage.content or ""

    if content ~= "" then
      local content_lines = pdf:split_text_to_size(content, max_width)
      for _, line in ipairs(content_lines) do
        if y_pos < margin + 20 then
          pdf:add_page()
          y_pos = page_height - margin
        end
        pdf:text(line, margin, y_pos)
        y_pos = y_pos - (font_size * line_height)
      end
    end

    y_pos = y_pos - font_size

    -- Choices
    local choices = passage.choices or passage.links or {}
    if #choices > 0 then
      pdf:set_font("helvetica-italic", font_size)
      pdf:text("Choices:", margin, y_pos)
      y_pos = y_pos - (font_size * 1.5)

      for _, choice in ipairs(choices) do
        if y_pos < margin + 20 then
          pdf:add_page()
          y_pos = page_height - margin
        end

        local choice_text = choice.text or choice.label or ""
        local target = choice.target or choice.passage or choice.link or "[No target]"
        local choice_line = string.format("* %s -> %s", choice_text, target)

        local choice_lines = pdf:split_text_to_size(choice_line, max_width - 10)
        for _, line in ipairs(choice_lines) do
          pdf:text(line, margin + 10, y_pos)
          y_pos = y_pos - (font_size * line_height)
        end
      end
    end

    y_pos = y_pos - (font_size * 2)
  end
end

--- Add manuscript content (printable text format)
-- @param pdf PDFGenerator PDF document
-- @param story table Story data
-- @param margin number Page margin
-- @param font_size number Base font size
-- @param line_height number Line height multiplier
function PDFExporter:_add_manuscript_content(pdf, story, margin, font_size, line_height)
  local page_width, page_height = pdf:get_page_size()
  local max_width = page_width - (margin * 2)
  local y_pos = page_height - margin

  -- Find start passage name
  local start_name = story.start_passage or story.start or "Start"

  -- Sort passages by name
  local passages = {}
  for _, p in ipairs(story.passages) do
    table.insert(passages, p)
  end
  table.sort(passages, function(a, b)
    return (a.name or "") < (b.name or "")
  end)

  -- Add each passage
  for _, passage in ipairs(passages) do
    -- Check if we need a new page for the header
    if y_pos < margin + 60 then
      pdf:add_page()
      y_pos = page_height - margin
    end

    -- Passage header
    pdf:set_font("helvetica-bold", font_size + 2)
    local name = passage.name or passage.id or "Unnamed"
    local is_start = name == start_name
    local header = is_start and (name .. " (Start)") or name
    pdf:text(header, margin, y_pos)
    y_pos = y_pos - (font_size * 1.8)

    -- Passage content
    pdf:set_font("helvetica", font_size)
    local content = passage.text or passage.content or ""

    if content ~= "" then
      local content_lines = pdf:split_text_to_size(content, max_width)
      for _, line in ipairs(content_lines) do
        if y_pos < margin + 20 then
          pdf:add_page()
          y_pos = page_height - margin
        end
        pdf:text(line, margin, y_pos)
        y_pos = y_pos - (font_size * line_height)
      end
    end

    y_pos = y_pos - (font_size * 2)
  end
end

--- Add outline content (story structure view)
-- @param pdf PDFGenerator PDF document
-- @param story table Story data
-- @param margin number Page margin
-- @param font_size number Base font size
function PDFExporter:_add_outline_content(pdf, story, margin, font_size)
  local page_width, page_height = pdf:get_page_size()
  local max_width = page_width - (margin * 2)
  local y_pos = page_height - margin

  -- Section: Story Structure
  pdf:set_font("helvetica-bold", font_size + 4)
  pdf:text("Story Structure", margin, y_pos)
  y_pos = y_pos - (font_size * 2.5)

  -- Statistics
  pdf:set_font("helvetica", font_size)

  local total_choices = 0
  for _, passage in ipairs(story.passages) do
    local choices = passage.choices or passage.links or {}
    total_choices = total_choices + #choices
  end

  local start_name = story.start_passage or story.start or "Start"

  local stats = {
    string.format("Total Passages: %d", #story.passages),
    string.format("Total Choices: %d", total_choices),
    string.format("Start Passage: %s", start_name),
  }

  for _, stat in ipairs(stats) do
    pdf:text(stat, margin, y_pos)
    y_pos = y_pos - (font_size * 1.5)
  end

  y_pos = y_pos - (font_size * 2)

  -- Section: Passage Details
  if y_pos < margin + 60 then
    pdf:add_page()
    y_pos = page_height - margin
  end

  pdf:set_font("helvetica-bold", font_size + 4)
  pdf:text("Passage Details", margin, y_pos)
  y_pos = y_pos - (font_size * 2.5)

  -- Sort passages by name
  local passages = {}
  for _, p in ipairs(story.passages) do
    table.insert(passages, p)
  end
  table.sort(passages, function(a, b)
    return (a.name or "") < (b.name or "")
  end)

  -- Add each passage outline
  pdf:set_font("helvetica", font_size)
  for _, passage in ipairs(passages) do
    if y_pos < margin + 60 then
      pdf:add_page()
      y_pos = page_height - margin
    end

    -- Passage name
    pdf:set_font("helvetica-bold", font_size)
    local name = passage.name or passage.id or "Unnamed"
    local is_start = name == start_name
    local header = is_start and (name .. " (Start)") or name
    pdf:text(header, margin, y_pos)
    y_pos = y_pos - (font_size * 1.5)

    -- Word count
    pdf:set_font("helvetica", font_size)
    local content = passage.text or passage.content or ""
    local word_count = 0
    for _ in content:gmatch("%S+") do
      word_count = word_count + 1
    end
    pdf:text(string.format("  Words: %d", word_count), margin, y_pos)
    y_pos = y_pos - (font_size * 1.3)

    -- Choices count
    local choices = passage.choices or passage.links or {}
    pdf:text(string.format("  Choices: %d", #choices), margin, y_pos)
    y_pos = y_pos - (font_size * 1.3)

    -- List choices
    if #choices > 0 then
      pdf:set_font("helvetica-italic", font_size)
      for _, choice in ipairs(choices) do
        if y_pos < margin + 20 then
          pdf:add_page()
          y_pos = page_height - margin
        end

        local choice_text = choice.text or choice.label or ""
        local target = choice.target or choice.passage or choice.link or "[No target]"
        local choice_line = string.format("    -> %s (to: %s)", choice_text, target)

        local lines = pdf:split_text_to_size(choice_line, max_width - 20)
        for _, line in ipairs(lines) do
          pdf:text(line, margin, y_pos)
          y_pos = y_pos - (font_size * 1.2)
        end
      end
    end

    y_pos = y_pos - (font_size * 1.5)
  end
end

--- Validate export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function PDFExporter:validate(bundle)
  local errors = {}
  local warnings = {}

  if not bundle.content or #bundle.content == 0 then
    table.insert(errors, { message = "PDF content is empty", severity = "error" })
    return { valid = false, errors = errors, warnings = warnings }
  end

  -- Check for PDF header
  if not bundle.content:match("^%%PDF%-1%.4") then
    table.insert(errors, { message = "Invalid PDF header", severity = "error" })
  end

  -- Check for PDF trailer
  if not bundle.content:match("%%%%EOF") then
    table.insert(errors, { message = "Missing PDF EOF marker", severity = "error" })
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

--- Validate export options
-- @param options table Export options
-- @return table Array of error messages
function PDFExporter:validate_options(options)
  local errors = {}

  if options.format and not PDFGenerator.FORMATS[options.format] then
    table.insert(errors, "Invalid PDF format option (use a4, letter, or legal)")
  end

  if options.orientation and options.orientation ~= "portrait" and options.orientation ~= "landscape" then
    table.insert(errors, "Invalid PDF orientation option (use portrait or landscape)")
  end

  if options.mode and options.mode ~= "playable" and options.mode ~= "manuscript" and options.mode ~= "outline" then
    table.insert(errors, "Invalid PDF mode option (use playable, manuscript, or outline)")
  end

  if options.font_size and (options.font_size < 8 or options.font_size > 24) then
    table.insert(errors, "PDF font size must be between 8 and 24 points")
  end

  if options.line_height and (options.line_height < 1 or options.line_height > 3) then
    table.insert(errors, "PDF line height must be between 1 and 3")
  end

  if options.margin and (options.margin < 28 or options.margin > 142) then
    table.insert(errors, "PDF margin must be between 28 and 142 points (10-50mm)")
  end

  return errors
end

--- Estimate export size
-- @param story table Story data
-- @return number Estimated size in bytes
function PDFExporter:estimate_size(story)
  -- Rough estimate: ~2KB per passage + base overhead
  local base_size = 10000 -- 10KB base
  local per_passage_size = 2000 -- 2KB per passage
  local passage_count = story.passages and #story.passages or 0
  return base_size + (passage_count * per_passage_size)
end

return PDFExporter
