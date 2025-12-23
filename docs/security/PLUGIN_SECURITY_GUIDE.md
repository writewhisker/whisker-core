# Plugin Security Best Practices

This guide covers security best practices for whisker-core plugin developers.

## Principle of Least Privilege

**Only request capabilities you actually need.**

### Example: Good vs Bad

```lua
-- BAD: Requests unnecessary capabilities
{
  id = "passage-counter",
  capabilities = {
    "READ_STATE",   -- Actually needed
    "WRITE_STATE",  -- NOT needed
    "NETWORK",      -- NOT needed
    "FILESYSTEM"    -- NOT needed
  }
}

-- GOOD: Minimal capabilities
{
  id = "passage-counter",
  capabilities = {
    "READ_STATE"  -- Only what's needed
  }
}
```

**Why it matters**: Users are more likely to grant minimal permissions. Excessive capabilities raise security concerns and reduce trust.

## Capability Reference

### READ_STATE (Low Risk)

Allows reading story variables, passage history, and game progress.

```lua
-- Requires READ_STATE
local score = whisker.get_variable("score")
local current = whisker.get_current_passage()
local history = whisker.get_history()
```

### WRITE_STATE (Medium Risk)

Allows modifying story variables and triggering navigation.

```lua
-- Requires WRITE_STATE (and READ_STATE)
whisker.set_variable("score", 100)
whisker.navigate_to("ending")
```

### NETWORK (High Risk)

Allows HTTP requests to external servers.

```lua
-- Requires NETWORK
whisker.http_get("https://api.example.com/data", function(response)
  -- Handle response
end)
```

### FILESYSTEM (High Risk)

Allows reading and writing local files.

```lua
-- Requires FILESYSTEM
whisker.save_file("save.json", data)
local content = whisker.load_file("save.json")
```

## Secure Coding Practices

### Never Log Sensitive Data

```lua
-- BAD: Logs story content
function on_passage_view(passage)
  whisker.log.info("Content: " .. passage.content)
end

-- GOOD: Logs non-sensitive metadata
function on_passage_view(passage)
  whisker.log.info("Passage viewed: " .. passage.id)
end
```

### Validate All Input

```lua
-- BAD: Trusts user input
function set_custom_variable(name, value)
  whisker.set_variable(name, value)
end

-- GOOD: Validates input
function set_custom_variable(name, value)
  if type(name) ~= "string" or name == "" then
    error("Invalid variable name")
  end

  if #name > 100 then
    error("Variable name too long")
  end

  -- Only allow alphanumeric names
  if not name:match("^[a-zA-Z][a-zA-Z0-9_]*$") then
    error("Invalid variable name format")
  end

  whisker.set_variable(name, value)
end
```

### Use HTTPS for All Requests

```lua
-- BAD: HTTP (unencrypted)
whisker.http_get("http://api.example.com/data", callback)

-- GOOD: HTTPS (encrypted)
whisker.http_get("https://api.example.com/data", callback)
```

### Validate Server Responses

```lua
function fetch_data(url, callback)
  whisker.http_get(url, function(response)
    -- Validate response exists
    if not response then
      whisker.log.error("No response from server")
      return
    end

    -- Validate status code
    if response.status ~= 200 then
      whisker.log.error("Server error: " .. response.status)
      return
    end

    -- Validate content type
    local content_type = response.headers["Content-Type"]
    if not content_type or not content_type:match("application/json") then
      whisker.log.error("Unexpected content type")
      return
    end

    -- Parse and validate JSON
    local success, data = pcall(json.decode, response.body)
    if not success or type(data) ~= "table" then
      whisker.log.error("Invalid JSON response")
      return
    end

    callback(data)
  end)
end
```

### Don't Exfiltrate User Data

