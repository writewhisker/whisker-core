-- Markdown Exporter
-- Export stories to Markdown format for documentation and reading

local M = {}
M._dependencies = {}

--- Create a new Markdown exporter
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
    format = "markdown",
    version = "1.0.0",
    description = "Markdown export for documentation and reading",
    file_extension = ".md",
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

--- Export story to Markdown
-- @param story table Story data
-- @param options table Export options:
--   - include_toc: boolean (include table of contents, default true)
--   - include_metadata: boolean (include metadata header, default true)
--   - passage_links: boolean (convert passage links to anchors, default true)
--   - heading_level: number (starting heading level, default 2)
--   - strip_macros: boolean (remove format-specific macros, default true)
-- @return table Export bundle with content, assets, manifest
function M:export(story, options)
  options = options or {}
  local include_toc = options.include_toc ~= false
  local include_metadata = options.include_metadata ~= false
  local passage_links = options.passage_links ~= false
  local heading_level = options.heading_level or 2
  local strip_macros = options.strip_macros ~= false

  local result = {}

  -- Add title
  if story.name then
    table.insert(result, "# " .. story.name)
    table.insert(result, "")
  end

  -- Add metadata
  if include_metadata then
    table.insert(result, "---")
    if story.name then
      table.insert(result, "title: " .. story.name)
    end
    if story.format then
      table.insert(result, "format: " .. story.format)
    end
    if story.author then
      table.insert(result, "author: " .. story.author)
    end
    table.insert(result, "passages: " .. #story.passages)
    table.insert(result, "exported: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(result, "---")
    table.insert(result, "")
  end

  -- Add table of contents
  if include_toc then
    table.insert(result, "## Table of Contents")
    table.insert(result, "")
    for i, passage in ipairs(story.passages) do
      local anchor = self:make_anchor(passage.name)
      table.insert(result, i .. ". [" .. passage.name .. "](#" .. anchor .. ")")
    end
    table.insert(result, "")
    table.insert(result, "---")
    table.insert(result, "")
  end

  -- Add passages
  for _, passage in ipairs(story.passages) do
    local heading_prefix = string.rep("#", heading_level)
    local anchor = self:make_anchor(passage.name)

    -- Passage header with anchor
    table.insert(result, heading_prefix .. " " .. passage.name .. " {#" .. anchor .. "}")

    -- Tags if any
    if passage.tags and #passage.tags > 0 then
      table.insert(result, "*Tags: " .. table.concat(passage.tags, ", ") .. "*")
    end

    table.insert(result, "")

    -- Passage content
    local content = passage.content
    if strip_macros then
      content = self:strip_macros(content, story.format)
    end
    if passage_links then
      content = self:convert_links(content, story.format)
    end

    table.insert(result, content)
    table.insert(result, "")
    table.insert(result, "---")
    table.insert(result, "")
  end

  local md_content = table.concat(result, "\n")

  return {
    content = md_content,
    assets = {},
    manifest = {
      format = "markdown",
      story_name = story.name or "Untitled",
      passage_count = #story.passages,
      exported_at = os.time(),
    }
  }
end

--- Make anchor from passage name
-- @param name string Passage name
-- @return string Anchor-safe name
function M:make_anchor(name)
  return name:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
end

--- Strip format-specific macros from content
-- @param content string Passage content
-- @param format string Source format
-- @return string Cleaned content
function M:strip_macros(content, format)
  local text = content

  if format == "harlowe" then
    -- Remove Harlowe macros: (set: ...), (if: ...)[...], (print: ...)
    text = text:gsub("%(%s*set:%s*[^%)]+%)", "")
    text = text:gsub("%(%s*if:%s*[^%)]+%)%[([^%]]+)%]", "%1")
    text = text:gsub("%(%s*print:%s*%$([%w_]+)%s*%)", "[%1]")
    -- Convert $var to [var]
    text = text:gsub("%$([%w_]+)", "[%1]")
  elseif format == "sugarcube" then
    -- Remove SugarCube macros
    text = text:gsub("<<%s*set%s+[^>]+>>", "")
    text = text:gsub("<<%s*if%s+[^>]+>>(.-)<</%s*if%s*>>", "%1")
    text = text:gsub("<<%s*print%s+%$([%w_]+)%s*>>", "[%1]")
    text = text:gsub("%$([%w_]+)", "[%1]")
  elseif format == "chapbook" then
    -- Remove Chapbook vars section
    text = text:gsub("^[%w_]+:%s*[^\n]+\n%-%-\n?", "")
    -- Convert {var} to [var]
    text = text:gsub("{([%w_]+)}", "[%1]")
  elseif format == "snowman" then
    -- Remove Snowman code blocks
    text = text:gsub("<%%%s*[^%%]+%s*%%>", "")
    text = text:gsub("<%%=%s*s%.([%w_]+)%s*%%>", "[%1]")
  end

  -- Clean up extra whitespace
  text = text:gsub("\n\n\n+", "\n\n")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  return text
end

--- Convert passage links to Markdown links
-- @param content string Passage content
-- @param format string Source format
-- @return string Content with Markdown links
function M:convert_links(content, format)
  local text = content

  if format == "harlowe" then
    -- [[Text->Target]] to [Text](#target)
    text = text:gsub("%[%[([^%]>]+)%->([^%]]+)%]%]", function(link_text, target)
      local anchor = self:make_anchor(target)
      return "[" .. link_text .. "](#" .. anchor .. ")"
    end)
    -- [[Target]] to [Target](#target)
    text = text:gsub("%[%[([^%]|>]+)%]%]", function(target)
      local anchor = self:make_anchor(target)
      return "[" .. target .. "](#" .. anchor .. ")"
    end)
  elseif format == "sugarcube" then
    -- [[Text|Target]] to [Text](#target)
    text = text:gsub("%[%[([^%]|]+)%|([^%]]+)%]%]", function(link_text, target)
      local anchor = self:make_anchor(target)
      return "[" .. link_text .. "](#" .. anchor .. ")"
    end)
    -- [[Target]] to [Target](#target)
    text = text:gsub("%[%[([^%]|]+)%]%]", function(target)
      local anchor = self:make_anchor(target)
      return "[" .. target .. "](#" .. anchor .. ")"
    end)
  elseif format == "chapbook" then
    -- Same as Harlowe
    text = text:gsub("%[%[([^%]>]+)%->([^%]]+)%]%]", function(link_text, target)
      local anchor = self:make_anchor(target)
      return "[" .. link_text .. "](#" .. anchor .. ")"
    end)
    text = text:gsub("%[%[([^%]|>]+)%]%]", function(target)
      local anchor = self:make_anchor(target)
      return "[" .. target .. "](#" .. anchor .. ")"
    end)
  elseif format == "snowman" then
    -- [Text](Target) is already Markdown-like
    text = text:gsub("%[([^%]]+)%]%(([^%)]+)%)", function(link_text, target)
      local anchor = self:make_anchor(target)
      return "[" .. link_text .. "](#" .. anchor .. ")"
    end)
  end

  return text
end

--- Validate export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function M:validate(bundle)
  local errors = {}
  local warnings = {}

  if not bundle.content or #bundle.content == 0 then
    table.insert(errors, {message = "No content in bundle", severity = "error"})
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

return M
