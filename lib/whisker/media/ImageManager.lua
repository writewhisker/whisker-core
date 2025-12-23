-- Image Manager
-- Manages image display with responsive variants and containers

local Types = require("whisker.media.types")
local AssetManager = require("whisker.media.AssetManager")

local ImageManager = {
  _VERSION = "1.0.0",

  _containers = {},
  _displayedImages = {},
  _devicePixelRatio = 1,
  _initialized = false
}

function ImageManager:initialize(config)
  config = config or {}

  self._containers = {}
  self._displayedImages = {}
  self._devicePixelRatio = config.devicePixelRatio or 1
  self._defaultFitMode = config.defaultFitMode or Types.FitMode.CONTAIN

  -- Create default containers
  self:createContainer("background", {
    x = 0, y = 0,
    width = config.screenWidth or 800,
    height = config.screenHeight or 600,
    zIndex = 0
  })

  self:createContainer("left", {
    x = 0, y = 0,
    width = (config.screenWidth or 800) / 3,
    height = config.screenHeight or 600,
    zIndex = 10
  })

  self:createContainer("center", {
    x = (config.screenWidth or 800) / 3, y = 0,
    width = (config.screenWidth or 800) / 3,
    height = config.screenHeight or 600,
    zIndex = 10
  })

  self:createContainer("right", {
    x = 2 * (config.screenWidth or 800) / 3, y = 0,
    width = (config.screenWidth or 800) / 3,
    height = config.screenHeight or 600,
    zIndex = 10
  })

  self._initialized = true

  return self
end

function ImageManager:createContainer(containerId, config)
  config = config or {}

  self._containers[containerId] = {
    id = containerId,
    x = config.x or 0,
    y = config.y or 0,
    width = config.width or 100,
    height = config.height or 100,
    zIndex = config.zIndex or 0,
    visible = config.visible ~= false
  }

  return self._containers[containerId]
end

function ImageManager:getContainer(containerId)
  return self._containers[containerId]
end

function ImageManager:removeContainer(containerId)
  -- Hide image first if displayed
  if self._displayedImages[containerId] then
    self:hide(containerId)
  end

  self._containers[containerId] = nil
end

function ImageManager:display(assetId, options)
  if not self._initialized then
    self:initialize()
  end

  options = options or {}
  local containerId = options.container or options.position or "center"

  -- Ensure container exists
  if not self._containers[containerId] then
    self:createContainer(containerId, options)
  end

  -- Get asset from AssetManager
  local asset = AssetManager:get(assetId)

  if not asset then
    local loadedAsset, err = AssetManager:loadSync(assetId)
    if not loadedAsset then
      return false, err
    end
    asset = loadedAsset
  end

  -- Select appropriate variant
  local variant = self:_selectVariant(assetId)

  -- Hide existing image in container
  if self._displayedImages[containerId] then
    self:hide(containerId)
  end

  -- Create display info
  local displayInfo = {
    assetId = assetId,
    containerId = containerId,
    asset = asset,
    variant = variant,
    fitMode = options.fitMode or self._defaultFitMode,
    opacity = 1.0,
    targetOpacity = 1.0,
    fadeTime = options.fadeIn or 0,
    fadeElapsed = 0,
    fading = options.fadeIn and options.fadeIn > 0,
    visible = true
  }

  if displayInfo.fading then
    displayInfo.opacity = 0
  end

  self._displayedImages[containerId] = displayInfo

  -- Retain asset
  AssetManager:retain(assetId)

  return true
end

function ImageManager:hide(containerId, options)
  options = options or {}

  local displayInfo = self._displayedImages[containerId]
  if not displayInfo then
    return false
  end

  if options.fadeOut and options.fadeOut > 0 then
    displayInfo.fading = true
    displayInfo.fadeTime = options.fadeOut
    displayInfo.fadeElapsed = 0
    displayInfo.targetOpacity = 0
    return true
  end

  return self:_removeDisplay(containerId)
end

function ImageManager:_removeDisplay(containerId)
  local displayInfo = self._displayedImages[containerId]
  if not displayInfo then
    return false
  end

  -- Release asset
  AssetManager:release(displayInfo.assetId)

  self._displayedImages[containerId] = nil

  return true
