--- JSON Story Parser
-- Parses JSON story files into internal story format
-- @module whisker.format.parsers.json
-- GAP-020: JSON Settings Section
-- GAP-021: IFID Generation
-- GAP-048: JSON Assets

local M = {}
M._dependencies = {"json_codec", "story_schema", "uuid", "assets"}

-- Lazy-loaded dependencies
local _json = nil
local _schema = nil
local _uuid = nil
local _assets = nil

local function get_json()
  if not _json then
    _json = require("whisker.utils.json")
  end
  return _json
end

local function get_schema()
  if not _schema then
    local SchemaClass = require("whisker.format.schemas.story_schema")
    _schema = SchemaClass.new()
  end
  return _schema
end

local function get_uuid()
  if not _uuid then
    _uuid = require("whisker.utils.uuid")
  end
  return _uuid
end

local function get_assets()
  if not _assets then
    _assets = require("whisker.utils.assets")
  end
  return _assets
end

--- Create a new JSON parser instance
-- @param deps table Dependencies
-- @return JsonParser instance
function M.new(deps)
  local self = setmetatable({}, {__index = M})
  self._json = deps and deps.json_codec or get_json()
  self._schema = deps and deps.story_schema or get_schema()
  return self
end

--- Check if two versions are compatible (GAP-010, GAP-011)
---@param file_version string Version from file
---@param current_version string Current implementation version
---@return boolean compatible
---@return string|nil warning
function M.check_version_compatibility(file_version, current_version)
  if not file_version then
    return true, nil  -- No version = assume compatible
  end

  -- Parse versions
  local file_major, file_minor = file_version:match("^(%d+)%.(%d+)")
  local curr_major, curr_minor = current_version:match("^(%d+)%.(%d+)")

  file_major = tonumber(file_major) or 0
  file_minor = tonumber(file_minor) or 0
  curr_major = tonumber(curr_major) or 0
  curr_minor = tonumber(curr_minor) or 0

  -- Major version mismatch = incompatible
  if file_major > curr_major then
    return false, string.format(
      "File format version %s is newer than supported version %s",
      file_version, current_version
    )
  end

  -- Minor version higher = warning (may have unsupported features)
  if file_major == curr_major and file_minor > curr_minor then
    return true, string.format(
      "File format version %s is newer than %s; some features may not work",
      file_version, current_version
    )
  end

  return true, nil
end

--- Parse JSON content into story structure
-- @param content string JSON content
-- @param options table Optional parsing options
-- @return table|nil Parsed story
-- @return string|nil Error message
function M.parse(content, options)
  options = options or {}
  local json = get_json()
  local schema = get_schema()

  -- Decode JSON
  local story, err = json.decode(content)
  if not story then
    return nil, "JSON parse error: " .. tostring(err)
  end

  -- Check format_version for compatibility (GAP-010)
  if story.format_version then
    local compat, compat_err = M.check_version_compatibility(
      story.format_version,
      schema.FORMAT_VERSION
    )
    if not compat then
      if options.strict_version then
        return nil, compat_err
      elseif options.on_warning then
        options.on_warning(compat_err)
      end
    elseif compat_err and options.on_warning then
      options.on_warning(compat_err)
    end
  end

  -- Check WLS version for compatibility (GAP-011)
  if story.wls then
    local wls_compat, wls_err = M.check_version_compatibility(
      story.wls,
      schema.WLS_VERSION
    )
    if not wls_compat then
      if options.strict_version then
        return nil, wls_err
      elseif options.on_warning then
        options.on_warning(wls_err)
      end
    elseif wls_err and options.on_warning then
      options.on_warning(wls_err)
    end
  end

  -- Validate against schema (optional)
  if options.validate ~= false then
    local valid, errors = schema:validate(story)
    if not valid then
      return nil, "Validation errors: " .. table.concat(errors, "; ")
    end
  end

  -- Apply defaults
  story = schema:apply_defaults(story)

  -- Normalize to internal format
  local normalized = M.normalize_story(story)

  -- Preserve WLS version in normalized story (GAP-011)
  if story.wls then
    normalized.wls_version = story.wls
  end

  return normalized
