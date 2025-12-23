-- lib/whisker/i18n/tools/init.lua
-- i18n workflow tools module
-- Stage 8: Translation Workflow

local M = {}

-- Module version
M._VERSION = "1.0.0"

-- Lazy load submodules
local _extract
local _validate
local _status

--- Get extract tool
-- @return table Extract module
function M.getExtract()
  if not _extract then
    _extract = require("whisker.i18n.tools.extract")
  end
  return _extract
end

--- Get validate tool
-- @return table Validate module
function M.getValidate()
  if not _validate then
    _validate = require("whisker.i18n.tools.validate")
  end
  return _validate
end

--- Get status tool
-- @return table Status module
function M.getStatus()
  if not _status then
    _status = require("whisker.i18n.tools.status")
  end
  return _status
end

-- Export submodules
M.Extract = M.getExtract
M.Validate = M.getValidate
M.Status = M.getStatus

return M
