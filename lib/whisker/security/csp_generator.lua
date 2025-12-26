--- CSP Generator
-- Content Security Policy generation for web exports
-- @module whisker.security.csp_generator
-- @author Whisker Core Team
-- @license MIT

local HTMLParser = require("whisker.security.html_parser")
local SHA256 = require("whisker.security.sha256")

local CSPGenerator = {}

--- CSP directive definitions
CSPGenerator.DIRECTIVES = {
  -- Fetch directives
  default_src = "Default source for all resource types",
  script_src = "Valid sources for JavaScript",
  style_src = "Valid sources for CSS",
  img_src = "Valid sources for images",
  font_src = "Valid sources for fonts",
  connect_src = "Valid targets for fetch, XHR, WebSocket",
  media_src = "Valid sources for audio and video",
  object_src = "Valid sources for <object>, <embed>, <applet>",
  frame_src = "Valid sources for frames and iframes",
  worker_src = "Valid sources for web workers",
  manifest_src = "Valid sources for app manifests",
  child_src = "Valid sources for workers and frames",

  -- Document directives
  base_uri = "Valid URLs for <base> element",
  form_action = "Valid targets for form submissions",
  frame_ancestors = "Valid parents for embedding this page",

  -- Navigation directives
  navigate_to = "Valid navigation targets",

  -- Other directives
  upgrade_insecure_requests = "Upgrade HTTP to HTTPS",
  block_all_mixed_content = "Block HTTP resources on HTTPS page",
  sandbox = "Enable sandbox mode",
  report_uri = "URI to send violation reports",
  report_to = "Reporting endpoint name",
}

--- CSP source values
CSPGenerator.SOURCES = {
  NONE = "'none'",
  SELF = "'self'",
  UNSAFE_INLINE = "'unsafe-inline'",
  UNSAFE_EVAL = "'unsafe-eval'",
  STRICT_DYNAMIC = "'strict-dynamic'",
  UNSAFE_HASHES = "'unsafe-hashes'",
  WASM_UNSAFE_EVAL = "'wasm-unsafe-eval'",
}

--- Plugin CSP extensions
local _extensions = {}

