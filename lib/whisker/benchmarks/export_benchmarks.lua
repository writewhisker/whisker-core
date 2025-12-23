--- Export Benchmarks
-- Benchmarks for story export operations
-- @module whisker.benchmarks.export_benchmarks
-- @author Whisker Core Team
-- @license MIT

local BenchmarkSuite = require("whisker.benchmarks.suite")

local suite = BenchmarkSuite.new("Export Operations")

-- Test stories
local small_story, medium_story

local function setup_stories()
  -- Small story (10 passages)
  small_story = {
    title = "Small Test Story",
    author = "Test Author",
    passages = {},
  }
  for i = 1, 10 do
    table.insert(small_story.passages, {
      name = "passage_" .. i,
      text = "This is test passage " .. i .. " with some sample content.",
      choices = {
        { text = "Continue", target = "passage_" .. ((i % 10) + 1) },
      },
    })
  end

  -- Medium story (50 passages)
  medium_story = {
    title = "Medium Test Story",
    author = "Test Author",
    ifid = "12345678-1234-1234-1234-123456789012",
    passages = {},
  }
  for i = 1, 50 do
    table.insert(medium_story.passages, {
      name = "passage_" .. i,
      text = string.rep("Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", 3),
      tags = { "chapter" .. math.floor((i-1)/10 + 1) },
      choices = {
        { text = "Choice A", target = "passage_" .. ((i % 50) + 1) },
        { text = "Choice B", target = "passage_" .. (((i + 10) % 50) + 1) },
      },
    })
  end
end

setup_stories()

-- Benchmark: JSON escape
local ExportUtils = require("whisker.export.utils")

suite:register("escape_html", function()
  return ExportUtils.escape_html('<div class="test">Hello "World" & Friends</div>')
end, {
  iterations = 10000,
  description = "Escape HTML special characters",
})

suite:register("escape_json", function()
  return ExportUtils.escape_json('Hello "World"\nNew line\tTab')
end, {
  iterations = 10000,
  description = "Escape JSON special characters",
})

-- Benchmark: Manifest creation
suite:register("create_manifest", function()
  return ExportUtils.create_manifest("html", medium_story, { minify = true })
end, {
  iterations = 5000,
  description = "Create export manifest",
})

-- Benchmark: Text export (small)
local TextExporter = require("whisker.export.text.text_exporter")
local text_exporter = TextExporter.new()

suite:register("text_export_small", function()
  return text_exporter:export(small_story, {})
end, {
  iterations = 500,
  description = "Export 10-passage story to text",
})

-- Benchmark: Text export (medium)
suite:register("text_export_medium", function()
  return text_exporter:export(medium_story, {})
end, {
  iterations = 100,
  description = "Export 50-passage story to text",
})

-- Benchmark: HTML export (small)
local HTMLExporter = require("whisker.export.html.html_exporter")
local html_exporter = HTMLExporter.new()

suite:register("html_export_small", function()
  return html_exporter:export(small_story, {})
end, {
  iterations = 200,
  description = "Export 10-passage story to HTML",
})

-- Benchmark: HTML export (medium)
suite:register("html_export_medium", function()
  return html_exporter:export(medium_story, {})
end, {
  iterations = 50,
  description = "Export 50-passage story to HTML",
})

-- Benchmark: HTML export with minification
suite:register("html_export_minified", function()
  return html_exporter:export(small_story, { minify = true })
end, {
  iterations = 200,
  description = "Export and minify 10-passage story to HTML",
})

-- Benchmark: HTML validation
suite:register("html_validate", function()
  local bundle = {
    content = [[<!DOCTYPE html><html lang="en"><head><title>Test</title></head>
    <body><script>var WHISKER_STORY_DATA = {};</script></body></html>]],
  }
  return html_exporter:validate(bundle)
end, {
  iterations = 1000,
  description = "Validate HTML export bundle",
})

-- Benchmark: Ink export (small)
local InkExporter = require("whisker.export.ink.ink_exporter")
local ink_exporter = InkExporter.new()

suite:register("ink_export_small", function()
  return ink_exporter:export(small_story, {})
end, {
  iterations = 200,
  description = "Export 10-passage story to Ink JSON",
})

-- Benchmark: Ink export (medium)
suite:register("ink_export_medium", function()
  return ink_exporter:export(medium_story, {})
end, {
  iterations = 50,
  description = "Export 50-passage story to Ink JSON",
})

-- Benchmark: JSON serialization (custom)
suite:register("json_serialize_small", function()
  return html_exporter:to_json({
    title = "Test",
    count = 42,
    enabled = true,
    items = { "a", "b", "c" },
  })
end, {
  iterations = 5000,
  description = "Serialize small table to JSON",
})

-- Benchmark: Base64 encode
suite:register("base64_encode", function()
  local data = string.rep("Test data for base64 encoding. ", 10)
  return ExportUtils.base64_encode(data)
end, {
  iterations = 1000,
  description = "Base64 encode ~300 bytes",
})

-- Benchmark: Template rendering
local TemplateEngine = require("whisker.export.template_engine")
local engine = TemplateEngine.new()
engine:register("test", [[
<html>
<head><title>{{title}}</title></head>
<body>
{{#if author}}<p>By: {{author}}</p>{{/if}}
<div>{{content}}</div>
</body>
</html>
]])

suite:register("template_render", function()
  return engine:render("test", {
    title = "Test Story",
    author = "Test Author",
    content = "Hello, World!",
  })
end, {
  iterations = 2000,
  description = "Render simple HTML template",
})

return suite
