-- Asset Schema Definitions
-- Validates asset configurations and metadata

local Schemas = {
  _VERSION = "1.0.0"
}

-- Audio asset schema
Schemas.AudioAsset = {
  required = {"id", "type", "sources"},
  optional = {"metadata"},
  fields = {
    id = {type = "string", minLength = 1},
    type = {type = "string", enum = {"audio"}},
    sources = {
      type = "array",
      minItems = 1,
      items = {
        required = {"format", "path"},
        fields = {
          format = {type = "string"},
          path = {type = "string"}
        }
      }
    },
    metadata = {
      type = "object",
      fields = {
        duration = {type = "number", min = 0},
        loop = {type = "boolean"},
        bpm = {type = "number", min = 0},
        loopStart = {type = "number", min = 0},
        loopEnd = {type = "number", min = 0},
        tags = {type = "array", items = {type = "string"}}
      }
    }
  }
}

-- Image asset schema
Schemas.ImageAsset = {
  required = {"id", "type", "variants"},
  optional = {"metadata"},
  fields = {
    id = {type = "string", minLength = 1},
    type = {type = "string", enum = {"image"}},
    variants = {
      type = "array",
      minItems = 1,
      items = {
        required = {"density", "path"},
        fields = {
          density = {type = "string"},
          path = {type = "string"},
          width = {type = "number", min = 1},
          height = {type = "number", min = 1}
        }
      }
    },
    metadata = {
      type = "object",
      fields = {
        width = {type = "number", min = 1},
        height = {type = "number", min = 1},
        alt = {type = "string"},
        tags = {type = "array", items = {type = "string"}}
      }
    }
  }
}

-- Video asset schema
Schemas.VideoAsset = {
  required = {"id", "type", "sources"},
  optional = {"metadata"},
  fields = {
    id = {type = "string", minLength = 1},
    type = {type = "string", enum = {"video"}},
    sources = {
      type = "array",
      minItems = 1,
      items = {
        required = {"format", "path"},
        fields = {
          format = {type = "string"},
          path = {type = "string"}
        }
      }
    },
    metadata = {
      type = "object",
      fields = {
        duration = {type = "number", min = 0},
        width = {type = "number", min = 1},
        height = {type = "number", min = 1},
        tags = {type = "array", items = {type = "string"}}
      }
    }
  }
}

-- Preload group schema
Schemas.PreloadGroup = {
  required = {"name", "assetIds"},
  optional = {"priority"},
  fields = {
    name = {type = "string", minLength = 1},
    assetIds = {type = "array", items = {type = "string"}},
    priority = {type = "string", enum = {"low", "normal", "high"}}
  }
}

-- Validate a value against a field schema
local function validateField(value, schema, path)
  local errors = {}

  if schema.type then
    local actualType = type(value)

    if schema.type == "array" then
      if actualType ~= "table" then
        table.insert(errors, {path = path, message = "Expected array, got " .. actualType})
        return errors
      end
    elseif schema.type == "object" then
      if actualType ~= "table" then
        table.insert(errors, {path = path, message = "Expected object, got " .. actualType})
        return errors
      end
    elseif actualType ~= schema.type then
      table.insert(errors, {path = path, message = "Expected " .. schema.type .. ", got " .. actualType})
      return errors
    end
  end

  if schema.type == "string" then
    if schema.minLength and #value < schema.minLength then
      table.insert(errors, {path = path, message = "String length must be at least " .. schema.minLength})
    end
    if schema.enum then
      local valid = false
      for _, v in ipairs(schema.enum) do
        if value == v then valid = true; break end
      end
      if not valid then
        table.insert(errors, {path = path, message = "Value must be one of: " .. table.concat(schema.enum, ", ")})
      end
    end
  end

  if schema.type == "number" then
    if schema.min and value < schema.min then
      table.insert(errors, {path = path, message = "Value must be at least " .. schema.min})
    end
    if schema.max and value > schema.max then
      table.insert(errors, {path = path, message = "Value must be at most " .. schema.max})
    end
  end

  if schema.type == "array" then
    if schema.minItems and #value < schema.minItems then
      table.insert(errors, {path = path, message = "Array must have at least " .. schema.minItems .. " items"})
    end
    if schema.items then
      for i, item in ipairs(value) do
        local itemPath = path .. "[" .. i .. "]"
        if schema.items.fields then
          local itemErrors = Schemas.validate(item, schema.items)
          for _, err in ipairs(itemErrors) do
            err.path = itemPath .. "." .. (err.path or "")
            table.insert(errors, err)
          end
        else
          local fieldErrors = validateField(item, schema.items, itemPath)
          for _, err in ipairs(fieldErrors) do
            table.insert(errors, err)
          end
        end
      end
    end
  end

  if schema.type == "object" and schema.fields then
    for fieldName, fieldSchema in pairs(schema.fields) do
      local fieldValue = value[fieldName]
      if fieldValue ~= nil then
        local fieldPath = path .. "." .. fieldName
        local fieldErrors = validateField(fieldValue, fieldSchema, fieldPath)
        for _, err in ipairs(fieldErrors) do
          table.insert(errors, err)
        end
      end
    end
  end

  return errors
end

-- Validate an object against a schema
function Schemas.validate(obj, schema)
  local errors = {}

  if type(obj) ~= "table" then
    return {{path = "", message = "Expected object, got " .. type(obj)}}
  end

  if schema.required then
    for _, fieldName in ipairs(schema.required) do
      if obj[fieldName] == nil then
        table.insert(errors, {path = fieldName, message = "Required field missing"})
      end
    end
  end

  if schema.fields then
    for fieldName, fieldSchema in pairs(schema.fields) do
      local value = obj[fieldName]
      if value ~= nil then
        local fieldErrors = validateField(value, fieldSchema, fieldName)
        for _, err in ipairs(fieldErrors) do
          table.insert(errors, err)
        end
      end
    end
  end

  return errors
end

function Schemas.validateAudioAsset(config)
  return Schemas.validate(config, Schemas.AudioAsset)
end

function Schemas.validateImageAsset(config)
  return Schemas.validate(config, Schemas.ImageAsset)
end

function Schemas.validateVideoAsset(config)
  return Schemas.validate(config, Schemas.VideoAsset)
end

function Schemas.validateAsset(config)
  if not config or not config.type then
    return {{path = "type", message = "Asset type is required"}}
  end

  if config.type == "audio" then
    return Schemas.validateAudioAsset(config)
  elseif config.type == "image" then
    return Schemas.validateImageAsset(config)
  elseif config.type == "video" then
    return Schemas.validateVideoAsset(config)
  else
    return {{path = "type", message = "Unknown asset type: " .. config.type}}
  end
end

return Schemas
