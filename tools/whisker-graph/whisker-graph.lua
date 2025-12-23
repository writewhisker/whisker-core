#!/usr/bin/env lua
-- whisker-graph: Story Graph Visualizer for whisker-core
-- Generates visual representations of story passage flow

-- Add lib directory to package path
local script_dir = arg[0]:match("(.*/)")
if script_dir then
  package.path = script_dir .. "?.lua;" ..
                 script_dir .. "lib/?.lua;" ..
                 package.path
end

local function print_help()
  print([[
whisker-graph - Story Graph Visualizer

Usage: whisker-graph [options] <story-file>

Options:
  -h, --help           Show this help message
  -v, --version        Show version information
  -f, --format FORMAT  Output format (mermaid, dot, json)
  -o, --output FILE    Output file (default: stdout)
  --no-unreachable     Hide unreachable passages
  --clusters           Group passages by tags/sections

Formats:
  mermaid   - Mermaid.js flowchart (default)
  dot       - Graphviz DOT format
  json      - JSON graph representation

Examples:
  whisker-graph story.ink
  whisker-graph -f dot -o story.dot story.ink
  whisker-graph --format mermaid story.twee
]])
end

local function print_version()
  print("whisker-graph 0.1.0")
  print("Story graph visualizer for whisker-core")
end

