# PreloadManager API Reference

The PreloadManager coordinates preloading operations with group management and memory budget.

## Initialization

```lua
local PreloadManager = require("whisker.media.PreloadManager")
PreloadManager:initialize(config)
```

**Config Options**:
- `maxConcurrent` (number): Maximum concurrent preload operations (default: 3)
- `budgetRatio` (number): Ratio of cache budget for preloading (default: 0.3)

## Methods

### registerGroup(groupName, assetIds)

Register a preload group.

**Parameters**:
- `groupName` (string): Unique group name
- `assetIds` (table): Array of asset IDs

**Example**:
```lua
PreloadManager:registerGroup("chapter_1", {
  "forest_theme",
  "forest_ambience",
  "portrait_ranger",
  "background_forest"
})
```

### unregisterGroup(groupName)

Unregister a preload group.

**Parameters**:
- `groupName` (string): Group name

### getGroup(groupName)

Get a registered group.

**Parameters**:
- `groupName` (string): Group name

**Returns**: `group` (table or nil)

### preloadGroup(groupNameOrAssets, options)

Preload a group or array of assets.

**Parameters**:
- `groupNameOrAssets` (string or table): Group name or array of asset IDs
- `options` (table):
  - `priority` (string): "high", "normal", or "low"
  - `onProgress` (function): Progress callback `function(loaded, total)`
  - `onComplete` (function): Completion callback `function(succeeded, errors)`

**Returns**: `preloadId` (number or nil)

**Example**:
```lua
-- Preload by group name
PreloadManager:preloadGroup("chapter_1", {
  priority = "high",
  onProgress = function(loaded, total)
    print(string.format("Loading: %d/%d", loaded, total))
  end,
  onComplete = function(succeeded, errors)
    print(string.format("Loaded %d assets", succeeded))
  end
})

-- Preload array of assets
PreloadManager:preloadGroup({"forest_theme", "portrait_alice"})
```

### cancelPreload(preloadId)

Cancel an active preload operation.

**Parameters**:
- `preloadId` (number): Preload ID from preloadGroup()

**Returns**: `success` (boolean)

### unloadGroup(groupNameOrAssets)

Unload assets in a group.

**Parameters**:
- `groupNameOrAssets` (string or table): Group name or array of asset IDs

**Returns**: `success` (boolean)

**Example**:
```lua
-- Unload by group name
PreloadManager:unloadGroup("chapter_1")

-- Unload array of assets
PreloadManager:unloadGroup({"forest_theme", "portrait_alice"})
```

### extractPassageAssets(passage)

Extract asset IDs from passage content.

**Parameters**:
- `passage` (table): Passage with content field

**Returns**: `assetIds` (table)

**Example**:
```lua
local passage = {
  content = [[
    @@audio:play forest_theme
    @@image:show portrait_alice
  ]]
}
local assets = PreloadManager:extractPassageAssets(passage)
-- Returns: {"forest_theme", "portrait_alice"}
```

### getPreloadStatus(preloadId)

Get status of a preload operation.

**Parameters**:
- `preloadId` (number): Preload ID

**Returns**: `status` (table or nil)
- `id` (number): Preload ID
- `status` (string): "loading" or "queued"
- `loaded` (number): Assets loaded (if loading)
- `total` (number): Total assets (if loading)
- `progress` (number): Progress 0.0-1.0 (if loading)
- `errors` (number): Error count (if loading)
- `priority` (string): Priority (if queued)

### getActivePreloads()

Get all active preload operations.

**Returns**: `preloads` (table) - Array of status objects

### getQueuedPreloads()

Get all queued preload operations.

**Returns**: `preloads` (table) - Array of queued info

### getPreloadBudget()

Get the preload memory budget.

**Returns**: `budget` (number) - Bytes available for preloading

### getPreloadUsage()

Get current preload memory usage.

**Returns**: `usage` (number) - Bytes used by preloaded assets

### isPreloadBudgetExceeded()

Check if preload budget is exceeded.

**Returns**: `exceeded` (boolean)

## Priority Levels

| Priority | Description |
|----------|-------------|
| `high`   | Load immediately, before normal priority |
| `normal` | Standard loading order |
| `low`    | Load when no higher priority work |

## Preload Groups

Groups organize related assets for batch operations:

```lua
-- Register chapter assets
PreloadManager:registerGroup("chapter_2_intro", {
  "cave_theme",
  "cave_ambience",
  "background_cave"
})

PreloadManager:registerGroup("chapter_2_boss", {
  "boss_theme",
  "boss_portrait",
  "boss_attack_sfx"
})

-- Preload intro assets
PreloadManager:preloadGroup("chapter_2_intro")

-- Later, preload boss assets
PreloadManager:preloadGroup("chapter_2_boss")

-- When leaving chapter, unload all
PreloadManager:unloadGroup("chapter_2_intro")
PreloadManager:unloadGroup("chapter_2_boss")
```

## WhiskerScript Integration

Use preload directives in passages:

```
:: Chapter Start
@@preload:audio cave_theme, cave_ambience
@@preload:image background_cave, portrait_miner
@@preload:group chapter_2_assets

[[Continue|Cave Entrance]]
```
