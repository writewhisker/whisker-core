--- Dependency Resolver
-- Resolves plugin load order based on dependencies using topological sort
-- @module whisker.plugin.dependency_resolver
-- @author Whisker Core Team
-- @license MIT

local DependencyResolver = {}

--- Parse semantic version string
-- @param version_str string Version string (e.g., "1.2.3")
-- @return table|nil Parsed version {major, minor, patch} or nil
function DependencyResolver.parse_version(version_str)
  if type(version_str) ~= "string" then
    return nil
  end

  local major, minor, patch = version_str:match("^(%d+)%.(%d+)%.(%d+)")
  if not major then
    return nil
  end

  return {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
  }
end

--- Compare two versions
-- @param v1 table Parsed version
-- @param v2 table Parsed version
-- @return number -1 if v1 < v2, 0 if equal, 1 if v1 > v2
function DependencyResolver.compare_versions(v1, v2)
  if v1.major ~= v2.major then
    return v1.major < v2.major and -1 or 1
  end
  if v1.minor ~= v2.minor then
    return v1.minor < v2.minor and -1 or 1
  end
  if v1.patch ~= v2.patch then
    return v1.patch < v2.patch and -1 or 1
  end
  return 0
end

--- Check if version satisfies constraint
-- Supports: exact ("1.2.3"), caret ("^1.2.3"), tilde ("~1.2.3"), any ("*")
-- @param version string The version to check
-- @param constraint string The version constraint
-- @return boolean True if version satisfies constraint
function DependencyResolver.satisfies(version, constraint)
  if constraint == "*" then
    return true
  end

  local version_parsed = DependencyResolver.parse_version(version)
  if not version_parsed then
    return false
  end

  -- Handle caret constraint (^1.2.3 = >=1.2.3 <2.0.0)
  if constraint:sub(1, 1) == "^" then
    local constraint_parsed = DependencyResolver.parse_version(constraint:sub(2))
    if not constraint_parsed then
      return false
    end

    -- Major version must match
    if version_parsed.major ~= constraint_parsed.major then
      return false
    end

    -- Must be >= constraint version
    local cmp = DependencyResolver.compare_versions(version_parsed, constraint_parsed)
    return cmp >= 0
  end

  -- Handle tilde constraint (~1.2.3 = >=1.2.3 <1.3.0)
  if constraint:sub(1, 1) == "~" then
    local constraint_parsed = DependencyResolver.parse_version(constraint:sub(2))
    if not constraint_parsed then
      return false
    end

    -- Major and minor must match
    if version_parsed.major ~= constraint_parsed.major then
      return false
    end
    if version_parsed.minor ~= constraint_parsed.minor then
      return false
    end

    -- Must be >= constraint version
    local cmp = DependencyResolver.compare_versions(version_parsed, constraint_parsed)
    return cmp >= 0
  end

  -- Handle >= constraint
  if constraint:sub(1, 2) == ">=" then
    local constraint_parsed = DependencyResolver.parse_version(constraint:sub(3))
    if not constraint_parsed then
      return false
    end
    local cmp = DependencyResolver.compare_versions(version_parsed, constraint_parsed)
    return cmp >= 0
  end

  -- Handle > constraint
  if constraint:sub(1, 1) == ">" then
    local constraint_parsed = DependencyResolver.parse_version(constraint:sub(2))
    if not constraint_parsed then
      return false
    end
    local cmp = DependencyResolver.compare_versions(version_parsed, constraint_parsed)
    return cmp > 0
  end

  -- Handle <= constraint
  if constraint:sub(1, 2) == "<=" then
    local constraint_parsed = DependencyResolver.parse_version(constraint:sub(3))
    if not constraint_parsed then
      return false
    end
    local cmp = DependencyResolver.compare_versions(version_parsed, constraint_parsed)
    return cmp <= 0
  end

  -- Handle < constraint
  if constraint:sub(1, 1) == "<" then
    local constraint_parsed = DependencyResolver.parse_version(constraint:sub(2))
    if not constraint_parsed then
      return false
    end
    local cmp = DependencyResolver.compare_versions(version_parsed, constraint_parsed)
    return cmp < 0
  end

  -- Exact match
  local constraint_parsed = DependencyResolver.parse_version(constraint)
  if not constraint_parsed then
    return false
  end
  return DependencyResolver.compare_versions(version_parsed, constraint_parsed) == 0
