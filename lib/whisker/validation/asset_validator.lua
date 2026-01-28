--- Asset Validator - Validates asset references in story content
-- WLS 1.0 Gap 24: Asset Errors (AST)
-- @module whisker.validation.asset_validator

local AssetValidator = {}
AssetValidator.__index = AssetValidator

--- Supported asset types per category
AssetValidator.SUPPORTED_IMAGE_TYPES = {
    png = true, jpg = true, jpeg = true, gif = true, svg = true, webp = true
}

AssetValidator.SUPPORTED_AUDIO_TYPES = {
    mp3 = true, wav = true, ogg = true, m4a = true, flac = true
}

AssetValidator.SUPPORTED_VIDEO_TYPES = {
    mp4 = true, webm = true, ogv = true
}

--- Size limits (in bytes)
AssetValidator.MAX_IMAGE_SIZE = 10 * 1024 * 1024  -- 10MB
AssetValidator.MAX_AUDIO_SIZE = 50 * 1024 * 1024  -- 50MB
AssetValidator.MAX_VIDEO_SIZE = 100 * 1024 * 1024 -- 100MB

--- Error codes
AssetValidator.ERROR_CODES = {
    MISSING_ASSET = "WLS-AST-001",
    INVALID_ASSET_PATH = "WLS-AST-002",
    UNSUPPORTED_ASSET_TYPE = "WLS-AST-003",
    ASSET_TOO_LARGE = "WLS-AST-004",
}

--- Create new asset validator
---@param config table Configuration options
---@return table AssetValidator instance
function AssetValidator.new(config)
    local self = setmetatable({}, AssetValidator)
    config = config or {}
    self.base_path = config.base_path or "."
    self.check_existence = config.check_existence ~= false
    self.check_size = config.check_size or false
    return self
end

--- Validate an asset reference
---@param asset_type string "image", "audio", "video", "embed"
---@param path string Asset path
---@param location table|nil Source location
---@return table diagnostics
function AssetValidator:validate(asset_type, path, location)
    local diagnostics = {}

    -- Check for empty path
    if not path or path == "" then
        table.insert(diagnostics, {
            code = self.ERROR_CODES.INVALID_ASSET_PATH,
            message = "Empty asset path",
            severity = "error",
            location = location
        })
        return diagnostics
    end

    -- Skip validation for external URLs (must check before invalid char check)
    if path:match("^https?://") then
        return diagnostics  -- External URLs are not validated locally
    end

    -- Check for invalid characters in path (local files only)
    if path:match("[<>:\"|?*]") then
        table.insert(diagnostics, {
            code = self.ERROR_CODES.INVALID_ASSET_PATH,
            message = string.format('Invalid characters in asset path: "%s"', path),
            severity = "error",
            location = location
        })
        return diagnostics
    end

    -- Check file extension
    local ext = path:match("%.([^%.]+)$")
    if ext then
        ext = ext:lower()
        local supported = self:is_supported_type(asset_type, ext)
        if not supported then
            table.insert(diagnostics, {
                code = self.ERROR_CODES.UNSUPPORTED_ASSET_TYPE,
                message = string.format(
                    'Unsupported %s type: .%s',
                    asset_type, ext
                ),
                severity = "warning",
                location = location,
                suggestion = "Use a supported format for " .. asset_type
            })
        end
    end

    -- Check file existence
    if self.check_existence then
        local full_path = self:resolve_path(path)
        if not self:file_exists(full_path) then
            table.insert(diagnostics, {
                code = self.ERROR_CODES.MISSING_ASSET,
                message = string.format('Missing asset file: "%s"', path),
                severity = "error",
                location = location,
                suggestion = "Ensure the file exists at: " .. full_path
            })
        elseif self.check_size then
            -- Check file size
            local size = self:get_file_size(full_path)
            local max_size = self:get_max_size(asset_type)
            if size and size > max_size then
                table.insert(diagnostics, {
                    code = self.ERROR_CODES.ASSET_TOO_LARGE,
                    message = string.format(
                        'Asset too large: %s (%.2f MB, max %.2f MB)',
                        path, size / 1024 / 1024, max_size / 1024 / 1024
                    ),
                    severity = "warning",
                    location = location
                })
            end
        end
    end

    return diagnostics
end

--- Check if extension is supported for asset type
---@param asset_type string
---@param ext string
---@return boolean
function AssetValidator:is_supported_type(asset_type, ext)
    if asset_type == "image" then
        return self.SUPPORTED_IMAGE_TYPES[ext]
    elseif asset_type == "audio" then
        return self.SUPPORTED_AUDIO_TYPES[ext]
    elseif asset_type == "video" then
        return self.SUPPORTED_VIDEO_TYPES[ext]
    elseif asset_type == "embed" then
        return true  -- Embeds can be any URL
    end
    return false
end

--- Resolve relative path to absolute
---@param path string
---@return string
function AssetValidator:resolve_path(path)
    if path:match("^/") then
        return self.base_path .. path
    else
        return self.base_path .. "/" .. path
    end
end

--- Check if file exists
---@param path string
---@return boolean
function AssetValidator:file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

--- Get file size in bytes
---@param path string
---@return number|nil
function AssetValidator:get_file_size(path)
    local file = io.open(path, "r")
    if file then
        local size = file:seek("end")
        file:close()
        return size
    end
    return nil
end

--- Get max size for asset type
---@param asset_type string
---@return number
function AssetValidator:get_max_size(asset_type)
    if asset_type == "image" then
        return self.MAX_IMAGE_SIZE
    elseif asset_type == "audio" then
        return self.MAX_AUDIO_SIZE
    elseif asset_type == "video" then
        return self.MAX_VIDEO_SIZE
    end
    return self.MAX_IMAGE_SIZE  -- Default
end

return AssetValidator
