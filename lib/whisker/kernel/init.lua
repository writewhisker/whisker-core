-- lib/whisker/kernel/init.lua
-- Whisker-Core Microkernel Bootstrap (Version 2.1, ≤50 lines)
local M = {}

---@class Whisker
---@field version string Framework version
---@field _capabilities table<string, boolean> Detected capabilities
---@field container table|nil DI container (loaded later)
---@field events table|nil Event bus (loaded later)
---@field loader table|nil Module loader (loaded later)

_G.whisker = _G.whisker or {}
local whisker = _G.whisker
whisker.version = "2.1.0"
whisker._capabilities = whisker._capabilities or {}

---Initialize the microkernel (called once at framework startup)
function M.init()
  whisker._capabilities.lua_version = _VERSION
  whisker._capabilities.io = (io ~= nil)
  whisker._capabilities.os = (os ~= nil)
  whisker._capabilities.package = (package ~= nil)
  whisker._capabilities.debug = (debug ~= nil)
  whisker._capabilities.luajit = (jit ~= nil)
  whisker._capabilities.json = pcall(require, "cjson") or pcall(require, "dkjson") or pcall(require, "json")
  whisker.container, whisker.events, whisker.loader = nil, nil, nil
  return whisker
end

---Check if a capability is available
---@param cap string Capability name
---@return boolean available
function M.has_capability(cap)
  return whisker._capabilities[cap] == true
end

---Get all available capabilities
---@return table<string, boolean> capabilities
function M.get_capabilities()
  local caps = {}
  for k, v in pairs(whisker._capabilities) do caps[k] = v end
  return caps
end

if not whisker._initialized then M.init(); whisker._initialized = true end

return M
