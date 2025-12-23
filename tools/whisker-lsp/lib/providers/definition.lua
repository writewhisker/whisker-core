-- whisker-lsp/lib/providers/definition.lua
-- Go-to-definition provider

local DefinitionProvider = {}
DefinitionProvider.__index = DefinitionProvider

--- Create a new definition provider
--- @param document_manager table DocumentManager instance
--- @param parser_integration table ParserIntegration instance
--- @return table DefinitionProvider instance
function DefinitionProvider.new(document_manager, parser_integration)
  local self = setmetatable({}, DefinitionProvider)
  self.document_manager = document_manager
  self.parser = parser_integration
  return self
end

--- Get definition location for a position
--- @param params table Definition request params
--- @return table|nil Location or nil
function DefinitionProvider:get_definition(params)
  local uri = params.textDocument.uri
  local line = params.position.line
  local character = params.position.character

  -- Get word at position
  local word = self.document_manager:get_word_at_position(uri, line, character)
  if not word then
    return nil
  end

  -- Check if it's a passage reference
  local passage = self:find_passage(uri, word)
  if passage then
    return self:create_location(uri, passage.line, 0)
  end

  -- Check if it's a variable reference
  local variable = self:find_variable(uri, word)
  if variable then
    return self:create_location(uri, variable.line, variable.column or 0)
  end

  return nil
end

--- Find passage by name
--- @param uri string Document URI
--- @param name string Passage name
--- @return table|nil Passage info
function DefinitionProvider:find_passage(uri, name)
  local passages = self.parser:get_passages(uri)
  for _, passage in ipairs(passages) do
    if passage.name == name then
      return passage
    end
  end
  return nil
end

--- Find variable by name
--- @param uri string Document URI
--- @param name string Variable name
--- @return table|nil Variable info
function DefinitionProvider:find_variable(uri, name)
  local variables = self.parser:get_variables(uri)
  for _, var in ipairs(variables) do
    if var.name == name then
      return var
    end
  end
  return nil
end

--- Create a location result
--- @param uri string Document URI
--- @param line number 0-based line number
--- @param character number 0-based character offset
--- @return table Location
function DefinitionProvider:create_location(uri, line, character)
  return {
    uri = uri,
    range = {
      start = { line = line, character = character },
      ["end"] = { line = line, character = character }
    }
  }
end

return DefinitionProvider
