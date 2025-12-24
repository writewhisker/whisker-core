--- Media Interface Contract Tests
-- Validates that implementations conform to media interfaces
-- @module tests.contracts.media_contract
-- @author Whisker Core Team
-- @license MIT

local MediaInterfaces = require("whisker.interfaces.media")

local M = {}

--- Test IAssetCache implementation
-- @param impl table The implementation to test
-- @return boolean, string Success and error message if any
function M.test_asset_cache(impl)
  -- Must implement all required methods
  local required = {"get", "put", "remove", "has", "clear", "getStats"}
  for _, method in ipairs(required) do
    if type(impl[method]) ~= "function" then
      return false, "IAssetCache: missing method '" .. method .. "'"
    end
  end

  -- Test basic operations
  local success, err = pcall(function()
    -- put should accept id, asset, optional size
    impl:put("test_id", {data = "test"}, 100)

    -- has should return boolean
    local has_result = impl:has("test_id")
    assert(type(has_result) == "boolean", "has() should return boolean")

    -- get should return the asset
    local asset = impl:get("test_id")
    assert(asset ~= nil, "get() should return cached asset")

    -- getStats should return a table
    local stats = impl:getStats()
    assert(type(stats) == "table", "getStats() should return table")

    -- remove should work
    impl:remove("test_id")

    -- clear should work
    impl:clear()
  end)

  if not success then
    return false, "IAssetCache: " .. tostring(err)
  end

  return true
end

--- Test IAssetLoader implementation
-- @param impl table The implementation to test
-- @return boolean, string Success and error message if any
function M.test_asset_loader(impl)
  local required = {"load", "loadAsync", "exists", "detectType"}
  for _, method in ipairs(required) do
    if type(impl[method]) ~= "function" then
      return false, "IAssetLoader: missing method '" .. method .. "'"
    end
  end

  -- Test method signatures (doesn't require actual loading)
  local success, err = pcall(function()
    -- exists should return boolean
    local exists = impl:exists("/nonexistent/path")
    assert(type(exists) == "boolean", "exists() should return boolean")

    -- detectType should handle paths
    local asset_type = impl:detectType("/test/file.png")
    -- Can be nil or string
    assert(asset_type == nil or type(asset_type) == "string",
      "detectType() should return nil or string")
  end)

  if not success then
    return false, "IAssetLoader: " .. tostring(err)
  end

  return true
end

--- Test IAssetManager implementation
-- @param impl table The implementation to test
-- @return boolean, string Success and error message if any
function M.test_asset_manager(impl)
  local required = {
    "register", "unregister", "get", "load", "unload",
    "isRegistered", "isLoaded", "getState", "getAllIds"
  }
  for _, method in ipairs(required) do
    if type(impl[method]) ~= "function" then
      return false, "IAssetManager: missing method '" .. method .. "'"
    end
  end

  local success, err = pcall(function()
    -- register should accept id and config
    local registered = impl:register("test_asset", {path = "/test/path"})
    assert(type(registered) == "boolean", "register() should return boolean")

    -- isRegistered should return boolean
    local is_reg = impl:isRegistered("test_asset")
    assert(type(is_reg) == "boolean", "isRegistered() should return boolean")

    -- getState should return string
    local state = impl:getState("test_asset")
    assert(type(state) == "string", "getState() should return string")

    -- getAllIds should return table
    local ids = impl:getAllIds()
    assert(type(ids) == "table", "getAllIds() should return table")

    -- unregister should work
    impl:unregister("test_asset")
  end)

  if not success then
    return false, "IAssetManager: " .. tostring(err)
  end

  return true
end

--- Test IAudioManager implementation
-- @param impl table The implementation to test
-- @return boolean, string Success and error message if any
function M.test_audio_manager(impl)
  local required = {
    "play", "stop", "pause", "resume",
    "setVolume", "getVolume", "setMasterVolume", "getMasterVolume"
  }
  for _, method in ipairs(required) do
    if type(impl[method]) ~= "function" then
      return false, "IAudioManager: missing method '" .. method .. "'"
    end
  end

  local success, err = pcall(function()
    -- getMasterVolume should return number
    local vol = impl:getMasterVolume()
    assert(type(vol) == "number", "getMasterVolume() should return number")

    -- setMasterVolume should accept number
    impl:setMasterVolume(0.5)
  end)

  if not success then
    return false, "IAudioManager: " .. tostring(err)
  end

  return true
end

--- Test IImageManager implementation
-- @param impl table The implementation to test
-- @return boolean, string Success and error message if any
function M.test_image_manager(impl)
  local required = {"get", "load", "unload", "getDimensions"}
  for _, method in ipairs(required) do
    if type(impl[method]) ~= "function" then
      return false, "IImageManager: missing method '" .. method .. "'"
    end
  end

  return true
end

--- Test IPreloadManager implementation
-- @param impl table The implementation to test
-- @return boolean, string Success and error message if any
function M.test_preload_manager(impl)
  local required = {"preload", "cancel", "getProgress"}
  for _, method in ipairs(required) do
    if type(impl[method]) ~= "function" then
      return false, "IPreloadManager: missing method '" .. method .. "'"
    end
  end

  local success, err = pcall(function()
    -- getProgress should return table
    local progress = impl:getProgress()
    assert(type(progress) == "table", "getProgress() should return table")
  end)

  if not success then
    return false, "IPreloadManager: " .. tostring(err)
  end

  return true
end

--- Test IBundler implementation
-- @param impl table The implementation to test
-- @return boolean, string Success and error message if any
function M.test_bundler(impl)
  local required = {"bundle", "extract", "getInfo"}
  for _, method in ipairs(required) do
    if type(impl[method]) ~= "function" then
      return false, "IBundler: missing method '" .. method .. "'"
    end
  end

  local success, err = pcall(function()
    -- getInfo should return table
    local info = impl:getInfo()
    assert(type(info) == "table", "getInfo() should return table")
  end)

  if not success then
    return false, "IBundler: " .. tostring(err)
  end

  return true
end

return M
