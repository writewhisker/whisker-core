-- lib/whisker/core/modules_runtime.lua
-- WLS 1.0 Modules Runtime: FUNCTION and NAMESPACE execution support
-- Implements GAP-004 (include path resolution), GAP-005 (circular detection),
-- GAP-044 (function recursion), GAP-045 (qualified names), GAP-046 (nested namespaces)

-- Compatibility: loadstring was renamed to load in Lua 5.2+
local loadstring = loadstring or load

local ModulesRuntime = {}
ModulesRuntime.__index = ModulesRuntime

-- Dependencies for DI pattern
ModulesRuntime._dependencies = {
    PathResolver = "whisker.core.path_resolver"
}

-- Maximum include depth to prevent stack overflow
ModulesRuntime.MAX_INCLUDE_DEPTH = 50

-- Maximum recursion depth for function calls (GAP-044)
ModulesRuntime.MAX_RECURSION_DEPTH = 100

-- Error codes for module-related errors (WLS spec)
ModulesRuntime.ERROR_CODES = {
    CIRCULAR_INCLUDE = "WLS-MOD-001",
    INCLUDE_NOT_FOUND = "WLS-MOD-002",
    INCLUDE_PARSE_ERROR = "WLS-MOD-003",
    MAX_DEPTH_EXCEEDED = "WLS-MOD-004",
    -- GAP-044: Recursion errors
    RECURSION_LIMIT = "WLS-REC-001",
    INFINITE_RECURSION = "WLS-REC-002"
}