```lua
-- BAD: Sends entire story state to external server
function backup_to_cloud()
  local all_data = whisker.get_all_state()
  whisker.http_post("https://myserver.com/backup", all_data)
end

-- GOOD: Only send necessary data with user awareness
function backup_to_cloud()
  -- Only send save-relevant data
  local save_data = {
    passage = whisker.get_current_passage(),
    variables = whisker.get_save_variables(),
    timestamp = os.time()
  }

  whisker.http_post("https://myserver.com/backup", save_data)
end
```

## Error Handling

### Fail Gracefully

```lua
-- BAD: Unhandled errors crash plugin
function risky_operation()
  local result = whisker.http_get("https://api.example.com")
  return result.data.value
end

-- GOOD: Handle errors gracefully
function risky_operation()
  local success, result = pcall(function()
    local response = whisker.http_get("https://api.example.com")
    if not response or not response.data then
      error("Invalid response")
    end
    return response.data.value
  end)

  if not success then
    whisker.log.warn("Operation failed: " .. tostring(result))
    return nil
  end

  return result
end
```

### Don't Leak Information in Errors

```lua
-- BAD: Error exposes internal paths
function load_config()
  local file = whisker.load_file("/home/user/.plugin/secret.conf")
  -- Error: "Failed to read /home/user/.plugin/secret.conf"
end

-- GOOD: Generic error message
function load_config()
  local success, file = pcall(whisker.load_file, "config.conf")
  if not success then
    error("Failed to load configuration")
  end
  return file
end
```

## Avoiding Common Vulnerabilities

### Path Traversal Prevention

```lua
-- BAD: User-controlled path
function load_template(template_name)
  return whisker.load_file("templates/" .. template_name)
end
-- Attack: template_name = "../../etc/passwd"

-- GOOD: Validate filename
function load_template(template_name)
  -- Only allow alphanumeric and dashes
  if not template_name:match("^[a-zA-Z0-9_-]+$") then
    error("Invalid template name")
  end

  return whisker.load_file("templates/" .. template_name .. ".html")
end
```

### Injection Prevention

```lua
-- BAD: Direct string interpolation
function query_user(username)
  local query = "SELECT * FROM users WHERE name = '" .. username .. "'"
  return db.execute(query)
end

-- GOOD: Parameterized queries
function query_user(username)
  local query = "SELECT * FROM users WHERE name = ?"
  return db.execute(query, username)
end
```

## Plugin Manifest Best Practices

```lua
return {
  -- Required fields
  name = "my-plugin",
  version = "1.0.0",

  -- Minimal capabilities
  capabilities = {"READ_STATE"},

  -- Describe why you need each capability
  description = [[
    This plugin tracks passage visit counts.
    Requires READ_STATE to access visit history.
  ]],

  -- Lifecycle hooks
  on_init = function(context)
    -- Initialize plugin
  end,

  on_destroy = function(context)
    -- Clean up resources
  end,

  -- API functions
  api = {
    get_visit_count = function(passage_id)
      -- Implementation
    end
  }
}
```

## Security Checklist for Plugin Release

Before releasing your plugin:

- [ ] Request only necessary capabilities
- [ ] Validate all user input
- [ ] Handle errors gracefully
- [ ] Use HTTPS for all network requests
- [ ] Don't log sensitive data
- [ ] Test plugin with minimal permissions
- [ ] Document all capabilities in README
- [ ] Explain why each capability is needed
- [ ] Provide privacy policy if collecting data
- [ ] Test for path traversal vulnerabilities
- [ ] Never trust data from external sources
- [ ] Code review for security issues

## Handling Permission Denial

Users may deny capabilities. Handle this gracefully:

```lua
function on_init(context)
  -- Check if we have the capabilities we need
  if not context:has_capability("NETWORK") then
    whisker.log.info("Network features disabled (permission not granted)")
    -- Disable network-dependent features
    features.cloud_save = false
  end
end
```

## Testing Security

Test your plugin with different permission scenarios:

1. All permissions granted
2. Some permissions denied
3. No permissions granted

Ensure the plugin:
- Doesn't crash when permissions are denied
- Provides useful feedback to users
- Disables features gracefully
