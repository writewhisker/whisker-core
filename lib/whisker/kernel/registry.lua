--- Module Registry
-- Registry for tracking and discovering modules
-- @module whisker.kernel.registry
-- @author Whisker Core Team
-- @license MIT

local Registry = {}
Registry._dependencies = {}
Registry.__index = Registry

--- Create a new registry instance
-- @return Registry A new registry
function Registry.new(deps)
  deps = deps or {}
  local self = setmetatable({}, Registry)
  self._modules = {}
  self._categories = {}
  self._metadata = {}
  return self
end

--- Register a module
-- @param name string The module name
-- @param module table The module table
-- @param metadata table|nil Module metadata
function Registry:register(name, module, metadata)
  metadata = metadata or {}

  self._modules[name] = module
  self._metadata[name] = metadata

  -- Add to category
  local category = metadata.category or "default"
  self._categories[category] = self._categories[category] or {}
  table.insert(self._categories[category], name)
end

--- Get a module by name
-- @param name string The module name
-- @return table|nil The module, or nil if not found
function Registry:get(name)
  return self._modules[name]
end

--- Check if a module is registered
-- @param name string The module name
-- @return boolean True if registered
function Registry:has(name)
  return self._modules[name] ~= nil
end

--- Unregister a module
-- @param name string The module name
function Registry:unregister(name)
  local metadata = self._metadata[name]
  if metadata then
    local category = metadata.category or "default"
    local cat_modules = self._categories[category]
    if cat_modules then
      for i, n in ipairs(cat_modules) do
        if n == name then
          table.remove(cat_modules, i)
          break
        end
      end
    end
  end

  self._modules[name] = nil
  self._metadata[name] = nil
end

--- Get all module names
-- @return table Array of module names
function Registry:get_names()
  local names = {}
  for name in pairs(self._modules) do
    table.insert(names, name)
  end
  return names
end

--- Get modules by category
-- @param category string The category name
-- @return table Array of module names in the category
function Registry:get_by_category(category)
  return self._categories[category] or {}
end

--- Get module metadata
-- @param name string The module name
-- @return table|nil The metadata, or nil if not found
function Registry:get_metadata(name)
  return self._metadata[name]
end

--- Get all categories
-- @return table Array of category names
function Registry:get_categories()
  local categories = {}
  for category in pairs(self._categories) do
    table.insert(categories, category)
  end
  return categories
end

--- Clear all registrations
function Registry:clear()
  self._modules = {}
  self._categories = {}
  self._metadata = {}
end

--- Find modules matching a pattern
-- @param pattern string The pattern to match
-- @return table Array of matching module names
function Registry:find(pattern)
  local matches = {}
  for name in pairs(self._modules) do
    if name:match(pattern) then
      table.insert(matches, name)
    end
  end
  return matches
end

return Registry
