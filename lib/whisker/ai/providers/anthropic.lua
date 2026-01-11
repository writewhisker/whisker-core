--[[
  Anthropic Provider for AI Client
  
  Integrates with Anthropic Claude API
  
  Requires:
  - ANTHROPIC_API_KEY environment variable
  
  Usage:
    local AIClient = require("whisker.ai.client")
    local ai = AIClient.new({
      provider = "anthropic",
      api_key = os.getenv("ANTHROPIC_API_KEY"),
      model = "claude-3-opus-20240229"
    })
]]

local json = require("cjson")

local Anthropic = {}

--[[
  Complete text generation (converted to chat format for Claude)
]]
function Anthropic.complete(client, request)
  -- Convert to chat format
  return Anthropic.chat(client, {
    messages = {
      { role = "user", content = request.prompt }
    },
    temperature = request.temperature,
    max_tokens = request.max_tokens
  })
end

--[[
  Chat completion request
]]
function Anthropic.chat(client, request)
  local api_key = client.api_key or os.getenv("ANTHROPIC_API_KEY")
  
  if not api_key then
    return {
      text = "Error: ANTHROPIC_API_KEY not set",
      usage = { prompt_tokens = 0, completion_tokens = 0, total_tokens = 0 },
      error = "Missing API key"
    }
  end
  
  local model = client.model or "claude-3-sonnet-20240229"
  local temperature = request.temperature or client.temperature or 0.7
  local max_tokens = request.max_tokens or client.max_tokens or 1000
  
  -- Build API request
  local api_request = {
    model = model,
    messages = request.messages,
    temperature = temperature,
    max_tokens = max_tokens
  }
  
  -- Make HTTP request
  local response = Anthropic.http_request(
    "https://api.anthropic.com/v1/messages",
    "POST",
    api_key,
    api_request
  )
  
  if not response or response.error then
    return {
      text = "Error: " .. (response and (response.error.message or response.error) or "Request failed"),
      usage = { prompt_tokens = 0, completion_tokens = 0, total_tokens = 0 },
      error = response and (response.error.message or response.error) or "Request failed"
    }
  end
  
  -- Extract result
  local text = ""
  if response.content and #response.content > 0 then
    text = response.content[1].text or ""
  end
  
  -- Calculate usage
  local usage = {
    prompt_tokens = response.usage and response.usage.input_tokens or 0,
    completion_tokens = response.usage and response.usage.output_tokens or 0,
    total_tokens = 0
  }
  usage.total_tokens = usage.prompt_tokens + usage.completion_tokens
  
  return {
    text = text,
    usage = usage,
    model = response.model
  }
end

--[[
  Make HTTP request to Anthropic API
]]
function Anthropic.http_request(url, method, api_key, data)
  local body = json.encode(data)
  
  -- Write request to temp file
  local temp_file = os.tmpname()
  local f = io.open(temp_file, "w")
  f:write(body)
  f:close()
  
  -- Make curl request with Anthropic-specific headers
  local cmd = string.format(
    'curl -s -X %s "%s" ' ..
    '-H "x-api-key: %s" ' ..
    '-H "anthropic-version: 2023-06-01" ' ..
    '-H "Content-Type: application/json" ' ..
    '-d @%s',
    method, url, api_key, temp_file
  )
  
  local handle = io.popen(cmd)
  local response_str = handle:read("*a")
  handle:close()
  
  -- Cleanup
  os.remove(temp_file)
  
  -- Parse response
  if response_str and response_str ~= "" then
    local ok, response = pcall(json.decode, response_str)
    if ok then
      return response
    end
  end
  
  return nil
end

return Anthropic
