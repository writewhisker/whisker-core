-- lib/whisker/debug/breakpoints.lua
-- WLS 1.0.0 GAP-056: Breakpoint Management
-- Provides line, passage, conditional, hit count, and logpoint breakpoints

local Breakpoints = {}
Breakpoints.__index = Breakpoints

-- Breakpoint types
Breakpoints.TYPE_LINE = "line"
Breakpoints.TYPE_PASSAGE = "passage"
Breakpoints.TYPE_CONDITIONAL = "conditional"
Breakpoints.TYPE_LOGPOINT = "logpoint"

--- Create a new Breakpoints manager instance
-- @return Breakpoints instance
function Breakpoints.new()
    local self = setmetatable({}, Breakpoints)
    self.breakpoints = {}  -- id -> breakpoint
    self.by_file = {}      -- file -> { line -> breakpoint_id }
    self.by_passage = {}   -- passage_name -> breakpoint_id
    self.next_id = 1
    return self
end

--- Add a new breakpoint
-- @param options table Breakpoint options:
--   type: string - Breakpoint type (line, passage, conditional, logpoint)
--   file: string - Source file path (for line breakpoints)
--   line: number - Line number (for line breakpoints)
--   passage: string - Passage name (for passage breakpoints)
--   condition: string - Lua expression for conditional breakpoints
--   hit_condition: string - Hit count condition (e.g., ">= 5")
--   log_message: string - Log message template for logpoints
--   enabled: boolean - Whether breakpoint is enabled (default true)
-- @return table Breakpoint object
function Breakpoints:add(options)
    local bp = {
        id = self.next_id,
        type = options.type or Breakpoints.TYPE_LINE,
        file = options.file,
        line = options.line,
        passage = options.passage,
        condition = options.condition,
        hit_condition = options.hit_condition,  -- e.g., ">= 5"
        log_message = options.log_message,
        enabled = options.enabled ~= false,
        hit_count = 0,
        verified = false
    }

    self.next_id = self.next_id + 1
    self.breakpoints[bp.id] = bp

    -- Index by file/line
    if bp.file and bp.line then
        if not self.by_file[bp.file] then
            self.by_file[bp.file] = {}
        end
        self.by_file[bp.file][bp.line] = bp.id
        bp.verified = true
    end

    -- Index by passage
    if bp.passage then
        self.by_passage[bp.passage] = bp.id
        bp.verified = true
    end

    return bp
end

--- Remove a breakpoint by ID
-- @param id number Breakpoint ID
-- @return boolean success
function Breakpoints:remove(id)
    local bp = self.breakpoints[id]
    if not bp then return false end

    -- Remove from indices
    if bp.file and bp.line and self.by_file[bp.file] then
        self.by_file[bp.file][bp.line] = nil
    end
    if bp.passage then
        self.by_passage[bp.passage] = nil
    end

    self.breakpoints[id] = nil
    return true
end

--- Clear all breakpoints for a specific file
-- @param file string File path
function Breakpoints:clear_file(file)
    if not self.by_file[file] then return end

    for line, id in pairs(self.by_file[file]) do
        self.breakpoints[id] = nil
    end
    self.by_file[file] = nil
end

--- Clear all breakpoints
function Breakpoints:clear_all()
    self.breakpoints = {}
    self.by_file = {}
    self.by_passage = {}
end

--- Enable a breakpoint
-- @param id number Breakpoint ID
-- @return boolean success
function Breakpoints:enable(id)
    local bp = self.breakpoints[id]
    if bp then
        bp.enabled = true
        return true
    end
    return false
end

--- Disable a breakpoint
-- @param id number Breakpoint ID
-- @return boolean success
function Breakpoints:disable(id)
    local bp = self.breakpoints[id]
    if bp then
        bp.enabled = false
        return true
    end
    return false
end

--- Get a breakpoint by ID
-- @param id number Breakpoint ID
-- @return table|nil Breakpoint object
function Breakpoints:get(id)
    return self.breakpoints[id]
end

--- Check for breakpoint at file/line
-- @param file string File path
-- @param line number Line number
-- @param context table Evaluation context { interpreter, game_state }
-- @return table|nil Result { type = "break"|"log", ... } or nil
function Breakpoints:check_line(file, line, context)
    if not self.by_file[file] then return nil end

    local bp_id = self.by_file[file][line]
    if not bp_id then return nil end

    return self:evaluate_breakpoint(bp_id, context)
end

--- Check for breakpoint at passage entry
-- @param passage_name string Passage name
-- @param context table Evaluation context { interpreter, game_state }
-- @return table|nil Result { type = "break"|"log", ... } or nil
function Breakpoints:check_passage(passage_name, context)
    local bp_id = self.by_passage[passage_name]
    if not bp_id then return nil end

    return self:evaluate_breakpoint(bp_id, context)
end

