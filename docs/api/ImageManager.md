# ImageManager API Reference

The ImageManager handles image display with responsive variants and fit modes.

## Initialization

```lua
local ImageManager = require("whisker.media.ImageManager")
ImageManager:initialize(config)
```

**Config Options**:
- `devicePixelRatio` (number): Device pixel ratio (default: 1)

## Methods

### createContainer(containerId, config)

Create an image display container.

**Parameters**:
- `containerId` (string): Unique container identifier
- `config` (table):
  - `x` (number): X position
  - `y` (number): Y position
  - `width` (number): Container width
  - `height` (number): Container height

**Returns**: `success` (boolean)

**Example**:
```lua
ImageManager:createContainer("portrait_left", {
  x = 50,
  y = 100,
  width = 300,
  height = 400
})
```

### removeContainer(containerId)

Remove a display container.

**Parameters**:
- `containerId` (string): Container ID

**Returns**: `success` (boolean)

### getContainer(containerId)

Get a container by ID.

**Parameters**:
- `containerId` (string): Container ID

**Returns**: `container` (table or nil)

### display(assetId, options)

Display an image in a container.

**Parameters**:
- `assetId` (string): Image asset ID
- `options` (table):
  - `container` (string): Container ID (default: "default")
  - `fitMode` (string): "contain", "cover", or "fill"
  - `fadeIn` (number): Fade in duration in seconds
  - `variant` (string): Specific variant to use

**Returns**: `success` (boolean)

**Example**:
```lua
ImageManager:display("portrait_alice", {
  container = "portrait_left",
  fitMode = "contain",
  fadeIn = 0.5
})
```

### hide(containerId, options)

Hide an image from a container.

**Parameters**:
- `containerId` (string): Container ID
- `options` (table):
  - `fadeOut` (number): Fade out duration in seconds

**Returns**: `success` (boolean)

**Example**:
```lua
ImageManager:hide("portrait_left", { fadeOut = 0.3 })
```

### calculateFitDimensions(imageWidth, imageHeight, containerWidth, containerHeight, fitMode)

Calculate fitted dimensions for an image.

**Parameters**:
- `imageWidth` (number): Source image width
- `imageHeight` (number): Source image height
- `containerWidth` (number): Container width
- `containerHeight` (number): Container height
- `fitMode` (string): "contain", "cover", or "fill"

**Returns**: `width`, `height`, `offsetX`, `offsetY` (numbers)

**Example**:
```lua
local w, h, x, y = ImageManager:calculateFitDimensions(
  800, 600,   -- image size
  400, 300,   -- container size
  "contain"
)
```

### setDevicePixelRatio(dpr)

Set the device pixel ratio for variant selection.

**Parameters**:
- `dpr` (number): Device pixel ratio (1, 2, 3, etc.)

### getDevicePixelRatio()

Get the current device pixel ratio.

**Returns**: `dpr` (number)

### selectVariant(assetConfig)

Select the best variant for current device.

**Parameters**:
- `assetConfig` (table): Asset configuration with variants

**Returns**: `variant` (table)

### update(dt)

Update image transitions. Call every frame.

**Parameters**:
- `dt` (number): Delta time in seconds

### registerImage(config)

Register an image asset (convenience method).

**Parameters**:
- `config` (table): Image asset configuration

**Returns**: `success` (boolean), `error` (table or nil)

## Fit Modes

| Mode | Description |
|------|-------------|
| `contain` | Scale to fit inside container, maintaining aspect ratio (letterboxing) |
| `cover` | Scale to cover container, maintaining aspect ratio (may crop) |
| `fill` | Stretch to fill container exactly (may distort) |

## Image Variants

Register multiple variants for responsive images:

```lua
AssetManager:register({
  id = "portrait_alice",
  type = "image",
  variants = {
    { density = "1x", path = "images/alice.png" },
    { density = "2x", path = "images/alice@2x.png" },
    { density = "thumbnail", path = "images/alice_thumb.png" }
  }
})
```

The ImageManager automatically selects the appropriate variant based on:
1. Device pixel ratio
2. Container size
3. Available variants

## Container Properties

Each container has:

```lua
{
  id = "container_id",
  x = 0,
  y = 0,
  width = 400,
  height = 300,
  currentImage = nil,  -- Currently displayed asset ID
  alpha = 1.0,         -- Current opacity
  transitioning = false
}
```
