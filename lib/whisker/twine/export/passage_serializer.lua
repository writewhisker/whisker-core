--- Passage serializer
-- Converts whisker passages to Twine tw-passagedata format
--
-- lib/whisker/twine/export/passage_serializer.lua

local PassageSerializer = {}

--------------------------------------------------------------------------------
-- Serialization
--------------------------------------------------------------------------------

--- Serialize passage to Twine format
---@param passage table Whisker passage object
---@param format string Target format
---@param pid number Passage ID
---@return table Serialized passage data
function PassageSerializer.serialize(passage, format, pid)
  -- Calculate position (simple grid layout)
  local position = PassageSerializer._calculate_position(pid)

  -- Serialize content based on format
  local content = PassageSerializer._serialize_content(passage, format)

  -- Extract tags
  local tags = passage.tags or {}

  return {
    pid = pid,
    name = passage.name or ("Passage " .. pid),
    tags = tags,
    position = position,
    size = { width = 100, height = 100 },
    content = content
  }
end

--------------------------------------------------------------------------------
-- Position Calculation
--------------------------------------------------------------------------------

--- Calculate passage position for Twine editor
-- Simple grid layout: 200px horizontal spacing, 150px vertical
---@param pid number Passage ID
---@return table Position with x, y
function PassageSerializer._calculate_position(pid)
  local cols = 5
  local spacing_x = 200
  local spacing_y = 150

  local col = (pid - 1) % cols
  local row = math.floor((pid - 1) / cols)

  return {
    x = 100 + (col * spacing_x),
    y = 100 + (row * spacing_y)
  }
end

--------------------------------------------------------------------------------
-- Content Serialization
--------------------------------------------------------------------------------

--- Serialize passage content based on format
---@param passage table Passage data
---@param format string Target format
---@return string Serialized content
function PassageSerializer._serialize_content(passage, format)
  -- If passage already has text content, use it
  if passage.text then
    return passage.text
  end

  -- If passage has content field, use it
  if passage.content then
    return passage.content
  end

  -- If passage has AST, serialize it
  if passage.ast then
    local serializer = PassageSerializer._get_format_serializer(format)
    if serializer then
      return serializer.serialize(passage.ast)
    else
      return PassageSerializer._default_serializer(passage.ast)
    end
  end

  -- Fallback: empty passage
  return ""
end

--- Get format-specific serializer
---@param format string Format name
---@return table|nil Serializer module
function PassageSerializer._get_format_serializer(format)
  local format_lower = format:lower()

  -- Try to load format-specific serializer
  local success, serializer = pcall(function()
    return require('whisker.twine.export.serializers.' .. format_lower .. '_serializer')
  end)

  if success then
    return serializer
  end

  return nil
end

--- Default serializer (plain text)
---@param ast table AST nodes
---@return string Plain text
function PassageSerializer._default_serializer(ast)
  local parts = {}

  for _, node in ipairs(ast) do
    if node.type == "text" then
      table.insert(parts, node.content or node.value or "")
    elseif node.type == "choice" then
      -- Simple link format
      if node.text == node.destination then
        table.insert(parts, "[[" .. node.text .. "]]")
      else
        table.insert(parts, "[[" .. node.text .. "->" .. node.destination .. "]]")
      end
    end
  end

  return table.concat(parts, "\n")
end

return PassageSerializer