--- Create a new ModulesRuntime instance
-- @param game_state table The game state for variable access
-- @param config table|nil Optional configuration (project_root, search_paths)
-- @return ModulesRuntime
function ModulesRuntime.new(game_state, config, deps)
    config = config or {}
    deps = deps or {}

    -- Use injected PathResolver or lazy load to avoid circular dependency
    local PathResolver = deps.PathResolver or require("whisker.core.path_resolver")

    local instance = {
        -- Function registry: name -> { params = {...}, body = "..." }
        functions = {},
        -- Namespace stack for scoping
        namespace_stack = {},
        -- Namespace registry for nested namespaces (GAP-046)
        namespaces = {},
        -- All passages indexed by qualified name (GAP-045)
        all_passages = {},
        -- All functions indexed by qualified name (GAP-045)
        all_functions = {},
        -- Reference to game state for variable operations
        game_state = game_state,
        -- Included file tracking (prevent circular includes)
        included_files = {},
        -- Loaded module cache
        loaded_modules = {},
        -- Path resolver for include resolution
        resolver = PathResolver.new({
            project_root = config.project_root or ".",
            search_paths = config.search_paths or {}
        }),
        -- Parser factory (can be injected for testing)
        parser_factory = config.parser_factory,
        -- GAP-044: Call stack for recursion tracking
        call_stack = {},
        -- Configurable recursion depth limit
        max_recursion_depth = config.max_recursion_depth or ModulesRuntime.MAX_RECURSION_DEPTH
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

--- GAP-046: Register a namespace with its contents
-- @param namespace table Namespace definition with name, passages, functions, nested_namespaces
function ModulesRuntime:register_namespace_tree(namespace)
    if not namespace or not namespace.full_name then
        return
    end

    -- Register this namespace
    self.namespaces[namespace.full_name] = namespace

    -- Register all passages with qualified names
    for name, passage in pairs(namespace.passages or {}) do
        local qualified = namespace.full_name .. "." .. name
        self.all_passages[qualified] = passage
        passage.qualified_name = qualified
    end

    -- Register all functions with qualified names
    for name, func in pairs(namespace.functions or {}) do
        local qualified = namespace.full_name .. "." .. name
        self.all_functions[qualified] = func
        -- Also register in main functions table
        self.functions[qualified] = func
    end

    -- Recursively register nested namespaces
    for _, nested in pairs(namespace.nested_namespaces or {}) do
        self:register_namespace_tree(nested)
    end
end

--- GAP-045: Parse a qualified name into parts
-- @param name string The qualified name (e.g., "Namespace.SubNamespace.name")
-- @return table A table with parts array, full_name, namespace, and name
function ModulesRuntime:parse_qualified_name(name)
    if not name or name == "" then
        return nil
    end

    local parts = {}
    for part in name:gmatch("([%w_]+)") do
        table.insert(parts, part)
    end

    if #parts == 0 then
        return nil
    end

    return {
        parts = parts,
        full_name = name,
        namespace = #parts > 1 and table.concat(parts, ".", 1, #parts - 1) or "",
        name = parts[#parts]
    }
end

--- GAP-045: Resolve a qualified name to its target
-- @param qualified_name table|string The qualified name (parsed or string)
-- @param type_hint string|nil "passage", "function", or nil for any
-- @return table|nil The resolved target
-- @return string|nil Error message if not found
function ModulesRuntime:resolve_qualified_name(qualified_name, type_hint)
    -- Parse if string
    if type(qualified_name) == "string" then
        qualified_name = self:parse_qualified_name(qualified_name)
        if not qualified_name then
            return nil, "Invalid qualified name"
        end
    end

    local parts = qualified_name.parts
    local current = self.namespaces

    -- Navigate through namespace hierarchy
    for i = 1, #parts - 1 do
        local part = parts[i]
        -- Build partial qualified name
        local partial_name = table.concat(parts, ".", 1, i)
        if current[partial_name] then
            current = current[partial_name]
        elseif current[part] then
            current = current[part]
        else
            return nil, "Namespace not found: " .. part
        end
    end

    -- Look up final name
    local final_name = parts[#parts]
    local full_qualified = qualified_name.full_name

    if type_hint == "passage" then
        return self.all_passages[full_qualified] or
               (current and current.passages and current.passages[final_name])
    elseif type_hint == "function" then
        return self.all_functions[full_qualified] or
               self.functions[full_qualified] or
               (current and current.functions and current.functions[final_name])
    else
        -- Try both
        return self.all_passages[full_qualified] or
               self.all_functions[full_qualified] or
               self.functions[full_qualified] or
               (current and current.passages and current.passages[final_name]) or
               (current and current.functions and current.functions[final_name])
    end
end

--- GAP-045/046: Resolve a name in the context of the current namespace
-- Tries: qualified name, current namespace, parent namespaces, then global
-- @param name string The name to resolve
-- @param type_hint string|nil "passage", "function", or nil for any
-- @return table|nil The resolved target
function ModulesRuntime:resolve_in_context(name, type_hint)
    if not name or name == "" then
        return nil
    end

    -- 1. Try as fully qualified name first
    if name:find("%.") then
        local result = self:resolve_qualified_name(name, type_hint)
        if result then
            return result
        end
    end

    -- 2. Try current namespace
    local current_ns = self:current_namespace()
    if current_ns ~= "" then
        local qualified = current_ns .. "." .. name
        local result = self:resolve_qualified_name(qualified, type_hint)
        if result then
            return result
        end

        -- 3. Try parent namespaces
        local ns = current_ns
        while ns:find("%.") do
            ns = ns:match("(.+)%.[^%.]+$")  -- Remove last segment
            qualified = ns .. "." .. name
            result = self:resolve_qualified_name(qualified, type_hint)
            if result then
                return result
            end
        end
    end

    -- 4. Fall back to global/unqualified
    if type_hint == "passage" then
        return self.all_passages[name]
    elseif type_hint == "function" then
        return self.functions[name]
    else
        return self.all_passages[name] or self.functions[name]
    end
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

--- GAP-044: Push a call frame onto the call stack
-- @param func_name string The function name being called
-- @param args table The arguments passed
-- @return nil
-- @error If recursion limit is exceeded
function ModulesRuntime:push_call(func_name, args)
    if #self.call_stack >= self.max_recursion_depth then
        local stack_trace = self:format_stack_trace()
        error(string.format(
            "%s: Maximum recursion depth (%d) exceeded in function '%s'\n%s",
            self.ERROR_CODES.RECURSION_LIMIT,
            self.max_recursion_depth,
            func_name,
            stack_trace
        ))
    end

    table.insert(self.call_stack, {
        name = func_name,
        args = args,
        depth = #self.call_stack + 1,
        time = os.clock()
    })
end

--- GAP-044: Pop the current call frame from the stack
-- @return table|nil The popped call frame
function ModulesRuntime:pop_call()
    return table.remove(self.call_stack)
end

--- GAP-044: Get the current call stack depth
-- @return number The current recursion depth
function ModulesRuntime:get_call_depth()
    return #self.call_stack
end

--- GAP-044: Format a stack trace for error reporting
-- @param max_frames number|nil Maximum frames to show (default: 10)
-- @return string The formatted stack trace
function ModulesRuntime:format_stack_trace(max_frames)
    max_frames = max_frames or 10
    local lines = { "Call stack:" }
    local start_frame = math.max(1, #self.call_stack - max_frames + 1)

    for i = #self.call_stack, start_frame, -1 do
        local frame = self.call_stack[i]
        table.insert(lines, string.format(
            "  %d: %s(%s)",
            frame.depth,
            frame.name,
            self:format_args(frame.args)
        ))
    end

    if #self.call_stack > max_frames then
        table.insert(lines, string.format("  ... (%d more frames)", #self.call_stack - max_frames))
    end

    return table.concat(lines, "\n")
end

--- GAP-044: Format function arguments for display
-- @param args table The arguments to format
-- @return string The formatted arguments
function ModulesRuntime:format_args(args)
    local parts = {}
    for _, arg in ipairs(args or {}) do
        local str = tostring(arg)
        if #str > 20 then
            str = str:sub(1, 17) .. "..."
        end
        table.insert(parts, str)
    end
    return table.concat(parts, ", ")
end

--- GAP-044: Set the maximum recursion depth
-- @param depth number The maximum recursion depth
function ModulesRuntime:set_max_recursion_depth(depth)
    self.max_recursion_depth = depth or self.MAX_RECURSION_DEPTH
end

--- GAP-044: Get the maximum recursion depth
-- @return number The maximum recursion depth
function ModulesRuntime:get_max_recursion_depth()
    return self.max_recursion_depth
end

--- Call a function with recursion tracking (GAP-044)
-- @param name string The function name
-- @param args table Array of argument values
-- @return any The function result
function ModulesRuntime:call_function(name, args)
    local func_def = self:get_function(name)
    if not func_def then
        error("Undefined function: " .. tostring(name))
    end

    args = args or {}

    -- GAP-044: Push call frame for recursion tracking
    self:push_call(func_def.qualified_name or name, args)

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

    -- Execute function body with protected call
    local success, result = pcall(function()
        local res = nil
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
                    local ok, exec_res = pcall(chunk)
                    if ok then
                        res = exec_res
                    else
                        error("Function execution error: " .. tostring(exec_res))
                    end
                else
                    error("Function compilation error: " .. tostring(err))
                end
            else
                -- WLS expression: evaluate with game state
                if self.game_state and self.game_state.evaluate_expression then
                    res = self.game_state:evaluate_expression(body)
                else
                    -- Simple return of body as string
                    res = body
                end
            end
        end

        return res
    end)

    -- GAP-044: Pop call frame after execution
    self:pop_call()

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

    if not success then
        error(result)
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
    -- GAP-044/045/046: Reset additional state
    self.call_stack = {}
    self.namespaces = {}
    self.all_passages = {}
    self.all_functions = {}
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

--- Format an error message with location and suggestions
-- @param code string Error code
-- @param message string Error message
-- @param location table|nil Source location
-- @param suggestion string|nil Fix suggestion
-- @param details table|nil Additional details
-- @return string
function ModulesRuntime:format_error(code, message, location, suggestion, details)
    local parts = {code .. ": " .. message}

    if details and details.cycle then
        table.insert(parts, "  Include chain: " .. details.cycle)
    end

    if details and details.chain then
        table.insert(parts, "  Current chain: " .. details.chain)
    end

    if location then
        table.insert(parts, string.format(
            "  Location: %s:%d:%d",
            location.file or "unknown",
            location.line or 0,
            location.column or 0
        ))
    end

    if suggestion then
        table.insert(parts, "  Suggestion: " .. suggestion)
    end

    if details and details.errors then
        for _, err in ipairs(details.errors) do
            table.insert(parts, "    - " .. tostring(err))
        end
    end

    return table.concat(parts, "\n")
end

--- Load an include file with path resolution and cycle detection
-- @param path string Include path from the INCLUDE statement
-- @param from_file string|nil The file containing the INCLUDE
-- @param location table|nil Source location for error reporting
-- @return table|nil content The parsed content
-- @return string|nil error Error message if loading failed
function ModulesRuntime:load_include(path, from_file, location)
    -- Check depth limit first
    if self.resolver:get_include_depth() >= self.MAX_INCLUDE_DEPTH then
        return nil, self:format_error(
            self.ERROR_CODES.MAX_DEPTH_EXCEEDED,
            "Maximum include depth exceeded (" .. self.MAX_INCLUDE_DEPTH .. ")",
            location,
            "Reduce nesting or check for indirect circular includes"
        )
    end

    -- Resolve path
    local resolved, resolve_err = self.resolver:resolve(path, from_file)
    if not resolved then
        return nil, self:format_error(
            self.ERROR_CODES.INCLUDE_NOT_FOUND,
            "Include not found: " .. path,
            location,
            "Check the file path and ensure the file exists",
            { original_error = resolve_err }
        )
    end

    -- Check for circular include
    local is_circular, cycle_desc = self.resolver:push_include(resolved)
    if is_circular then
        return nil, self:format_error(
            self.ERROR_CODES.CIRCULAR_INCLUDE,
            "Circular include detected",
            location,
            "Remove one of the includes to break the cycle",
            {
                cycle = cycle_desc,
                chain = self.resolver:get_include_chain()
            }
        )
    end

    -- Check cache (after cycle check, as cycle is still an error)
    if self.loaded_modules[resolved] then
        self.resolver:pop_include()  -- Pop since we won't recurse
        return self.loaded_modules[resolved]
    end

    -- Load file content
    local file, open_err = io.open(resolved, "r")
    if not file then
        self.resolver:pop_include()
        return nil, self:format_error(
            self.ERROR_CODES.INCLUDE_NOT_FOUND,
            "Cannot open file: " .. resolved,
            location,
            "Check file permissions and path",
            { original_error = open_err }
        )
    end

    local content = file:read("*all")
    file:close()

    -- Parse content
    local parser
    if self.parser_factory then
        -- Use injected parser factory (for testing)
        parser = self.parser_factory()
    else
        -- Use default parser
        local ok, WSParser = pcall(require, "whisker.parser.ws_parser")
        if not ok then
            self.resolver:pop_include()
            return nil, self:format_error(
                self.ERROR_CODES.INCLUDE_PARSE_ERROR,
                "Parser not available",
                location,
                nil
            )
        end
        parser = WSParser.new()
    end

    -- Set context for the parser
    parser.modules_runtime = self
    parser.current_file = resolved

    local result = parser:parse(content)

    -- Pop from stack after parsing (including nested includes)
    self.resolver:pop_include()

    if not result.success then
        return nil, self:format_error(
            self.ERROR_CODES.INCLUDE_PARSE_ERROR,
            "Parse error in " .. path,
            location,
            nil,
            { errors = result.errors }
        )
    end

    -- Cache and return
    self.loaded_modules[resolved] = result.story
    return result.story
end

--- Get the path resolver
-- @return PathResolver
function ModulesRuntime:get_resolver()
    return self.resolver
end

--- Set the project root for path resolution
-- @param root string The project root path
function ModulesRuntime:set_project_root(root)
    self.resolver.project_root = root
end

--- Add a search path for include resolution
-- @param path string The search path to add
function ModulesRuntime:add_search_path(path)
    table.insert(self.resolver.search_paths, path)
end

--- Clear all loaded modules from cache
function ModulesRuntime:clear_module_cache()
    self.loaded_modules = {}
    self.resolver:clear_include_stack()
end

return ModulesRuntime
