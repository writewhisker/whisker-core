--- LSP Document Manager
-- Manages text documents for the LSP server
-- @module whisker.lsp.document
-- @author Whisker Core Team
-- @license MIT

local Document = {}
Document.__index = Document
Document._dependencies = {}

--- Create a new document manager
-- @param options table Options
-- @return Document Document manager instance
function Document.new(options)
  local self = setmetatable({}, Document)
  self._documents = {}
  self._parsed_cache = {}
  return self
end

--- Open a document
-- @param uri string Document URI
-- @param content string Document content
-- @param version number Document version
function Document:open(uri, content, version)
  self._documents[uri] = {
    uri = uri,
    content = content,
    version = version or 1,
    lines = nil, -- Lazy computed
  }
  -- Clear parsed cache
  self._parsed_cache[uri] = nil
end

--- Update a document
-- @param uri string Document URI
-- @param content string New content
-- @param version number New version
function Document:update(uri, content, version)
  local doc = self._documents[uri]
  if doc then
    doc.content = content
    doc.version = version or (doc.version + 1)
    doc.lines = nil -- Clear line cache
    self._parsed_cache[uri] = nil
  else
    self:open(uri, content, version)
  end
end

--- Close a document
-- @param uri string Document URI
function Document:close(uri)
  self._documents[uri] = nil
  self._parsed_cache[uri] = nil
end

--- Get a document
-- @param uri string Document URI
-- @return table|nil Document data
function Document:get(uri)
  return self._documents[uri]
end

--- Get document content
-- @param uri string Document URI
-- @return string|nil Content
function Document:get_content(uri)
  local doc = self._documents[uri]
  return doc and doc.content
end

--- Get document lines (cached)
-- @param uri string Document URI
-- @return table|nil Array of lines
function Document:get_lines(uri)
  local doc = self._documents[uri]
  if not doc then return nil end

  if not doc.lines then
    doc.lines = {}
    for line in (doc.content .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(doc.lines, line)
    end
  end

  return doc.lines
end

--- Get line at position
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @return string|nil Line content
function Document:get_line(uri, line)
  local lines = self:get_lines(uri)
  if lines and lines[line + 1] then
    return lines[line + 1]
  end
  return nil
end

--- Get word at position
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return string|nil Word at position
-- @return number|nil Start character
-- @return number|nil End character
function Document:get_word_at(uri, line, character)
  local line_text = self:get_line(uri, line)
  if not line_text then return nil end

  -- Find word boundaries (allowing $ prefix and _ in identifiers)
  local start_char = character + 1
  local end_char = character + 1

  -- Search backward for word start
  while start_char > 1 do
    local c = line_text:sub(start_char - 1, start_char - 1)
    if c:match("[%w_$]") then
      start_char = start_char - 1
    else
      break
    end
  end

  -- Search forward for word end
  while end_char <= #line_text do
    local c = line_text:sub(end_char, end_char)
    if c:match("[%w_]") then
      end_char = end_char + 1
    else
      break
    end
  end

  if start_char >= end_char then
    return nil
  end

  local word = line_text:sub(start_char, end_char - 1)
  return word, start_char - 1, end_char - 1
end

--- Get text before position on same line
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return string|nil Text before position
function Document:get_text_before(uri, line, character)
  local line_text = self:get_line(uri, line)
  if not line_text then return nil end
  return line_text:sub(1, character)
end

--- Get parsed document (cached)
-- @param uri string Document URI
-- @param parser table Parser instance
-- @return table|nil Parsed AST
function Document:get_parsed(uri, parser)
  local doc = self._documents[uri]
  if not doc then return nil end

  local cached = self._parsed_cache[uri]
  if cached and cached.version == doc.version then
    return cached.ast
  end

  -- Parse document
  if parser then
    local ok, result = pcall(function()
      return parser.parse(doc.content)
    end)
    if ok and result then
      self._parsed_cache[uri] = {
        version = doc.version,
        ast = result,
      }
      return result
    end
  end

  return nil
end

--- Convert position to offset
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return number|nil Offset in content
function Document:position_to_offset(uri, line, character)
  local lines = self:get_lines(uri)
  if not lines then return nil end

  local offset = 0
  for i = 1, line do
    if lines[i] then
      offset = offset + #lines[i] + 1 -- +1 for newline
    end
  end
  offset = offset + character

  return offset
end

--- Convert offset to position
-- @param uri string Document URI
-- @param offset number Offset in content
-- @return number|nil line (0-based)
-- @return number|nil character (0-based)
function Document:offset_to_position(uri, offset)
  local lines = self:get_lines(uri)
  if not lines then return nil, nil end

  local current_offset = 0
  for i, line_text in ipairs(lines) do
    local line_end = current_offset + #line_text + 1
    if offset < line_end then
      return i - 1, offset - current_offset
    end
    current_offset = line_end
  end

  -- Return end of document
  return #lines - 1, lines[#lines] and #lines[#lines] or 0
end

--- Get all document URIs
-- @return table Array of URIs
function Document:get_all_uris()
  local uris = {}
  for uri in pairs(self._documents) do
    table.insert(uris, uri)
  end
  return uris
end

return Document