end

--- Normalize a story object to internal format
-- @param story table Raw story object
-- @return table Normalized story
function M.normalize_story(story)
  local schema = get_schema()

  local result = {
    name = story.name,
    format = story.format or "harlowe",
    ifid = story.ifid,
    start = story.start or "Start",
    zoom = story.zoom or 1.0,
    tags = story.tags or {},
    metadata = story.metadata or {},
    passages = {},
    -- GAP-020: Include settings
    settings = schema:apply_default_settings(story.settings),
  }

  -- Normalize passages
  if story.passages then
    for _, passage in ipairs(story.passages) do
      local normalized_passage = {
        name = passage.name,
        content = passage.content or "",
        tags = passage.tags or {},
        -- GAP-016: Include passage-level fallback
        fallback = passage.fallback,
      }

      -- Optional position
      if passage.position then
        normalized_passage.position = {
          x = passage.position.x or 0,
          y = passage.position.y or 0,
        }
      end

      -- Optional size
      if passage.size then
        normalized_passage.size = {
          width = passage.size.width or 100,
          height = passage.size.height or 100,
        }
      end

      table.insert(result.passages, normalized_passage)
    end
  end

  return result
end

--- Parse JSON from file
-- @param path string File path
-- @param options table Optional parsing options
-- @return table|nil Parsed story
-- @return string|nil Error message
function M.parse_file(path, options)
  local file, err = io.open(path, "r")
  if not file then
    return nil, "Cannot open file: " .. tostring(err)
  end

  local content = file:read("*all")
  file:close()

  return M.parse(content, options)
end

--- Check if content is valid JSON
-- @param content string Content to check
-- @return boolean True if valid JSON
function M.is_json(content)
  local json = get_json()
  local result, _ = json.decode(content)
  return result ~= nil
end

--- Detect if content is a JSON story
-- @param content string Content to check
-- @return boolean True if appears to be a JSON story
function M.is_json_story(content)
  local json = get_json()
  local result, _ = json.decode(content)
  if not result or type(result) ~= "table" then
    return false
  end

  -- Check for story-like structure
  return result.passages ~= nil and result.name ~= nil
end

--- Export story to JSON
-- @param story table Story object
-- @param options table Export options
-- @return string JSON content
-- @return string|nil Error message
function M.to_json(story, options)
  options = options or {}
  local json = get_json()
  local schema = get_schema()
  local uuid = get_uuid()

  -- Validate before export
  if options.validate ~= false then
    local valid, errors = schema:validate(story)
    if not valid then
      return nil, "Validation errors: " .. table.concat(errors, "; ")
    end
  end

  -- GAP-021: Ensure IFID exists
  local ifid = story.ifid
  if not ifid and options.generate_ifid ~= false then
    ifid = uuid.v4()
    -- Store generated IFID back in story
    story.ifid = ifid
  end

  -- Build export object with required version fields at top level (GAP-010, GAP-011)
  local export_story = {
    format_version = schema.FORMAT_VERSION,
    -- Use story's declared WLS version, or default to current
    wls = story.wls_version or schema.WLS_VERSION,
    name = story.name,
    ifid = ifid,
  }

  -- GAP-020: Include settings (only non-default values)
  if story.settings then
    export_story.settings = schema:serialize_settings(story.settings)
  end

  -- Copy remaining story fields (except internal fields and already-handled ones)
  local skip_fields = {
    format_version = true,
    wls = true,
    wls_version = true,
    name = true,
    ifid = true,
    settings = true,
  }

  for k, v in pairs(story) do
    if not skip_fields[k] then
      export_story[k] = v
    end
  end

  -- Add schema version and export info to metadata
  export_story.metadata = export_story.metadata or {}
  export_story.metadata.schemaVersion = schema.SCHEMA_VERSION
  export_story.metadata.exported = os.date("%Y-%m-%dT%H:%M:%S")
  export_story.metadata.exporter = "whisker-core-lua"

  -- Encode
  if options.pretty then
    return json.encode(export_story, 1)
  else
    return json.encode(export_story)
  end
