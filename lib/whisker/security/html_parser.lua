--- HTML Parser
-- Simple HTML parser for content sanitization
-- @module whisker.security.html_parser
-- @author Whisker Core Team
-- @license MIT

local HTMLParser = {}

--- Node types
HTMLParser.NODE_TYPES = {
  ELEMENT = "element",
  TEXT = "text",
  COMMENT = "comment",
  DOCTYPE = "doctype",
}

--- Self-closing tags (void elements)
HTMLParser.VOID_ELEMENTS = {
  area = true,
  base = true,
  br = true,
  col = true,
  embed = true,
  hr = true,
  img = true,
  input = true,
  link = true,
  meta = true,
  param = true,
  source = true,
  track = true,
  wbr = true,
}

--- Create a text node
-- @param text string Text content
-- @return table Text node
function HTMLParser.text_node(text)
  return {
    type = HTMLParser.NODE_TYPES.TEXT,
    content = text,
  }
end

--- Create an element node
-- @param tag string Tag name
-- @param attributes table|nil Attribute map
-- @param children table|nil Child nodes
-- @return table Element node
function HTMLParser.element_node(tag, attributes, children)
  return {
    type = HTMLParser.NODE_TYPES.ELEMENT,
    tag = tag:lower(),
    attributes = attributes or {},
    children = children or {},
  }
end

--- Create a comment node
-- @param text string Comment text
-- @return table Comment node
function HTMLParser.comment_node(text)
  return {
    type = HTMLParser.NODE_TYPES.COMMENT,
    content = text,
  }
end

--- Decode HTML entities
-- @param text string Text with entities
-- @return string Decoded text
function HTMLParser.decode_entities(text)
  -- Common named entities
  local entities = {
    ["&amp;"] = "&",
    ["&lt;"] = "<",
    ["&gt;"] = ">",
    ["&quot;"] = '"',
    ["&#39;"] = "'",
    ["&apos;"] = "'",
    ["&nbsp;"] = " ",
    ["&copy;"] = "\194\169",       -- ©
    ["&reg;"] = "\194\174",        -- ®
    ["&trade;"] = "\226\132\162",  -- ™
    ["&ndash;"] = "\226\128\147",  -- –
    ["&mdash;"] = "\226\128\148",  -- —
    ["&lsquo;"] = "\226\128\152",  -- '
    ["&rsquo;"] = "\226\128\153",  -- '
    ["&ldquo;"] = "\226\128\156",  -- "
    ["&rdquo;"] = "\226\128\157",  -- "
    ["&bull;"] = "\226\128\162",   -- •
    ["&hellip;"] = "\226\128\166", -- …
  }

  -- Replace named entities
  for entity, char in pairs(entities) do
    text = text:gsub(entity, char)
  end

  -- Replace decimal numeric entities
  text = text:gsub("&#(%d+);", function(code)
    local num = tonumber(code)
    if num and num < 256 then
      return string.char(num)
    end
    return ""
  end)

  -- Replace hex numeric entities
  text = text:gsub("&#[xX](%x+);", function(code)
    local num = tonumber(code, 16)
    if num and num < 256 then
      return string.char(num)
    end
    return ""
  end)

  return text
end

--- Encode HTML entities
-- @param text string Plain text
-- @return string Encoded text
function HTMLParser.encode_entities(text)
  text = text:gsub("&", "&amp;")
  text = text:gsub("<", "&lt;")
  text = text:gsub(">", "&gt;")
  text = text:gsub('"', "&quot;")
  text = text:gsub("'", "&#39;")
  return text
end

--- Parse attributes from attribute string
-- @param attr_str string Attribute string (e.g., 'class="foo" id="bar"')
-- @return table Attribute map
function HTMLParser.parse_attributes(attr_str)
  local attributes = {}

  if not attr_str or attr_str == "" then
    return attributes
  end

  -- Match attribute patterns
  -- name="value", name='value', name=value, or just name

  -- Double-quoted values
  for name, value in attr_str:gmatch('([%w_%-:]+)%s*=%s*"([^"]*)"') do
    attributes[name:lower()] = HTMLParser.decode_entities(value)
  end

  -- Single-quoted values
  for name, value in attr_str:gmatch("([%w_%-:]+)%s*=%s*'([^']*)'") do
    attributes[name:lower()] = HTMLParser.decode_entities(value)
  end

  -- Unquoted values
  for name, value in attr_str:gmatch("([%w_%-:]+)%s*=%s*([^%s\"'>]+)") do
    if not attributes[name:lower()] then
      attributes[name:lower()] = HTMLParser.decode_entities(value)
    end
  end

  -- Boolean attributes (just name, no value)
  for name in attr_str:gmatch("([%w_%-:]+)%s*[^=]") do
    if not attributes[name:lower()] then
      attributes[name:lower()] = true
    end
  end

  -- Handle trailing boolean attribute
  local trailing = attr_str:match("([%w_%-:]+)%s*$")
  if trailing and not trailing:match("=") then
    if not attributes[trailing:lower()] then
      attributes[trailing:lower()] = true
    end
  end

  return attributes
end

