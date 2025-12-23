--- IFID (UUID v4) generator
-- Generates unique identifiers for Twine stories
--
-- lib/whisker/twine/util/ifid_generator.lua

local IFIDGenerator = {}

--------------------------------------------------------------------------------
-- UUID Generation
--------------------------------------------------------------------------------

--- Generate UUID v4
---@return string UUID in format XXXXXXXX-XXXX-4XXX-YXXX-XXXXXXXXXXXX
function IFIDGenerator.generate()
  -- Seed random number generator
  math.randomseed(os.time() + os.clock() * 1000000)

  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

  return template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end):upper()
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

--- Validate IFID format
---@param ifid string IFID to validate
---@return boolean True if valid
function IFIDGenerator.validate(ifid)
  if not ifid or type(ifid) ~= "string" then
    return false
  end

  -- Check format: XXXXXXXX-XXXX-4XXX-YXXX-XXXXXXXXXXXX
  -- Y must be 8, 9, A, or B
  local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ABab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

  return ifid:match(pattern) ~= nil
end

return IFIDGenerator