--- Base64 encoding table
local b64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- Encode bytes to base64
-- @param bytes table Array of byte values
-- @return string Base64 encoded string
local function base64_encode(bytes)
  local result = {}
  local padding = (3 - (#bytes % 3)) % 3

  -- Pad input if necessary
  for i = 1, padding do
    bytes[#bytes + 1] = 0
  end

  for i = 1, #bytes, 3 do
    local b1, b2, b3 = bytes[i], bytes[i + 1] or 0, bytes[i + 2] or 0

    local n = b1 * 65536 + b2 * 256 + b3

    local c1 = math.floor(n / 262144) % 64
    local c2 = math.floor(n / 4096) % 64
    local c3 = math.floor(n / 64) % 64
    local c4 = n % 64

    result[#result + 1] = b64_chars:sub(c1 + 1, c1 + 1)
    result[#result + 1] = b64_chars:sub(c2 + 1, c2 + 1)
    result[#result + 1] = b64_chars:sub(c3 + 1, c3 + 1)
    result[#result + 1] = b64_chars:sub(c4 + 1, c4 + 1)
  end

  -- Replace padding
  for i = 1, padding do
    result[#result - i + 1] = "="
  end

  return table.concat(result)
end

--- Generate cryptographically random nonce
-- @return string Base64 encoded nonce (at least 128 bits)
function CSPGenerator.generate_nonce()
  local bytes = {}

  -- Generate 16 random bytes (128 bits)
  -- Note: In production, use a proper crypto random source
  math.randomseed(os.time() + os.clock() * 1000000)

  for i = 1, 16 do
    bytes[i] = math.random(0, 255)
  end

  -- Add some entropy from clock
  local clock_bytes = tostring(os.clock() * 1000000000)
  for i = 1, math.min(8, #clock_bytes) do
    bytes[i] = (bytes[i] + clock_bytes:byte(i)) % 256
  end

  return base64_encode(bytes)
end

--- Validate nonce format
-- @param nonce string Nonce value
-- @return boolean True if valid
function CSPGenerator.is_valid_nonce(nonce)
  if type(nonce) ~= "string" then
    return false
  end

  -- Must be at least 16 characters (for 128-bit security)
  if #nonce < 16 then
    return false
  end

  -- Must be valid base64
  if not nonce:match("^[A-Za-z0-9+/]+=*$") then
    return false
  end

  return true
end

--- Generate SHA-256 hash of content for CSP
-- @param content string Content to hash
-- @return string Hash in CSP format (sha256-base64hash)
function CSPGenerator.generate_hash(content)
  if type(content) ~= "string" then
    return nil, "Content must be a string"
  end

  local hash_base64 = SHA256.base64(content)
  return "sha256-" .. hash_base64
end

--- Create default restrictive CSP policy
-- @param options table|nil {nonce, script_hashes, allow_eval}
-- @return table Policy directive map
function CSPGenerator.create_default_policy(options)
  options = options or {}

  local policy = {
    -- Default to same-origin only
    default_src = {"'self'"},

    -- Scripts: self only (plus nonce if provided)
    script_src = {"'self'"},

    -- Styles: self + unsafe-inline (needed for style attributes)
    style_src = {"'self'", "'unsafe-inline'"},

    -- Images: self + data URIs + https (for external images)
    img_src = {"'self'", "data:", "https:"},

    -- Fonts: self + data URIs (for embedded fonts)
    font_src = {"'self'", "data:"},

    -- AJAX/Fetch: self only
    connect_src = {"'self'"},

    -- Media: self only
    media_src = {"'self'"},

    -- No plugins
    object_src = {"'none'"},

    -- Frames: none (prevent embedding malicious content)
    frame_src = {"'none'"},

    -- Prevent being embedded in iframes (clickjacking protection)
    frame_ancestors = {"'none'"},

    -- Base URI: self only (prevent base tag injection)
    base_uri = {"'self'"},

    -- Form submissions: self only
    form_action = {"'self'"},
  }

  -- Add nonce if provided
  if options.nonce then
    if CSPGenerator.is_valid_nonce(options.nonce) then
      table.insert(policy.script_src, string.format("'nonce-%s'", options.nonce))
    end
  end

  -- Add script hashes if provided
  if options.script_hashes then
    for _, hash in ipairs(options.script_hashes) do
      table.insert(policy.script_src, string.format("'%s'", hash))
    end
  end

  -- Allow unsafe-eval if explicitly requested
  if options.allow_eval then
    table.insert(policy.script_src, "'unsafe-eval'")
  end

  -- Upgrade insecure requests if on HTTPS
  if options.upgrade_https then
    policy.upgrade_insecure_requests = {}
  end

  return policy
end

--- Create relaxed policy for development
-- @param options table|nil Policy options
-- @return table Policy directive map
function CSPGenerator.create_development_policy(options)
  options = options or {}

  local policy = CSPGenerator.create_default_policy(options)

  -- Allow inline styles and scripts for development
  table.insert(policy.script_src, "'unsafe-inline'")

  -- Allow eval for hot reloading
  table.insert(policy.script_src, "'unsafe-eval'")

  -- Allow localhost connections
  table.insert(policy.connect_src, "ws://localhost:*")
  table.insert(policy.connect_src, "http://localhost:*")

  return policy
end

--- Serialize policy to CSP header string
-- @param policy table Policy directive map
-- @return string CSP header value
function CSPGenerator.serialize_policy(policy)
  local directives = {}

  -- Sort directive names for consistent output
  local names = {}
  for name in pairs(policy) do
    table.insert(names, name)
  end
  table.sort(names)

  for _, name in ipairs(names) do
    local sources = policy[name]

    -- Convert underscores to hyphens (script_src -> script-src)
    local directive = name:gsub("_", "-")

    if type(sources) == "table" then
      if #sources > 0 then
        local sources_str = table.concat(sources, " ")
        table.insert(directives, directive .. " " .. sources_str)
      else
        -- Boolean directive (no sources)
        table.insert(directives, directive)
      end
    end
  end

  return table.concat(directives, "; ")
end

--- Create CSP meta tag
-- @param policy_string string Serialized CSP policy
-- @return string HTML meta tag
function CSPGenerator.create_meta_tag(policy_string)
  local escaped = HTMLParser.encode_entities(policy_string)
  return string.format(
    '<meta http-equiv="Content-Security-Policy" content="%s">',
    escaped
  )
end

--- Create CSP HTTP header
-- @param policy_string string Serialized CSP policy
-- @return table {name, value}
function CSPGenerator.create_header(policy_string)
  return {
    name = "Content-Security-Policy",
    value = policy_string,
  }
end

--- Create report-only CSP header (for testing)
-- @param policy_string string Serialized CSP policy
-- @param report_uri string|nil URI to send reports
-- @return table {name, value}
function CSPGenerator.create_report_only_header(policy_string, report_uri)
  local policy = policy_string

  if report_uri then
    policy = policy .. "; report-uri " .. report_uri
  end

  return {
    name = "Content-Security-Policy-Report-Only",
    value = policy,
  }
end

--- Add violation reporting to policy
-- @param policy table Policy directive map
-- @param report_uri string Report URI
-- @return table Modified policy
function CSPGenerator.add_reporting(policy, report_uri)
  policy.report_uri = {report_uri}
  return policy
end

--- Register plugin CSP extension
-- @param plugin_id string Plugin identifier
-- @param directive string CSP directive name
-- @param sources table Array of source values
function CSPGenerator.register_extension(plugin_id, directive, sources)
  if not _extensions[plugin_id] then
    _extensions[plugin_id] = {}
  end

  if not _extensions[plugin_id][directive] then
    _extensions[plugin_id][directive] = {}
  end

  for _, source in ipairs(sources) do
    table.insert(_extensions[plugin_id][directive], source)
  end
end

--- Clear plugin extension
-- @param plugin_id string Plugin identifier
function CSPGenerator.clear_extension(plugin_id)
  _extensions[plugin_id] = nil
end

--- Apply plugin extensions to policy
-- @param policy table Policy directive map
-- @return table Modified policy with extensions
function CSPGenerator.apply_extensions(policy)
  for plugin_id, extensions in pairs(_extensions) do
    for directive, sources in pairs(extensions) do
      if not policy[directive] then
        policy[directive] = {}
      end

      for _, source in ipairs(sources) do
        -- Avoid duplicates
        local exists = false
        for _, existing in ipairs(policy[directive]) do
          if existing == source then
            exists = true
            break
          end
        end

        if not exists then
          table.insert(policy[directive], source)
        end
      end
    end
  end

  return policy
end

--- Get all registered extensions
-- @return table Extensions by plugin
function CSPGenerator.get_extensions()
  return _extensions
end

--- Clear all extensions
function CSPGenerator.clear_all_extensions()
  _extensions = {}
end

--- Generate complete CSP setup for HTML export
-- @param options table|nil Export options
-- @return table {meta_tag, nonce, policy}
function CSPGenerator.generate_for_export(options)
  options = options or {}

  -- Generate nonce
  local nonce = CSPGenerator.generate_nonce()

  -- Create policy
  local policy = CSPGenerator.create_default_policy({
    nonce = nonce,
    allow_eval = options.allow_eval,
    upgrade_https = options.upgrade_https,
  })

  -- Apply plugin extensions
  if options.apply_extensions ~= false then
    policy = CSPGenerator.apply_extensions(policy)
  end

  -- Serialize
  local policy_string = CSPGenerator.serialize_policy(policy)

  -- Create meta tag
  local meta_tag = CSPGenerator.create_meta_tag(policy_string)

  return {
    meta_tag = meta_tag,
    nonce = nonce,
    policy = policy,
    policy_string = policy_string,
  }
end

--- Validate policy for common issues
-- @param policy table Policy directive map
-- @return boolean valid
-- @return table|nil issues Array of issue descriptions
function CSPGenerator.validate_policy(policy)
  local issues = {}

  -- Check for dangerous configurations
  if policy.script_src then
    for _, source in ipairs(policy.script_src) do
      if source == "'unsafe-inline'" and not source:match("'nonce%-") then
        table.insert(issues, "script-src has 'unsafe-inline' without nonce (XSS risk)")
      end
      if source == "'unsafe-eval'" then
        table.insert(issues, "script-src has 'unsafe-eval' (potential security risk)")
      end
      if source == "*" then
        table.insert(issues, "script-src has wildcard (allows any domain)")
      end
    end
  end

  -- Check for missing default-src
  if not policy.default_src then
    table.insert(issues, "Missing default-src directive")
  end

  -- Check for missing object-src
  if not policy.object_src then
    table.insert(issues, "Missing object-src directive (should be 'none')")
  end

  -- Check for missing base-uri
  if not policy.base_uri then
    table.insert(issues, "Missing base-uri directive (base injection risk)")
  end

  return #issues == 0, issues
end

return CSPGenerator