end

--- Convert parsed story to Twee format
-- @param story table Parsed story
-- @return string Twee format content
function M.to_twee(story)
  local result = {}

  -- Story metadata header (optional)
  if story.ifid or story.name then
    table.insert(result, ":: StoryData")
    local json = get_json()
    local metadata = {
      ifid = story.ifid,
      format = story.format,
      start = story.start,
    }
    table.insert(result, json.encode(metadata))
    table.insert(result, "")
  end

  -- Convert each passage
  for _, passage in ipairs(story.passages) do
    local header = ":: " .. passage.name
    if passage.tags and #passage.tags > 0 then
      header = header .. " [" .. table.concat(passage.tags, " ") .. "]"
    end
    table.insert(result, header)
    table.insert(result, passage.content)
    table.insert(result, "")
  end

  return table.concat(result, "\n")
end

--- Convert Twee format to JSON story object
-- @param twee_content string Twee format content
-- @param format string Source format (harlowe, sugarcube, etc.)
-- @return table Story object suitable for JSON export
function M.from_twee(twee_content, format)
  format = format or "harlowe"

  -- Get the appropriate parser
  local parser
  local ok, p = pcall(require, "whisker.format.parsers." .. format)
  if ok then
    parser = p
  else
    -- Fall back to harlowe parser
    parser = require("whisker.format.parsers.harlowe")
  end

  -- Parse the Twee content
  local parsed = parser.parse(twee_content)

  -- Build JSON story object
  local story = {
    name = "Imported Story",
    format = format,
    start = "Start",
    passages = parsed.passages,
    metadata = {
      imported = os.date("%Y-%m-%dT%H:%M:%S"),
      sourceFormat = format,
    }
  }

  -- Try to find story name from StoryTitle passage
  for _, passage in ipairs(parsed.passages) do
    if passage.name == "StoryTitle" then
      story.name = passage.content:match("^%s*(.-)%s*$") or "Imported Story"
      break
    end
  end

  return story
end

-- ============================================================================
-- GAP-048: JSON Asset Support
-- ============================================================================

--- Collect asset references from passage content
-- Scans for @image(), @audio(), @video(), @embed() directives and markdown images
-- @param content string The passage content
-- @return table List of asset references
function M.collect_asset_references(content)
  local refs = {}
  local seen = {}

  -- Pattern for @image(), @audio(), @video(), @embed()
  for directive_type, path in content:gmatch("@(%w+)%(([^)]+)") do
    if directive_type == "image" or directive_type == "audio" or
       directive_type == "video" or directive_type == "embed" then
      -- Extract path from directive args
      local src = path:match('^"([^"]+)"') or path:match("^'([^']+)'") or path:match("^([^,]+)")
      if src then
        src = src:match("^%s*(.-)%s*$")  -- Trim
        if not seen[src] then
          seen[src] = true
          table.insert(refs, {
            type = directive_type,
            path = src
          })
        end
      end
    end
  end

  -- Pattern for markdown images: ![alt](src)
  for src in content:gmatch("!%[.-%]%(([^%)]+)%)") do
    -- Extract just the URL part (before any attributes)
    src = src:match("^([^%s\"']+)") or src
    src = src:match("^%s*(.-)%s*$")  -- Trim
    if not seen[src] then
      seen[src] = true
      table.insert(refs, {
        type = "image",
        path = src
      })
    end
  end

  return refs
end

--- Collect all assets from a story
-- @param story table The story object
-- @return table List of unique asset references
function M.collect_story_assets(story)
  local all_refs = {}
  local seen = {}

  for _, passage in ipairs(story.passages or {}) do
    local refs = M.collect_asset_references(passage.content or "")
    for _, ref in ipairs(refs) do
      if not seen[ref.path] then
        seen[ref.path] = true
        table.insert(all_refs, ref)
      end
    end
  end

  return all_refs
end

