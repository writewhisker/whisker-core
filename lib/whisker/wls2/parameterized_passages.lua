--- Parameterized Passages Manager for WLS 2.0
--- Supports passages that accept parameters for reusable content
--- @module whisker.wls2.parameterized_passages

local ParameterizedPassages = {
    _VERSION = "2.0.0"
}
ParameterizedPassages.__index = ParameterizedPassages
ParameterizedPassages._dependencies = {}

--- Parse a passage header with parameters
--- @param header string The header (e.g., "Describe(item, quality = \"normal\")")
--- @return table Parsed header with name and params
function ParameterizedPassages.parsePassageHeader(header)
    if type(header) ~= "string" or header == "" then
        error("Header must be a non-empty string")
    end

    -- Check for parameterized format: Name(params)
    local name, params_str = header:match("^([%w_]+)%((.*)%)$")

    if not name then
        -- No parameters - check if it's a valid identifier
        name = header:match("^[%w_]+$")
        if not name then
            error("Invalid passage header: " .. header)
        end
        return {
            name = name,
            params = {}
        }
    end

    local params = {}

    if params_str and params_str ~= "" then
        -- Parse parameters: name, name = "default", name = 123
        local i = 1
        local len = #params_str

        while i <= len do
            -- Skip whitespace and commas
            while i <= len and params_str:sub(i, i):match("[%s,]") do
                i = i + 1
            end

            if i > len then break end

            -- Read parameter name
            local param_start = i
            while i <= len and params_str:sub(i, i):match("[%w_]") do
                i = i + 1
            end
            local param_name = params_str:sub(param_start, i - 1)

            if param_name == "" then
                break
            end

            -- Skip whitespace
            while i <= len and params_str:sub(i, i):match("%s") do
                i = i + 1
            end

            local default_value = nil

            -- Check for default value
            if i <= len and params_str:sub(i, i) == "=" then
                i = i + 1

                -- Skip whitespace
                while i <= len and params_str:sub(i, i):match("%s") do
                    i = i + 1
                end

                -- Parse default value
                local char = params_str:sub(i, i)

                if char == '"' or char == "'" then
                    -- String literal
                    local quote = char
                    i = i + 1
                    local str_start = i
                    while i <= len and params_str:sub(i, i) ~= quote do
                        i = i + 1
                    end
                    default_value = params_str:sub(str_start, i - 1)
                    i = i + 1  -- Skip closing quote
                elseif char:match("[%d%-]") then
                    -- Number literal
                    local num_start = i
                    while i <= len and params_str:sub(i, i):match("[%d%.%-]") do
                        i = i + 1
                    end
                    default_value = tonumber(params_str:sub(num_start, i - 1))
                elseif params_str:sub(i, i + 3) == "true" then
                    default_value = true
                    i = i + 4
                elseif params_str:sub(i, i + 4) == "false" then
                    default_value = false
                    i = i + 5
                end
            end

            table.insert(params, {
                name = param_name,
                default = default_value
            })
        end
    end

    return {
        name = name,
        params = params
    }
end

--- Parse a passage call with arguments
--- @param call string The call (e.g., "Describe(\"sword\", \"excellent\")")
--- @return table Parsed call with target and args
function ParameterizedPassages.parsePassageCall(call)
    if type(call) ~= "string" or call == "" then
        error("Call must be a non-empty string")
    end

    -- Check for call format: Name(args)
    local target, args_str = call:match("^([%w_]+)%((.*)%)$")

    if not target then
        -- No arguments - just passage name
        target = call:match("^[%w_]+$")
        if not target then
            error("Invalid passage call: " .. call)
        end
        return {
            target = target,
            args = {}
        }
    end

    local args = {}

    if args_str and args_str ~= "" then
        -- Parse arguments
        local i = 1
        local len = #args_str

        while i <= len do
            -- Skip whitespace and commas
            while i <= len and args_str:sub(i, i):match("[%s,]") do
                i = i + 1
            end

            if i > len then break end

            local char = args_str:sub(i, i)

            if char == '"' or char == "'" then
                -- String literal
                local quote = char
                i = i + 1
                local str_start = i
                while i <= len and args_str:sub(i, i) ~= quote do
                    i = i + 1
                end
                table.insert(args, args_str:sub(str_start, i - 1))
                i = i + 1  -- Skip closing quote
            elseif char:match("[%d%-]") then
                -- Number literal
                local num_start = i
                while i <= len and args_str:sub(i, i):match("[%d%.%-]") do
                    i = i + 1
                end
                table.insert(args, tonumber(args_str:sub(num_start, i - 1)))
            elseif args_str:sub(i, i + 3) == "true" then
                table.insert(args, true)
                i = i + 4
            elseif args_str:sub(i, i + 4) == "false" then
                table.insert(args, false)
                i = i + 5
            elseif char == "$" then
                -- Variable reference - store as special table
                i = i + 1
                local var_start = i
                while i <= len and args_str:sub(i, i):match("[%w_]") do
                    i = i + 1
                end
                table.insert(args, {
                    _type = "variable_ref",
                    name = args_str:sub(var_start, i - 1)
                })
            else
                -- Identifier or expression - skip until comma or end
                local expr_start = i
                local paren_depth = 0
                while i <= len do
                    local c = args_str:sub(i, i)
                    if c == "(" then
                        paren_depth = paren_depth + 1
                    elseif c == ")" then
                        if paren_depth == 0 then break end
                        paren_depth = paren_depth - 1
                    elseif c == "," and paren_depth == 0 then
                        break
                    end
                    i = i + 1
                end
                local expr = args_str:sub(expr_start, i - 1):match("^%s*(.-)%s*$")
                if expr ~= "" then
                    table.insert(args, {
                        _type = "expression",
                        expr = expr
                    })
                end
            end
        end
    end

    return {
        target = target,
        args = args
    }
