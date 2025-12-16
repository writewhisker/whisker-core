-- whisker/kernel/errors.lua
-- Kernel-level error definitions
-- Zero external dependencies

local Errors = {}

-- Error codes
Errors.codes = {
  MODULE_NOT_FOUND = "E001",
  MODULE_ALREADY_REGISTERED = "E002",
  INVALID_MODULE = "E003",
  CAPABILITY_NOT_FOUND = "E004",
  BOOTSTRAP_FAILED = "E005",
}

-- Create a kernel error with code and message
function Errors.new(code, message, details)
  return {
    code = code,
    message = message,
    details = details or {},
    is_kernel_error = true
  }
end

-- Format error for display
function Errors.format(err)
  if type(err) == "table" and err.is_kernel_error then
    return string.format("[%s] %s", err.code, err.message)
  end
  return tostring(err)
end

-- Throw a kernel error
function Errors.throw(code, message, details)
  error(Errors.format(Errors.new(code, message, details)), 2)
end

return Errors