--- Parse HTML string to DOM tree
-- @param html string HTML string
-- @return table Root node with children
function HTMLParser.parse(html)
  local root = {
    type = "root",
    children = {},
  }

  local stack = {root}
  local pos = 1

  while pos <= #html do
    local current = stack[#stack]

    -- Find next tag
    local tag_start = html:find("<", pos)

    if not tag_start then
      -- Rest is text
      local text = html:sub(pos)
      if text:match("%S") then
        table.insert(current.children, HTMLParser.text_node(text))
      end
      break
    end

    -- Add text before tag
    if tag_start > pos then
      local text = html:sub(pos, tag_start - 1)
      if text:match("%S") then
        table.insert(current.children, HTMLParser.text_node(text))
      end
    end

    -- Check tag type
    local tag_end = html:find(">", tag_start)
    if not tag_end then
      -- Malformed HTML, treat rest as text
      local text = html:sub(tag_start)
      table.insert(current.children, HTMLParser.text_node(text))
      break
    end

    local tag_content = html:sub(tag_start + 1, tag_end - 1)

    -- Check for comment
    if tag_content:sub(1, 3) == "!--" then
      local comment_end = html:find("-->", tag_start)
      if comment_end then
        local comment_text = html:sub(tag_start + 4, comment_end - 1)
        table.insert(current.children, HTMLParser.comment_node(comment_text))
        pos = comment_end + 3
      else
        pos = tag_end + 1
      end
    elseif tag_content:sub(1, 1) == "!" then
      -- DOCTYPE or other declaration, skip
      pos = tag_end + 1
    elseif tag_content:sub(1, 1) == "/" then
      -- Closing tag
      local closing_tag = tag_content:sub(2):match("^%s*(%w+)")
      if closing_tag then
        closing_tag = closing_tag:lower()
        -- Pop stack until matching tag
        for i = #stack, 2, -1 do
          if stack[i].tag == closing_tag then
            for j = #stack, i + 1, -1 do
              table.remove(stack)
            end
            table.remove(stack)
            break
          end
        end
      end
      pos = tag_end + 1
    else
      -- Opening tag
      local self_closing = tag_content:sub(-1) == "/"
      if self_closing then
        tag_content = tag_content:sub(1, -2)
      end

      local tag_name = tag_content:match("^%s*([%w_%-:]+)")
      if tag_name then
        tag_name = tag_name:lower()
        local attr_str = tag_content:sub(#tag_name + 1)
        local attributes = HTMLParser.parse_attributes(attr_str)

        local node = HTMLParser.element_node(tag_name, attributes)
        table.insert(current.children, node)

        -- Push to stack if not void/self-closing
        if not self_closing and not HTMLParser.VOID_ELEMENTS[tag_name] then
          table.insert(stack, node)
        end
      end
      pos = tag_end + 1
    end
  end

  return root
end

--- Serialize DOM tree back to HTML
-- @param node table DOM node
-- @param options table|nil {pretty, indent_level}
-- @return string HTML string
function HTMLParser.serialize(node, options)
  options = options or {}
  local indent = options.indent_level or 0

  if node.type == HTMLParser.NODE_TYPES.TEXT then
    return node.content
  elseif node.type == HTMLParser.NODE_TYPES.COMMENT then
    return "<!--" .. node.content .. "-->"
  elseif node.type == "root" then
    local parts = {}
    for _, child in ipairs(node.children) do
      table.insert(parts, HTMLParser.serialize(child, options))
    end
    return table.concat(parts)
  elseif node.type == HTMLParser.NODE_TYPES.ELEMENT then
    local parts = {}

    -- Opening tag
    table.insert(parts, "<")
    table.insert(parts, node.tag)

    -- Attributes
    local attr_names = {}
    for name in pairs(node.attributes) do
      table.insert(attr_names, name)
    end
    table.sort(attr_names)

    for _, name in ipairs(attr_names) do
      local value = node.attributes[name]
      if value == true then
        table.insert(parts, " ")
        table.insert(parts, name)
      else
        table.insert(parts, " ")
        table.insert(parts, name)
        table.insert(parts, '="')
        table.insert(parts, HTMLParser.encode_entities(tostring(value)))
        table.insert(parts, '"')
      end
    end

    -- Void element
    if HTMLParser.VOID_ELEMENTS[node.tag] then
      table.insert(parts, ">")
      return table.concat(parts)
    end

    table.insert(parts, ">")

    -- Children
    for _, child in ipairs(node.children) do
      table.insert(parts, HTMLParser.serialize(child, {
        pretty = options.pretty,
        indent_level = indent + 1,
      }))
    end

    -- Closing tag
    table.insert(parts, "</")
    table.insert(parts, node.tag)
    table.insert(parts, ">")

    return table.concat(parts)
  end

  return ""
end

--- Walk DOM tree and call callback for each node
-- @param node table DOM node
-- @param callback function(node, parent) Called for each node
-- @param parent table|nil Parent node
function HTMLParser.walk(node, callback, parent)
  callback(node, parent)

  if node.children then
    for _, child in ipairs(node.children) do
      HTMLParser.walk(child, callback, node)
    end
  end
end

--- Clone a DOM node
-- @param node table Node to clone
-- @return table Cloned node
function HTMLParser.clone(node)
  if node.type == HTMLParser.NODE_TYPES.TEXT then
    return HTMLParser.text_node(node.content)
  elseif node.type == HTMLParser.NODE_TYPES.COMMENT then
    return HTMLParser.comment_node(node.content)
  elseif node.type == HTMLParser.NODE_TYPES.ELEMENT then
    local cloned_attrs = {}
    for k, v in pairs(node.attributes) do
      cloned_attrs[k] = v
    end

    local cloned_children = {}
    for _, child in ipairs(node.children) do
      table.insert(cloned_children, HTMLParser.clone(child))
    end

    return HTMLParser.element_node(node.tag, cloned_attrs, cloned_children)
  elseif node.type == "root" then
    local cloned = {type = "root", children = {}}
    for _, child in ipairs(node.children) do
      table.insert(cloned.children, HTMLParser.clone(child))
    end
    return cloned
  end

  return node
end

return HTMLParser
