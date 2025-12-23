# AssetManager API Reference

The AssetManager is the central registry and loader for all media assets.

## Initialization

```lua
local AssetManager = require("whisker.media.AssetManager")
AssetManager:initialize(config)
```

**Config Options**:
- `memoryBudget` (number): Maximum cache size in bytes (default: 100MB)
- `basePath` (string): Base path for asset files

## Methods

### register(config)

Register an asset.

**Parameters**:
- `config` (table): Asset configuration
  - `id` (string, required): Unique asset identifier
  - `type` (string, required): "audio", "image", or "video"
  - `sources` (table): Array of source files with format and path
  - `variants` (table): Array of variants (images only) with density and path
  - `metadata` (table): Optional metadata

**Returns**: `success` (boolean), `error` (table or nil)

**Example**:
```lua
AssetManager:register({
  id = "forest_theme",
  type = "audio",
  sources = {
    { format = "mp3", path = "assets/audio/forest.mp3" },
    { format = "ogg", path = "assets/audio/forest.ogg" }
  },
  metadata = {
    duration = 180,
    loop = true,
    tags = { "music", "forest" }
  }
})
```

### unregister(assetId)

Unregister and unload an asset.

**Parameters**:
- `assetId` (string): Asset ID to unregister

**Returns**: `success` (boolean)

### load(assetId, callback)

Load an asset asynchronously.

**Parameters**:
- `assetId` (string): Asset ID to load
- `callback` (function): Called when load completes `function(asset, error)`

**Returns**: `success` (boolean)

**Example**:
```lua
AssetManager:load("forest_theme", function(asset, error)
  if error then
    print("Load failed: " .. error.message)
  else
    print("Loaded: " .. asset.id)
  end
end)
```

### loadSync(assetId, timeout)

Load an asset synchronously (blocking).

**Parameters**:
- `assetId` (string): Asset ID to load
- `timeout` (number, optional): Timeout in milliseconds

**Returns**: `asset` (table or nil), `error` (table or nil)

### loadBatch(assetIds, options)

Load multiple assets.

**Parameters**:
- `assetIds` (table): Array of asset IDs
- `options` (table):
  - `onProgress` (function): Progress callback `function(loaded, total)`
  - `onComplete` (function): Completion callback `function(assets, errors)`

### get(assetId)

Get a loaded asset.

**Parameters**:
- `assetId` (string): Asset ID

**Returns**: `asset` (table or nil)

### getState(assetId)

Get the current state of an asset.

**Parameters**:
- `assetId` (string): Asset ID

**Returns**: State string: "unloaded", "loading", "loaded", or "failed"

### isLoaded(assetId)

Check if an asset is loaded.

**Parameters**:
- `assetId` (string): Asset ID

**Returns**: `boolean`

### unload(assetId)

Unload an asset from cache.

**Parameters**:
- `assetId` (string): Asset ID

**Returns**: `success` (boolean)

### pin(assetId)

Pin an asset to prevent cache eviction.

**Parameters**:
- `assetId` (string): Asset ID

### unpin(assetId)

Unpin an asset to allow cache eviction.

**Parameters**:
- `assetId` (string): Asset ID

### retain(assetId)

Increment asset reference count.

**Parameters**:
- `assetId` (string): Asset ID

### release(assetId)

Decrement asset reference count.

**Parameters**:
- `assetId` (string): Asset ID

### getCacheStats()

Get cache statistics.

**Returns**: `stats` (table)
- `bytesUsed` (number): Bytes currently in cache
- `bytesLimit` (number): Maximum cache size
- `assetCount` (number): Number of cached assets

**Example**:
```lua
local stats = AssetManager:getCacheStats()
print(string.format("Cache: %.2f MB / %.2f MB (%d assets)",
  stats.bytesUsed / 1024 / 1024,
  stats.bytesLimit / 1024 / 1024,
  stats.assetCount))
```

### setMemoryBudget(bytes)

Set the cache memory budget.

**Parameters**:
- `bytes` (number): Maximum cache size in bytes

**Example**:
```lua
AssetManager:setMemoryBudget(100 * 1024 * 1024)  -- 100MB
```

### clearCache()

Clear all cached assets.

## Asset Configuration

### Audio Asset

```lua
{
  id = "music_track",
  type = "audio",
  sources = {
    { format = "mp3", path = "audio/track.mp3" },
    { format = "ogg", path = "audio/track.ogg" }
  },
  metadata = {
    duration = 180,
    loop = true
  }
}
```

### Image Asset

```lua
{
  id = "portrait",
  type = "image",
  sources = {
    { format = "png", path = "images/portrait.png" }
  },
  variants = {
    { density = "1x", path = "images/portrait.png" },
    { density = "2x", path = "images/portrait@2x.png" }
  },
  metadata = {
    width = 400,
    height = 600,
    alt = "Character portrait"
  }
}
```

## Error Types

- `validation`: Asset configuration validation failed
- `not_found`: Asset not registered
- `load_error`: Failed to load asset file
- `duplicate`: Asset ID already registered
