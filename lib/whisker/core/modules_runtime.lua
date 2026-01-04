-- lib/whisker/core/modules_runtime.lua
-- WLS 1.0 Modules Runtime: FUNCTION and NAMESPACE execution support

-- Compatibility: loadstring was renamed to load in Lua 5.2+
local loadstring = loadstring or load

local ModulesRuntime = {}
ModulesRuntime.__index = ModulesRuntime

-- Dependencies for DI pattern
ModulesRuntime._dependencies = {}

--- Create a new ModulesRuntime instance
-- @param game_state table The game state for variable access
-- @return ModulesRuntime
function ModulesRuntime.new(game_state)
    local instance = {
        -- Function registry: name -> { params = {...}, body = "..." }
        functions = {},
        -- Namespace stack for scoping
        namespace_stack = {},
        -- Reference to game state for variable operations
        game_state = game_state,
        -- Included file tracking (prevent circular includes)
        included_files = {}
    }
    setmetatable(instance, ModulesRuntime)
    return instance
end

--- Get the current namespace prefix
-- @return string The current namespace path (e.g., "MyModule.SubModule")
function ModulesRuntime:current_namespace()
    if #self.namespace_stack == 0 then
        return ""
    end
    return table.concat(self.namespace_stack, ".")
end

--- Enter a namespace scope
-- @param name string The namespace name
function ModulesRuntime:enter_namespace(name)
    if not name or name == "" then
        error("Namespace name cannot be empty")
    end
    table.insert(self.namespace_stack, name)
end

--- Exit the current namespace scope
-- @return string|nil The exited namespace name, or nil if at root
function ModulesRuntime:exit_namespace()
    if #self.namespace_stack == 0 then
        return nil
    end
    return table.remove(self.namespace_stack)
end

--- Resolve a name with namespace scoping
-- Tries current namespace first, then walks up to global
-- @param name string The name to resolve (may be qualified like "Foo.bar")
-- @return string The fully qualified name that was found, or the original name
function ModulesRuntime:resolve_name(name)
    if not name or name == "" then
        return name
    end

    -- If already qualified (contains .), check if it exists directly
    if string.find(name, ".", 1, true) then
        if self.functions[name] then
            return name
        end
    end

    -- Try current namespace and walk up
    local ns = self:current_namespace()
    while ns ~= "" do
        local qualified = ns .. "." .. name
        if self.functions[qualified] then
            return qualified
        end
        -- Walk up one level
        local last_dot = ns:match(".*()%.")
        if last_dot then
            ns = ns:sub(1, last_dot - 1)
        else
            ns = ""
        end
    end

    -- Try global
    if self.functions[name] then
        return name
    end

    -- Return original name (caller may want to report error)
    return name
end

--- Define a function
-- @param name string The function name (without namespace prefix)
-- @param params table Array of parameter names
-- @param body string The function body (Lua code or WLS script)
function ModulesRuntime:define_function(name, params, body)
    if not name or name == "" then
        error("Function name cannot be empty")
    end

    -- Qualify with current namespace
    local qualified_name = name
    local ns = self:current_namespace()
    if ns ~= "" then
        qualified_name = ns .. "." .. name
    end

    self.functions[qualified_name] = {
        name = name,
        qualified_name = qualified_name,
        params = params or {},
        body = body or "",
        namespace = ns
    }

    return qualified_name
end

--- Check if a function exists
-- @param name string The function name (may be qualified)
-- @return boolean
function ModulesRuntime:has_function(name)
    local resolved = self:resolve_name(name)
    return self.functions[resolved] ~= nil
end

--- Get a function definition
-- @param name string The function name (may be qualified)
-- @return table|nil The function definition
function ModulesRuntime:get_function(name)
    local resolved = self:resolve_name(name)
    return self.functions[resolved]
end

