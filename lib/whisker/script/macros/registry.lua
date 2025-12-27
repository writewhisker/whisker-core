-- Whisker Macro Registry
-- Central registry for managing macros (Twine/Ink compatible)
-- Supports Harlowe, SugarCube, Chapbook, and Ink macro styles
--
-- lib/whisker/script/macros/registry.lua

local MacroRegistry = {}
MacroRegistry.__index = MacroRegistry

-- Dependencies for DI pattern
MacroRegistry._dependencies = { "event_bus" }

-- Macro categories for organization
MacroRegistry.CATEGORY = {
    CONTROL = "control",       -- if, for, while, switch
    DATA = "data",             -- set, put, unset, arrays, datamaps
    TEXT = "text",             -- print, display, append, replace
    LINK = "link",             -- link, goto, link-goto, back
    UI = "ui",                 -- dialog, prompt, confirm
    AUDIO = "audio",           -- audio, playlist (for clients that support it)
    LIFECYCLE = "lifecycle",   -- live, event, after
    UTILITY = "utility",       -- random, either, time, date
    CUSTOM = "custom",         -- user-defined macros
}

-- Macro source format identifiers
MacroRegistry.FORMAT = {
    HARLOWE = "harlowe",       -- (macro:)
    SUGARCUBE = "sugarcube",   -- <<macro>>
    CHAPBOOK = "chapbook",     -- [modifier] and {insert}
    INK = "ink",               -- {macro} and stitches
    WHISKER = "whisker",       -- @macro or native
}

--- Create a new MacroRegistry via DI container
-- @param deps table Dependencies from container
-- @return MacroRegistry instance
function MacroRegistry.create(deps)
    return MacroRegistry.new(deps)
end

--- Create a new MacroRegistry instance
-- @param deps table Optional dependencies (event_bus)
-- @return MacroRegistry instance
function MacroRegistry.new(deps)
    deps = deps or {}
    local self = setmetatable({}, MacroRegistry)

    self._event_bus = deps.event_bus
    self._macros = {}           -- name -> macro definition
    self._aliases = {}          -- alias -> canonical name
    self._categories = {}       -- category -> {names}
    self._formats = {}          -- format -> {names}
    self._disabled = {}         -- name -> true (disabled macros)
    self._hooks = {
        before_register = {},
        after_register = {},
        before_execute = {},
        after_execute = {},
    }

    return self
end

-- ============================================================================
-- Macro Registration
-- ============================================================================

--- Register a new macro
-- @param name string The macro name
-- @param definition table Macro definition
-- @return boolean, string Success and optional error message
function MacroRegistry:register(name, definition)
    if type(name) ~= "string" or name == "" then
        return false, "Macro name must be a non-empty string"
    end

    if self._macros[name] then
        return false, "Macro '" .. name .. "' is already registered"
    end

    -- Validate definition
    local valid, err = self:_validate_definition(definition)
    if not valid then
        return false, err
    end

    -- Run before_register hooks
    for _, hook in ipairs(self._hooks.before_register) do
        local continue, hook_err = hook.fn(name, definition)
        if continue == false then
            return false, hook_err or "Registration blocked by hook"
        end
    end

    -- Store macro with normalized definition
    local macro = {
        name = name,
        handler = definition.handler,
        signature = definition.signature,
        category = definition.category or MacroRegistry.CATEGORY.CUSTOM,
        format = definition.format or MacroRegistry.FORMAT.WHISKER,
        description = definition.description or "",
        examples = definition.examples or {},
        deprecated = definition.deprecated,
        replacement = definition.replacement,
        async = definition.async or false,
        pure = definition.pure or false,
        registered_at = os.time(),
    }

    self._macros[name] = macro

    -- Index by category
    if not self._categories[macro.category] then
        self._categories[macro.category] = {}
    end
    table.insert(self._categories[macro.category], name)

    -- Index by format
    if not self._formats[macro.format] then
        self._formats[macro.format] = {}
    end
    table.insert(self._formats[macro.format], name)

    -- Register aliases
    if definition.aliases then
        for _, alias in ipairs(definition.aliases) do
            self._aliases[alias] = name
        end
    end

    -- Run after_register hooks
    for _, hook in ipairs(self._hooks.after_register) do
        hook.fn(name, macro)
    end

    -- Emit registration event
    self:_emit_event("MACRO_REGISTERED", {
        name = name,
        category = macro.category,
        format = macro.format,
    })

    return true, nil
end

--- Register multiple macros at once
-- @param macros table Map of name -> definition
-- @return number, table Number registered and list of errors
function MacroRegistry:register_all(macros)
    local count = 0
    local errors = {}

    for name, definition in pairs(macros) do
        local ok, err = self:register(name, definition)
        if ok then
            count = count + 1
        else
            table.insert(errors, { name = name, error = err })
        end
    end

    return count, errors
end