end

function ImageManager:hideAll(options)
  for containerId, _ in pairs(self._displayedImages) do
    self:hide(containerId, options)
  end
end

function ImageManager:isDisplayed(assetId)
  for _, displayInfo in pairs(self._displayedImages) do
    if displayInfo.assetId == assetId then
      return true
    end
  end
  return false
end

function ImageManager:getDisplayedImage(containerId)
  return self._displayedImages[containerId]
end

function ImageManager:getAllDisplayedImages()
  local images = {}
  for containerId, displayInfo in pairs(self._displayedImages) do
    images[containerId] = {
      assetId = displayInfo.assetId,
      containerId = containerId,
      fitMode = displayInfo.fitMode,
      opacity = displayInfo.opacity
    }
  end
  return images
end

function ImageManager:setOpacity(containerId, opacity)
  local displayInfo = self._displayedImages[containerId]
  if not displayInfo then
    return false
  end

  displayInfo.opacity = math.max(0, math.min(1, opacity))
  displayInfo.targetOpacity = displayInfo.opacity
  displayInfo.fading = false

  return true
end

function ImageManager:getOpacity(containerId)
  local displayInfo = self._displayedImages[containerId]
  return displayInfo and displayInfo.opacity or 0
end

function ImageManager:setFitMode(containerId, fitMode)
  local displayInfo = self._displayedImages[containerId]
  if not displayInfo then
    return false
  end

  displayInfo.fitMode = fitMode
  return true
end

function ImageManager:update(dt)
  local toRemove = {}

  for containerId, displayInfo in pairs(self._displayedImages) do
    if displayInfo.fading then
      displayInfo.fadeElapsed = displayInfo.fadeElapsed + dt

      local progress = math.min(1, displayInfo.fadeElapsed / displayInfo.fadeTime)
      local startOpacity = displayInfo.targetOpacity == 0 and 1 or 0
      displayInfo.opacity = startOpacity + (displayInfo.targetOpacity - startOpacity) * progress

      if progress >= 1 then
        displayInfo.fading = false
        displayInfo.opacity = displayInfo.targetOpacity

        if displayInfo.targetOpacity == 0 then
          table.insert(toRemove, containerId)
        end
      end
    end
  end

  for _, containerId in ipairs(toRemove) do
    self:_removeDisplay(containerId)
  end
end

function ImageManager:_selectVariant(assetId)
  local config = AssetManager:getConfig(assetId)
  if not config or not config.variants then
    return nil
  end

  local variants = config.variants

  -- Select variant based on device pixel ratio
  local targetDensity = self._devicePixelRatio >= 2 and "2x" or "1x"

  for _, variant in ipairs(variants) do
    if variant.density == targetDensity then
      return variant
    end
  end

  -- Fallback to first variant
  return variants[1]
end

function ImageManager:setDevicePixelRatio(ratio)
  self._devicePixelRatio = ratio
end

function ImageManager:getDevicePixelRatio()
  return self._devicePixelRatio
end

function ImageManager:calculateFitDimensions(imageWidth, imageHeight, containerWidth, containerHeight, fitMode)
  fitMode = fitMode or Types.FitMode.CONTAIN

  local scaleX = containerWidth / imageWidth
  local scaleY = containerHeight / imageHeight
  local scale

  if fitMode == Types.FitMode.CONTAIN then
    scale = math.min(scaleX, scaleY)
  elseif fitMode == Types.FitMode.COVER then
    scale = math.max(scaleX, scaleY)
  elseif fitMode == Types.FitMode.FILL then
    return containerWidth, containerHeight, 0, 0
  else -- NONE
    scale = 1
  end

  local finalWidth = imageWidth * scale
  local finalHeight = imageHeight * scale

  -- Center the image
  local offsetX = (containerWidth - finalWidth) / 2
  local offsetY = (containerHeight - finalHeight) / 2

  return finalWidth, finalHeight, offsetX, offsetY
end

function ImageManager:registerImage(config)
  -- Convenience method that delegates to AssetManager
  config.type = "image"
  return AssetManager:register(config)
end

return ImageManager
