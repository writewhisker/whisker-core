--- LSP Symbols Provider
-- Provides document symbols and folding ranges for WLS documents
-- @module whisker.lsp.symbols
-- @author Whisker Core Team
-- @license MIT

local Symbols = {}
Symbols.__index = Symbols
Symbols._dependencies = {}

--- Symbol kinds
local SymbolKind = {
  FILE = 1,
  MODULE = 2,
  CLASS = 5,
  METHOD = 6,
  PROPERTY = 7,
  FIELD = 8,
  FUNCTION = 12,
  VARIABLE = 13,
  CONSTANT = 14,
  STRING = 15,
}

--- Create a new symbols provider
-- @param options table Options with documents manager
-- @return Symbols Provider instance
function Symbols.new(options)
  options = options or {}
  local self = setmetatable({}, Symbols)
  self._documents = options.documents
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function Symbols:set_parser(parser)
  self._parser = parser
end

--- Get document symbols
-- @param uri string Document URI
-- @return table Array of document symbols
function Symbols:get_symbols(uri)
  local symbols = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return symbols end

  -- Track current passage for nested symbols
  local current_passage = nil
  local current_passage_symbol = nil

  for i, line in ipairs(lines) do
    -- Check for passage header
    local header = line:match("^::%s*(.+)$")
    if header then
      -- Save previous passage
      if current_passage_symbol then
        -- Update passage range to end at previous line
        current_passage_symbol.range["end"] = { line = i - 2, character = 0 }
        current_passage_symbol.selectionRange["end"] = { line = i - 2, character = 0 }
      end

      local name = header:match("^([^%[%]]+)")
      if name then
        name = name:match("^%s*(.-)%s*$")

        -- Extract tags
        local tags = {}
        local tags_str = header:match("%[(.+)%]")
        if tags_str then
          for tag in tags_str:gmatch("[^,%s]+") do
            table.insert(tags, tag)
          end
        end

        local detail = #tags > 0 and ("tags: " .. table.concat(tags, ", ")) or nil
        local name_start = line:find(name, 1, true) - 1

        current_passage_symbol = {
          name = name,
          kind = SymbolKind.CLASS,
          detail = detail,
          range = {
            start = { line = i - 1, character = 0 },
            ["end"] = { line = i - 1, character = #line },
          },
          selectionRange = {
            start = { line = i - 1, character = name_start },
            ["end"] = { line = i - 1, character = name_start + #name },
          },
          children = {},
        }
        current_passage = name
        table.insert(symbols, current_passage_symbol)
      end

    -- Check for VAR declaration
    elseif line:match("^%s*VAR%s+") then
      local var_name, var_value = line:match("^%s*VAR%s+([%w_]+)%s*=%s*(.+)$")
      if var_name then
        local var_start = line:find(var_name, 1, true) - 1
        local var_symbol = {
          name = "$" .. var_name,
          kind = SymbolKind.VARIABLE,
          detail = var_value:match("^%s*(.-)%s*$"),
          range = {
            start = { line = i - 1, character = 0 },
            ["end"] = { line = i - 1, character = #line },
          },
          selectionRange = {
            start = { line = i - 1, character = var_start },
            ["end"] = { line = i - 1, character = var_start + #var_name },
          },
        }

        -- Add to document level if no current passage
        if current_passage_symbol then
          table.insert(current_passage_symbol.children, var_symbol)
        else
          table.insert(symbols, var_symbol)
        end
      end

    -- Check for choice
    elseif current_passage_symbol and line:match("^%s*[+*]") then
      local choice_text = line:match("^%s*[+*]%s*%[([^%]]+)%]")
      if choice_text then
        local choice_start = line:find("[", 1, true)
        local choice_symbol = {
          name = choice_text,
          kind = SymbolKind.METHOD,
          detail = "choice",
          range = {
            start = { line = i - 1, character = 0 },
            ["end"] = { line = i - 1, character = #line },
          },
          selectionRange = {
            start = { line = i - 1, character = choice_start },
            ["end"] = { line = i - 1, character = choice_start + #choice_text + 1 },
          },
        }
        table.insert(current_passage_symbol.children, choice_symbol)
      end
    end
  end

  -- Update last passage range
  if current_passage_symbol then
    current_passage_symbol.range["end"] = { line = #lines - 1, character = #lines[#lines] }
    current_passage_symbol.selectionRange["end"] = { line = #lines - 1, character = #lines[#lines] }
  end

  return symbols
end

--- Get folding ranges
-- @param uri string Document URI
-- @return table Array of folding ranges
function Symbols:get_folding_ranges(uri)
  local ranges = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return ranges end

  local passage_start = nil
  local in_block_comment = false
  local block_comment_start = nil

  for i, line in ipairs(lines) do
    -- Block comments
    if line:find("/%*") and not in_block_comment then
      in_block_comment = true
      block_comment_start = i - 1
    end
    if in_block_comment and line:find("%*/") then
      in_block_comment = false
      if i - 1 > block_comment_start then
        table.insert(ranges, {
          startLine = block_comment_start,
          endLine = i - 1,
          kind = "comment",
        })
      end
    end

    -- Passage headers
    if line:match("^::") then
      -- End previous passage
      if passage_start ~= nil and i - 2 > passage_start then
        table.insert(ranges, {
          startLine = passage_start,
          endLine = i - 2,
          kind = "region",
        })
      end
      passage_start = i - 1
    end

    -- Region markers
    if line:match("^%s*//[%s#]*region") then
      -- Start of region - would need stack for nested regions
    end
    if line:match("^%s*//[%s#]*endregion") then
      -- End of region
    end
  end

  -- End last passage
  if passage_start ~= nil and #lines - 1 > passage_start then
    table.insert(ranges, {
      startLine = passage_start,
      endLine = #lines - 1,
      kind = "region",
    })
  end

  return ranges
end

return Symbols
