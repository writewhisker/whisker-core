-- whisker-lsp/lib/document_manager.lua
-- Manages open documents and their state

local DocumentManager = {}
DocumentManager.__index = DocumentManager

--- Create a new document manager
--- @return table DocumentManager instance
function DocumentManager.new()
  local self = setmetatable({}, DocumentManager)
  self.documents = {}  -- uri -> {text, version, language_id}
  return self
end

--- Open a document
--- @param uri string Document URI
--- @param text string Document content
--- @param version number Document version
--- @param language_id string? Language identifier
--- @return boolean Success
function DocumentManager:open(uri, text, version, language_id)
  self.documents[uri] = {
    text = text,
    version = version,
    language_id = language_id or self:detect_language(uri),
    lines = nil  -- Lazily computed
  }
  return true
end

--- Close a document
--- @param uri string Document URI
--- @return boolean Success
function DocumentManager:close(uri)
  if self.documents[uri] then
    self.documents[uri] = nil
    return true
  end
  return false
end

--- Get document text
--- @param uri string Document URI
--- @return string|nil Document content or nil if not open
function DocumentManager:get_text(uri)
  local doc = self.documents[uri]
  return doc and doc.text
end

--- Get document version
--- @param uri string Document URI
--- @return number|nil Document version or nil if not open
function DocumentManager:get_version(uri)
  local doc = self.documents[uri]
  return doc and doc.version
end

--- Get document language ID
--- @param uri string Document URI
--- @return string|nil Language ID or nil if not open
function DocumentManager:get_language_id(uri)
  local doc = self.documents[uri]
  return doc and doc.language_id
end

--- Apply incremental changes to a document
--- @param uri string Document URI
--- @param changes table Array of change events
--- @param version number New document version
--- @return boolean Success
function DocumentManager:apply_changes(uri, changes, version)
  local doc = self.documents[uri]
  if not doc then
    return false
  end

  for _, change in ipairs(changes) do
    if change.range then
      -- Incremental change
      doc.text = self:apply_incremental_change(doc.text, change.range, change.text)
    else
      -- Full document sync
      doc.text = change.text
    end
  end

  doc.version = version
  doc.lines = nil  -- Invalidate line cache

  return true
end

--- Apply a single incremental change
--- @param text string Original text
--- @param range table Range to replace {start: {line, character}, end: {line, character}}
--- @param replacement string Replacement text
--- @return string Modified text
function DocumentManager:apply_incremental_change(text, range, replacement)
  local lines = self:split_lines(text)

  -- Convert range to character offsets
  local start_offset = self:position_to_offset(lines, range.start.line, range.start.character)
  local end_offset = self:position_to_offset(lines, range["end"].line, range["end"].character)

  -- Apply replacement
  local before = text:sub(1, start_offset)
  local after = text:sub(end_offset + 1)

  return before .. replacement .. after
end

--- Convert line/character position to character offset
--- @param lines table Array of lines
--- @param line number 0-based line number
--- @param character number 0-based character offset
--- @return number 0-based character offset in full text
function DocumentManager:position_to_offset(lines, line, character)
  local offset = 0

  -- Add full lines before target line
  for i = 1, line do
    if lines[i] then
      offset = offset + #lines[i] + 1  -- +1 for newline
    end
  end

  -- Add character offset within line
  offset = offset + character

  return offset
end

--- Split text into lines
--- @param text string Text to split
--- @return table Array of lines
function DocumentManager:split_lines(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

--- Get line at position
--- @param uri string Document URI
--- @param line number 0-based line number
--- @return string|nil Line content
function DocumentManager:get_line(uri, line)
  local doc = self.documents[uri]
  if not doc then
    return nil
  end

  -- Lazy line splitting
  if not doc.lines then
    doc.lines = self:split_lines(doc.text)
  end

  return doc.lines[line + 1]  -- Convert to 1-based
end

--- Get all open document URIs
--- @return table Array of URIs
function DocumentManager:get_all_uris()
  local uris = {}
  for uri, _ in pairs(self.documents) do
    uris[#uris + 1] = uri
  end
  return uris
end

--- Check if document is open
--- @param uri string Document URI
--- @return boolean
function DocumentManager:is_open(uri)
  return self.documents[uri] ~= nil
end

--- Detect language from URI
--- @param uri string Document URI
--- @return string Language ID
function DocumentManager:detect_language(uri)
  local ext = uri:match("%.([^%.]+)$")
  if ext then
    ext = ext:lower()
    if ext == "ink" then
      return "ink"
    elseif ext == "wscript" then
      return "wscript"
    elseif ext == "twee" then
      return "twee"
    end
  end
  return "whisker"
end

--- Get word at position
--- @param uri string Document URI
--- @param line number 0-based line number
--- @param character number 0-based character offset
--- @return string|nil Word at position
--- @return number|nil Start character
--- @return number|nil End character
function DocumentManager:get_word_at_position(uri, line, character)
  local line_text = self:get_line(uri, line)
  if not line_text then
    return nil
  end

  -- Find word boundaries
  local start_char = character
  local end_char = character

  -- Scan backwards
  while start_char > 0 do
    local c = line_text:sub(start_char, start_char)
    if not c:match("[%w_]") then
      break
    end
    start_char = start_char - 1
  end
  start_char = start_char + 1

  -- Scan forwards
  while end_char <= #line_text do
    local c = line_text:sub(end_char + 1, end_char + 1)
    if not c:match("[%w_]") then
      break
    end
    end_char = end_char + 1
  end

  if start_char <= end_char then
    return line_text:sub(start_char, end_char), start_char - 1, end_char
  end

  return nil
end

return DocumentManager
