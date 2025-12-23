# Audio Design Guide

This guide explains advanced audio techniques for creating immersive soundscapes in whisker-core games.

## Multi-Channel Mixing

### Channel Philosophy

Each audio channel serves a distinct purpose:

- **MUSIC**: Sets emotional tone and atmosphere
- **AMBIENT**: Creates environmental immersion
- **SFX**: Provides interactive feedback
- **VOICE**: Conveys dialogue and narration

### Example: Forest Scene

```
:: Deep Forest
You venture deeper into the ancient forest.

@@audio:play forest_theme channel=MUSIC loop=true volume=0.6 fadeIn=3
@@audio:play forest_birds channel=AMBIENT loop=true volume=0.4 fadeIn=4
@@audio:play forest_wind channel=AMBIENT loop=true volume=0.3 fadeIn=5

@@audio:play footstep_leaves channel=SFX volume=0.7

A ranger appears from behind a tree.

@@audio:play dialogue_ranger_01 channel=VOICE volume=1.0

**Ranger**: "These woods are dangerous at night."
```

**Result**:
- Gentle music sets peaceful mood
- Layered ambient sounds create forest atmosphere
- Footstep SFX provides immediate feedback
- Dialogue plays clearly with music/ambient automatically ducked

## Ducking

Ducking automatically reduces background volumes when important audio plays.

### How It Works

The VOICE channel ducks other channels:

```lua
AudioManager:createChannel("VOICE", {
  maxConcurrent = 1,
  priority = 20,
  volume = 1.0,
  ducking = {
    MUSIC = 0.3,    -- Reduce music to 30%
    AMBIENT = 0.4,  -- Reduce ambient to 40%
    SFX = 0.7       -- Reduce SFX to 70%
  }
})
```

When dialogue finishes, other channels return to normal volume.

### Custom Ducking

```lua
AudioManager:createChannel("NARRATION", {
  maxConcurrent = 1,
  priority = 25,
  volume = 1.0,
  ducking = {
    MUSIC = 0.2,
    AMBIENT = 0.3
  }
})
```

## Crossfading

Crossfading smoothly transitions between tracks.

### When to Crossfade

- **Location changes**: Forest to Cave
- **Mood shifts**: Peaceful to Tense
- **Time transitions**: Day to Night
- **Story beats**: Calm to Battle

### Basic Crossfade

```
@@audio:crossfade forest_theme cave_theme duration=3
```

### Crossfade with Options

```
@@audio:crossfade old_music new_music duration=5 channel=MUSIC loop=true volume=0.8
```

### Crossfade Timing

- **Fast (1-2s)**: Abrupt transitions, high energy
- **Medium (3-4s)**: Standard scene changes
- **Slow (5-8s)**: Gradual mood shifts, cinematic moments

## Looping

### Seamless Loops

```
@@audio:play ocean_waves channel=AMBIENT loop=true volume=0.5
```

Ensure your audio files loop seamlessly (no clicks/pops at loop point).

### Creating Loop Points

Many audio editors support loop markers:
- Audacity: Analysis > Find Loop Points
- Logic Pro: Region > Loop
- Reaper: Item Properties > Loop Source

## Volume Balancing

### Channel Volume Hierarchy

Typical volume levels:

- **MUSIC**: 0.6-0.8 (noticeable but not overwhelming)
- **AMBIENT**: 0.3-0.6 (subtle background)
- **SFX**: 0.7-1.0 (clear and immediate)
- **VOICE**: 0.9-1.0 (always clear)

### Dynamic Volume Adjustments

```
:: Tense Moment
@@audio:volume MUSIC 0.3
@@audio:play heartbeat channel=AMBIENT loop=true volume=0.8

:: Safe Area
@@audio:volume MUSIC 0.7
@@audio:stop heartbeat fadeOut=2
```

### Master Volume

```lua
AudioManager:setMasterVolume(0.8)
```

## Audio Layering

Layer multiple ambient tracks for rich environments:

### Example: Stormy Night

```
@@audio:play rain_heavy channel=AMBIENT loop=true volume=0.6
@@audio:play thunder_distant channel=AMBIENT loop=true volume=0.4
@@audio:play wind_howling channel=AMBIENT loop=true volume=0.5
```

**Tips**:
- Start each layer with slightly offset fade-ins
- Use complementary sounds
- Limit to 2-4 simultaneous ambient layers

## Common Patterns

### Pattern: Location Ambience

```
:: Forest
@@audio:play forest_ambience channel=AMBIENT loop=true volume=0.5 fadeIn=2

:: Cave
@@audio:stop forest_ambience fadeOut=2
@@audio:play cave_ambience channel=AMBIENT loop=true volume=0.5 fadeIn=2
```

### Pattern: Emotional Music

```
:: Calm Scene
@@audio:play peaceful_theme channel=MUSIC loop=true volume=0.7

:: Danger Appears
@@audio:crossfade peaceful_theme danger_theme duration=2 loop=true volume=0.8

:: Danger Resolved
@@audio:crossfade danger_theme peaceful_theme duration=4 loop=true volume=0.7
```

### Pattern: UI Feedback

```
[[Open the door|Next Room]]
@@audio:play door_open channel=SFX volume=0.8

[[Pick up the key|Inventory]]
@@audio:play item_pickup channel=SFX volume=0.7
```

## Audio File Formats

### Recommended Formats

- **Music**: MP3 (128-192 kbps) + OGG Vorbis (128 kbps)
- **Ambient**: OGG Vorbis (96-128 kbps)
- **SFX**: WAV (uncompressed) or OGG (64-96 kbps)
- **Voice**: MP3 (96-128 kbps)

### Format Selection

Whisker-core automatically selects the best supported format:

```lua
sources = {
  { format = "ogg", path = "audio/music.ogg" },
  { format = "mp3", path = "audio/music.mp3" }
}
```

## Performance

### Concurrent Sound Limits

```lua
AudioManager:createChannel("SFX", {
  maxConcurrent = 10
})
```

### Preloading Strategies

```
:: Chapter 2 Intro
@@preload:audio cave_theme, cave_ambience, cave_drip, echo_sfx

[[Continue|Cave Entrance]]
```

### Memory Management

```lua
PreloadManager:unloadGroup("chapter_1_audio")
PreloadManager:preloadGroup("chapter_2_audio")
```

## Tools and Resources

### Audio Editing
- **Audacity** (free): Basic editing
- **Reaper** (affordable): Professional DAW
- **Logic Pro** / **Ableton Live**: Professional production

### Sound Libraries
- **Freesound.org**: Free sound effects (CC licensed)
- **OpenGameArt.org**: Free game audio
- **Incompetech.com**: Free music by Kevin MacLeod
