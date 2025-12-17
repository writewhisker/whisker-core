-- whisker/formats/ink/transformers/tunnel.lua
-- Tunnel transformer for Ink to Whisker conversion
-- Converts Ink tunnels to whisker passage + call stack pattern

local TunnelTransformer = {}
TunnelTransformer.__index = TunnelTransformer

-- Module metadata
TunnelTransformer._whisker = {
  name = "TunnelTransformer",
  version = "1.0.0",
  description = "Transforms Ink tunnels to whisker call stack pattern",
  depends = {},
  capability = "formats.ink.transformers.tunnel"
}

-- Create a new TunnelTransformer instance
function TunnelTransformer.new()
  local instance = {}
  setmetatable(instance, TunnelTransformer)
  return instance
end

-- Transform a tunnel divert to whisker format
-- @param divert_data table - The tunnel divert data
-- @param parent_path string - The parent passage path
-- @param options table|nil - Conversion options
-- @return table - Transformed tunnel info
function TunnelTransformer:transform(divert_data, parent_path, options)
  options = options or {}

  local target = self:_extract_target(divert_data)
  local is_tunnel = self:_is_tunnel(divert_data)

  return {
    target = target,
    is_tunnel = is_tunnel,
    return_point = is_tunnel and parent_path or nil,
    metadata = {
      type = is_tunnel and "tunnel" or "divert",
      ink_source = parent_path
    }
  }
end

-- Check if a divert is a tunnel call
-- @param divert_data table - The divert data
-- @return boolean
function TunnelTransformer:_is_tunnel(divert_data)
  if type(divert_data) ~= "table" then
    return false
  end

  -- Tunnel diverts in Ink JSON have tunnel: true or use ->-> syntax marker
  if divert_data.tunnel then
    return true
  end

  -- Check for pushpop flag indicating tunnel
  if divert_data["->t->"] then
    return true
  end

  return false
end

-- Extract target path from divert
-- @param divert_data table - The divert data
-- @return string|nil - The target path
function TunnelTransformer:_extract_target(divert_data)
  if type(divert_data) ~= "table" then
    return nil
  end

  -- Target can be in different places
  if divert_data["->"] then
    return divert_data["->"]
  end

  if divert_data["->t->"] then
    return divert_data["->t->"]
  end

  if divert_data.target then
    return divert_data.target
  end

  return nil
end

-- Find tunnel calls in a container
-- @param container table - The container to search
-- @return table - Array of tunnel info
function TunnelTransformer:find_tunnels(container)
  local tunnels = {}

  if type(container) ~= "table" then
    return tunnels
  end

  self:_find_tunnels_recursive(container, tunnels)

  return tunnels
end

-- Recursively find tunnel calls
function TunnelTransformer:_find_tunnels_recursive(container, tunnels)
  if type(container) ~= "table" then
    return
  end

  for i, item in ipairs(container) do
    if type(item) == "table" then
      if self:_is_tunnel(item) then
        table.insert(tunnels, item)
      else
        self:_find_tunnels_recursive(item, tunnels)
      end
    end
  end
end

-- Check if a passage is a tunnel target
-- @param passage_data table - The passage container data
-- @return boolean
function TunnelTransformer:is_tunnel_target(passage_data)
  if type(passage_data) ~= "table" then
    return false
  end

  -- Look for return marker in the container
  for _, item in ipairs(passage_data) do
    if type(item) == "table" and item["->->"] then
      return true
    end
  end

  return false
end

-- Create passage metadata for tunnel support
-- @param is_tunnel_target boolean - Whether this passage is called as tunnel
-- @param return_points table - Array of return point paths
-- @return table - Metadata for passage
function TunnelTransformer:create_passage_metadata(is_tunnel_target, return_points)
  return {
    is_tunnel_target = is_tunnel_target,
    return_points = return_points or {},
    call_type = is_tunnel_target and "tunnel" or "normal"
  }
end

return TunnelTransformer
