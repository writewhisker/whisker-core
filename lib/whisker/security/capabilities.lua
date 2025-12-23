--- Capability Definitions
-- Registry of all security capabilities with metadata
-- @module whisker.security.capabilities
-- @author Whisker Core Team
-- @license MIT

local Capabilities = {}

--- Risk levels for capabilities
-- @table RISK_LEVELS
Capabilities.RISK_LEVELS = {
  LOW = "LOW",
  MEDIUM = "MEDIUM",
  HIGH = "HIGH",
  CRITICAL = "CRITICAL",
}

--- Capability registry with full metadata
-- @table REGISTRY
Capabilities.REGISTRY = {
  -- State reading capability
  READ_STATE = {
    id = "READ_STATE",
    name = "Read Story State",
    description = "Access story variables, passage history, and game progress",
    risk_level = "LOW",
    examples = {
      "Track player statistics",
      "Display current score",
      "Check passage visit counts",
    },
    user_prompt = "This plugin wants to read your game progress and story variables.",
    details = "Allows reading but not modifying game state. Low risk as it only observes data.",
  },

  -- State writing capability
  WRITE_STATE = {
    id = "WRITE_STATE",
    name = "Modify Story State",
    description = "Change story variables, trigger navigation, and modify game progress",
    risk_level = "MEDIUM",
    examples = {
      "Save game to slot",
      "Reset player progress",
      "Unlock achievements",
    },
    user_prompt = "This plugin wants to modify your game progress and story variables.",
    details = "Allows modifying game state. Could corrupt saves or alter story flow if misused.",
    requires = {"READ_STATE"}, -- WRITE_STATE implies READ_STATE
  },

  -- Network access capability
  NETWORK = {
    id = "NETWORK",
    name = "Network Access",
    description = "Make HTTP requests to external servers",
    risk_level = "HIGH",
    examples = {
      "Cloud save synchronization",
      "Analytics reporting",
      "Download additional content",
    },
    user_prompt = "This plugin wants to connect to the internet and may send data externally.",
    details = "Could send your game data to external servers. Only grant to trusted plugins.",
    warnings = {
      "May transmit your game progress",
      "Could contact third-party servers",
      "Data may be sent without visible indication",
    },
  },

  -- Filesystem access capability
  FILESYSTEM = {
    id = "FILESYSTEM",
    name = "File System Access",
    description = "Read and write local files",
    risk_level = "HIGH",
    examples = {
      "Export game saves to file",
      "Import story content",
      "Log game events to file",
    },
    user_prompt = "This plugin wants to read and write files on your computer.",
    details = "Could access sensitive files. Only grant to highly trusted plugins.",
    warnings = {
      "May read files outside game directory",
      "Could write to unexpected locations",
      "Path traversal must be prevented",
    },
  },

  -- UI modification capability
  MODIFY_UI = {
    id = "MODIFY_UI",
    name = "Modify User Interface",
    description = "Add or modify UI elements in the story display",
    risk_level = "LOW",
    examples = {
      "Add custom sidebar widgets",
      "Display popup notifications",
      "Inject custom CSS styles",
    },
    user_prompt = "This plugin wants to modify the game's user interface.",
    details = "Allows adding visual elements. Content is still sanitized for XSS.",
  },

  -- Audio capability
  AUDIO = {
    id = "AUDIO",
    name = "Audio Playback",
    description = "Play sounds and music",
    risk_level = "LOW",
    examples = {
      "Play background music",
      "Sound effects on actions",
      "Voice narration",
    },
    user_prompt = "This plugin wants to play audio.",
    details = "Allows playing audio files. May include external audio sources.",
  },

  -- System info capability
  SYSTEM_INFO = {
    id = "SYSTEM_INFO",
    name = "System Information",
    description = "Access basic system information (platform, version)",
    risk_level = "LOW",
    examples = {
      "Detect mobile vs desktop",
      "Check whisker-core version",
      "Adjust for screen size",
    },
    user_prompt = "This plugin wants to access basic system information.",
    details = "Allows reading non-sensitive platform info for compatibility checks.",
  },

  -- Plugin communication capability
  PLUGIN_COMM = {
    id = "PLUGIN_COMM",
    name = "Plugin Communication",
    description = "Communicate with other plugins",
    risk_level = "MEDIUM",
    examples = {
      "Extend another plugin's functionality",
      "Share data between plugins",
      "Coordinate plugin actions",
    },
    user_prompt = "This plugin wants to communicate with other plugins.",
    details = "Allows reading/calling other plugin APIs. Could inherit their capabilities.",
  },
}