--- Unregister a macro
-- @param name string The macro name
-- @return boolean Success
function MacroRegistry:unregister(name)
    local macro = self._macros[name]
    if not macro then
        return false
    end

    -- Remove from category index
    if self._categories[macro.category] then
        for i, n in ipairs(self._categories[macro.category]) do
            if n == name then
                table.remove(self._categories[macro.category], i)
                break
            end
        end
    end

    -- Remove from format index
    if self._formats[macro.format] then
        for i, n in ipairs(self._formats[macro.format]) do
            if n == name then
                table.remove(self._formats[macro.format], i)
                break
            end
        end
    end

    -- Remove aliases
    for alias, target in pairs(self._aliases) do
        if target == name then
            self._aliases[alias] = nil
        end
    end

    -- Remove macro
    self._macros[name] = nil
    self._disabled[name] = nil

    -- Emit unregistration event
    self:_emit_event("MACRO_UNREGISTERED", { name = name })

    return true
end

-- ============================================================================
-- Macro Lookup
-- ============================================================================

--- Get a macro by name (resolves aliases)
-- @param name string The macro name or alias
-- @return table|nil The macro definition or nil
function MacroRegistry:get(name)
    -- Resolve alias
    local canonical = self._aliases[name] or name
    return self._macros[canonical]
end

--- Check if a macro exists
-- @param name string The macro name or alias
-- @return boolean
function MacroRegistry:exists(name)
    return self:get(name) ~= nil
end

--- Get all registered macro names
-- @return table Array of macro names
function MacroRegistry:get_all_names()
    local names = {}
    for name in pairs(self._macros) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- Get all macros in a category
-- @param category string The category
-- @return table Array of macro names
function MacroRegistry:get_by_category(category)
    return self._categories[category] or {}
end

--- Get all macros for a format
-- @param format string The format (harlowe, sugarcube, etc.)
-- @return table Array of macro names
function MacroRegistry:get_by_format(format)
    return self._formats[format] or {}
end

--- Get macro handler
-- @param name string The macro name or alias
-- @return function|nil The handler function or nil
function MacroRegistry:get_handler(name)
    local macro = self:get(name)
    if macro and not self:is_disabled(name) then
        return macro.handler
    end
    return nil
end

--- Get macro signature
-- @param name string The macro name or alias
-- @return table|nil The signature or nil
function MacroRegistry:get_signature(name)
    local macro = self:get(name)
    if macro then
        return macro.signature
    end
    return nil
end

-- ============================================================================
-- Macro State Management
-- ============================================================================

--- Disable a macro
-- @param name string The macro name
-- @return boolean Success
function MacroRegistry:disable(name)
    if not self:exists(name) then
        return false
    end
    local canonical = self._aliases[name] or name
    self._disabled[canonical] = true

    self:_emit_event("MACRO_DISABLED", { name = canonical })
    return true
end

--- Enable a macro
-- @param name string The macro name
-- @return boolean Success
function MacroRegistry:enable(name)
    if not self:exists(name) then
        return false
    end
    local canonical = self._aliases[name] or name
    self._disabled[canonical] = nil

    self:_emit_event("MACRO_ENABLED", { name = canonical })
    return true
end

--- Check if macro is disabled
-- @param name string The macro name
-- @return boolean
function MacroRegistry:is_disabled(name)
    local canonical = self._aliases[name] or name
    return self._disabled[canonical] == true
end

--- Check if macro is deprecated
-- @param name string The macro name
-- @return boolean, string|nil Is deprecated and replacement if any
function MacroRegistry:is_deprecated(name)
    local macro = self:get(name)
    if macro and macro.deprecated then
        return true, macro.replacement
    end
    return false, nil
end

-- ============================================================================
-- Hooks Management
-- ============================================================================

--- Add a hook
-- @param hook_type string Type: before_register, after_register, before_execute, after_execute
-- @param callback function The hook function
-- @return string Hook ID for removal
function MacroRegistry:add_hook(hook_type, callback)
    if not self._hooks[hook_type] then
        error("Invalid hook type: " .. tostring(hook_type))
    end

    local id = string.format("hook_%d_%d", os.time(), math.random(10000, 99999))
    table.insert(self._hooks[hook_type], { id = id, fn = callback })
    return id
end

--- Remove a hook
-- @param hook_type string The hook type
-- @param hook_id string The hook ID
-- @return boolean Success
function MacroRegistry:remove_hook(hook_type, hook_id)
    if not self._hooks[hook_type] then
        return false
    end

    for i, hook in ipairs(self._hooks[hook_type]) do
        if hook.id == hook_id then
            table.remove(self._hooks[hook_type], i)
            return true
        end
    end
    return false
end

-- ============================================================================
-- Execution Support
-- ============================================================================

--- Execute a macro by name
-- @param name string The macro name
-- @param context table The execution context
-- @param args table The arguments
-- @return any, string Result and optional error
function MacroRegistry:execute(name, context, args)
    local macro = self:get(name)
    if not macro then
        return nil, "Unknown macro: " .. tostring(name)
    end

    if self:is_disabled(name) then
        return nil, "Macro is disabled: " .. name
    end

    -- Check deprecation
    local deprecated, replacement = self:is_deprecated(name)
    if deprecated then
        self:_emit_event("MACRO_DEPRECATION_WARNING", {
            name = name,
            replacement = replacement,
        })
    end

    -- Run before_execute hooks
    for _, hook in ipairs(self._hooks.before_execute) do
        local continue, hook_err = hook.fn(name, context, args)
        if continue == false then
            return nil, hook_err or "Execution blocked by hook"
        end
    end

    -- Execute handler
    local success, result = pcall(macro.handler, context, args)

    if not success then
        self:_emit_event("MACRO_ERROR", {
            name = name,
            error = result,
        })
        return nil, "Macro error: " .. tostring(result)
    end

    -- Run after_execute hooks
    for _, hook in ipairs(self._hooks.after_execute) do
        hook.fn(name, context, args, result)
    end

    return result, nil