end

--- Build dependency graph from plugins
-- @param plugins table[] Array of plugin objects
-- @return table graph Adjacency list: plugin_name -> {dep_name -> version_constraint}
-- @return table plugin_map Map of name -> plugin
function DependencyResolver.build_graph(plugins)
  local graph = {}
  local plugin_map = {}

  for _, plugin in ipairs(plugins) do
    local name = plugin.name
    plugin_map[name] = plugin

    -- Get dependencies from plugin definition
    local deps = {}
    if plugin.definition and plugin.definition.dependencies then
      for dep_name, version_constraint in pairs(plugin.definition.dependencies) do
        deps[dep_name] = version_constraint
      end
    end

    graph[name] = deps
  end

  return graph, plugin_map
end

--- Detect circular dependencies using DFS
-- @param graph table Dependency graph
-- @return boolean has_cycle
-- @return string[]|nil cycle_path Path of nodes in the cycle
function DependencyResolver.detect_cycle(graph)
  local WHITE = 0  -- Not visited
  local GRAY = 1   -- In progress
  local BLACK = 2  -- Complete

  local color = {}
  local parent = {}

  for node in pairs(graph) do
    color[node] = WHITE
  end

  local function dfs(node, path)
    color[node] = GRAY
    table.insert(path, node)

    local deps = graph[node] or {}
    for dep_name in pairs(deps) do
      if graph[dep_name] then  -- Only check if dependency exists
        if color[dep_name] == GRAY then
          -- Found cycle - extract cycle path
          local cycle = {dep_name}
          for i = #path, 1, -1 do
            table.insert(cycle, 1, path[i])
            if path[i] == dep_name then
              break
            end
          end
          return true, cycle
        elseif color[dep_name] == WHITE then
          local has_cycle, cycle = dfs(dep_name, path)
          if has_cycle then
            return true, cycle
          end
        end
      end
    end

    color[node] = BLACK
    table.remove(path)
    return false, nil
  end

  for node in pairs(graph) do
    if color[node] == WHITE then
      local has_cycle, cycle = dfs(node, {})
      if has_cycle then
        return true, cycle
      end
    end
  end

  return false, nil
end