--- List of all capability IDs
-- @table ALL
Capabilities.ALL = {}
for id in pairs(Capabilities.REGISTRY) do
  table.insert(Capabilities.ALL, id)
end
table.sort(Capabilities.ALL)

--- Get capability metadata by ID
-- @param id string Capability ID
-- @return table|nil Capability metadata or nil if not found
function Capabilities.get(id)
  return Capabilities.REGISTRY[id]
end

--- Check if capability ID is valid
-- @param id string Capability ID
-- @return boolean True if valid
function Capabilities.is_valid(id)
  return Capabilities.REGISTRY[id] ~= nil
end

--- Get capability risk level
-- @param id string Capability ID
-- @return string|nil Risk level or nil if not found
function Capabilities.get_risk_level(id)
  local cap = Capabilities.REGISTRY[id]
  if cap then
    return cap.risk_level
  end
  return nil
end

--- Check if capability is high risk
-- @param id string Capability ID
-- @return boolean True if HIGH or CRITICAL risk
function Capabilities.is_high_risk(id)
  local level = Capabilities.get_risk_level(id)
  return level == "HIGH" or level == "CRITICAL"
end

--- Get required capabilities (transitive)
-- @param id string Capability ID
-- @return table Array of required capability IDs
function Capabilities.get_required(id)
  local cap = Capabilities.REGISTRY[id]
  if not cap then
    return {}
  end
  return cap.requires or {}
end

--- Expand capabilities to include all required
-- @param capabilities table Array of capability IDs
-- @return table Expanded array including all requirements
function Capabilities.expand(capabilities)
  local result = {}
  local seen = {}

  local function add_with_requirements(cap_id)
    if seen[cap_id] then
      return
    end
    seen[cap_id] = true

    -- Add requirements first
    local required = Capabilities.get_required(cap_id)
    for _, req in ipairs(required) do
      add_with_requirements(req)
    end

    table.insert(result, cap_id)
  end

  for _, cap_id in ipairs(capabilities) do
    add_with_requirements(cap_id)
  end

  return result
end

--- Validate capability array
-- @param capabilities table Array of capability IDs
-- @return boolean success
-- @return string|nil error Error message if validation failed
function Capabilities.validate(capabilities)
  if type(capabilities) ~= "table" then
    return false, "Capabilities must be a table"
  end

  for i, cap_id in ipairs(capabilities) do
    if type(cap_id) ~= "string" then
      return false, string.format(
        "Capability at index %d must be string, got %s",
        i, type(cap_id)
      )
    end

    if not Capabilities.is_valid(cap_id) then
      return false, string.format(
        "Unknown capability: %s",
        cap_id
      )
    end
  end

  return true
end

--- Get user-friendly description for permission request
-- @param capabilities table Array of capability IDs
-- @return table Array of {id, name, prompt, risk_level}
function Capabilities.get_permission_prompts(capabilities)
  local prompts = {}

  for _, cap_id in ipairs(capabilities) do
    local cap = Capabilities.REGISTRY[cap_id]
    if cap then
      table.insert(prompts, {
        id = cap.id,
        name = cap.name,
        prompt = cap.user_prompt,
        risk_level = cap.risk_level,
        warnings = cap.warnings,
      })
    end
  end

  -- Sort by risk level (HIGH first)
  table.sort(prompts, function(a, b)
    local order = {CRITICAL = 1, HIGH = 2, MEDIUM = 3, LOW = 4}
    return (order[a.risk_level] or 5) < (order[b.risk_level] or 5)
  end)

  return prompts
end

--- Create capability set for efficient lookup
-- @param capabilities table Array of capability IDs
-- @return table Set (map of id -> true)
function Capabilities.to_set(capabilities)
  local set = {}
  for _, cap_id in ipairs(capabilities) do
    set[cap_id] = true
  end
  return set
end

--- Convert capability set to array
-- @param set table Set (map of id -> true)
-- @return table Array of capability IDs
function Capabilities.from_set(set)
  local arr = {}
  for cap_id in pairs(set) do
    table.insert(arr, cap_id)
  end
  table.sort(arr)
  return arr
end

return Capabilities