end

-- ============================================================================
-- Alias Management
-- ============================================================================

--- Add an alias for a macro
-- @param alias string The alias name
-- @param target string The target macro name
-- @return boolean, string Success and optional error
function MacroRegistry:add_alias(alias, target)
    if not self:exists(target) then
        return false, "Target macro does not exist: " .. target
    end
    if self._aliases[alias] then
        return false, "Alias already exists: " .. alias
    end
    if self._macros[alias] then
        return false, "A macro with this name already exists: " .. alias
    end

    self._aliases[alias] = target
    return true, nil
end

--- Remove an alias
-- @param alias string The alias to remove
-- @return boolean Success
function MacroRegistry:remove_alias(alias)
    if self._aliases[alias] then
        self._aliases[alias] = nil
        return true
    end
    return false
end

--- Get all aliases for a macro
-- @param name string The macro name
-- @return table Array of aliases
function MacroRegistry:get_aliases(name)
    local aliases = {}
    for alias, target in pairs(self._aliases) do
        if target == name then
            table.insert(aliases, alias)
        end
    end
    return aliases
end

--- Resolve an alias to canonical name
-- @param name string The name or alias
-- @return string The canonical name
function MacroRegistry:resolve_alias(name)
    return self._aliases[name] or name
end

-- ============================================================================
-- Statistics and Debugging
-- ============================================================================

--- Get registry statistics
-- @return table Statistics
function MacroRegistry:get_stats()
    local category_counts = {}
    for category, names in pairs(self._categories) do
        category_counts[category] = #names
    end

    local format_counts = {}
    for format, names in pairs(self._formats) do
        format_counts[format] = #names
    end

    local disabled_count = 0
    for _ in pairs(self._disabled) do
        disabled_count = disabled_count + 1
    end

    local alias_count = 0
    for _ in pairs(self._aliases) do
        alias_count = alias_count + 1
    end

    return {
        total_macros = self:count(),
        categories = category_counts,
        formats = format_counts,
        disabled = disabled_count,
        aliases = alias_count,
    }
end

--- Get count of registered macros
-- @return number
function MacroRegistry:count()
    local count = 0
    for _ in pairs(self._macros) do
        count = count + 1
    end
    return count
end

--- Export all macros for debugging
-- @return table Map of name -> macro info
function MacroRegistry:export()
    local result = {}
    for name, macro in pairs(self._macros) do
        result[name] = {
            name = macro.name,
            category = macro.category,
            format = macro.format,
            description = macro.description,
            deprecated = macro.deprecated,
            replacement = macro.replacement,
            async = macro.async,
            pure = macro.pure,
            aliases = self:get_aliases(name),
            disabled = self:is_disabled(name),
        }
    end
    return result
end

--- Clear all registrations
function MacroRegistry:clear()
    self._macros = {}
    self._aliases = {}
    self._categories = {}
    self._formats = {}
    self._disabled = {}
end

-- ============================================================================
-- Internal Helpers
-- ============================================================================

--- Validate a macro definition
-- @param definition table The definition to validate
-- @return boolean, string Success and optional error
function MacroRegistry:_validate_definition(definition)
    if type(definition) ~= "table" then
        return false, "Definition must be a table"
    end

    if type(definition.handler) ~= "function" then
        return false, "Definition must have a handler function"
    end

    if definition.category and not self:_is_valid_category(definition.category) then
        return false, "Invalid category: " .. tostring(definition.category)
    end

    if definition.format and not self:_is_valid_format(definition.format) then
        return false, "Invalid format: " .. tostring(definition.format)
    end

    if definition.aliases and type(definition.aliases) ~= "table" then
        return false, "Aliases must be a table"
    end

    if definition.examples and type(definition.examples) ~= "table" then
        return false, "Examples must be a table"
    end

    return true, nil
end

--- Check if category is valid
-- @param category string The category
-- @return boolean
function MacroRegistry:_is_valid_category(category)
    for _, v in pairs(MacroRegistry.CATEGORY) do
        if v == category then
            return true
        end
    end
    return false
end

--- Check if format is valid
-- @param format string The format
-- @return boolean
function MacroRegistry:_is_valid_format(format)
    for _, v in pairs(MacroRegistry.FORMAT) do
        if v == format then
            return true
        end
    end
    return false
end

--- Emit an event
-- @param event_type string The event type
-- @param data table Event data
function MacroRegistry:_emit_event(event_type, data)
    if self._event_bus then
        self._event_bus:emit(event_type, data)
    end
end

return MacroRegistry
