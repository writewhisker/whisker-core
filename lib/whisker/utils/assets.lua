-- lib/whisker/utils/assets.lua
-- Asset utilities for WLS 1.0 JSON export
-- Implements GAP-048: JSON Assets support

local Assets = {}

--- Calculate SHA256 checksum of file
---@param file_path string
---@return string|nil checksum
---@return string|nil error
function Assets.checksum(file_path)
    -- Try using external sha256sum command
    local handle = io.popen("sha256sum " .. file_path .. " 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        local hash = result:match("^(%x+)")
        if hash then
            return "sha256:" .. hash
        end
    end

    -- Try using shasum on macOS
    handle = io.popen("shasum -a 256 " .. file_path .. " 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        local hash = result:match("^(%x+)")
        if hash then
            return "sha256:" .. hash
        end
    end

    return nil, "Failed to calculate checksum"
end

--- Get MIME type from file extension
---@param file_path string
---@return string
function Assets.get_mime_type(file_path)
    local ext = file_path:match("%.([^%.]+)$")
    if not ext then return "application/octet-stream" end

    local mime_types = {
        -- Images
        png = "image/png",
        jpg = "image/jpeg",
        jpeg = "image/jpeg",
        gif = "image/gif",
        svg = "image/svg+xml",
        webp = "image/webp",
        ico = "image/x-icon",
        bmp = "image/bmp",
        -- Audio
        mp3 = "audio/mpeg",
        ogg = "audio/ogg",
        wav = "audio/wav",
        m4a = "audio/mp4",
        flac = "audio/flac",
        aac = "audio/aac",
        -- Video
        mp4 = "video/mp4",
        webm = "video/webm",
        avi = "video/x-msvideo",
        mov = "video/quicktime",
        mkv = "video/x-matroska",
        -- Documents
        pdf = "application/pdf",
        json = "application/json",
        xml = "application/xml",
        txt = "text/plain",
        html = "text/html",
        css = "text/css",
        js = "application/javascript",
        -- Fonts
        woff = "font/woff",
        woff2 = "font/woff2",
        ttf = "font/ttf",
        otf = "font/otf",
        eot = "application/vnd.ms-fontobject",
    }

    return mime_types[ext:lower()] or "application/octet-stream"
end

--- Base64 encoding implementation
---@param data string
---@return string
function Assets.base64_encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r, byte = '', x:byte()
        for i = 8, 1, -1 do
            r = r .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
        end
        return b:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

--- Base64 decoding implementation
---@param data string
---@return string
function Assets.base64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^' .. b .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end
        return string.char(c)
    end))
end

--- Read file and encode as base64 data URI
---@param file_path string
---@return string|nil data_uri
---@return string|nil error
function Assets.to_base64(file_path)
    local file = io.open(file_path, "rb")
    if not file then
        return nil, "Cannot open file: " .. file_path
    end

    local content = file:read("*a")
    file:close()

    -- Base64 encode
    local b64 = Assets.base64_encode(content)
    local mime = Assets.get_mime_type(file_path)

    return "data:" .. mime .. ";base64," .. b64
end

--- Get file size in bytes
---@param file_path string
---@return number|nil
function Assets.get_size(file_path)
    local file = io.open(file_path, "rb")
    if not file then return nil end
    local size = file:seek("end")
    file:close()
    return size
end

--- Check if file exists
---@param file_path string
---@return boolean
function Assets.file_exists(file_path)
    local file = io.open(file_path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

--- Generate unique asset ID from path and index
---@param file_path string
---@param index number
---@return string
function Assets.generate_id(file_path, index)
    local name = file_path:match("([^/\\]+)$") or "asset"
    name = name:gsub("%.[^%.]+$", "")  -- Remove extension
    name = name:gsub("[^%w_%-]", "_")   -- Sanitize
    return string.format("asset-%03d-%s", index, name)
end

--- Determine asset type from MIME type
---@param mime_type string
---@return string "image"|"audio"|"video"|"font"|"document"|"other"
function Assets.get_asset_type(mime_type)
    if mime_type:match("^image/") then
        return "image"
    elseif mime_type:match("^audio/") then
        return "audio"
    elseif mime_type:match("^video/") then
        return "video"
    elseif mime_type:match("^font/") or mime_type:match("fontobject") then
        return "font"
    elseif mime_type:match("^text/") or mime_type:match("^application/") then
        return "document"
    else
        return "other"
    end
end

--- Check if URL is external (http/https)
---@param url string
---@return boolean
function Assets.is_external_url(url)
    return url:match("^https?://") ~= nil
end

--- Create an asset manifest entry
---@param path string The asset path
---@param base_path string The base directory
---@param index number Asset index
---@return table Asset manifest entry
function Assets.create_manifest_entry(path, base_path, index)
    local full_path = base_path .. "/" .. path

    local entry = {
        id = Assets.generate_id(path, index),
        path = path,
        type = Assets.get_mime_type(path),
    }

    if not Assets.is_external_url(path) then
        entry.size = Assets.get_size(full_path)
        local checksum, _ = Assets.checksum(full_path)
        entry.checksum = checksum
    end

    return entry
end

--- Validate an asset reference
---@param path string The asset path
---@param base_path string The base directory
---@return boolean valid
---@return string|nil error
function Assets.validate_asset(path, base_path)
    if Assets.is_external_url(path) then
        -- Basic URL format validation
        if not path:match("^https?://[%w%.%-]+") then
            return false, "Invalid URL format: " .. path
        end
        return true, nil
    end

    -- Local file validation
    local full_path = base_path .. "/" .. path
    if not Assets.file_exists(full_path) then
        return false, "Asset not found: " .. path
    end

    return true, nil
end

--- Supported image formats
Assets.SUPPORTED_IMAGE_FORMATS = { "jpg", "jpeg", "png", "gif", "webp", "svg", "ico", "bmp" }

--- Supported audio formats
Assets.SUPPORTED_AUDIO_FORMATS = { "mp3", "ogg", "wav", "m4a", "flac", "aac" }

--- Supported video formats
Assets.SUPPORTED_VIDEO_FORMATS = { "mp4", "webm", "avi", "mov", "mkv" }

--- Check if file extension is supported for asset type
---@param path string The file path
---@param asset_type string "image"|"audio"|"video"
---@return boolean supported
function Assets.is_format_supported(path, asset_type)
    local ext = path:match("%.([^%.]+)$")
    if not ext then return false end
    ext = ext:lower()

    local formats
    if asset_type == "image" then
        formats = Assets.SUPPORTED_IMAGE_FORMATS
    elseif asset_type == "audio" then
        formats = Assets.SUPPORTED_AUDIO_FORMATS
    elseif asset_type == "video" then
        formats = Assets.SUPPORTED_VIDEO_FORMATS
    else
        return true  -- Unknown type, assume supported
    end

    for _, fmt in ipairs(formats) do
        if ext == fmt then
            return true
        end
    end

    return false
end

return Assets
