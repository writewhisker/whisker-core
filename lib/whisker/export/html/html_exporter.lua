--- HTML Exporter
-- Export stories to standalone HTML files with embedded runtime
-- @module whisker.export.html.html_exporter
-- @author Whisker Core Team
-- @license MIT

local ExportUtils = require("whisker.export.utils")
local Runtime = require("whisker.export.html.runtime")
local CSSVariables = require("whisker.export.html.css_variables")

local HTMLExporter = {}
HTMLExporter._dependencies = {}
HTMLExporter.__index = HTMLExporter

--- Create a new HTML exporter instance
-- @return HTMLExporter A new exporter
function HTMLExporter.new(deps)
  deps = deps or {}
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

--- Get theme CSS for the story
-- @param story table Story data with metadata.themes
-- @return string CSS for themes
function HTMLExporter:get_theme_css(story)
  local themes = {}
  if story.metadata and story.metadata.themes then
    themes = story.metadata.themes
  end
  return CSSVariables.get_theme_css(themes)
end

--- Get theme classes for HTML element
-- @param story table Story data
-- @return string Space-separated CSS classes
function HTMLExporter:get_theme_classes(story)
  local themes = {}
  if story.metadata and story.metadata.themes then
    themes = story.metadata.themes
  end
  return CSSVariables.get_theme_classes(themes)
end

--- Get custom CSS from @style blocks
-- @param story table Story data
-- @return string Custom CSS wrapped in style tag or empty string
function HTMLExporter:get_custom_css(story)
  local styles = {}
  if story.metadata and story.metadata.custom_styles then
    styles = story.metadata.custom_styles
  end

  if #styles == 0 then
    return ""
  end

  return "<style>\n/* Custom Story Styles */\n" .. table.concat(styles, "\n") .. "\n</style>"
end

--- Render an audio element to HTML
-- @param node table Audio AST node
-- @return string HTML audio element
function HTMLExporter:render_audio(node)
  local attrs = {}
  table.insert(attrs, string.format('src="%s"', ExportUtils.escape_html(node.src)))

  if node.autoplay then table.insert(attrs, "autoplay") end
  if node.loop then table.insert(attrs, "loop") end
  if node.muted then table.insert(attrs, "muted") end
  if node.controls then table.insert(attrs, "controls") end

  local volume_script = ""
  if node.volume and node.volume ~= 1.0 then
    -- Volume needs to be set via JavaScript
    local audio_id = "whisker-audio-" .. tostring(node.position or os.time())
    table.insert(attrs, 1, string.format('id="%s"', audio_id))
    volume_script = string.format(
      '<script>document.getElementById("%s").volume = %s;</script>',
      audio_id,
      tostring(node.volume)
    )
  end

  return string.format('<audio class="whisker-audio" %s></audio>%s', table.concat(attrs, " "), volume_script)
end

--- Render a video element to HTML
-- @param node table Video AST node
-- @return string HTML video element
function HTMLExporter:render_video(node)
  local attrs = {}
  table.insert(attrs, string.format('src="%s"', ExportUtils.escape_html(node.src)))

  if node.width then table.insert(attrs, string.format('width="%d"', node.width)) end
  if node.height then table.insert(attrs, string.format('height="%d"', node.height)) end
  if node.autoplay then table.insert(attrs, "autoplay") end
  if node.loop then table.insert(attrs, "loop") end
  if node.muted then table.insert(attrs, "muted") end
  if node.controls then table.insert(attrs, "controls") end
  if node.poster then table.insert(attrs, string.format('poster="%s"', ExportUtils.escape_html(node.poster))) end

  return string.format('<video class="whisker-video" %s></video>', table.concat(attrs, " "))
end

--- Render an embed/iframe element to HTML
-- @param node table Embed AST node
-- @return string HTML iframe element
function HTMLExporter:render_embed(node)
  local attrs = {}
  table.insert(attrs, string.format('src="%s"', ExportUtils.escape_html(node.url)))
  table.insert(attrs, string.format('width="%d"', node.width))
  table.insert(attrs, string.format('height="%d"', node.height))
  table.insert(attrs, string.format('title="%s"', ExportUtils.escape_html(node.title)))
  table.insert(attrs, string.format('loading="%s"', node.loading))

  -- Security: sandbox by default
  if node.sandbox then
    table.insert(attrs, 'sandbox="allow-scripts allow-same-origin"')
  end

  if node.allow and node.allow ~= "" then
    table.insert(attrs, string.format('allow="%s"', ExportUtils.escape_html(node.allow)))
  end

  -- Security: prevent referrer leakage
  table.insert(attrs, 'referrerpolicy="no-referrer"')

  return string.format(
    '<iframe class="whisker-embed" %s frameborder="0" allowfullscreen></iframe>',
    table.concat(attrs, " ")
  )
end

--- Render an image element to HTML with all attributes
-- @param node table Image AST node
-- @return string HTML img element
function HTMLExporter:render_image(node)
  local attrs = {}
  table.insert(attrs, string.format('src="%s"', ExportUtils.escape_html(node.src)))
  table.insert(attrs, string.format('alt="%s"', ExportUtils.escape_html(node.alt or "")))

  if node.title then
    table.insert(attrs, string.format('title="%s"', ExportUtils.escape_html(node.title)))
  end
  if node.width then
    table.insert(attrs, string.format('width="%s"', tostring(node.width)))
  end
  if node.height then
    table.insert(attrs, string.format('height="%s"', tostring(node.height)))
  end
  if node.loading then
    table.insert(attrs, string.format('loading="%s"', node.loading))
  end
  if node.class then
    table.insert(attrs, string.format('class="whisker-media %s"', ExportUtils.escape_html(node.class)))
  else
    table.insert(attrs, 'class="whisker-media"')
  end
  if node.id then
    table.insert(attrs, string.format('id="%s"', ExportUtils.escape_html(node.id)))
  end

  return string.format('<img %s />', table.concat(attrs, " "))
end

--- Render media node to HTML based on type
-- @param node table Media AST node
-- @param platform string Output platform (web, console, plain)
-- @return string Rendered output
function HTMLExporter:render_media_node(node, platform)
  platform = platform or "web"

  if platform ~= "web" then
    -- Non-web platforms: show placeholder
    if node.type == "audio" then
      return string.format("[Audio: %s]", node.src)
    elseif node.type == "video" then
      local dims = ""
      if node.width and node.height then
        dims = string.format(" (%dx%d)", node.width, node.height)
      end
      return string.format("[Video: %s%s]", node.src, dims)
    elseif node.type == "embed" then
      return string.format("[Embed: %s]", node.url)
    elseif node.type == "image" then
      local desc = node.alt or node.src
      if node.width and node.height then
        desc = desc .. string.format(" (%dx%d)", node.width, node.height)
      end
      return string.format("[Image: %s]", desc)
    end
    return ""
  end

  -- Web platform: render HTML
  if node.type == "audio" then
    return self:render_audio(node)
  elseif node.type == "video" then
    return self:render_video(node)
  elseif node.type == "embed" then
    return self:render_embed(node)
  elseif node.type == "image" then
    return self:render_image(node)
  end

  return ""
end

return HTMLExporter
