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

  -- Find passage ranges
  local passage_ranges = self:_find_passage_ranges(lines)
  for _, range in ipairs(passage_ranges) do
    table.insert(ranges, range)
  end

  -- Find block ranges (NAMESPACE, FUNCTION)
  local block_ranges = self:_find_block_ranges(lines)
  for _, range in ipairs(block_ranges) do
    table.insert(ranges, range)
  end

  -- Find style block ranges
  local style_ranges = self:_find_style_ranges(lines)
  for _, range in ipairs(style_ranges) do
    table.insert(ranges, range)
  end

  -- Find comment ranges (consecutive comments)
  local comment_ranges = self:_find_comment_ranges(lines)
  for _, range in ipairs(comment_ranges) do
    table.insert(ranges, range)
  end

  -- Find block comment ranges (/* ... */)
  local block_comment_ranges = self:_find_block_comment_ranges(lines)
  for _, range in ipairs(block_comment_ranges) do
    table.insert(ranges, range)
  end

  return ranges
end

--- Find passage folding ranges
-- @param lines table Array of lines
-- @return table Array of folding ranges
function Symbols:_find_passage_ranges(lines)
  local ranges = {}
  local passage_starts = {}

  -- Find all passage markers
  for i, line in ipairs(lines) do
    if line:match("^%s*::%s*%S") then
      table.insert(passage_starts, i - 1) -- 0-based line
    end
  end

  -- Create ranges between passages
  for i, start_line in ipairs(passage_starts) do
    local end_line
    if i < #passage_starts then
      end_line = passage_starts[i + 1] - 1
    else
      end_line = #lines - 1
    end

    -- Only fold if more than one line
    if end_line > start_line then
      table.insert(ranges, {
        startLine = start_line,
        endLine = end_line,
        kind = "region",
      })
    end
  end

  return ranges
end

--- Find NAMESPACE and FUNCTION block ranges
-- @param lines table Array of lines
-- @return table Array of folding ranges
function Symbols:_find_block_ranges(lines)
  local ranges = {}

  -- Find NAMESPACE blocks
  local namespace_stack = {}
  for i, line in ipairs(lines) do
    if line:match("^%s*NAMESPACE%s+%w+") then
      table.insert(namespace_stack, i - 1) -- 0-based
    elseif line:match("^%s*END%s+NAMESPACE") then
      if #namespace_stack > 0 then
        local start_line = table.remove(namespace_stack)
        if i - 1 > start_line then
          table.insert(ranges, {
            startLine = start_line,
            endLine = i - 1,
            kind = "region",
          })
        end
      end
    end
  end

  -- Find FUNCTION blocks
  local function_stack = {}
  for i, line in ipairs(lines) do
    if line:match("^%s*FUNCTION%s+%w+") then
      table.insert(function_stack, i - 1) -- 0-based
    elseif line:match("^%s*END%s*$") then
      if #function_stack > 0 then
        local start_line = table.remove(function_stack)
        if i - 1 > start_line then
          table.insert(ranges, {
            startLine = start_line,
            endLine = i - 1,
            kind = "region",
          })
        end
      end
    end
  end

  return ranges
end

--- Find @style { ... } block ranges
-- @param lines table Array of lines
-- @return table Array of folding ranges
function Symbols:_find_style_ranges(lines)
  local ranges = {}
  local in_style = false
  local style_start = nil
  local brace_depth = 0

  for i, line in ipairs(lines) do
    if line:match("^%s*@style%s*{") then
      in_style = true
      style_start = i - 1 -- 0-based
      brace_depth = 1
    elseif in_style then
      for char in line:gmatch(".") do
        if char == "{" then
          brace_depth = brace_depth + 1
        elseif char == "}" then
          brace_depth = brace_depth - 1
          if brace_depth == 0 then
            if i - 1 > style_start then
              table.insert(ranges, {
                startLine = style_start,
                endLine = i - 1,
                kind = "region",
              })
            end
            in_style = false
            break
          end
        end
      end
    end
  end

  return ranges
end

--- Find consecutive line comment ranges
-- @param lines table Array of lines
-- @return table Array of folding ranges
function Symbols:_find_comment_ranges(lines)
  local ranges = {}
  local comment_start = nil

  for i, line in ipairs(lines) do
    local is_comment = line:match("^%s*//") or line:match("^%s*%-%-")

    if is_comment then
      if not comment_start then
        comment_start = i - 1 -- 0-based
      end
    else
      -- End of comment block
      if comment_start and (i - 1) - comment_start > 1 then
        table.insert(ranges, {
          startLine = comment_start,
          endLine = i - 2, -- 0-based, previous line
          kind = "comment",
        })
      end
      comment_start = nil
    end
  end

  -- Handle comment at end of file
  if comment_start and (#lines - 1) - comment_start > 0 then
    table.insert(ranges, {
      startLine = comment_start,
      endLine = #lines - 1,
      kind = "comment",
    })
  end

  return ranges
end

--- Find block comment ranges (/* ... */)
-- @param lines table Array of lines
-- @return table Array of folding ranges
function Symbols:_find_block_comment_ranges(lines)
  local ranges = {}
  local in_block_comment = false
  local block_comment_start = nil

  for i, line in ipairs(lines) do
    if line:find("/%*") and not in_block_comment then
      in_block_comment = true
      block_comment_start = i - 1 -- 0-based
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
  end

  return ranges
end

return Symbols
