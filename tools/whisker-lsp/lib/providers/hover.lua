-- whisker-lsp/lib/providers/hover.lua
-- Hover documentation provider

local HoverProvider = {}
HoverProvider.__index = HoverProvider

--- Create a new hover provider
--- @param document_manager table DocumentManager instance
--- @param parser_integration table ParserIntegration instance
--- @return table HoverProvider instance
function HoverProvider.new(document_manager, parser_integration)
  local self = setmetatable({}, HoverProvider)
  self.document_manager = document_manager
  self.parser = parser_integration
  return self
end

--- Get hover information for a position
--- @param params table Hover request params
--- @return table|nil Hover result or nil
function HoverProvider:get_hover(params)
  local uri = params.textDocument.uri
  local line = params.position.line
  local character = params.position.character

  -- Get word at position
  local word, start_char, end_char = self.document_manager:get_word_at_position(uri, line, character)
  if not word then
    return nil
  end

  -- Check if it's a passage reference
  local passage = self:find_passage(uri, word)
  if passage then
    return self:create_passage_hover(passage, line, start_char, end_char)
  end

  -- Check if it's a variable reference
  local variable = self:find_variable(uri, word)
  if variable then
    return self:create_variable_hover(variable, line, start_char, end_char)
  end

  -- Check if it's a macro
  local macro = self:find_macro(word)
  if macro then
    return self:create_macro_hover(macro, line, start_char, end_char)
  end

  -- Check if it's a keyword
  local keyword = self:find_keyword(word)
  if keyword then
    return self:create_keyword_hover(keyword, line, start_char, end_char)
  end

  return nil
end

--- Find passage by name
--- @param uri string Document URI
--- @param name string Passage name
--- @return table|nil Passage info
function HoverProvider:find_passage(uri, name)
  local passages = self.parser:get_passages(uri)
  for _, passage in ipairs(passages) do
    if passage.name == name then
      return passage
    end
  end

  -- Check special passages
  local special = {
    END = { name = "END", description = "Ends the story", special = true },
    DONE = { name = "DONE", description = "Ends the current thread", special = true },
    START = { name = "START", description = "Story entry point", special = true }
  }

  return special[name]
end

--- Find variable by name
--- @param uri string Document URI
--- @param name string Variable name
--- @return table|nil Variable info
function HoverProvider:find_variable(uri, name)
  local variables = self.parser:get_variables(uri)
  for _, var in ipairs(variables) do
    if var.name == name then
      return var
    end
  end
  return nil
end

--- Find macro by name
--- @param name string Macro name
--- @return table|nil Macro info
function HoverProvider:find_macro(name)
  local macros = {
    ["if"] = {
      name = "if",
      signature = "<<if condition>>...<<endif>>",
      description = "Conditional block. Content is shown only if condition is true."
    },
    ["else"] = {
      name = "else",
      signature = "<<else>>",
      description = "Else branch of conditional block."
    },
    ["elseif"] = {
      name = "elseif",
      signature = "<<elseif condition>>",
      description = "Else-if branch of conditional block."
    },
    ["endif"] = {
      name = "endif",
      signature = "<<endif>>",
      description = "Ends a conditional block."
    },
    ["set"] = {
      name = "set",
      signature = "<<set variable = value>>",
      description = "Sets a variable to a value."
    },
    ["include"] = {
      name = "include",
      signature = "<<include passageName>>",
      description = "Includes content from another passage."
    },
    ["link"] = {
      name = "link",
      signature = "<<link text>>target<</link>>",
      description = "Creates a clickable link to another passage."
    },
    ["silently"] = {
      name = "silently",
      signature = "<<silently>>...<</silently>>",
      description = "Executes content without displaying output."
    },
    ["nobr"] = {
      name = "nobr",
      signature = "<<nobr>>...<</nobr>>",
      description = "Removes line breaks from content."
    }
  }

  return macros[name]
end

