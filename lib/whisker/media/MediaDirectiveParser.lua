-- Media Directive Parser
-- Parses and executes WhiskerScript media directives (@@audio:, @@image:, @@preload:, @@video:)

local AudioManager = require("whisker.media.AudioManager")
local ImageManager = require("whisker.media.ImageManager")
local PreloadManager = require("whisker.media.PreloadManager")

local MediaDirectiveParser = {
  _VERSION = "1.0.0"
}

function MediaDirectiveParser:parse(directiveText)
  -- Parse directive into structured command
  -- Input: "@@audio:play forest_theme channel=MUSIC loop=true"
  -- Output: { type = "audio", command = "play", args = { ... }, params = { ... } }

  if not directiveText:match("^@@%w+:") then
    return nil, "Invalid directive format"
  end

  local directiveType, rest = directiveText:match("^@@(%w+):(.*)$")
  if not directiveType or directiveType == "" then
    return nil, "Missing directive type"
  end

  rest = rest or ""

  -- Parse command and arguments
  local parts = {}
  for part in rest:gmatch("%S+") do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return nil, "Missing command"
  end

  local command = parts[1]
  local args = {}
  local params = {}

  -- Parse arguments and parameters
  for i = 2, #parts do
    local part = parts[i]

    if part:match("=") then
      -- Parameter: key=value
      local key, value = part:match("([^=]+)=(.+)")
      if key and value then
        params[key] = self:_parseValue(value)
      end
    else
      -- Argument (handle comma-separated values)
      local cleanArg = part:gsub(",", "")
      if cleanArg ~= "" then
        table.insert(args, cleanArg)
      end
    end
  end

  return {
    type = directiveType,
    command = command,
    args = args,
    params = params,
    raw = directiveText
  }
end

function MediaDirectiveParser:_parseValue(value)
  -- Parse parameter value to appropriate type

  -- Boolean
  if value == "true" then
    return true
  elseif value == "false" then
    return false
  end

  -- Number
  local num = tonumber(value)
  if num then
    return num
  end

  -- String (remove quotes if present)
  if value:match("^['\"].*['\"]$") then
    return value:sub(2, -2)
  end

  -- Identifier
  return value
end

function MediaDirectiveParser:execute(directive)
  -- Execute parsed directive by calling appropriate manager

  if not directive or not directive.type then
    return false, "Invalid directive"
  end

  local success, err

  if directive.type == "audio" then
    success, err = self:_executeAudio(directive)
  elseif directive.type == "image" then
    success, err = self:_executeImage(directive)
  elseif directive.type == "preload" then
    success, err = self:_executePreload(directive)
  elseif directive.type == "video" then
    success, err = self:_executeVideo(directive)
  else
    return false, "Unknown directive type: " .. directive.type
  end

  return success, err
end

function MediaDirectiveParser:_executeAudio(directive)
  local command = directive.command
  local args = directive.args
  local params = directive.params

  if command == "play" then
    if #args < 1 then
      return false, "audio:play requires asset ID"
    end

    local assetId = args[1]
    local options = {
      channel = params.channel,
      loop = params.loop,
      volume = params.volume,
      fadeIn = params.fadeIn,
      priority = params.priority
    }

    local sourceId = AudioManager:play(assetId, options)
    return sourceId ~= nil, sourceId and tostring(sourceId) or "Failed to play audio"

  elseif command == "stop" then
    if #args < 1 then
      return false, "audio:stop requires asset ID or source ID"
    end

    local assetIdOrSourceId = args[1]
    local options = {
      fadeOut = params.fadeOut
    }

    -- If numeric, treat as source ID; otherwise, find source by asset ID
    local sourceId = tonumber(assetIdOrSourceId) or self:_findSourceByAssetId(assetIdOrSourceId)

    if sourceId then
      return AudioManager:stop(sourceId, options), nil
    else
      -- Try stopping by asset ID anyway
      return true, nil
    end

  elseif command == "pause" then
    if #args < 1 then return false, "audio:pause requires source ID" end
    local sourceId = tonumber(args[1])
    if not sourceId then return false, "Invalid source ID" end
    return AudioManager:pause(sourceId), nil

  elseif command == "resume" then
    if #args < 1 then return false, "audio:resume requires source ID" end
    local sourceId = tonumber(args[1])
    if not sourceId then return false, "Invalid source ID" end
    return AudioManager:resume(sourceId), nil

  elseif command == "volume" then
    if #args < 2 then
      return false, "audio:volume requires target and volume value"
    end

    local target = args[1]
    local volume = tonumber(args[2])

    if not volume then
      return false, "Invalid volume value"
    end

    -- Check if target is a channel name or source ID
    if AudioManager:getChannel(target) then
      return AudioManager:setChannelVolume(target, volume), nil
    else
      local sourceId = tonumber(target)
      if sourceId then
        return AudioManager:setVolume(sourceId, volume), nil
      else
        return false, "Invalid audio target: " .. target
      end
    end

  elseif command == "crossfade" then
    if #args < 2 then
      return false, "audio:crossfade requires from and to asset IDs"
    end

    local fromSourceId = self:_findSourceByAssetId(args[1])
    local toAssetId = args[2]

    if not fromSourceId then
      -- Try to start the crossfade anyway
      fromSourceId = tonumber(args[1])
    end

    local options = {
      duration = params.duration or 2.0,
      channel = params.channel,
      loop = params.loop,
      volume = params.volume
    }

    local newSourceId = AudioManager:crossfade(fromSourceId, toAssetId, options)
    return newSourceId ~= nil, newSourceId and tostring(newSourceId) or "Crossfade failed"

  elseif command == "channel" then
    if #args < 1 then
      return false, "audio:channel requires channel name"
    end

    local channelName = args[1]
    local volume = params.volume

    if volume then
      return AudioManager:setChannelVolume(channelName, volume), nil
    end

    return true, nil

  else
    return false, "Unknown audio command: " .. command
  end
