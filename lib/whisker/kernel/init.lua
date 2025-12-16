-- whisker/kernel/init.lua
-- Microkernel entry point
-- Bootstraps the module system with zero external dependencies

local Errors = require("whisker.kernel.errors")
local Registry = require("whisker.kernel.registry")
local Capabilities = require("whisker.kernel.capabilities")

local Kernel = {
  _VERSION = "0.1.0",
  _NAME = "whisker-kernel",
  _bootstrapped = false,
}

-- Initialize kernel subsystems
function Kernel.bootstrap()
  if Kernel._bootstrapped then
    return Kernel
  end

  -- Create kernel subsystems
  Kernel.errors = Errors
  Kernel.registry = Registry.new(Errors)
  Kernel.capabilities = Capabilities.new()

  -- Register core capability
  Kernel.capabilities:register("kernel", true)

  Kernel._bootstrapped = true
  return Kernel
end

-- Reset kernel to pre-bootstrap state (mainly for testing)
function Kernel.reset()
  Kernel.registry = nil
  Kernel.capabilities = nil
  Kernel.errors = nil
  Kernel._bootstrapped = false
end

-- Convenience: Register a module
function Kernel.register(name, module)
  if not Kernel._bootstrapped then
    Kernel.bootstrap()
  end
  return Kernel.registry:register(name, module)
end

-- Convenience: Get a module
function Kernel.get(name)
  if not Kernel._bootstrapped then
    return nil
  end
  return Kernel.registry:get(name)
end

-- Convenience: Check if module exists
function Kernel.has(name)
  if not Kernel._bootstrapped then
    return false
  end
  return Kernel.registry:has(name)
end

-- Convenience: Check capability
function Kernel.has_capability(name)
  if not Kernel._bootstrapped then
    return false
  end
  return Kernel.capabilities:has(name)
end

-- Get kernel version
function Kernel.version()
  return Kernel._VERSION
end

-- Check if kernel is bootstrapped
function Kernel.is_bootstrapped()
  return Kernel._bootstrapped
end

return Kernel