--- Evaluate a breakpoint to determine if it should trigger
-- @param bp_id number Breakpoint ID
-- @param context table Evaluation context
-- @return table|nil Result object or nil if not triggered
function Breakpoints:evaluate_breakpoint(bp_id, context)
    local bp = self.breakpoints[bp_id]
    if not bp or not bp.enabled then return nil end

    -- Increment hit count
    bp.hit_count = bp.hit_count + 1

    -- Check hit condition
    if bp.hit_condition then
        if not self:check_hit_condition(bp.hit_condition, bp.hit_count) then
            return nil
        end
    end

    -- Check condition
    if bp.condition then
        local success, result = self:evaluate_condition(bp.condition, context)
        if not success or not result then
            return nil
        end
    end

    -- Handle logpoint
    if bp.type == Breakpoints.TYPE_LOGPOINT then
        local message = self:format_log_message(bp.log_message, context)
        return { type = "log", message = message, breakpoint = bp }
    end

    -- Regular breakpoint hit
    return { type = "break", breakpoint = bp }
end

--- Check if a hit condition is satisfied
-- Supports: >= N, > N, <= N, < N, == N, != N, % N == M
-- @param condition string Hit condition expression
-- @param count number Current hit count
-- @return boolean Whether condition is satisfied
function Breakpoints:check_hit_condition(condition, count)
    -- Parse conditions like ">= 5", "== 3", "% 10 == 0"

    -- First check for modulo pattern: % N == M
    local mod_divisor, mod_remainder = condition:match("%%%s*(%d+)%s*==%s*(%d+)")
    if mod_divisor then
        return count % tonumber(mod_divisor) == tonumber(mod_remainder)
    end

    -- Then check standard comparisons
    local op, num = condition:match("^%s*([><=!]+)%s*(%d+)")
    if not op or not num then return true end

    num = tonumber(num)

    if op == ">=" then return count >= num
    elseif op == ">" then return count > num
    elseif op == "<=" then return count <= num
    elseif op == "<" then return count < num
    elseif op == "==" then return count == num
    elseif op == "!=" then return count ~= num
    end

    return true
end

--- Evaluate a conditional breakpoint expression
-- @param condition string Lua expression
-- @param context table { interpreter, game_state }
-- @return boolean success, boolean|nil result
function Breakpoints:evaluate_condition(condition, context)
    -- Use interpreter to evaluate if available
    if context and context.interpreter then
        local pcall_ok, eval_success, result = pcall(function()
            local s, r = context.interpreter:evaluate_expression(condition, context.game_state)
            return s, r
        end)
        if pcall_ok and eval_success then
            return true, result
        else
            return false, nil
        end
    end

    -- Fallback: try to evaluate as simple Lua expression
    local func, err = load("return " .. condition)
    if func then
        local success, result = pcall(func)
        if success then
            return true, result
        end
    end

    return true, true  -- Default to triggering if we can't evaluate
end

--- Format a logpoint message with expression interpolation
-- Replaces {expr} patterns with evaluated values
-- @param template string Message template
-- @param context table Evaluation context
-- @return string Formatted message
function Breakpoints:format_log_message(template, context)
    if not template then return "" end

    return template:gsub("{([^}]+)}", function(expr)
        if context and context.interpreter then
            local pcall_ok, eval_success, result = pcall(function()
                local s, r = context.interpreter:evaluate_expression(expr, context.game_state)
                return s, r
            end)
            if pcall_ok and eval_success and result ~= nil then
                return tostring(result)
            end
        end

        -- Try direct variable lookup in game_state
        if context and context.game_state then
            local value = context.game_state:get(expr)
            if value ~= nil then
                return tostring(value)
            end
        end

        return "{" .. expr .. "}"
    end)
end

--- Get all breakpoints
-- @return table Array of breakpoint objects
function Breakpoints:get_all()
    local list = {}
    for _, bp in pairs(self.breakpoints) do
        table.insert(list, bp)
    end
    return list
end

--- Get breakpoints for a specific file
-- @param file string File path
-- @return table Array of breakpoint objects
function Breakpoints:get_for_file(file)
    local list = {}
    if self.by_file[file] then
        for line, id in pairs(self.by_file[file]) do
            if self.breakpoints[id] then
                table.insert(list, self.breakpoints[id])
            end
        end
    end
    return list
end

--- Serialize breakpoints for saving
-- @return table Serialized data
function Breakpoints:serialize()
    local data = {
        breakpoints = {},
        next_id = self.next_id
    }

    for id, bp in pairs(self.breakpoints) do
        data.breakpoints[id] = {
            id = bp.id,
            type = bp.type,
            file = bp.file,
            line = bp.line,
            passage = bp.passage,
            condition = bp.condition,
            hit_condition = bp.hit_condition,
            log_message = bp.log_message,
            enabled = bp.enabled,
            hit_count = bp.hit_count
        }
    end

    return data
end

--- Deserialize breakpoints from saved data
-- @param data table Serialized data
function Breakpoints:deserialize(data)
    if not data then return end

    self.breakpoints = {}
    self.by_file = {}
    self.by_passage = {}
    self.next_id = data.next_id or 1

    for _, bp_data in pairs(data.breakpoints or {}) do
        -- Re-add each breakpoint to rebuild indices
        local bp = self:add({
            type = bp_data.type,
            file = bp_data.file,
            line = bp_data.line,
            passage = bp_data.passage,
            condition = bp_data.condition,
            hit_condition = bp_data.hit_condition,
            log_message = bp_data.log_message,
            enabled = bp_data.enabled
        })
        bp.hit_count = bp_data.hit_count or 0
    end
end

--- Reset hit counts for all breakpoints
function Breakpoints:reset_hit_counts()
    for _, bp in pairs(self.breakpoints) do
        bp.hit_count = 0
    end
end

return Breakpoints