end

--- Create a new ParameterizedPassages manager
--- @param deps table Optional dependencies
--- @return ParameterizedPassages The new manager instance
function ParameterizedPassages.new(deps)
    local self = setmetatable({}, ParameterizedPassages)
    self._passages = {}  -- name -> { params = [...] }
    self._deps = deps or {}
    return self
end

--- Register a parameterized passage
--- @param name string The passage name
--- @param params table Array of parameter definitions
function ParameterizedPassages:registerPassage(name, params)
    if type(name) ~= "string" or name == "" then
        error("Passage name must be a non-empty string")
    end

    self._passages[name] = {
        params = params or {}
    }
end

--- Check if a passage is registered
--- @param name string The passage name
--- @return boolean True if registered
function ParameterizedPassages:hasPassage(name)
    return self._passages[name] ~= nil
end

--- Get a passage's parameter definitions
--- @param name string The passage name
--- @return table|nil The parameter definitions or nil
function ParameterizedPassages:getPassageParams(name)
    local passage = self._passages[name]
    if passage then
        return passage.params
    end
    return nil
end

--- Bind arguments to a passage's parameters
--- @param passageName string The passage name
--- @param args table The arguments to bind
--- @return table Result with bindings and resolved passage name
function ParameterizedPassages:bindArguments(passageName, args)
    local passage = self._passages[passageName]
    args = args or {}

    local bindings = {}

    if passage then
        local params = passage.params

        for i, param in ipairs(params) do
            local arg = args[i]

            if arg ~= nil then
                bindings[param.name] = arg
            elseif param.default ~= nil then
                bindings[param.name] = param.default
            else
                error(string.format(
                    "Missing required argument '%s' for passage '%s'",
                    param.name, passageName
                ))
            end
        end

        -- Check for extra arguments
        if #args > #params then
            error(string.format(
                "Too many arguments for passage '%s': expected %d, got %d",
                passageName, #params, #args
            ))
        end
    end

    return {
        passageName = passageName,
        bindings = bindings
    }
end

--- Create a variable scope from bindings
--- @param bindings table Map of parameter names to values
--- @return table Variable scope object
function ParameterizedPassages:createVariableScope(bindings)
    local scope = {}

    if type(bindings) == "table" then
        for name, value in pairs(bindings) do
            scope[name] = value
        end
    end

    return scope
end

--- Resolve variable references in arguments
--- @param args table Arguments that may contain variable refs
--- @param variables table Current variable state
--- @return table Resolved arguments
function ParameterizedPassages:resolveVariables(args, variables)
    local resolved = {}
    variables = variables or {}

    for i, arg in ipairs(args) do
        if type(arg) == "table" and arg._type == "variable_ref" then
            resolved[i] = variables[arg.name]
        elseif type(arg) == "table" and arg._type == "expression" then
            -- Expression evaluation would be handled by the runtime
            resolved[i] = arg
        else
            resolved[i] = arg
        end
    end

    return resolved
end

--- Get all registered passage names
--- @return table Array of passage names
function ParameterizedPassages:getRegisteredNames()
    local names = {}
    for name in pairs(self._passages) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- Clear all registered passages
function ParameterizedPassages:clear()
    self._passages = {}
end

return ParameterizedPassages
