#!/usr/bin/env lua
--- Fix Modularity Warnings
-- Adds _dependencies declarations and deps parameters to modules
-- @script fix_modularity

local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return content
end

local function write_file(path, content)
  local file = io.open(path, "w")
  if not file then return false end
  file:write(content)
  file:close()
  return true
end

local function fix_missing_dependencies(content, module_name)
  -- Check if _dependencies already exists
  if content:match("_dependencies%s*=") then
    return content, false
  end

  -- Find the module table declaration
  local patterns = {
    "(local%s+" .. module_name .. "%s*=%s*{})",
    "(local%s+" .. module_name .. "%s*=%s*setmetatable%s*%(%s*{})",
  }

  for _, pattern in ipairs(patterns) do
    if content:match(pattern) then
      -- Add _dependencies after module declaration
      local replacement = "%1\n" .. module_name .. "._dependencies = {}"
      local new_content = content:gsub(pattern, replacement, 1)
      if new_content ~= content then
        return new_content, true
      end
    end
  end

  return content, false
end

local function fix_no_deps_param(content, module_name)
  -- Find new() functions without deps parameter
  local pattern = "(function%s+" .. module_name .. "%.new%s*%(%s*%))"
  if content:match(pattern) then
    local replacement = "function " .. module_name .. ".new(deps)"
    local new_content = content:gsub(pattern, replacement, 1)
    if new_content ~= content then
      -- Add deps initialization at start of function
      new_content = new_content:gsub(
        "(function%s+" .. module_name .. "%.new%s*%(deps%))",
        "%1\n  deps = deps or {}", 1)
      return new_content, true
    end
  end

  -- Also check for single parameter that isn't deps
  pattern = "(function%s+" .. module_name .. "%.new%s*%(config%))"
  if content:match(pattern) then
    local replacement = "function " .. module_name .. ".new(config, deps)"
    local new_content = content:gsub(pattern, replacement, 1)
    if new_content ~= content then
      new_content = new_content:gsub(
        "(function%s+" .. module_name .. "%.new%s*%(config, deps%))",
        "%1\n  deps = deps or {}", 1)
      return new_content, true
    end
  end

  return content, false
end

local function get_module_name(content)
  -- Try to find the module name from the return statement
  local name = content:match("return%s+(%w+)%s*$")
  if name then return name end

  -- Try to find from local X = {} pattern
  name = content:match("local%s+(%w+)%s*=%s*{}")
  return name
end

local function process_file(path)
  local content = read_file(path)
  if not content then
    print("Error reading: " .. path)
    return false
  end

  local module_name = get_module_name(content)
  if not module_name then
    print("Could not determine module name: " .. path)
    return false
  end

  local modified = false
  local new_content = content

  -- Fix missing dependencies
  new_content, changed = fix_missing_dependencies(new_content, module_name)
  modified = modified or changed

  -- Fix no deps param
  new_content, changed = fix_no_deps_param(new_content, module_name)
  modified = modified or changed

  if modified then
    if write_file(path, new_content) then
      print("Fixed: " .. path)
      return true
    else
      print("Error writing: " .. path)
      return false
    end
  end

  return false
end

-- Get files from validate_modularity output
local function get_files_to_fix()
  local files = {}
  local seen = {}
  local handle = io.popen("lua tools/validate_modularity.lua 2>&1")
  if not handle then return files end

  for line in handle:lines() do
    local file = line:match("lib/whisker/[^:]+")
    if file and not seen[file] then
      seen[file] = true
      table.insert(files, file)
    end
  end
  handle:close()
  return files
end

-- Main
print("Modularity Fixer")
print("================")

local files = get_files_to_fix()
print("Found " .. #files .. " files with warnings")
print("")

local fixed = 0
for _, file in ipairs(files) do
  if process_file(file) then
    fixed = fixed + 1
  end
end

print("")
print("Fixed " .. fixed .. " files")
