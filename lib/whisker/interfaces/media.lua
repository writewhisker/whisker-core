--- Media Interfaces
-- Interfaces for media system components (DI pattern)
-- @module whisker.interfaces.media
-- @author Whisker Core Team
-- @license MIT

local M = {}

--- IAssetCache Interface
-- Interface for asset caching with LRU eviction
-- @table IAssetCache
M.IAssetCache = {}

--- Get an asset from the cache
-- @param id string Asset identifier
-- @return table|nil The cached asset or nil if not found
function M.IAssetCache:get(id)
  error("IAssetCache:get must be implemented")
end

--- Put an asset into the cache
-- @param id string Asset identifier
-- @param asset table Asset data to cache
-- @param size number|nil Optional size for memory tracking
-- @return boolean True if cached successfully
function M.IAssetCache:put(id, asset, size)
  error("IAssetCache:put must be implemented")
end

--- Remove an asset from the cache
-- @param id string Asset identifier
-- @return boolean True if removed
function M.IAssetCache:remove(id)
  error("IAssetCache:remove must be implemented")
end

--- Check if an asset exists in the cache
-- @param id string Asset identifier
-- @return boolean True if asset is cached
function M.IAssetCache:has(id)
  error("IAssetCache:has must be implemented")
end

--- Clear all assets from the cache
function M.IAssetCache:clear()
  error("IAssetCache:clear must be implemented")
end

--- Get cache statistics
-- @return table Cache stats (size, hits, misses, etc.)
function M.IAssetCache:getStats()
  error("IAssetCache:getStats must be implemented")
end


--- IAssetLoader Interface
-- Interface for loading assets from various sources
-- @table IAssetLoader
M.IAssetLoader = {}

--- Load an asset synchronously
-- @param path string Path to the asset
-- @param asset_type string|nil Optional asset type hint
-- @return table|nil, string|nil Asset data or nil, error message
function M.IAssetLoader:load(path, asset_type)
  error("IAssetLoader:load must be implemented")
end

--- Load an asset asynchronously
-- @param path string Path to the asset
-- @param callback function Callback(success, result_or_error)
-- @param asset_type string|nil Optional asset type hint
function M.IAssetLoader:loadAsync(path, callback, asset_type)
  error("IAssetLoader:loadAsync must be implemented")
end

--- Check if a path exists and is accessible
-- @param path string Path to check
-- @return boolean True if accessible
function M.IAssetLoader:exists(path)
  error("IAssetLoader:exists must be implemented")
end

--- Get the detected asset type for a path
-- @param path string Path to analyze
-- @return string|nil Asset type or nil if unknown
function M.IAssetLoader:detectType(path)
  error("IAssetLoader:detectType must be implemented")
end


--- IAssetManager Interface
-- Interface for central asset management
-- @table IAssetManager
M.IAssetManager = {}

--- Register an asset with the manager
-- @param id string Unique asset identifier
-- @param config table Asset configuration (path, type, etc.)
-- @return boolean True if registered successfully
function M.IAssetManager:register(id, config)
  error("IAssetManager:register must be implemented")
end

--- Unregister an asset from the manager
-- @param id string Asset identifier
-- @return boolean True if unregistered
function M.IAssetManager:unregister(id)
  error("IAssetManager:unregister must be implemented")
end

--- Get an asset (loads if needed)
-- @param id string Asset identifier
-- @return table|nil Asset data or nil
function M.IAssetManager:get(id)
  error("IAssetManager:get must be implemented")
end

--- Load an asset explicitly
-- @param id string Asset identifier
-- @param callback function|nil Optional callback for async loading
-- @return boolean, string|nil Success and error message
function M.IAssetManager:load(id, callback)
  error("IAssetManager:load must be implemented")
end

--- Unload an asset from memory
-- @param id string Asset identifier
-- @return boolean True if unloaded
function M.IAssetManager:unload(id)
  error("IAssetManager:unload must be implemented")
end

--- Check if an asset is registered
-- @param id string Asset identifier
-- @return boolean True if registered
function M.IAssetManager:isRegistered(id)
  error("IAssetManager:isRegistered must be implemented")
end

--- Check if an asset is loaded
-- @param id string Asset identifier
-- @return boolean True if loaded
function M.IAssetManager:isLoaded(id)
  error("IAssetManager:isLoaded must be implemented")
end

--- Get the state of an asset
-- @param id string Asset identifier
-- @return string Asset state (unloaded, loading, loaded, failed)
function M.IAssetManager:getState(id)
  error("IAssetManager:getState must be implemented")
