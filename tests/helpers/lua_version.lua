--- Lua Version Helper for Tests
-- Provides utilities for version-conditional test execution
-- @module tests.helpers.lua_version
-- @author Whisker Core Team
-- @license MIT

local LuaVersion = {}

--- Lua version as a number (5.1, 5.2, 5.3, 5.4)
LuaVersion.version = tonumber(_VERSION:match("Lua (%d+%.%d+)")) or 5.1

--- Is this Lua 5.1?
LuaVersion.is_51 = LuaVersion.version == 5.1

--- Is this Lua 5.2?
LuaVersion.is_52 = LuaVersion.version == 5.2

--- Is this Lua 5.3?
LuaVersion.is_53 = LuaVersion.version == 5.3

--- Is this Lua 5.4?
LuaVersion.is_54 = LuaVersion.version == 5.4

--- Is this Lua 5.2 or later?
LuaVersion.is_52_plus = LuaVersion.version >= 5.2

--- Is this Lua 5.3 or later?
LuaVersion.is_53_plus = LuaVersion.version >= 5.3

--- Is this Lua 5.4 or later?
LuaVersion.is_54_plus = LuaVersion.version >= 5.4

--- Is this LuaJIT?
LuaVersion.is_luajit = type(jit) == "table"

--- Get a human-readable version string
-- @return string Version description (e.g., "Lua 5.4" or "LuaJIT 2.1.0")
function LuaVersion.get_description()
  if LuaVersion.is_luajit then
    return "LuaJIT " .. (jit.version or "unknown")
  else
    return _VERSION
  end
end

--- Check if the current version satisfies a minimum requirement
-- @param min_version number Minimum required version (e.g., 5.3)
-- @return boolean True if current version >= min_version
function LuaVersion.at_least(min_version)
  return LuaVersion.version >= min_version
end

--- Skip a test if the Lua version is below the minimum
-- Uses busted's `pending()` to skip the test with a reason (if available)
-- @param min_version number Minimum required version
-- @param feature_name string Optional description of the feature requiring this version
-- @return boolean True if version is sufficient, false if test should be skipped
function LuaVersion.skip_below(min_version, feature_name)
  if LuaVersion.version < min_version then
    local reason = string.format(
      "Requires Lua %s+ (current: %s)",
      tostring(min_version),
      LuaVersion.get_description()
    )
    if feature_name then
      reason = feature_name .. " - " .. reason
    end
    -- Call pending if available (busted function), otherwise just skip silently
    if type(pending) == "function" then
      pending(reason)
    end
    return false
  end
  return true
end

--- Skip a test if running on LuaJIT
-- Some tests may behave differently on LuaJIT due to JIT compilation
-- @param reason string Optional reason for skipping
-- @return boolean True if not LuaJIT, false if test should be skipped
function LuaVersion.skip_on_luajit(reason)
  if LuaVersion.is_luajit then
    -- Call pending if available (busted function), otherwise just skip silently
    if type(pending) == "function" then
      pending(reason or "Skipped on LuaJIT")
    end
    return false
  end
  return true
end

--- Skip a test if running on a specific Lua version
-- @param version number Version to skip (e.g., 5.1)
-- @param reason string Optional reason for skipping
-- @return boolean True if not on that version, false if test should be skipped
function LuaVersion.skip_on(version, reason)
  if LuaVersion.version == version then
    local default_reason = string.format("Skipped on Lua %s", tostring(version))
    -- Call pending if available (busted function), otherwise just skip silently
    if type(pending) == "function" then
      pending(reason or default_reason)
    end
    return false
  end
  return true
end

--- Get the appropriate bitwise XOR function for this Lua version
-- @return function The bxor function
function LuaVersion.get_bxor()
  local compat = require("whisker.vendor.compat")
  return compat.bit.bxor
end

--- Check if bitwise operators are available natively
-- @return boolean True if native bitwise operators are available
function LuaVersion.has_native_bitops()
  return LuaVersion.is_53_plus
end

--- Check if utf8 library is available
-- @return boolean True if utf8 library is available
function LuaVersion.has_utf8()
  return utf8 ~= nil
end

--- Check if integer division operator (//) is available
-- @return boolean True if // operator is available (Lua 5.3+)
function LuaVersion.has_integer_division()
  return LuaVersion.is_53_plus
end

--- Known limitations for each Lua version
LuaVersion.limitations = {
  ["5.1"] = {
    "No native bitwise operators (use bit library or pure Lua fallback)",
    "No utf8 library",
    "No integer division operator (//)",
    "loadstring instead of load",
    "setfenv/getfenv available (removed in 5.2+)",
    "unpack is global (moved to table.unpack in 5.2+)",
  },
  ["5.2"] = {
    "No native bitwise operators (use bit32 library)",
    "No utf8 library",
    "No integer division operator (//)",
    "bit32 library available",
  },
  ["5.3"] = {
    "Native bitwise operators available",
    "utf8 library available",
    "Integer division operator (//) available",
    "bit32 library deprecated",
  },
  ["5.4"] = {
    "Native bitwise operators available",
    "utf8 library available",
    "Integer division operator (//) available",
    "const and close attributes for locals",
  },
  ["luajit"] = {
    "Based on Lua 5.1 with extensions",
    "bit library for bitwise operations (not bit32)",
    "JIT compilation may affect timing-sensitive tests",
    "FFI available for C interop",
  },
}

return LuaVersion
