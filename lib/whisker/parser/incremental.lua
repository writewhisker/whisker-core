-- lib/whisker/parser/incremental.lua
-- Incremental Parser for WLS documents
-- WLS 1.0 GAP-063: Incremental parsing for editor performance

local Incremental = {}
Incremental.__index = Incremental

--- Create a new Incremental parser wrapper
---@param parser table Base parser instance (WSParser)
---@return Incremental
function Incremental.new(parser)
    local self = setmetatable({}, Incremental)
    self.parser = parser
    self.cache = {}  -- uri -> { ast, content, line_map, passage_ranges }
    return self
end

--- Parse a document fully (initial parse or after invalidation)
---@param uri string Document URI
---@param content string Full document content
---@return table Parse result
function Incremental:parse_document(uri, content)
    -- Full parse using base parser
    local result = self.parser:parse(content)

    self.cache[uri] = {
        ast = result,
        content = content,
        line_map = self:build_line_map(content),
        passage_ranges = self:build_passage_ranges(result)
    }

    return result
end

--- Update document with incremental changes
---@param uri string Document URI
---@param changes table Array of changes { range = { start, end }, text }
---@param new_content string New full content after changes
---@return table Updated parse result
function Incremental:update_document(uri, changes, new_content)
    local cached = self.cache[uri]
    if not cached then
        return self:parse_document(uri, new_content)
    end

    -- Determine what needs re-parsing
    local affected = self:find_affected_regions(cached, changes)

    if affected.full_reparse then
        return self:parse_document(uri, new_content)
    end

    -- Update cache content
    cached.content = new_content
    cached.line_map = self:build_line_map(new_content)

    -- Re-parse only affected passages
    for _, passage_name in ipairs(affected.passages) do
        self:reparse_passage(uri, passage_name, new_content)
    end

    -- Update positions for unaffected nodes
    self:update_positions(cached, changes)

    return cached.ast
end

--- Find regions affected by changes
---@param cached table Cached parse data
---@param changes table Array of changes
---@return table { full_reparse = boolean, passages = table }
function Incremental:find_affected_regions(cached, changes)
    local affected = {
        full_reparse = false,
        passages = {}
    }

    local seen_passages = {}

    for _, change in ipairs(changes) do
        local range = change.range
        if not range then
            -- Full content change
            affected.full_reparse = true
            return affected
        end

        -- Find which passage(s) are affected
        local start_line = range.start and range.start.line or 0
        local end_line = range["end"] and range["end"].line or start_line

        for passage_name, passage_range in pairs(cached.passage_ranges) do
            if self:ranges_overlap(start_line, end_line, passage_range.start, passage_range["end"]) then
                if not seen_passages[passage_name] then
                    seen_passages[passage_name] = true
                    table.insert(affected.passages, passage_name)
                end
            end
        end

        -- Check if change affects passage boundaries
        if self:affects_passage_boundary(cached, change) then
            affected.full_reparse = true
            return affected
        end
    end

    return affected
end

--- Check if two line ranges overlap
---@param start1 number Start of first range
---@param end1 number End of first range
---@param start2 number Start of second range
---@param end2 number End of second range
---@return boolean
function Incremental:ranges_overlap(start1, end1, start2, end2)
    return start1 <= end2 and start2 <= end1
end

--- Check if a change affects passage boundaries
---@param cached table Cached parse data
---@param change table Change object
---@return boolean
function Incremental:affects_passage_boundary(cached, change)
    -- Check if the change creates or removes a passage marker (::)
    local text = change.text or ""
    local range = change.range

    -- New passage marker added?
    if text:match("::") then
        return true
    end

    -- Existing passage marker removed?
    if range then
        local old_text = self:get_range_text(cached.content, range)
        if old_text and old_text:match("::") then
            return true
        end
    end

    return false
end

--- Re-parse a single passage
---@param uri string Document URI
---@param passage_name string Passage name
---@param content string Full document content
function Incremental:reparse_passage(uri, passage_name, content)
    local cached = self.cache[uri]
    local range = cached.passage_ranges[passage_name]

    if not range then return end

    -- Extract passage text
    local passage_text = self:extract_lines(content, range.start, range["end"])

    -- Parse passage content
    local passage_result = self.parser:parse_passage_content(passage_text)

    -- Update AST
    if cached.ast and cached.ast.story and cached.ast.story.passages and cached.ast.story.passages[passage_name] then
        cached.ast.story.passages[passage_name].content = passage_text
        cached.ast.story.passages[passage_name].parsed_content = passage_result
    end
end