end

--- Get all registered asset IDs
-- @return table List of asset IDs
function M.IAssetManager:getAllIds()
  error("IAssetManager:getAllIds must be implemented")
end


--- IAudioManager Interface
-- Interface for audio playback management
-- @table IAudioManager
M.IAudioManager = {}

--- Play audio on a channel
-- @param id string Asset identifier
-- @param channel string|nil Channel name (defaults to SFX)
-- @param options table|nil Playback options (loop, volume, etc.)
-- @return table|nil Audio handle or nil
function M.IAudioManager:play(id, channel, options)
  error("IAudioManager:play must be implemented")
end

--- Stop audio playback
-- @param handle table|string Audio handle or channel name
function M.IAudioManager:stop(handle)
  error("IAudioManager:stop must be implemented")
end

--- Pause audio playback
-- @param handle table|string Audio handle or channel name
function M.IAudioManager:pause(handle)
  error("IAudioManager:pause must be implemented")
end

--- Resume audio playback
-- @param handle table|string Audio handle or channel name
function M.IAudioManager:resume(handle)
  error("IAudioManager:resume must be implemented")
end

--- Set volume for a handle or channel
-- @param handle table|string Audio handle or channel name
-- @param volume number Volume level (0.0 to 1.0)
function M.IAudioManager:setVolume(handle, volume)
  error("IAudioManager:setVolume must be implemented")
end

--- Get volume for a handle or channel
-- @param handle table|string Audio handle or channel name
-- @return number Volume level
function M.IAudioManager:getVolume(handle)
  error("IAudioManager:getVolume must be implemented")
end

--- Set master volume
-- @param volume number Volume level (0.0 to 1.0)
function M.IAudioManager:setMasterVolume(volume)
  error("IAudioManager:setMasterVolume must be implemented")
end

--- Get master volume
-- @return number Master volume level
function M.IAudioManager:getMasterVolume()
  error("IAudioManager:getMasterVolume must be implemented")
end


--- IImageManager Interface
-- Interface for image display management
-- @table IImageManager
M.IImageManager = {}

--- Get image data for an asset
-- @param id string Asset identifier
-- @return table|nil Image data or nil
function M.IImageManager:get(id)
  error("IImageManager:get must be implemented")
end

--- Load an image
-- @param id string Asset identifier
-- @param callback function|nil Optional callback for async loading
-- @return boolean, string|nil Success and error message
function M.IImageManager:load(id, callback)
  error("IImageManager:load must be implemented")
end

--- Unload an image
-- @param id string Asset identifier
-- @return boolean True if unloaded
function M.IImageManager:unload(id)
  error("IImageManager:unload must be implemented")
end

--- Get image dimensions
-- @param id string Asset identifier
-- @return number, number Width and height (or nil, nil if not loaded)
function M.IImageManager:getDimensions(id)
  error("IImageManager:getDimensions must be implemented")
end


--- IPreloadManager Interface
-- Interface for asset preloading
-- @table IPreloadManager
M.IPreloadManager = {}

--- Preload a list of assets
-- @param asset_ids table List of asset identifiers
-- @param callback function|nil Optional progress callback(loaded, total)
-- @param priority string|nil Priority level (low, normal, high)
function M.IPreloadManager:preload(asset_ids, callback, priority)
  error("IPreloadManager:preload must be implemented")
end

--- Cancel preloading
-- @param asset_ids table|nil List of asset IDs to cancel, or nil for all
function M.IPreloadManager:cancel(asset_ids)
  error("IPreloadManager:cancel must be implemented")
end

--- Get preload progress
-- @return table Progress info (loaded, total, pending)
function M.IPreloadManager:getProgress()
  error("IPreloadManager:getProgress must be implemented")
end


--- IBundler Interface
-- Interface for asset bundling/packaging
-- @table IBundler
M.IBundler = {}

--- Bundle assets for a target platform
-- @param assets table List of asset configurations
-- @param options table Bundling options
-- @return table, string|nil Bundle info or nil, error message
function M.IBundler:bundle(assets, options)
  error("IBundler:bundle must be implemented")
end

--- Extract assets from a bundle
-- @param bundle_path string Path to the bundle
-- @param output_dir string Output directory
-- @return boolean, string|nil Success and error message
function M.IBundler:extract(bundle_path, output_dir)
  error("IBundler:extract must be implemented")
end

--- Get bundler information
-- @return table Bundler info (name, platform, formats)
function M.IBundler:getInfo()
  error("IBundler:getInfo must be implemented")
end


return M
