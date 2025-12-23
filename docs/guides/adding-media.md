# Adding Media to Your Story

This guide teaches you how to integrate audio, images, and other media into your whisker-core interactive fiction game.

## Quick Start

### 1. Register Your Assets

First, tell whisker-core about your media files:

```lua
local AssetManager = require("whisker.media.AssetManager")
local ImageManager = require("whisker.media.ImageManager")

-- Register background music
AssetManager:register({
  id = "forest_theme",
  type = "audio",
  sources = {
    { format = "mp3", path = "assets/audio/forest_theme.mp3" },
    { format = "ogg", path = "assets/audio/forest_theme.ogg" }
  },
  metadata = {
    duration = 180,
    loop = true
  }
})

-- Register character portrait
AssetManager:register({
  id = "portrait_alice",
  type = "image",
  variants = {
    { density = "1x", path = "assets/images/alice.png" },
    { density = "2x", path = "assets/images/alice@2x.png" }
  },
  metadata = {
    width = 400,
    height = 600,
    alt = "Alice, a young woman with red hair"
  }
})
```

### 2. Use Media in Passages

Add media directives directly in your passage text:

```
:: Forest Entrance
You stand at the edge of a dense forest.

@@audio:play forest_theme channel=MUSIC loop=true volume=0.7 fadeIn=2
@@image:show portrait_alice position=left fadeIn=0.5

A mysterious figure emerges from the trees.

[[Approach the figure|Forest Meeting]]
[[Turn back|Village]]
```

### 3. Initialize the Media System

In your game's main.lua:

```lua
local AudioManager = require("whisker.media.AudioManager")
local ImageManager = require("whisker.media.ImageManager")
local DummyBackend = require("whisker.media.backends.DummyAudioBackend")

function love.load()
  -- Initialize media managers
  AudioManager:initialize(DummyBackend.new())
  ImageManager:initialize()

  -- Start your story
  StoryEngine:start()
end

function love.update(dt)
  AudioManager:update(dt)
  ImageManager:update(dt)
  StoryEngine:update(dt)
end
```

## Organizing Your Assets

### Directory Structure

```
your-game/
├── main.lua
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   │   ├── forest_theme.mp3
│   │   │   └── cave_theme.mp3
│   │   ├── ambient/
│   │   │   ├── forest_ambience.ogg
│   │   │   └── cave_drip.ogg
│   │   └── sfx/
│   │       ├── footstep.wav
│   │       └── door_open.wav
│   └── images/
│       ├── backgrounds/
│       │   ├── forest.jpg
│       │   └── forest@2x.jpg
│       └── portraits/
│           ├── alice.png
│           ├── alice@2x.png
│           ├── bob.png
│           └── bob@2x.png
└── passages/
    └── story.twee
```

### Asset Naming Conventions

- **Music**: `{location}_{mood}_theme.mp3` (e.g., `forest_peaceful_theme.mp3`)
- **Ambient**: `{environment}_{detail}.ogg` (e.g., `forest_birds.ogg`)
- **SFX**: `{action}_{variant}.wav` (e.g., `footstep_grass.wav`)
- **Images**: `{subject}_{descriptor}.png` (e.g., `portrait_alice_happy.png`)
- **Retina images**: Add `@2x` before extension (e.g., `portrait_alice@2x.png`)

## Audio Basics

### Playing Background Music

```
@@audio:play forest_theme channel=MUSIC loop=true volume=0.7 fadeIn=2
```

**Parameters**:
- `channel`: MUSIC, AMBIENT, SFX, or VOICE
- `loop`: true/false - whether to loop playback
- `volume`: 0.0 to 1.0 - volume level
- `fadeIn`: seconds to fade in from silence

### Stopping Audio

```
@@audio:stop forest_theme fadeOut=1.5
```

### Crossfading Between Tracks

```
@@audio:crossfade forest_theme cave_theme duration=3
```

### Playing Sound Effects

```
@@audio:play footstep channel=SFX volume=0.8
```

## Image Basics

### Showing Images

```
@@image:show portrait_alice position=left fitMode=cover fadeIn=0.5
```

**Parameters**:
- `position`: Container ID (e.g., "left", "right", "center", "background")
- `fitMode`: contain, cover, or fill
- `fadeIn`: seconds to fade in

**Fit Modes**:
- `contain`: Scale to fit inside container, maintaining aspect ratio
- `cover`: Scale to cover container, may crop
- `fill`: Stretch to fill container exactly

### Hiding Images

```
@@image:hide portrait_alice fadeOut=0.3
```

### Clearing All Images

```
@@image:clear
```

## Preloading

Preload assets before they're needed:

```
:: Chapter 1 Start
@@preload:audio cave_theme, cave_ambience, echo_sfx
@@preload:image background_cave, portrait_miner

[[Continue|Cave Entrance]]
```

Or preload entire groups:

```lua
PreloadManager:registerGroup("chapter_2", {
  "cave_theme",
  "cave_ambience",
  "background_cave",
  "portrait_miner"
})
```

```
@@preload:group chapter_2
```

## Audio Channels

Whisker-core provides four audio channels:

- **MUSIC**: Background music, typically one track at a time
- **AMBIENT**: Environmental sounds, can layer multiple
- **SFX**: Sound effects, many concurrent sounds
- **VOICE**: Dialogue and narration, highest priority

### Channel Volume Control

```
@@audio:volume MUSIC 0.5
@@audio:volume AMBIENT 0.3
```

### Automatic Ducking

When audio plays on the VOICE channel, MUSIC and AMBIENT automatically reduce volume so dialogue is clear.

## Responsive Images

Provide multiple image sizes for different screen resolutions:

```lua
AssetManager:register({
  id = "portrait_alice",
  type = "image",
  variants = {
    { density = "1x", path = "assets/images/alice.png" },
    { density = "2x", path = "assets/images/alice@2x.png" },
    { density = "thumbnail", path = "assets/images/alice_thumb.png" }
  }
})
```

## Best Practices

### 1. Use Multiple Formats

```lua
sources = {
  { format = "mp3", path = "audio/music.mp3" },
  { format = "ogg", path = "audio/music.ogg" }
}
```

### 2. Optimize File Sizes

- **Audio**: Use 128kbps MP3 for music, 64kbps for SFX
- **Images**: Compress PNGs with OptiPNG or TinyPNG

### 3. Preload Strategically

```
:: Forest Area
@@preload:group forest_assets

:: Cave Area
@@preload:group cave_assets
```

### 4. Use Fade Transitions

```
@@audio:play music fadeIn=2
@@audio:stop music fadeOut=1.5
@@image:show portrait fadeIn=0.5
```

### 5. Manage Memory

```lua
PreloadManager:unloadGroup("chapter_1_assets")
PreloadManager:preloadGroup("chapter_2_assets")
```

## Troubleshooting

### Audio Doesn't Play

1. Check file path is correct
2. Verify format support
3. Check console for errors

### Images Don't Appear

1. Verify image is registered with correct ID
2. Check container ID exists
3. Check console for loading errors

### Loading Is Slow

1. Preload assets using `@@preload:` directives
2. Optimize file sizes
3. Check memory budget

## Next Steps

- Read the [Audio Design Guide](audio-mixing.md)
- Explore the [API Reference](../api/AssetManager.md)
