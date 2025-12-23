--- HTML Exporter
-- Export stories to standalone HTML files with embedded runtime
-- @module whisker.export.html.html_exporter
-- @author Whisker Core Team
-- @license MIT

local ExportUtils = require("whisker.export.utils")
local Runtime = require("whisker.export.html.runtime")

local HTMLExporter = {}
HTMLExporter.__index = HTMLExporter

--- Create a new HTML exporter instance
-- @return HTMLExporter A new exporter
function HTMLExporter.new()
  local self = setmetatable({}, HTMLExporter)
  return self
end

--- Check if this story can be exported to HTML
-- @param story table Story data structure
-- @param options table Export options
-- @return boolean True if export is possible
-- @return string|nil Error message if not possible
function HTMLExporter:can_export(story, options)
  if not story then
    return false, "No story provided"
  end

  if not story.passages or #story.passages == 0 then
    return false, "Story has no passages"
  end

  return true
end

--- Export story to standalone HTML
-- @param story table Story data structure
-- @param options table Export options:
--   - minify: boolean (minify output)
--   - template: string (template name or path)
--   - inline_assets: boolean (default true)
-- @return table Export bundle
function HTMLExporter:export(story, options)
  options = options or {}

  -- Serialize story data to JSON
  local story_json = self:serialize_story(story)

  -- Get embedded runtime JavaScript
  local runtime_js = options.minimal and Runtime.get_minimal_runtime_code() or Runtime.get_runtime_code()

  -- Generate HTML document
  local html = self:generate_html(story, story_json, runtime_js, options)

  -- Optionally minify
  if options.minify then
    html = self:minify_html(html)
  end

  -- Create export bundle
  local bundle = {
    content = html,
    assets = {},
    manifest = ExportUtils.create_manifest("html", story, options),
  }

  return bundle
end

--- Validate HTML export bundle
-- @param bundle table Export bundle
-- @return table Validation result
function HTMLExporter:validate(bundle)
  local errors = {}
  local warnings = {}

  -- Check content exists
  if not bundle.content or #bundle.content == 0 then
    table.insert(errors, {
      message = "HTML content is empty",
      severity = "error",
    })
    return { valid = false, errors = errors, warnings = warnings }
  end

  local html = bundle.content

  -- Check HTML structure
  if not html:match("<!DOCTYPE html>") then
    table.insert(warnings, {
      message = "Missing DOCTYPE declaration",
      severity = "warning",
    })
  end

  if not html:match("<html") then
    table.insert(errors, {
      message = "Missing <html> tag",
      severity = "error",
    })
  end

  if not html:match("<head") then
    table.insert(errors, {
      message = "Missing <head> tag",
      severity = "error",
    })
  end

  if not html:match("<body") then
    table.insert(errors, {
      message = "Missing <body> tag",
      severity = "error",
    })
  end

  if not html:match("<script") then
    table.insert(errors, {
      message = "Missing embedded runtime",
      severity = "error",
    })
  end

  if not html:match("WHISKER_STORY_DATA") then
    table.insert(errors, {
      message = "Missing story data",
      severity = "error",
    })
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

--- Get exporter metadata
-- @return table Metadata
function HTMLExporter:metadata()
  return {
    format = "html",
    version = "1.0.0",
    description = "Standalone HTML export with embedded runtime",
    file_extension = ".html",
  }
end

--- Serialize story to JSON string
-- @param story table Story data
-- @return string JSON string
function HTMLExporter:serialize_story(story)
  return self:to_json({
    title = story.title or "Untitled",
    author = story.author or "Anonymous",
    start = story.start_passage or story.start or "start",
    ifid = story.ifid,
    passages = self:serialize_passages(story.passages or {}),
  })
end

--- Serialize passages array
-- @param passages table Array of passages
-- @return table Serialized passages
function HTMLExporter:serialize_passages(passages)
  local result = {}
  for _, passage in ipairs(passages) do
    table.insert(result, {
      name = passage.name or passage.id,
      text = passage.text or passage.content or "",
      tags = passage.tags,
      choices = self:serialize_choices(passage.choices or passage.links or {}),
    })
  end
  return result
end

--- Serialize choices array
-- @param choices table Array of choices
-- @return table Serialized choices
function HTMLExporter:serialize_choices(choices)
  local result = {}
  for _, choice in ipairs(choices) do
    table.insert(result, {
      text = choice.text or choice.label or "",
      target = choice.target or choice.passage or choice.link or "",
    })
  end
  return result
end

