-- lib/whisker/core/path_resolver.lua
-- WLS 1.0 Include Path Resolution and Circular Detection
-- Implements GAP-004 (path resolution) and GAP-005 (circular detection)

local PathResolver = {}
PathResolver.__index = PathResolver

--- Create a new PathResolver instance
---@param config table|nil Configuration options
---@return PathResolver
function PathResolver.new(config)
    config = config or {}
    local self = setmetatable({}, PathResolver)
    self.project_root = config.project_root or "."
    self.search_paths = config.search_paths or {}
    self.current_file = nil
    self.include_stack = {}  -- For circular detection
    return self
end

--- Get directory from a file path
---@param path string
---@return string
function PathResolver:get_directory(path)
    if not path then
        return "."
    end
    -- Handle both Unix and Windows separators
    local dir = path:match("(.+)[/\\][^/\\]+$")
    return dir or "."
end

--- Get just the filename from a path
---@param path string
---@return string
function PathResolver:get_filename(path)
    if not path then
        return ""
    end
    return path:match("[^/\\]+$") or path
end

--- Join path components
---@param ... string Path components
---@return string
function PathResolver:join(...)
    local parts = {...}
    local result = table.concat(parts, "/")
    -- Normalize separators
    result = result:gsub("\\", "/")
    -- Remove duplicate slashes
    result = result:gsub("/+", "/")
    return result
end

--- Normalize a path (resolve . and ..)
---@param path string
---@return string
function PathResolver:normalize(path)
    if not path or path == "" then
        return "."
    end

    -- Convert to forward slashes
    path = path:gsub("\\", "/")

    -- Track if path is absolute
    local is_abs = self:is_absolute(path)
    local prefix = ""

    -- Handle Unix absolute paths
    if path:sub(1, 1) == "/" then
        prefix = "/"
        path = path:sub(2)
    -- Handle Windows absolute paths (C:/)
    elseif path:match("^%a:/") then
        prefix = path:sub(1, 3)
        path = path:sub(4)
    end

    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                table.remove(parts)
            elseif not is_abs then
                -- Keep .. for relative paths that go above cwd
                table.insert(parts, part)
            end
            -- For absolute paths, ignore .. that goes above root
        elseif part ~= "." and part ~= "" then
            table.insert(parts, part)
        end
    end

    local result = table.concat(parts, "/")

    -- Restore prefix for absolute paths
    if prefix ~= "" then
        result = prefix .. result
    end

    -- Return "." for empty relative paths
    if result == "" and not is_abs then
        return "."
    end

    return result
end

--- Check if path is absolute
---@param path string
---@return boolean
function PathResolver:is_absolute(path)
    if not path or path == "" then
        return false
    end
    -- Unix absolute
    if path:sub(1, 1) == "/" then
        return true
    end
    -- Windows absolute (C:\, D:\, etc.)
    if path:match("^%a:[\\/]") then
        return true
    end
    return false
end

--- Add .ws extension if not present
---@param path string
---@return string
function PathResolver:ensure_extension(path)
    if not path then
        return path
    end
    if not path:match("%.ws$") then
        return path .. ".ws"
    end
    return path
end

--- Check if a file exists
---@param path string
---@return boolean
function PathResolver:file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

--- Resolve an include path
---@param include_path string The path in the INCLUDE statement
---@param from_file string|nil The file containing the INCLUDE
---@return string|nil resolved_path
---@return string|nil error
function PathResolver:resolve(include_path, from_file)
    if not include_path or include_path == "" then
        return nil, "Empty include path"
    end

    from_file = from_file or self.current_file

    -- Ensure extension
    include_path = self:ensure_extension(include_path)

    -- Case 1: Absolute path (starts with / for project root)
    if self:is_absolute(include_path) then
        -- For project-relative absolute paths (starting with /),
        -- resolve relative to project root
        if include_path:sub(1, 1) == "/" then
            local full_path = self:join(self.project_root, include_path:sub(2))
            full_path = self:normalize(full_path)
            if self:file_exists(full_path) then
                return full_path
            end
            return nil, "File not found: " .. include_path
        else
            -- True absolute path (e.g., C:/...)
            local full_path = self:normalize(include_path)
            if self:file_exists(full_path) then
                return full_path
            end
            return nil, "File not found: " .. include_path
        end
    end

    -- Case 2: Relative path (starts with ./ or ../)
    if include_path:match("^%.%.?/") then
        local base_dir = self:get_directory(from_file or ".")
        local full_path = self:join(base_dir, include_path)
        full_path = self:normalize(full_path)
        if self:file_exists(full_path) then
            return full_path
        end
        return nil, "File not found: " .. full_path
    end

    -- Case 3: Simple relative (no ./ prefix) - relative to current file
    if from_file then
        local base_dir = self:get_directory(from_file)
        local full_path = self:join(base_dir, include_path)
        full_path = self:normalize(full_path)
        if self:file_exists(full_path) then
            return full_path
        end
    end

    -- Case 4: Search paths
    for _, search_path in ipairs(self.search_paths) do
        local full_path = self:join(search_path, include_path)
        full_path = self:normalize(full_path)
        if self:file_exists(full_path) then
            return full_path
        end
    end

    -- Case 5: Project root
    local root_path = self:join(self.project_root, include_path)
    root_path = self:normalize(root_path)
    if self:file_exists(root_path) then
        return root_path
    end

    return nil, "Include not found: " .. include_path
end

--- Set current file context for relative resolution
---@param path string
function PathResolver:set_current_file(path)
    self.current_file = path
end

--- Push file onto include stack and check for circular reference
---@param path string Absolute resolved path
---@return boolean is_circular
---@return string|nil cycle_description
function PathResolver:push_include(path)
    local normalized = self:normalize(path)

    -- Check if already in stack (circular)
    for i, included in ipairs(self.include_stack) do
        if included == normalized then
            -- Build cycle description
            local cycle_parts = {}
            for j = i, #self.include_stack do
                table.insert(cycle_parts, self:get_filename(self.include_stack[j]))
            end
            table.insert(cycle_parts, self:get_filename(normalized))

            local cycle_desc = table.concat(cycle_parts, " -> ")
            return true, cycle_desc
        end
    end

    table.insert(self.include_stack, normalized)
    return false, nil
end

--- Pop file from include stack
function PathResolver:pop_include()
    if #self.include_stack > 0 then
        table.remove(self.include_stack)
    end
end

--- Get the current include depth
---@return number
function PathResolver:get_include_depth()
    return #self.include_stack
end

--- Get the full include chain as a string
---@return string
function PathResolver:get_include_chain()
    local parts = {}
    for _, path in ipairs(self.include_stack) do
        table.insert(parts, self:get_filename(path))
    end
    return table.concat(parts, " -> ")
end

--- Clear the include stack (for testing or reset)
function PathResolver:clear_include_stack()
    self.include_stack = {}
end

--- Reset the resolver state
function PathResolver:reset()
    self.include_stack = {}
    self.current_file = nil
end

return PathResolver
