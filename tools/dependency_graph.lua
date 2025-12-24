#!/usr/bin/env lua
--- Dependency Graph Generator
-- Analyzes whisker-core modules and generates dependency graphs
-- Outputs DOT format for visualization with graphviz
-- @module tools.dependency_graph
-- @author Whisker Core Team

local lfs = pcall(require, "lfs") and require("lfs") or nil

-- Configuration
local CONFIG = {
  EXIT_SUCCESS = 0,
  EXIT_ERROR = 1,
  FORMAT_DOT = "dot",
  FORMAT_TEXT = "text",
  FORMAT_JSON = "json",
}

-- Module dependency data
local modules = {}
local dependencies = {}
local cycles = {}

-- Directories to skip
local SKIP_DIRS = {
  "tests",
  "spec",
  "examples",
  ".git",
  "node_modules",
  "build",
  "dist",
  "tinta",
}

-- Files to skip
local SKIP_PATTERNS = {
  "spec%.lua$",
  "_spec%.lua$",
  "_test%.lua$",
  "test_.*%.lua$",
  "^%.",
}

--- Check if a file should be skipped
local function should_skip_file(path)
  for _, pattern in ipairs(SKIP_PATTERNS) do
    if path:match(pattern) then
      return true
    end
  end
  for _, dir in ipairs(SKIP_DIRS) do
    if path:match("/" .. dir .. "/") or path:match("^" .. dir .. "/") then
      return true
    end
  end
  return false
end

--- Check if a directory should be skipped
local function should_skip_dir(name)
  for _, dir in ipairs(SKIP_DIRS) do
    if name == dir then
      return true
    end
  end
  return false
end

--- Convert file path to module name
-- @param filepath string The file path (e.g., lib/whisker/core/engine.lua)
-- @return string The module name (e.g., whisker.core.engine)
local function path_to_module(filepath)
  local mod = filepath
  -- Remove lib/ prefix
  mod = mod:gsub("^lib/", "")
  -- Remove .lua suffix
  mod = mod:gsub("%.lua$", "")
  -- Convert / to .
  mod = mod:gsub("/", ".")
  -- Handle init.lua
  mod = mod:gsub("%.init$", "")
  return mod
end

--- Extract module name from path for display
-- @param filepath string The file path
-- @return string Short module name
local function short_name(filepath)
  local mod = path_to_module(filepath)
  -- Get last part after whisker.
  return mod:gsub("^whisker%.", "")
end