--- Convert Lua table to JSON string
-- @param data table Data to convert
-- @param indent number Current indent level
-- @return string JSON string
function HTMLExporter:to_json(data, indent)
  indent = indent or 0

  if data == nil then
    return "null"
  end

  local t = type(data)

  if t == "boolean" then
    return data and "true" or "false"
  end

  if t == "number" then
    return tostring(data)
  end

  if t == "string" then
    return '"' .. ExportUtils.escape_json(data) .. '"'
  end

  if t == "table" then
    -- Check if array
    if #data > 0 or next(data) == nil then
      -- Array
      local parts = {}
      for i, v in ipairs(data) do
        parts[i] = self:to_json(v, indent + 1)
      end
      if #parts == 0 then
        return "[]"
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Object
      local parts = {}
      local keys = {}
      for k in pairs(data) do
        table.insert(keys, k)
      end
      table.sort(keys)

      for _, k in ipairs(keys) do
        local v = data[k]
        table.insert(parts, '"' .. ExportUtils.escape_json(tostring(k)) .. '":' .. self:to_json(v, indent + 1))
      end
      if #parts == 0 then
        return "{}"
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end

  return "null"
end

--- Generate complete HTML document
-- @param story table Story data
-- @param story_json string Serialized story JSON
-- @param runtime_js string JavaScript runtime code
-- @param options table Export options
-- @return string HTML document
function HTMLExporter:generate_html(story, story_json, runtime_js, options)
  local title = ExportUtils.escape_html(story.title or "Untitled")
  local author = story.author and ExportUtils.escape_html(story.author) or nil

  local html = [[<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="generator" content="whisker-core">
  <title>]] .. title .. [[</title>
  <style>
    * {
      box-sizing: border-box;
    }
    body {
      font-family: Georgia, 'Times New Roman', serif;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      line-height: 1.6;
      color: #333;
      background: #f9f9f9;
    }
    #story-container {
      background: white;
      padding: 2em;
      border-radius: 4px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .story-header {
      border-bottom: 2px solid #007bff;
      margin-bottom: 2em;
      padding-bottom: 1em;
    }
    .story-header h1 {
      margin: 0 0 0.5em;
      color: #007bff;
    }
    .story-header .author {
      margin: 0;
      color: #666;
      font-style: italic;
    }
    #passage {
      margin-bottom: 2em;
      min-height: 100px;
    }
    .passage-content {
      line-height: 1.8;
    }
    .choices {
      list-style: none;
      padding: 0;
      margin: 0;
    }
    .choices li {
      margin: 0.5em 0;
    }
    .choice-link {
      display: inline-block;
      padding: 0.75em 1.5em;
      background: #007bff;
      color: white;
      text-decoration: none;
      border-radius: 4px;
      border: none;
      cursor: pointer;
      font-size: 1em;
      transition: background 0.2s ease;
    }
    .choice-link:hover {
      background: #0056b3;
    }
    .choice-link:focus {
      outline: 3px solid #0056b3;
      outline-offset: 2px;
    }
    .story-footer {
      margin-top: 3em;
      padding-top: 1em;
      border-top: 1px solid #ddd;
      text-align: center;
      color: #666;
      font-size: 0.9em;
    }
    .story-footer a {
      color: #007bff;
    }
    .error {
      color: #dc3545;
      padding: 1em;
      background: #f8d7da;
      border: 1px solid #f5c6cb;
      border-radius: 4px;
    }
  </style>
</head>
<body>
  <div id="story-container">
    <header class="story-header">
      <h1>]] .. title .. [[</h1>
]] .. (author and ('      <p class="author">by ' .. author .. '</p>\n') or '') .. [[    </header>
    <main id="story" role="main" aria-live="polite">
      <div id="passage"></div>
      <ul id="choices" class="choices" role="navigation" aria-label="Story choices"></ul>
    </main>
    <footer class="story-footer">
      <p><small>Created with <a href="https://github.com/writewhisker/whisker-core">whisker-core</a></small></p>
    </footer>
  </div>

  <script>
    // Embedded story data
    var WHISKER_STORY_DATA = ]] .. story_json .. [[;

    // Embedded runtime
    ]] .. runtime_js .. [[
  </script>
</body>
</html>]]

  return html
end

--- Simple HTML minification
-- @param html string HTML content
-- @return string Minified HTML
function HTMLExporter:minify_html(html)
  -- Remove HTML comments (but not IE conditionals)
  html = html:gsub("<!%-%-[^%[].-%-%->\n?", "")

  -- Collapse multiple whitespace to single space
  html = html:gsub("%s+", " ")

  -- Remove whitespace around tags
  html = html:gsub(">%s+<", "><")

  -- Trim
  html = html:gsub("^%s+", ""):gsub("%s+$", "")

  return html
end

return HTMLExporter
