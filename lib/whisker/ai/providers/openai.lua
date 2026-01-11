--[[
  OpenAI Provider for AI Client
  
  Integrates with OpenAI API (GPT-3.5, GPT-4, etc.)
  
  Requires:
  - lua-http or luasocket for HTTP requests
  - lua-cjson for JSON
  - OPENAI_API_KEY environment variable
  
  Usage:
    local AIClient = require("whisker.ai.client")
    local ai = AIClient.new({
      provider = "openai",
      api_key = os.getenv("OPENAI_API_KEY"),
      model = "gpt-4"
    })
]]

local json = require("cjson")

local OpenAI = {}

--[[
  Complete text generation request
  
  @param client table AI client instance
  @param request table Completion request
  @return table Result with text and usage
]]
function OpenAI.complete(client, request)
  local api_key = client.api_key or os.getenv("OPENAI_API_KEY")
  
  if not api_key then
    return {
      text = "Error: OPENAI_API_KEY not set",
      usage = { prompt_tokens = 0, completion_tokens = 0, total_tokens = 0 },
      error = "Missing API key"
    }
  end
  
  local model = client.model or "gpt-3.5-turbo-instruct"
  local temperature = request.temperature or client.temperature or 0.7
  local max_tokens = request.max_tokens or client.max_tokens or 1000
  
  -- Build API request
  local api_request = {
    model = model,
    prompt = request.prompt,
    temperature = temperature,
    max_tokens = max_tokens
  }
  
  -- Make HTTP request
  local response = OpenAI.http_request(
    "https://api.openai.com/v1/completions",
    "POST",
    api_key,
    api_request
  )
  
  if not response or response.error then
    return {
      text = "Error: " .. (response and response.error or "Request failed"),
      usage = { prompt_tokens = 0, completion_tokens = 0, total_tokens = 0 },
      error = response and response.error or "Request failed"
    }
  end
  
  -- Extract result
  local text = ""
  if response.choices and #response.choices > 0 then
    text = response.choices[1].text or ""
  end
  
  return {
    text = text,
    usage = response.usage or {
      prompt_tokens = 0,
      completion_tokens = 0,
      total_tokens = 0
    },
    model = response.model
  }
end

--[[
  Chat completion request
  
  @param client table AI client instance
  @param request table Chat request with messages
  @return table Result with text and usage
]]
function OpenAI.chat(client, request)
  local api_key = client.api_key or os.getenv("OPENAI_API_KEY")
  
  if not api_key then
    return {
      text = "Error: OPENAI_API_KEY not set",
      usage = { prompt_tokens = 0, completion_tokens = 0, total_tokens = 0 },
      error = "Missing API key"
    }
  end
  
  local model = client.model or "gpt-3.5-turbo"
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
  local response = OpenAI.http_request(
    "https://api.openai.com/v1/chat/completions",
    "POST",
    api_key,
    api_request
  )
  
  if not response or response.error then
    return {
      text = "Error: " .. (response and response.error or "Request failed"),
      usage = { prompt_tokens = 0, completion_tokens = 0, total_tokens = 0 },
      error = response and response.error or "Request failed"
    }
  end
  
  -- Extract result
  local text = ""
  if response.choices and #response.choices > 0 then
    local message = response.choices[1].message
    text = message and message.content or ""
  end
  
  return {
    text = text,
    usage = response.usage or {
      prompt_tokens = 0,
      completion_tokens = 0,
      total_tokens = 0
    },
    model = response.model
  }
end

--[[
  Make HTTP request to OpenAI API
  
  @param url string API endpoint
  @param method string HTTP method
  @param api_key string API key
  @param data table Request body
  @return table Response data
]]
function OpenAI.http_request(url, method, api_key, data)
  -- Try lua-http first, fallback to curl
  local success, result = pcall(OpenAI.http_request_lua_http, url, method, api_key, data)
  
  if success and result then
    return result
  end
  
  -- Fallback to curl
  return OpenAI.http_request_curl(url, method, api_key, data)
end

--[[
  HTTP request using curl (fallback)
]]
function OpenAI.http_request_curl(url, method, api_key, data)
  local body = json.encode(data)
  
  -- Write request to temp file
  local temp_file = os.tmpname()
  local f = io.open(temp_file, "w")
  f:write(body)
  f:close()
  
  -- Make curl request
  local cmd = string.format(
    'curl -s -X %s "%s" ' ..
    '-H "Authorization: Bearer %s" ' ..
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

--[[
  HTTP request using lua-http (if available)
]]
function OpenAI.http_request_lua_http(url, method, api_key, data)
  -- Try to load lua-http
  local http = require("http.request")
  local headers = require("http.headers")
  
  local req = http.new_from_uri(url)
  req.headers:upsert(":method", method)
  req.headers:upsert("authorization", "Bearer " .. api_key)
  req.headers:upsert("content-type", "application/json")
  
  local body = json.encode(data)
  req:set_body(body)
  
  local hdrs, stream = req:go()
  local response_body = stream:get_body_as_string()
  
  if response_body then
    return json.decode(response_body)
  end
  
  return nil
end

return OpenAI