--- Find keyword
--- @param name string Keyword name
--- @return table|nil Keyword info
function HoverProvider:find_keyword(name)
  local keywords = {
    passage = {
      name = "passage",
      description = "Defines a named passage in the story."
    },
    choice = {
      name = "choice",
      description = "Defines a player choice (* [text] -> target)."
    }
  }

  return keywords[name]
end

--- Create hover result for passage
--- @param passage table Passage info
--- @param line number Line number
--- @param start_char number Start character
--- @param end_char number End character
--- @return table Hover result
function HoverProvider:create_passage_hover(passage, line, start_char, end_char)
  local contents = {}

  -- Title
  table.insert(contents, "**Passage: " .. passage.name .. "**")
  table.insert(contents, "")

  -- Tags
  if passage.tags and #passage.tags > 0 then
    table.insert(contents, "Tags: `" .. table.concat(passage.tags, "`, `") .. "`")
    table.insert(contents, "")
  end

  -- Description
  if passage.description and passage.description ~= "" then
    table.insert(contents, passage.description)
    table.insert(contents, "")
  end

  -- Location
  if passage.line then
    table.insert(contents, string.format("*Defined at line %d*", passage.line + 1))
  end

  if passage.special then
    table.insert(contents, "")
    table.insert(contents, "*Built-in passage*")
  end

  return {
    contents = {
      kind = "markdown",
      value = table.concat(contents, "\n")
    },
    range = {
      start = { line = line, character = start_char },
      ["end"] = { line = line, character = end_char }
    }
  }
end

--- Create hover result for variable
--- @param variable table Variable info
--- @param line number Line number
--- @param start_char number Start character
--- @param end_char number End character
--- @return table Hover result
function HoverProvider:create_variable_hover(variable, line, start_char, end_char)
  local contents = {}

  -- Title
  table.insert(contents, "**Variable: " .. variable.name .. "**")
  table.insert(contents, "")

  -- Type
  table.insert(contents, "Type: `" .. (variable.type or "unknown") .. "`")

  -- Value
  if variable.value ~= nil then
    table.insert(contents, "Initial value: `" .. tostring(variable.value) .. "`")
  end

  -- Location
  if variable.line then
    table.insert(contents, "")
    table.insert(contents, string.format("*Defined at line %d*", variable.line + 1))
  end

  return {
    contents = {
      kind = "markdown",
      value = table.concat(contents, "\n")
    },
    range = {
      start = { line = line, character = start_char },
      ["end"] = { line = line, character = end_char }
    }
  }
end

--- Create hover result for macro
--- @param macro table Macro info
--- @param line number Line number
--- @param start_char number Start character
--- @param end_char number End character
--- @return table Hover result
function HoverProvider:create_macro_hover(macro, line, start_char, end_char)
  local contents = {}

  -- Title
  table.insert(contents, "**Macro: " .. macro.name .. "**")
  table.insert(contents, "")

  -- Signature
  table.insert(contents, "```")
  table.insert(contents, macro.signature)
  table.insert(contents, "```")
  table.insert(contents, "")

  -- Description
  table.insert(contents, macro.description)

  return {
    contents = {
      kind = "markdown",
      value = table.concat(contents, "\n")
    },
    range = {
      start = { line = line, character = start_char },
      ["end"] = { line = line, character = end_char }
    }
  }
end

--- Create hover result for keyword
--- @param keyword table Keyword info
--- @param line number Line number
--- @param start_char number Start character
--- @param end_char number End character
--- @return table Hover result
function HoverProvider:create_keyword_hover(keyword, line, start_char, end_char)
  local contents = {}

  table.insert(contents, "**" .. keyword.name .. "**")
  table.insert(contents, "")
  table.insert(contents, keyword.description)

  return {
    contents = {
      kind = "markdown",
      value = table.concat(contents, "\n")
    },
    range = {
      start = { line = line, character = start_char },
      ["end"] = { line = line, character = end_char }
    }
  }
end

return HoverProvider
