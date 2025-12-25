--- Asset Bundler
-- Collects and bundles assets for export
-- @module whisker.export.asset_bundler
-- @author Whisker Core Team
-- @license MIT

local ExportUtils = require("whisker.export.utils")

local AssetBundler = {}
AssetBundler._dependencies = {}
AssetBundler.__index = AssetBundler

--- Create a new asset bundler instance
-- @param options table Options:
--   - base_path: string (default ".")
--   - minify: boolean (default false)
--   - inline: boolean (default true)
-- @return AssetBundler A new bundler
function AssetBundler.new(options)
  local self = setmetatable({}, AssetBundler)
  options = options or {}

  self._assets = {}
  self._base_path = options.base_path or "."
  self._minify = options.minify or false
  self._inline = options.inline ~= false  -- Default true

  return self
end

--- Add an asset to the bundle
-- @param path string Asset path relative to base_path
-- @param asset_type string Asset type (css, js, png, jpg, etc.)
-- @return boolean Success
-- @return string|nil Error message
function AssetBundler:add_asset(path, asset_type)
  local full_path = self._base_path .. "/" .. path
  local content = ExportUtils.read_file(full_path)

  if not content then
    return false, "Asset not found: " .. full_path
  end

  -- Minify if requested
  if self._minify then
    if asset_type == "css" then
      content = self:minify_css(content)
    elseif asset_type == "js" then
      content = self:minify_js(content)
    end
  end

  table.insert(self._assets, {
    path = path,
    type = asset_type,
    content = content,
    size = #content,
  })

  return true
end

--- Add an asset from content string
-- @param name string Asset name
-- @param content string Asset content
-- @param asset_type string Asset type
function AssetBundler:add_content(name, content, asset_type)
  -- Minify if requested
  if self._minify then
    if asset_type == "css" then
      content = self:minify_css(content)
    elseif asset_type == "js" then
      content = self:minify_js(content)
    end
  end

  table.insert(self._assets, {
    path = name,
    type = asset_type,
    content = content,
    size = #content,
  })
end

--- Get all assets
-- @return table Array of assets
function AssetBundler:get_all_assets()
  return self._assets
end

--- Get all assets of a specific type
-- @param asset_type string Asset type
-- @return table Array of assets
function AssetBundler:get_assets(asset_type)
  local result = {}
  for _, asset in ipairs(self._assets) do
    if asset.type == asset_type then
      table.insert(result, asset)
    end
  end
  return result
end

--- Get inline version of an asset (data URI)
-- @param path string Asset path
-- @return string|nil Data URI or nil if not found
function AssetBundler:inline_asset(path)
  for _, asset in ipairs(self._assets) do
    if asset.path == path then
      local mime = ExportUtils.get_mime_type(asset.type)
      return "data:" .. mime .. ";base64," .. ExportUtils.base64_encode(asset.content)
    end
  end
  return nil
end

--- Get combined CSS content
-- @return string Combined CSS
function AssetBundler:get_combined_css()
  local parts = {}
  for _, asset in ipairs(self._assets) do
    if asset.type == "css" then
      table.insert(parts, asset.content)
    end
  end
  return table.concat(parts, "\n")
end

--- Get combined JavaScript content
-- @return string Combined JavaScript
function AssetBundler:get_combined_js()
  local parts = {}
  for _, asset in ipairs(self._assets) do
    if asset.type == "js" then
      table.insert(parts, asset.content)
    end
  end
  return table.concat(parts, "\n")
end

--- Get inline CSS for HTML embedding
-- @return string CSS wrapped in style tag
function AssetBundler:get_inline_css_tag()
  local css = self:get_combined_css()
  if css == "" then
    return ""
  end
  return "<style>\n" .. css .. "\n</style>"
end

--- Get inline JavaScript for HTML embedding
-- @return string JavaScript wrapped in script tag
function AssetBundler:get_inline_js_tag()
  local js = self:get_combined_js()
  if js == "" then
    return ""
  end
  return "<script>\n" .. js .. "\n</script>"
end

--- Get total size of all assets
-- @return number Total size in bytes
function AssetBundler:get_total_size()
  local total = 0
  for _, asset in ipairs(self._assets) do
    total = total + asset.size
  end
  return total
end

--- Get asset count
-- @return number Number of assets
function AssetBundler:get_asset_count()
  return #self._assets
end

--- Clear all assets
function AssetBundler:clear()
  self._assets = {}
end

--- Simple CSS minification
-- @param css string CSS content
-- @return string Minified CSS
function AssetBundler:minify_css(css)
  if not css then return "" end

  return css
    :gsub("/%*.-%*/", "")           -- Remove block comments
    :gsub("%s+", " ")               -- Collapse whitespace
    :gsub("%s*([{}:;,>+~])%s*", "%1")  -- Remove space around punctuation
    :gsub(";}", "}")                -- Remove last semicolon before }
    :gsub("^%s+", "")               -- Trim start
    :gsub("%s+$", "")               -- Trim end
end

--- Simple JavaScript minification
-- Note: This is basic and may break some code
-- @param js string JavaScript content
-- @return string Minified JavaScript
function AssetBundler:minify_js(js)
  if not js then return "" end

  -- Remove single-line comments (but not URLs)
  local result = {}
  for line in js:gmatch("[^\n]+") do
    -- Only remove // comments if not preceded by : (URLs)
    line = line:gsub("^(.-)//[^\"']*$", function(before)
      -- Check if there's a URL-like pattern
      if before:match("https?:$") or before:match("'[^']*:$") or before:match('"[^"]*:$') then
        return line
      end
      return before
    end)
    table.insert(result, line)
  end
  js = table.concat(result, "\n")

  -- Remove block comments
  js = js:gsub("/%*.-%*/", "")

  -- Collapse multiple newlines/spaces (but preserve at least one newline for statements)
  js = js:gsub("\n%s*\n", "\n")
  js = js:gsub("  +", " ")

  -- Trim
  js = js:gsub("^%s+", ""):gsub("%s+$", "")

  return js
end

--- Create export bundle with assets
-- @return table Bundle with assets array
function AssetBundler:create_bundle()
  local bundle_assets = {}

  for _, asset in ipairs(self._assets) do
    table.insert(bundle_assets, {
      path = asset.path,
      type = asset.type,
      content = asset.content,
      size = asset.size,
    })
  end

  return bundle_assets
end

return AssetBundler
