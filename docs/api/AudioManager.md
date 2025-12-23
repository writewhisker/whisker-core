# AudioManager API Reference

The AudioManager provides high-level audio playback with channels, crossfading, and ducking.

## Initialization

```lua
local AudioManager = require("whisker.media.AudioManager")
local DummyBackend = require("whisker.media.backends.DummyAudioBackend")

AudioManager:initialize(DummyBackend.new(), config)
```

**Config Options**:
- `masterVolume` (number): Initial master volume (0.0-1.0, default: 1.0)

## Methods

### play(assetId, options)

Play an audio asset.

**Parameters**:
- `assetId` (string): Asset ID to play
- `options` (table):
  - `channel` (string): Channel name ("MUSIC", "AMBIENT", "SFX", "VOICE")
  - `loop` (boolean): Whether to loop
  - `volume` (number): Volume level (0.0-1.0)
  - `fadeIn` (number): Fade in duration in seconds
  - `priority` (number): Priority for channel limiting

**Returns**: `sourceId` (number or nil)

**Example**:
```lua
local sourceId = AudioManager:play("forest_theme", {
  channel = "MUSIC",
  loop = true,
  volume = 0.7,
  fadeIn = 2
})
```

### stop(sourceId, options)

Stop a playing source.

**Parameters**:
- `sourceId` (number): Source ID from play()
- `options` (table):
  - `fadeOut` (number): Fade out duration in seconds

**Returns**: `success` (boolean)

**Example**:
```lua
AudioManager:stop(sourceId, { fadeOut = 1.5 })
```

### pause(sourceId)

Pause a playing source.

**Parameters**:
- `sourceId` (number): Source ID

**Returns**: `success` (boolean)

### resume(sourceId)

Resume a paused source.

**Parameters**:
- `sourceId` (number): Source ID

**Returns**: `success` (boolean)

### crossfade(fromSourceId, toAssetId, options)

Crossfade from one source to another.

**Parameters**:
- `fromSourceId` (number): Currently playing source ID
- `toAssetId` (string): Asset ID to crossfade to
- `options` (table):
  - `duration` (number): Crossfade duration in seconds (default: 2.0)
  - `channel` (string): Channel for new source
  - `loop` (boolean): Whether new source loops
  - `volume` (number): Target volume for new source

**Returns**: `newSourceId` (number or nil)

**Example**:
```lua
local newSourceId = AudioManager:crossfade(musicSourceId, "cave_theme", {
  duration = 3.0,
  loop = true,
  volume = 0.8
})
```

### setVolume(sourceId, volume)

Set volume for a source.

**Parameters**:
- `sourceId` (number): Source ID
- `volume` (number): Volume level (0.0-1.0)

**Returns**: `success` (boolean)

### getVolume(sourceId)

Get volume for a source.

**Parameters**:
- `sourceId` (number): Source ID

**Returns**: `volume` (number)

### isPlaying(sourceId)

Check if a source is playing.

**Parameters**:
- `sourceId` (number): Source ID

**Returns**: `boolean`

### setChannelVolume(channelName, volume)

Set volume for a channel.

**Parameters**:
- `channelName` (string): Channel name
- `volume` (number): Volume level (0.0-1.0)

**Returns**: `success` (boolean)

**Example**:
```lua
AudioManager:setChannelVolume("MUSIC", 0.5)
```

### getChannelVolume(channelName)

Get volume for a channel.

**Parameters**:
- `channelName` (string): Channel name

**Returns**: `volume` (number)

### setMasterVolume(volume)

Set the master volume.

**Parameters**:
- `volume` (number): Volume level (0.0-1.0)

### getMasterVolume()

Get the master volume.

**Returns**: `volume` (number)

### stopChannel(channelName, options)

Stop all sources on a channel.

**Parameters**:
- `channelName` (string): Channel name
- `options` (table):
  - `fadeOut` (number): Fade out duration

**Returns**: `success` (boolean)

### stopAll(options)

Stop all playing sources.

**Parameters**:
- `options` (table):
  - `fadeOut` (number): Fade out duration

### createChannel(name, config)

Create a custom audio channel.

**Parameters**:
- `name` (string): Channel name
- `config` (table):
  - `maxConcurrent` (number): Max simultaneous sources
  - `priority` (number): Channel priority
  - `volume` (number): Initial volume
  - `ducking` (table): Ducking configuration

**Returns**: `channel` (AudioChannel)

**Example**:
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

### getChannel(name)

Get a channel by name.

**Parameters**:
- `name` (string): Channel name

**Returns**: `channel` (AudioChannel or nil)

### update(dt)

Update the audio system. Call every frame.

**Parameters**:
- `dt` (number): Delta time in seconds

### shutdown()

Shut down the audio system.

## Default Channels

The AudioManager creates these channels by default:

| Channel | Max Concurrent | Priority | Default Volume |
|---------|---------------|----------|----------------|
| MUSIC   | 2             | 5        | 1.0            |
| AMBIENT | 5             | 4        | 1.0            |
| SFX     | 10            | 3        | 1.0            |
| VOICE   | 1             | 10       | 1.0            |

## Ducking Configuration

The VOICE channel is configured to duck other channels:

```lua
ducking = {
  MUSIC = 0.3,    -- Reduce music to 30%
  AMBIENT = 0.4,  -- Reduce ambient to 40%
  SFX = 0.7       -- Reduce SFX to 70%
}
```