end

function MediaDirectiveParser:_executeImage(directive)
  local command = directive.command
  local args = directive.args
  local params = directive.params

  if command == "show" then
    if #args < 1 then
      return false, "image:show requires asset ID"
    end

    local assetId = args[1]
    local options = {
      container = params.container or params.position or "default",
      fitMode = params.fitMode or "contain",
      fadeIn = params.fadeIn or 0
    }

    ImageManager:display(assetId, options)
    return true, nil

  elseif command == "hide" then
    if #args < 1 then
      return false, "image:hide requires container ID or asset ID"
    end

    local containerId = args[1]
    local options = {
      fadeOut = params.fadeOut or 0
    }

    return ImageManager:hide(containerId, options), nil

  elseif command == "clear" then
    -- Hide all displayed images
    if ImageManager._displayedImages then
      for containerId, _ in pairs(ImageManager._displayedImages) do
        ImageManager:hide(containerId)
      end
    end
    return true, nil

  else
    return false, "Unknown image command: " .. command
  end
end

function MediaDirectiveParser:_executePreload(directive)
  local command = directive.command
  local args = directive.args

  if command == "audio" or command == "image" then
    -- Preload specific assets
    if #args == 0 then
      return false, "preload requires at least one asset ID"
    end

    PreloadManager:preloadGroup(args, {
      priority = "normal"
    })
    return true, nil

  elseif command == "group" then
    if #args < 1 then
      return false, "preload:group requires group name"
    end

    local groupName = args[1]
    PreloadManager:preloadGroup(groupName, {
      priority = "normal"
    })
    return true, nil

  else
    return false, "Unknown preload command: " .. command
  end
end

function MediaDirectiveParser:_executeVideo(directive)
  -- Video not yet implemented
  return false, "Video directives not yet supported"
end

function MediaDirectiveParser:_findSourceByAssetId(assetId)
  -- Find active audio source by asset ID
  if not AudioManager._sources then
    return nil
  end

  for sourceId, entry in pairs(AudioManager._sources) do
    if entry.assetId == assetId then
      return sourceId
    end
  end
  return nil
end

function MediaDirectiveParser:extractDirectives(content)
  -- Extract all media directives from content
  local directives = {}

  for directiveText in content:gmatch("(@@%w+:[^\n]+)") do
    local directive, err = self:parse(directiveText)
    if directive then
      table.insert(directives, directive)
    end
  end

  return directives
end

function MediaDirectiveParser:processContent(content, options)
  -- Process content, executing directives and removing them from output
  options = options or {}
  local showErrors = options.showErrors or false

  local results = {}
  local processedContent = content

  -- Find all directives
  for directiveText in content:gmatch("(@@%w+:[^\n]+)") do
    local directive, parseErr = self:parse(directiveText)

    if directive then
      local success, execErr = self:execute(directive)

      table.insert(results, {
        directive = directive,
        success = success,
        error = execErr
      })

      if success then
        -- Remove successfully executed directive
        processedContent = processedContent:gsub(self:_escapePattern(directiveText), "")
      else
        if showErrors then
          -- Replace with error message
          processedContent = processedContent:gsub(
            self:_escapePattern(directiveText),
            "[ERROR: " .. tostring(execErr) .. "]"
          )
        else
          -- Remove failed directive silently
          processedContent = processedContent:gsub(self:_escapePattern(directiveText), "")
        end
      end
    else
      table.insert(results, {
        raw = directiveText,
        success = false,
        error = parseErr
      })

      if showErrors then
        processedContent = processedContent:gsub(
          self:_escapePattern(directiveText),
          "[ERROR: " .. tostring(parseErr) .. "]"
        )
      else
        processedContent = processedContent:gsub(self:_escapePattern(directiveText), "")
      end
    end
  end

  -- Clean up empty lines left by directive removal
  processedContent = processedContent:gsub("\n%s*\n", "\n")

  return processedContent, results
end

function MediaDirectiveParser:_escapePattern(str)
  -- Escape special pattern characters
  return str:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
end

return MediaDirectiveParser