--- Parse a file for dependencies
-- @param filepath string Path to the Lua file
-- @return table List of dependencies found
local function parse_dependencies(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return {}
  end

  local content = file:read("*a")
  file:close()

  local deps = {}

  -- Find require statements
  for req in content:gmatch('require%s*%(%s*["\']([^"\']+)["\']%s*%)') do
    -- Only track whisker modules
    if req:match("^whisker%.") then
      table.insert(deps, req)
    end
  end

  -- Find _dependencies declarations
  local deps_decl = content:match("_dependencies%s*=%s*{([^}]+)}")
  if deps_decl then
    for dep in deps_decl:gmatch('["\']([^"\']+)["\']') do
      -- These are dependency names, not module paths
      -- Store them separately for analysis
      deps["_declared_" .. dep] = true
    end
  end

  return deps
end

--- Scan directory for Lua files
-- @param path string Directory path
-- @param all_files table Accumulator for files found
-- @return table All Lua files found
local function scan_directory(path, all_files)
  all_files = all_files or {}

  if lfs then
    for entry in lfs.dir(path) do
      if entry ~= "." and entry ~= ".." then
        local full_path = path .. "/" .. entry
        local attr = lfs.attributes(full_path)

        if attr then
          if attr.mode == "directory" then
            if not should_skip_dir(entry) then
              scan_directory(full_path, all_files)
            end
          elseif attr.mode == "file" and entry:match("%.lua$") then
            if not should_skip_file(entry) and not should_skip_file(full_path) then
              table.insert(all_files, full_path)
            end
          end
        end
      end
    end
  else
    local handle = io.popen('find "' .. path .. '" -name "*.lua" -type f 2>/dev/null')
    if handle then
      for filepath in handle:lines() do
        if not should_skip_file(filepath) then
          table.insert(all_files, filepath)
        end
      end
      handle:close()
    end
  end

  return all_files
end

--- Build dependency graph from files
-- @param files table List of file paths
local function build_graph(files)
  -- First pass: register all modules
  for _, filepath in ipairs(files) do
    local mod = path_to_module(filepath)
    modules[mod] = {
      path = filepath,
      name = short_name(filepath),
    }
  end

  -- Second pass: parse dependencies
  for _, filepath in ipairs(files) do
    local mod = path_to_module(filepath)
    local deps = parse_dependencies(filepath)

    dependencies[mod] = {}
    for _, dep in ipairs(deps) do
      table.insert(dependencies[mod], dep)
    end
  end
end

--- Detect cycles using DFS
-- @param node string Current node
-- @param visited table Visited nodes
-- @param rec_stack table Recursion stack
-- @param path table Current path
-- @return boolean True if cycle found
local function detect_cycle(node, visited, rec_stack, path)
  visited[node] = true
  rec_stack[node] = true
  table.insert(path, node)

  local deps = dependencies[node] or {}
  for _, dep in ipairs(deps) do
    if not visited[dep] then
      if detect_cycle(dep, visited, rec_stack, path) then
        return true
      end
    elseif rec_stack[dep] then
      -- Found cycle
      local cycle = {}
      local in_cycle = false
      for _, p in ipairs(path) do
        if p == dep then
          in_cycle = true
        end
        if in_cycle then
          table.insert(cycle, p)
        end
      end
      table.insert(cycle, dep)
      table.insert(cycles, cycle)
      return true
    end
  end

  table.remove(path)
  rec_stack[node] = false
  return false
end

--- Find all cycles in the graph
local function find_cycles()
  local visited = {}
  local rec_stack = {}

  for mod in pairs(modules) do
    if not visited[mod] then
      detect_cycle(mod, visited, rec_stack, {})
    end
  end
end

--- Generate DOT format output
-- @return string DOT format graph
local function format_dot()
  local lines = {}
  table.insert(lines, "digraph whisker_dependencies {")
  table.insert(lines, '  rankdir=LR;')
  table.insert(lines, '  node [shape=box, fontname="Helvetica"];')
  table.insert(lines, "")

  -- Group by directory
  local groups = {}
  for mod, info in pairs(modules) do
    local group = mod:match("^whisker%.([^%.]+)")
    if not groups[group] then
      groups[group] = {}
    end
    table.insert(groups[group], mod)
  end

  -- Create subgraphs for each group
  for group, mods in pairs(groups) do
    table.insert(lines, string.format('  subgraph cluster_%s {', group))
    table.insert(lines, string.format('    label="%s";', group))
    table.insert(lines, '    style=filled;')
    table.insert(lines, '    color=lightgrey;')
    for _, mod in ipairs(mods) do
      local label = modules[mod].name
      table.insert(lines, string.format('    "%s" [label="%s"];', mod, label))
    end
    table.insert(lines, '  }')
  end

  table.insert(lines, "")

  -- Add edges
  for mod, deps in pairs(dependencies) do
    for _, dep in ipairs(deps) do
      local color = "black"
      -- Check if edge is part of a cycle
      for _, cycle in ipairs(cycles) do
        for i = 1, #cycle - 1 do
          if cycle[i] == mod and cycle[i + 1] == dep then
            color = "red"
            break
          end
        end
      end
      table.insert(lines, string.format('  "%s" -> "%s" [color=%s];', mod, dep, color))
    end
  end

  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

--- Generate text format output
-- @return string Text format graph
local function format_text()
  local lines = {}

  -- Summary
  local mod_count = 0
  local edge_count = 0
  for _ in pairs(modules) do mod_count = mod_count + 1 end
  for _, deps in pairs(dependencies) do edge_count = edge_count + #deps end

  table.insert(lines, "Whisker Dependency Graph")
  table.insert(lines, "========================")
  table.insert(lines, string.format("Modules: %d", mod_count))
  table.insert(lines, string.format("Dependencies: %d", edge_count))
  table.insert(lines, string.format("Cycles: %d", #cycles))
  table.insert(lines, "")

  -- Cycles
  if #cycles > 0 then
    table.insert(lines, "CIRCULAR DEPENDENCIES:")
    for i, cycle in ipairs(cycles) do
      table.insert(lines, string.format("  Cycle %d: %s", i, table.concat(cycle, " -> ")))
    end
    table.insert(lines, "")
  end

  -- Module list
  table.insert(lines, "MODULES:")
  local sorted_mods = {}
  for mod in pairs(modules) do
    table.insert(sorted_mods, mod)
  end
  table.sort(sorted_mods)

  for _, mod in ipairs(sorted_mods) do
    local deps = dependencies[mod] or {}
    if #deps > 0 then
      table.insert(lines, string.format("  %s", mod))
      for _, dep in ipairs(deps) do
        table.insert(lines, string.format("    -> %s", dep))
      end
    end
  end

  return table.concat(lines, "\n")
end

--- Generate JSON format output
-- @return string JSON format graph
local function format_json()
  local lines = {}
  table.insert(lines, "{")

  -- Modules
  table.insert(lines, '  "modules": [')
  local sorted_mods = {}
  for mod in pairs(modules) do
    table.insert(sorted_mods, mod)
  end
  table.sort(sorted_mods)
  for i, mod in ipairs(sorted_mods) do
    local comma = i < #sorted_mods and "," or ""
    table.insert(lines, string.format('    "%s"%s', mod, comma))
  end
  table.insert(lines, '  ],')

  -- Dependencies
  table.insert(lines, '  "dependencies": {')
  local dep_lines = {}
  for mod, deps in pairs(dependencies) do
    if #deps > 0 then
      local dep_strs = {}
      for _, dep in ipairs(deps) do
        table.insert(dep_strs, string.format('"%s"', dep))
      end
      table.insert(dep_lines, string.format('    "%s": [%s]', mod, table.concat(dep_strs, ", ")))
    end
  end
  table.insert(lines, table.concat(dep_lines, ",\n"))
  table.insert(lines, '  },')

  -- Cycles
  table.insert(lines, '  "cycles": [')
  for i, cycle in ipairs(cycles) do
    local cycle_strs = {}
    for _, node in ipairs(cycle) do
      table.insert(cycle_strs, string.format('"%s"', node))
    end
    local comma = i < #cycles and "," or ""
    table.insert(lines, string.format('    [%s]%s', table.concat(cycle_strs, ", "), comma))
  end
  table.insert(lines, '  ]')

  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

--- Print usage information
local function print_usage()
  print("Usage: lua tools/dependency_graph.lua [OPTIONS] [PATH]")
  print("")
  print("Options:")
  print("  --format=FORMAT  Output format: dot, text, json (default: text)")
  print("  --cycles         Only check for and report cycles")
  print("  --help           Show this help message")
  print("")
  print("Examples:")
  print("  lua tools/dependency_graph.lua lib/")
  print("  lua tools/dependency_graph.lua --format=dot lib/ > graph.dot")
  print("  dot -Tpng graph.dot -o graph.png")
end

--- Main entry point
local function main(args)
  local format = CONFIG.FORMAT_TEXT
  local cycles_only = false
  local paths = {}

  -- Parse arguments
  for _, arg in ipairs(args) do
    if arg == "--help" or arg == "-h" then
      print_usage()
      return CONFIG.EXIT_SUCCESS
    elseif arg:match("^--format=") then
      format = arg:match("^--format=(.+)$")
    elseif arg == "--cycles" then
      cycles_only = true
    elseif not arg:match("^%-") then
      table.insert(paths, arg)
    end
  end

  if #paths == 0 then
    paths = { "lib/" }
  end

  -- Scan and build graph
  local all_files = {}
  for _, path in ipairs(paths) do
    scan_directory(path, all_files)
  end

  if #all_files == 0 then
    io.stderr:write("No Lua files found\n")
    return CONFIG.EXIT_ERROR
  end

  build_graph(all_files)
  find_cycles()

  -- Output
  if cycles_only then
    if #cycles > 0 then
      print("Circular dependencies detected:")
      for i, cycle in ipairs(cycles) do
        print(string.format("  %d: %s", i, table.concat(cycle, " -> ")))
      end
      return CONFIG.EXIT_ERROR
    else
      print("No circular dependencies found")
      return CONFIG.EXIT_SUCCESS
    end
  end

  local output
  if format == CONFIG.FORMAT_DOT then
    output = format_dot()
  elseif format == CONFIG.FORMAT_JSON then
    output = format_json()
  else
    output = format_text()
  end

  print(output)

  return #cycles > 0 and CONFIG.EXIT_ERROR or CONFIG.EXIT_SUCCESS
end

-- Export for testing
local M = {
  CONFIG = CONFIG,
  path_to_module = path_to_module,
  short_name = short_name,
  parse_dependencies = parse_dependencies,
  build_graph = build_graph,
  find_cycles = find_cycles,
  format_dot = format_dot,
  format_text = format_text,
  format_json = format_json,
  main = main,
  -- Expose internal state for testing
  _modules = modules,
  _dependencies = dependencies,
  _cycles = cycles,
}

-- Run if executed directly
if arg and arg[0] and arg[0]:match("dependency_graph%.lua$") then
  os.exit(main(arg))
end

return M