--- Resolve plugin load order based on dependencies
-- Uses Kahn's algorithm for topological sort
-- @param plugins table[] Array of plugin objects
-- @return table[]|nil ordered Plugins in load order, or nil on error
-- @return string|nil error Error message if resolution failed
function DependencyResolver.resolve(plugins)
  if not plugins or #plugins == 0 then
    return {}
  end

  -- Build dependency graph
  local graph, plugin_map = DependencyResolver.build_graph(plugins)

  -- Check for missing dependencies
  for plugin_name, deps in pairs(graph) do
    for dep_name, version_constraint in pairs(deps) do
      if not plugin_map[dep_name] then
        return nil, string.format(
          "Plugin '%s' depends on missing plugin '%s'",
          plugin_name,
          dep_name
        )
      end

      -- Check version constraint
      local dep_plugin = plugin_map[dep_name]
      local dep_version = dep_plugin.version or (dep_plugin.definition and dep_plugin.definition.version)
      if dep_version and not DependencyResolver.satisfies(dep_version, version_constraint) then
        return nil, string.format(
          "Plugin '%s' requires '%s' version '%s', but found '%s'",
          plugin_name,
          dep_name,
          version_constraint,
          dep_version
        )
      end
    end
  end

  -- Detect circular dependencies
  local has_cycle, cycle = DependencyResolver.detect_cycle(graph)
  if has_cycle then
    return nil, string.format(
      "Circular dependency detected: %s",
      table.concat(cycle, " -> ")
    )
  end

  -- Calculate in-degrees (number of dependencies each plugin has)
  -- A plugin can be loaded only after all its dependencies are loaded
  local in_degree = {}
  for name in pairs(graph) do
    in_degree[name] = 0
  end

  -- For each plugin, count how many dependencies it has
  for plugin_name, deps in pairs(graph) do
    for dep_name in pairs(deps) do
      if plugin_map[dep_name] then
        in_degree[plugin_name] = in_degree[plugin_name] + 1
      end
    end
  end

  -- Kahn's algorithm: start with nodes that have no dependencies
  local queue = {}
  for name, degree in pairs(in_degree) do
    if degree == 0 then
      table.insert(queue, name)
    end
  end

  -- Sort queue for deterministic order
  table.sort(queue)

  local result = {}

  while #queue > 0 do
    -- Remove first element
    local current = table.remove(queue, 1)

    -- Add plugin to result
    table.insert(result, plugin_map[current])

    -- Find all plugins that depend on current and decrease their in-degree
    for plugin_name, deps in pairs(graph) do
      if deps[current] then
        in_degree[plugin_name] = in_degree[plugin_name] - 1
        if in_degree[plugin_name] == 0 then
          table.insert(queue, plugin_name)
        end
      end
    end

    -- Re-sort for deterministic order
    table.sort(queue)
  end

  -- Verify all plugins were included
  if #result ~= #plugins then
    -- This shouldn't happen if cycle detection worked
    return nil, "Dependency resolution incomplete - possible circular dependency"
  end

  return result
end

--- Get the reverse load order (for destruction)
-- @param plugins table[] Array of plugins in load order
-- @return table[] Plugins in reverse order (for cleanup)
function DependencyResolver.reverse_order(plugins)
  local reversed = {}
  for i = #plugins, 1, -1 do
    table.insert(reversed, plugins[i])
  end
  return reversed
end

--- Get all plugins that depend on a given plugin
-- @param plugins table[] Array of plugin objects
-- @param target_name string Name of the plugin to find dependents for
-- @return string[] Array of plugin names that depend on target
function DependencyResolver.get_dependents(plugins, target_name)
  local dependents = {}

  for _, plugin in ipairs(plugins) do
    local deps = plugin.definition and plugin.definition.dependencies or {}
    for dep_name in pairs(deps) do
      if dep_name == target_name then
        table.insert(dependents, plugin.name)
        break
      end
    end
  end

  return dependents
end

--- Get all dependencies of a plugin (recursive)
-- @param plugins table[] Array of plugin objects
-- @param plugin_name string Name of the plugin
-- @param visited table|nil Visited set (for internal use)
-- @return string[] Array of all dependency names (recursive)
function DependencyResolver.get_all_dependencies(plugins, plugin_name, visited)
  visited = visited or {}
  if visited[plugin_name] then
    return {}
  end
  visited[plugin_name] = true

  -- Build plugin map
  local plugin_map = {}
  for _, p in ipairs(plugins) do
    plugin_map[p.name] = p
  end

  local plugin = plugin_map[plugin_name]
  if not plugin then
    return {}
  end

  local all_deps = {}
  local deps = plugin.definition and plugin.definition.dependencies or {}

  for dep_name in pairs(deps) do
    table.insert(all_deps, dep_name)
    -- Recursively get transitive dependencies
    local transitive = DependencyResolver.get_all_dependencies(plugins, dep_name, visited)
    for _, t_dep in ipairs(transitive) do
      -- Avoid duplicates
      local found = false
      for _, existing in ipairs(all_deps) do
        if existing == t_dep then
          found = true
          break
        end
      end
      if not found then
        table.insert(all_deps, t_dep)
      end
    end
  end

  return all_deps
end

return DependencyResolver
