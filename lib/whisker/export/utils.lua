--- Export Utilities
-- Helper functions for export implementations
-- @module whisker.export.utils
-- @author Whisker Core Team
-- @license MIT

local ExportUtils = {}

--- Generate a timestamp in ISO 8601 format
-- @return string Timestamp (e.g., "2024-12-17T10:30:00Z")
function ExportUtils.timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Escape HTML special characters
-- @param text string Raw text
-- @return string HTML-safe text
function ExportUtils.escape_html(text)
  if not text then return "" end
  text = tostring(text)

  return text
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
    :gsub("'", "&#39;")
end

--- Escape JSON special characters
-- @param text string Raw text
-- @return string JSON-safe text
function ExportUtils.escape_json(text)
  if not text then return "" end
  text = tostring(text)

  return text
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
    :gsub("[\x00-\x1f]", function(c)
      return string.format("\\u%04x", string.byte(c))
    end)
end

--- Read file contents
-- @param path string File path
-- @return string|nil File contents or nil on error
function ExportUtils.read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end

  local content = file:read("*all")
  file:close()
  return content
end

--- Write file contents
-- @param path string File path
-- @param content string Content to write
-- @return boolean True on success
function ExportUtils.write_file(path, content)
  local file = io.open(path, "wb")
  if not file then return false end

  file:write(content)
  file:close()
  return true
end

--- Get file extension from format
-- @param format string Format name
-- @return string File extension (e.g., ".html")
function ExportUtils.get_extension(format)
  local extensions = {
    html = ".html",
    ink = ".json",
    text = ".txt",
    json = ".json",
  }
  return extensions[format] or ".export"
end

--- Create a manifest for an export bundle
-- @param format string Export format
-- @param story table Story data
-- @param options table Export options
-- @return table Manifest
function ExportUtils.create_manifest(format, story, options)
  return {
    format = format,
    version = "1.0.0",
    created_at = ExportUtils.timestamp(),
    story_title = story.title or "Untitled",
    passage_count = story.passages and #story.passages or 0,
    options = options or {},
  }
end

--- Get the directory portion of a path
-- @param path string File path
-- @return string Directory path
function ExportUtils.dirname(path)
  return path:match("(.*/)")  or "./"
end

--- Get the filename portion of a path
-- @param path string File path
-- @return string Filename
function ExportUtils.basename(path)
  return path:match("([^/]+)$") or path
end

--- Get the filename without extension
-- @param path string File path
-- @return string Filename without extension
function ExportUtils.stem(path)
  local basename = ExportUtils.basename(path)
  return basename:match("(.+)%.[^.]+$") or basename
end

--- Check if a file exists
-- @param path string File path
-- @return boolean True if file exists
function ExportUtils.file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

--- Encode data as base64
-- @param data string Binary data
-- @return string Base64 encoded string
function ExportUtils.base64_encode(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  return ((data:gsub('.', function(x)
    local r, byte = '', x:byte()
    for i = 8, 1, -1 do
      r = r .. (byte % 2^i - byte % 2^(i-1) > 0 and '1' or '0')
    end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then return '' end
    local c = 0
    for i = 1, 6 do
      c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0)
    end
    return b:sub(c+1, c+1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

--- Get MIME type for a file extension or type
-- @param type_or_ext string File type or extension
-- @return string MIME type
function ExportUtils.get_mime_type(type_or_ext)
  local types = {
    css = "text/css",
    js = "application/javascript",
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    svg = "image/svg+xml",
    woff = "font/woff",
    woff2 = "font/woff2",
    ttf = "font/ttf",
    html = "text/html",
    json = "application/json",
    txt = "text/plain",
  }
  -- Remove leading dot if present
  local clean = type_or_ext:gsub("^%.", "")
  return types[clean] or "application/octet-stream"
end

return ExportUtils