-- Parse story file and extract passages/connections
local function parse_story(filepath)
  local file = io.open(filepath, "r")
  if not file then
    io.stderr:write("Error: Cannot open file: " .. filepath .. "\n")
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Detect format from extension
  local ext = filepath:match("%.([^%.]+)$")
  local format = "ink"
  if ext == "twee" or ext == "tw" then
    format = "twee"
  elseif ext == "wscript" then
    format = "wscript"
  end

  local passages = {}
  local connections = {}

  if format == "ink" then
    -- Parse Ink: === PassageName ===
    local current_passage = nil
    local line_num = 0

    for line in content:gmatch("([^\n]*)\n?") do
      line_num = line_num + 1
      local passage_name = line:match("^%s*===+%s*([%w_]+)%s*===+")

      if passage_name then
        current_passage = passage_name
        passages[passage_name] = {
          name = passage_name,
          line = line_num,
          targets = {},
          tags = {}
        }
      elseif current_passage then
        -- Find diverts: -> Target
        for target in line:gmatch("->%s*([%w_]+)") do
          if target ~= "END" and target ~= "DONE" then
            table.insert(passages[current_passage].targets, target)
            table.insert(connections, {from = current_passage, to = target})
          end
        end
        -- Find choice targets: * [text] -> Target
        for target in line:gmatch("%*[^%]]*%]%s*->%s*([%w_]+)") do
          if target ~= "END" and target ~= "DONE" then
            table.insert(passages[current_passage].targets, target)
            table.insert(connections, {from = current_passage, to = target, type = "choice"})
          end
        end
      end
    end

  elseif format == "twee" then
    -- Parse Twee: :: PassageName [tags]
    local current_passage = nil
    local line_num = 0

    for line in content:gmatch("([^\n]*)\n?") do
      line_num = line_num + 1
      local passage_name, tags = line:match("^::%s*([^%[%{]+)%s*%[?([^%]]*)")

      if passage_name then
        passage_name = passage_name:match("^%s*(.-)%s*$")
        current_passage = passage_name
        passages[passage_name] = {
          name = passage_name,
          line = line_num,
          targets = {},
          tags = tags and {tags} or {}
        }
      elseif current_passage then
        -- Find links: [[text|target]] or [[text->target]] or [[target]]
        for link in line:gmatch("%[%[([^%]]+)%]%]") do
          local target = link:match("|([^%]]+)$") or link:match("->([^%]]+)$") or link
          target = target:match("^%s*(.-)%s*$")
          table.insert(passages[current_passage].targets, target)
          table.insert(connections, {from = current_passage, to = target, type = "link"})
        end
      end
    end

  elseif format == "wscript" then
    -- Parse WhiskerScript: passage "Name" {
    local current_passage = nil
    local line_num = 0

    for line in content:gmatch("([^\n]*)\n?") do
      line_num = line_num + 1
      local passage_name = line:match('^%s*passage%s+"([^"]+)"')

      if passage_name then
        current_passage = passage_name
        passages[passage_name] = {
          name = passage_name,
          line = line_num,
          targets = {},
          tags = {}
        }
      elseif current_passage then
        -- Find diverts: -> Target
        for target in line:gmatch("->%s*([%w_]+)") do
          if target ~= "END" and target ~= "DONE" then
            table.insert(passages[current_passage].targets, target)
            table.insert(connections, {from = current_passage, to = target})
          end
        end
      end
    end
  end

  return {
    passages = passages,
    connections = connections,
    format = format
  }
end

-- Find unreachable passages
local function find_unreachable(graph)
  local reachable = {}
  local start_names = {"Start", "START", "start", "Beginning"}

  -- Find start passage
  local start = nil
  for _, name in ipairs(start_names) do
    if graph.passages[name] then
      start = name
      break
    end
  end

  if not start then
    -- Use first passage
    for name, _ in pairs(graph.passages) do
      start = name
      break
    end
  end

  if not start then
    return {}
  end

  -- BFS to find reachable
  local queue = {start}
  reachable[start] = true

  while #queue > 0 do
    local current = table.remove(queue, 1)
    local passage = graph.passages[current]
    if passage then
      for _, target in ipairs(passage.targets) do
        if graph.passages[target] and not reachable[target] then
          reachable[target] = true
          table.insert(queue, target)
        end
      end
    end
  end

  -- Find unreachable
  local unreachable = {}
  for name, _ in pairs(graph.passages) do
    if not reachable[name] then
      table.insert(unreachable, name)
    end
  end

  return unreachable
end

-- Generate Mermaid output
local function generate_mermaid(graph, options)
  local lines = {"graph TD"}
  local unreachable = {}
  if not options.no_unreachable then
    for _, name in ipairs(find_unreachable(graph)) do
      unreachable[name] = true
    end
  end

  -- Find start
  local start_names = {"Start", "START", "start"}
  local start = nil
  for _, name in ipairs(start_names) do
    if graph.passages[name] then
      start = name
      break
    end
  end

  -- Add nodes
  for name, passage in pairs(graph.passages) do
    local id = name:gsub("[^%w_]", "_")
    local style = ""

    if name == start then
      style = ":::start"
      table.insert(lines, string.format('    %s(["%s"])%s', id, name, style))
    elseif unreachable[name] then
      style = ":::unreachable"
      table.insert(lines, string.format('    %s["%s"]%s', id, name, style))
    else
      table.insert(lines, string.format('    %s["%s"]', id, name))
    end
  end

  -- Add edges
  for _, conn in ipairs(graph.connections) do
    local from_id = conn.from:gsub("[^%w_]", "_")
    local to_id = conn.to:gsub("[^%w_]", "_")

    if graph.passages[conn.to] then
      if conn.type == "choice" then
        table.insert(lines, string.format("    %s -->|choice| %s", from_id, to_id))
      else
        table.insert(lines, string.format("    %s --> %s", from_id, to_id))
      end
    else
      -- Undefined target
      table.insert(lines, string.format('    %s_undefined["%s"]:::undefined', to_id, conn.to))
      table.insert(lines, string.format("    %s --> %s_undefined", from_id, to_id))
    end
  end

  -- Add styles
  table.insert(lines, "")
  table.insert(lines, "    classDef start fill:#4CAF50,stroke:#2E7D32,color:#fff")
  table.insert(lines, "    classDef unreachable fill:#FF9800,stroke:#F57C00,color:#fff")
  table.insert(lines, "    classDef undefined fill:#F44336,stroke:#C62828,color:#fff")

  return table.concat(lines, "\n")
end

-- Generate DOT output
local function generate_dot(graph, options)
  local lines = {
    "digraph Story {",
    '    rankdir=TB;',
    '    node [shape=box, style="rounded,filled", fillcolor=white];',
    ""
  }

  local unreachable = {}
  for _, name in ipairs(find_unreachable(graph)) do
    unreachable[name] = true
  end

  -- Add nodes
  for name, passage in pairs(graph.passages) do
    local id = name:gsub("[^%w_]", "_")
    local attrs = {}

    if unreachable[name] then
      table.insert(attrs, 'fillcolor="#FFCC80"')
    end

    local attr_str = #attrs > 0 and " [" .. table.concat(attrs, ", ") .. "]" or ""
    table.insert(lines, string.format('    %s [label="%s"]%s;', id, name, attr_str))
  end

  table.insert(lines, "")

  -- Add edges
  for _, conn in ipairs(graph.connections) do
    local from_id = conn.from:gsub("[^%w_]", "_")
    local to_id = conn.to:gsub("[^%w_]", "_")

    if graph.passages[conn.to] then
      table.insert(lines, string.format("    %s -> %s;", from_id, to_id))
    end
  end

  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

-- Generate JSON output
local function generate_json(graph, options)
  local nodes = {}
  local edges = {}

  local unreachable = {}
  for _, name in ipairs(find_unreachable(graph)) do
    unreachable[name] = true
  end

  for name, passage in pairs(graph.passages) do
    table.insert(nodes, {
      id = name,
      line = passage.line,
      tags = passage.tags,
      unreachable = unreachable[name] or false
    })
  end

  for _, conn in ipairs(graph.connections) do
    table.insert(edges, {
      from = conn.from,
      to = conn.to,
      type = conn.type or "divert"
    })
  end

  -- Simple JSON encoding
  local function encode_value(v)
    if type(v) == "string" then
      return '"' .. v:gsub('"', '\\"') .. '"'
    elseif type(v) == "boolean" then
      return v and "true" or "false"
    elseif type(v) == "number" then
      return tostring(v)
    elseif type(v) == "table" then
      if #v > 0 then
        local items = {}
        for _, item in ipairs(v) do
          table.insert(items, encode_value(item))
        end
        return "[" .. table.concat(items, ", ") .. "]"
      else
        local items = {}
        for k, val in pairs(v) do
          table.insert(items, '"' .. k .. '": ' .. encode_value(val))
        end
        return "{" .. table.concat(items, ", ") .. "}"
      end
    end
    return "null"
  end

  return encode_value({nodes = nodes, edges = edges})
end

local function main()
  local options = {
    format = "mermaid",
    output = nil,
    no_unreachable = false,
    clusters = false
  }

  local filepath = nil
  local i = 1

  while i <= #arg do
    local a = arg[i]
    if a == "-h" or a == "--help" then
      print_help()
      os.exit(0)
    elseif a == "-v" or a == "--version" then
      print_version()
      os.exit(0)
    elseif a == "-f" or a == "--format" then
      i = i + 1
      options.format = arg[i]
    elseif a == "-o" or a == "--output" then
      i = i + 1
      options.output = arg[i]
    elseif a == "--no-unreachable" then
      options.no_unreachable = true
    elseif a == "--clusters" then
      options.clusters = true
    elseif not a:match("^%-") then
      filepath = a
    end
    i = i + 1
  end

  if not filepath then
    io.stderr:write("Error: No input file specified\n")
    io.stderr:write("Use --help for usage information\n")
    os.exit(1)
  end

  -- Parse story
  local graph = parse_story(filepath)
  if not graph then
    os.exit(1)
  end

  -- Generate output
  local output
  if options.format == "mermaid" then
    output = generate_mermaid(graph, options)
  elseif options.format == "dot" then
    output = generate_dot(graph, options)
  elseif options.format == "json" then
    output = generate_json(graph, options)
  else
    io.stderr:write("Error: Unknown format: " .. options.format .. "\n")
    os.exit(1)
  end

  -- Write output
  if options.output then
    local file = io.open(options.output, "w")
    if not file then
      io.stderr:write("Error: Cannot write to: " .. options.output .. "\n")
      os.exit(1)
    end
    file:write(output)
    file:write("\n")
    file:close()
  else
    print(output)
  end
end

if arg[0]:match("whisker%-graph") then
  main()
end

return {
  parse_story = parse_story,
  generate_mermaid = generate_mermaid,
  generate_dot = generate_dot,
  generate_json = generate_json,
  find_unreachable = find_unreachable
}