--- Update positions for nodes after changes
---@param cached table Cached parse data
---@param changes table Array of changes
function Incremental:update_positions(cached, changes)
    -- Calculate position delta from changes
    local delta_lines = 0
    local first_change_line = math.huge

    for _, change in ipairs(changes) do
        if change.range then
            local start_line = change.range.start and change.range.start.line or 0
            local end_line = change.range["end"] and change.range["end"].line or start_line
            local old_lines = end_line - start_line

            -- Count new lines in change text
            local new_lines = 0
            local text = change.text or ""
            for _ in text:gmatch("\n") do
                new_lines = new_lines + 1
            end

            delta_lines = delta_lines + (new_lines - old_lines)

            if start_line < first_change_line then
                first_change_line = start_line
            end
        end
    end

    if delta_lines == 0 or first_change_line == math.huge then
        return
    end

    -- Update passage ranges
    local new_ranges = {}
    for name, range in pairs(cached.passage_ranges) do
        if range.start > first_change_line then
            new_ranges[name] = {
                start = range.start + delta_lines,
                ["end"] = range["end"] + delta_lines
            }
        else
            new_ranges[name] = range
        end
    end
    cached.passage_ranges = new_ranges
end

--- Build a map of line numbers to character positions
---@param content string Document content
---@return table Line map { line_number = char_position }
function Incremental:build_line_map(content)
    local map = {}
    local line_num = 1
    local pos = 1

    map[1] = 1
    for char_pos in content:gmatch("()\n") do
        line_num = line_num + 1
        map[line_num] = char_pos + 1
    end

    return map
end

--- Build a map of passage names to their line ranges
---@param result table Parse result
---@return table Passage ranges { name = { start, end } }
function Incremental:build_passage_ranges(result)
    local ranges = {}

    if not result or not result.story or not result.story.passages then
        return ranges
    end

    local passages = result.story.passages

    -- Collect passages with their start lines
    local sorted = {}
    for name, passage in pairs(passages) do
        local start_line = 1
        if passage.location and passage.location.line then
            start_line = passage.location.line
        elseif passage.location and passage.location.start and passage.location.start.line then
            start_line = passage.location.start.line
        end
        table.insert(sorted, { name = name, start = start_line })
    end

    -- Sort by start line
    table.sort(sorted, function(a, b) return a.start < b.start end)

    -- Determine end of each passage
    for i, item in ipairs(sorted) do
        local end_line
        if i < #sorted then
            end_line = sorted[i + 1].start - 1
        else
            -- Last passage - estimate based on content
            local passage = passages[item.name]
            if passage.content then
                local lines = 0
                for _ in passage.content:gmatch("\n") do
                    lines = lines + 1
                end
                end_line = item.start + lines + 1
            else
                end_line = item.start + 100  -- Fallback estimate
            end
        end
        ranges[item.name] = {
            start = item.start,
            ["end"] = end_line
        }
    end

    return ranges
end

--- Extract lines from content
---@param content string Full content
---@param start_line number Start line (1-based)
---@param end_line number End line (1-based)
---@return string Extracted text
function Incremental:extract_lines(content, start_line, end_line)
    local lines = {}
    local line_num = 1
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        if line_num >= start_line and line_num <= end_line then
            table.insert(lines, line)
        end
        line_num = line_num + 1
    end
    return table.concat(lines, "\n")
end

--- Get text from a range in content
---@param content string Full content
---@param range table Range { start = { line, character }, end = { line, character } }
---@return string|nil Extracted text
function Incremental:get_range_text(content, range)
    if not range or not range.start or not range["end"] then
        return nil
    end

    local start_line = range.start.line or 0
    local end_line = range["end"].line or start_line
    local start_char = range.start.character or 0
    local end_char = range["end"].character or 0

    local lines = {}
    local line_num = 0
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        if line_num >= start_line and line_num <= end_line then
            if line_num == start_line and line_num == end_line then
                -- Single line range
                table.insert(lines, line:sub(start_char + 1, end_char))
            elseif line_num == start_line then
                table.insert(lines, line:sub(start_char + 1))
            elseif line_num == end_line then
                table.insert(lines, line:sub(1, end_char))
            else
                table.insert(lines, line)
            end
        end
        line_num = line_num + 1
    end

    return table.concat(lines, "\n")
end

--- Invalidate cache for a document
---@param uri string Document URI
function Incremental:invalidate(uri)
    self.cache[uri] = nil
end

--- Check if a document is cached
---@param uri string Document URI
---@return boolean
function Incremental:is_cached(uri)
    return self.cache[uri] ~= nil
end

--- Get cached AST for a document
---@param uri string Document URI
---@return table|nil AST or nil if not cached
function Incremental:get_cached_ast(uri)
    local cached = self.cache[uri]
    return cached and cached.ast or nil
end

--- Get passage range for a passage name
---@param uri string Document URI
---@param passage_name string Passage name
---@return table|nil Range { start, end } or nil
function Incremental:get_passage_range(uri, passage_name)
    local cached = self.cache[uri]
    if not cached or not cached.passage_ranges then
        return nil
    end
    return cached.passage_ranges[passage_name]
end

return Incremental