--- Create an asset manifest for the story
-- @param story table The story object
-- @param base_path string The base directory for resolving local assets
-- @param options table Options (include_checksums, include_base64, etc.)
-- @return table Asset manifest
function M.create_asset_manifest(story, base_path, options)
  options = options or {}
  local assets = get_assets()
  local refs = M.collect_story_assets(story)
  local manifest = {
    version = "1.0",
    generated = os.date("%Y-%m-%dT%H:%M:%S"),
    assets = {}
  }

  for i, ref in ipairs(refs) do
    local entry = {
      id = assets.generate_id(ref.path, i),
      path = ref.path,
      type = assets.get_mime_type(ref.path),
      asset_type = ref.type
    }

    -- External URL vs local file handling
    if assets.is_external_url(ref.path) then
      entry.external = true
    else
      local full_path = base_path .. "/" .. ref.path
      if assets.file_exists(full_path) then
        entry.size = assets.get_size(full_path)

        if options.include_checksums then
          local checksum, _ = assets.checksum(full_path)
          entry.checksum = checksum
        end

        if options.include_base64 then
          local data_uri, _ = assets.to_base64(full_path)
          entry.data = data_uri
        end
      else
        entry.missing = true
      end
    end

    table.insert(manifest.assets, entry)
  end

  return manifest
end

--- Validate all asset references in a story
-- @param story table The story object
-- @param base_path string The base directory for resolving local assets
-- @return boolean valid
-- @return table List of validation errors/warnings
function M.validate_story_assets(story, base_path)
  local assets = get_assets()
  local refs = M.collect_story_assets(story)
  local issues = {}
  local valid = true

  for _, ref in ipairs(refs) do
    local is_valid, err = assets.validate_asset(ref.path, base_path)
    if not is_valid then
      valid = false
      table.insert(issues, {
        severity = "error",
        path = ref.path,
        message = err
      })
    end

    -- Check format support
    if not assets.is_external_url(ref.path) then
      if not assets.is_format_supported(ref.path, ref.type) then
        table.insert(issues, {
          severity = "warning",
          path = ref.path,
          message = "Format may not be supported: " .. ref.path
        })
      end
    end
  end

  return valid, issues
end

--- Export story with embedded assets to JSON
-- @param story table Story object
-- @param base_path string Base directory for assets
-- @param options table Export options
-- @return string JSON content
-- @return string|nil Error message
function M.to_json_with_assets(story, base_path, options)
  options = options or {}
  local json = get_json()
  local schema = get_schema()
  local uuid = get_uuid()

  -- First, collect and validate assets
  local valid, issues = M.validate_story_assets(story, base_path)
  if not valid and options.strict_assets then
    local err_msgs = {}
    for _, issue in ipairs(issues) do
      if issue.severity == "error" then
        table.insert(err_msgs, issue.message)
      end
    end
    return nil, "Asset validation errors: " .. table.concat(err_msgs, "; ")
  end

  -- Standard export first
  local export_story = {
    format_version = schema.FORMAT_VERSION,
    wls = story.wls_version or schema.WLS_VERSION,
    name = story.name,
    ifid = story.ifid or (options.generate_ifid ~= false and uuid.v4() or nil),
  }

  -- GAP-020: Include settings
  if story.settings then
    export_story.settings = schema:serialize_settings(story.settings)
  end

  -- Copy story fields
  local skip_fields = { format_version = true, wls = true, wls_version = true, name = true, ifid = true, settings = true }
  for k, v in pairs(story) do
    if not skip_fields[k] then
      export_story[k] = v
    end
  end

  -- Add asset manifest
  export_story.assets = M.create_asset_manifest(story, base_path, {
    include_checksums = options.include_checksums,
    include_base64 = options.embed_assets
  })

  -- Add metadata
  export_story.metadata = export_story.metadata or {}
  export_story.metadata.schemaVersion = schema.SCHEMA_VERSION
  export_story.metadata.exported = os.date("%Y-%m-%dT%H:%M:%S")
  export_story.metadata.exporter = "whisker-core-lua"

  -- Encode
  if options.pretty then
    return json.encode(export_story, 1)
  else
    return json.encode(export_story)
  end
end

return M