--- Call a function
-- @param name string The function name
-- @param args table Array of argument values
-- @return any The function result
function ModulesRuntime:call_function(name, args)
    local func_def = self:get_function(name)
    if not func_def then
        error("Undefined function: " .. tostring(name))
    end

    args = args or {}

    -- Save current variable state for scoping
    local saved_vars = {}
    for i, param_name in ipairs(func_def.params) do
        -- Save existing variable value if any
        if self.game_state then
            saved_vars[param_name] = self.game_state:get_variable(param_name)
            -- Set parameter value
            self.game_state:set_variable(param_name, args[i])
        end
    end

    -- Execute function body
    local result = nil
    local body = func_def.body

    if body and body ~= "" then
        -- Check if body is Lua code or WLS script
        if string.find(body, "^%s*return%s") or string.find(body, "^%s*local%s") then
            -- Lua code: compile and execute with parameter environment
            -- Build parameter assignments
            local param_assigns = {}
            for i, param_name in ipairs(func_def.params) do
                local value = args[i]
                if type(value) == "string" then
                    table.insert(param_assigns, "local " .. param_name .. " = " .. string.format("%q", value))
                elseif type(value) == "number" then
                    table.insert(param_assigns, "local " .. param_name .. " = " .. tostring(value))
                elseif type(value) == "boolean" then
                    table.insert(param_assigns, "local " .. param_name .. " = " .. tostring(value))
                elseif value == nil then
                    table.insert(param_assigns, "local " .. param_name .. " = nil")
                else
                    -- For tables and other types, skip (complex serialization needed)
                    table.insert(param_assigns, "local " .. param_name .. " = nil")
                end
            end

            local full_code = table.concat(param_assigns, "\n") .. "\n" .. body
            local chunk, err = loadstring(full_code)
            if chunk then
                local ok, res = pcall(chunk)
                if ok then
                    result = res
                else
                    error("Function execution error: " .. tostring(res))
                end
            else
                error("Function compilation error: " .. tostring(err))
            end
        else
            -- WLS expression: evaluate with game state
            if self.game_state and self.game_state.evaluate_expression then
                result = self.game_state:evaluate_expression(body)
            else
                -- Simple return of body as string
                result = body
            end
        end
    end

    -- Restore saved variables
    for param_name, old_value in pairs(saved_vars) do
        if self.game_state then
            if old_value ~= nil then
                self.game_state:set_variable(param_name, old_value)
            else
                -- Clear parameter (was not defined before)
                self.game_state:set_variable(param_name, nil)
            end
        end
    end

    return result
end

--- List all defined functions
-- @param namespace string|nil Optional namespace filter
-- @return table Array of function names
function ModulesRuntime:list_functions(namespace)
    local result = {}
    for name, func_def in pairs(self.functions) do
        if not namespace or func_def.namespace == namespace then
            table.insert(result, name)
        end
    end
    table.sort(result)
    return result
end

--- Clear a function definition
-- @param name string The function name
-- @return boolean True if function was removed
function ModulesRuntime:remove_function(name)
    local resolved = self:resolve_name(name)
    if self.functions[resolved] then
        self.functions[resolved] = nil
        return true
    end
    return false
end

--- Mark a file as included
-- @param path string The file path
-- @return boolean True if not already included (safe to include)
function ModulesRuntime:mark_included(path)
    if self.included_files[path] then
        return false  -- Already included
    end
    self.included_files[path] = true
    return true
end

--- Check if a file has been included
-- @param path string The file path
-- @return boolean
function ModulesRuntime:is_included(path)
    return self.included_files[path] == true
end

--- Reset the runtime state
function ModulesRuntime:reset()
    self.functions = {}
    self.namespace_stack = {}
    self.included_files = {}
end

--- Load functions from a story's function definitions
-- @param story table The story object with functions table
function ModulesRuntime:load_from_story(story)
    if not story or not story.functions then
        return
    end

    for name, func_def in pairs(story.functions) do
        if type(func_def) == "table" then
            self:define_function(
                func_def.name or name,
                func_def.params,
                func_def.body
            )
        end
    end
end

return ModulesRuntime
