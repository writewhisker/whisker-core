# Migration Guide: Adding Media to Existing Games

This guide helps you add multimedia features to an existing text-only whisker-core game.

## Step 1: Assess Your Game

Before adding media:

1. **Identify key moments**: Where would audio/images enhance the experience?
2. **Plan your assets**: List all needed music, sounds, and images
3. **Consider file sizes**: Total asset size impact on distribution
4. **Set a budget**: How much memory can you allocate to media?

## Step 2: Prepare Assets

### Audio
- Export music as MP3 (128kbps) and OGG (128kbps)
- Export SFX as WAV or OGG (64kbps)
- Ensure loops are seamless (no clicks)

### Images
- Export at 1x (standard) and 2x (retina) resolutions
- Compress with OptiPNG or TinyPNG
- Save as PNG for illustrations, JPEG for photos

### Organization

```
assets/
├── audio/
│   ├── music/
│   ├── ambient/
│   └── sfx/
└── images/
    ├── backgrounds/
    └── portraits/
```

## Step 3: Initialize Media System

Update your `main.lua`:

```lua
-- Add media requires
local AssetManager = require("whisker.media.AssetManager")
local AudioManager = require("whisker.media.AudioManager")
local ImageManager = require("whisker.media.ImageManager")
local PreloadManager = require("whisker.media.PreloadManager")
local DummyBackend = require("whisker.media.backends.DummyAudioBackend")

function love.load()
  -- Initialize media
  AssetManager:initialize()
  AudioManager:initialize(DummyBackend.new())
  ImageManager:initialize()
  PreloadManager:initialize()

  -- Load asset manifest
  require("assets.manifest")

  -- Existing initialization
  StoryEngine:start()
end

function love.update(dt)
  -- Add media updates
  AudioManager:update(dt)
  ImageManager:update(dt)

  -- Existing updates
  StoryEngine:update(dt)
end
```

## Step 4: Register Assets

Create `assets/manifest.lua`:

```lua
local AssetManager = require("whisker.media.AssetManager")

-- Register music
AssetManager:register({
  id = "menu_theme",
  type = "audio",
  sources = {
    { format = "mp3", path = "assets/audio/music/menu.mp3" },
    { format = "ogg", path = "assets/audio/music/menu.ogg" }
  },
  metadata = { duration = 120, loop = true }
})

-- Register images
AssetManager:register({
  id = "title_screen",
  type = "image",
  variants = {
    { density = "1x", path = "assets/images/title.png" },
    { density = "2x", path = "assets/images/title@2x.png" }
  }
})

-- More registrations...
```

## Step 5: Add Media to Passages

Start with one passage and gradually add more:

### Before:
```
:: Forest Entrance
You stand at the edge of a dense forest.

A mysterious figure emerges from the trees.

[[Approach the figure|Forest Meeting]]
[[Turn back|Village]]
```

### After:
```
:: Forest Entrance
You stand at the edge of a dense forest.

@@audio:play forest_theme channel=MUSIC loop=true volume=0.7 fadeIn=2
@@image:show background_forest position=background fitMode=cover

A mysterious figure emerges from the trees.

@@image:show portrait_ranger position=left fadeIn=0.5

[[Approach the figure|Forest Meeting]]
[[Turn back|Village]]
```

## Step 6: Test Incrementally

1. **Test one passage**: Ensure media loads and plays correctly
2. **Test transitions**: Verify crossfades and image changes work
3. **Test memory**: Monitor cache usage with `AssetManager:getCacheStats()`
4. **Test platforms**: Verify on all target platforms

## Step 7: Optimize

### Preloading

Add preload directives to eliminate loading hitches:

```
:: Chapter Start
@@preload:audio forest_theme, forest_ambience, footstep
@@preload:image background_forest, portrait_ranger

[[Begin|Forest Entrance]]
```

### Memory Management

Unload previous chapter assets:

```lua
PreloadManager:unloadGroup("chapter_1")
PreloadManager:preloadGroup("chapter_2")
```

## Common Migration Issues

### Issue: Assets Don't Load

**Solution**: Check file paths in registration match actual file locations.

### Issue: Memory Exceeds Budget

**Solution**: Increase budget or unload unused assets:
```lua
AssetManager:setMemoryBudget(150 * 1024 * 1024)  -- 150MB
```

### Issue: Loading Pauses During Gameplay

**Solution**: Add preloading:
```
@@preload:audio next_music, next_ambient
```

## Gradual Migration Strategy

Don't add media everywhere at once. Prioritize:

1. **Title screen and main menu** - Sets first impression
2. **Major story beats** - Emotional moments benefit most
3. **Location transitions** - Music/ambience for each area
4. **Character introductions** - Portraits for main characters
5. **Background details** - SFX and secondary images

## Backward Compatibility

Your game still works without media:
- Missing assets are logged but don't crash
- Directives fail gracefully
- Text-only players get original experience

## Checklist

- [ ] Create asset directory structure
- [ ] Prepare audio files (MP3 + OGG)
- [ ] Prepare image files (1x + 2x)
- [ ] Update main.lua with media initialization
- [ ] Create asset manifest
- [ ] Add media to key passages
- [ ] Add preload directives
- [ ] Test on all platforms
- [ ] Optimize memory usage
