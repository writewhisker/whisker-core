--- AI Service Client
-- Multi-provider AI API client for story generation and assistance
--
-- @module whisker.ai.client
-- @author Whisker Team
-- @license MIT
-- @usage
-- local AIClient = require("whisker.ai.client")
-- local ai = AIClient.new({ provider = "openai", api_key = key })

local json = require("cjson")

local AIClient = {}
AIClient.__index = AIClient

--- Supported providers
AIClient.Providers = {
  OPENAI = "openai",
  ANTHROPIC = "anthropic",
  OLLAMA = "ollama",
  MOCK = "mock"  -- For testing
}

--- Create new AI client
-- @param options table Configuration
-- @param options.provider string Provider name
-- @param options.api_key string API key (not needed for Ollama)
-- @param options.model string Model name
-- @param options.temperature number Temperature (0-1, default: 0.7)
-- @param options.max_tokens number Max tokens (default: 1000)
-- @param options.base_url string Custom base URL (optional)
-- @return AIClient New client instance
function AIClient.new(options)
  assert(options, "Options required")
  assert(options.provider, "Provider required")
  
  local self = setmetatable({}, AIClient)
  self.provider = options.provider
  self.api_key = options.api_key
  self.model = options.model or self:get_default_model(options.provider)
  self.temperature = options.temperature or 0.7
  self.max_tokens = options.max_tokens or 1000
  self.base_url = options.base_url
  
  -- Load provider-specific implementation
  self.provider_impl = self:load_provider(options.provider)
  
  -- Statistics
  self.stats = {
    requests = 0,
    tokens_used = 0,
    errors = 0
  }
  
  -- Response cache
  self.cache = {}
  self.cache_enabled = options.cache ~= false
  
  return self
end

--- Get default model for provider
-- @param provider string Provider name
-- @return string Default model
function AIClient:get_default_model(provider)
  local defaults = {
    openai = "gpt-3.5-turbo",
    anthropic = "claude-3-sonnet-20240229",
    ollama = "llama2",
    mock = "mock-model"
  }
  return defaults[provider] or "gpt-3.5-turbo"
end

--- Load provider implementation
-- @param provider string Provider name
-- @return table Provider implementation
function AIClient:load_provider(provider)
  local provider_path = string.format("whisker.ai.providers.%s", provider)
  local success, provider_module = pcall(require, provider_path)
  
  if not success then
    error(string.format("Provider '%s' not found: %s", provider, provider_module))
  end
  
  return provider_module
end

--- Generate text completion
-- @param options table Completion options
-- @param options.prompt string Prompt text
-- @param options.max_tokens number Max tokens (optional)
-- @param options.temperature number Temperature (optional)
-- @param options.stream boolean Stream response (optional)
-- @param options.on_chunk function Stream callback (optional)
-- @return table Result {text, usage, model}
-- @return string|nil error Error message if failed
function AIClient:complete(options)
  assert(options.prompt, "Prompt required")
  
  -- Check cache
  if self.cache_enabled and not options.stream then
    local cache_key = self:get_cache_key("complete", options)
    if self.cache[cache_key] then
      return self.cache[cache_key]
    end
  end
  
  -- Prepare request
  local request = {
    prompt = options.prompt,
    max_tokens = options.max_tokens or self.max_tokens,
    temperature = options.temperature or self.temperature,
    model = self.model,
    stream = options.stream or false,
    on_chunk = options.on_chunk
  }
  
  -- Call provider
  self.stats.requests = self.stats.requests + 1
  local result, err = self.provider_impl.complete(self, request)
  
  if not result then
    self.stats.errors = self.stats.errors + 1
    return nil, err
  end
  
  -- Update stats
  if result.usage then
    self.stats.tokens_used = self.stats.tokens_used + (result.usage.total_tokens or 0)
  end
  
  -- Cache result
  if self.cache_enabled and not options.stream then
    local cache_key = self:get_cache_key("complete", options)
    self.cache[cache_key] = result
  end
  
  return result
end

--- Generate chat completion
-- @param options table Chat options
-- @param options.messages table Array of messages
-- @param options.max_tokens number Max tokens (optional)
-- @param options.temperature number Temperature (optional)
-- @param options.stream boolean Stream response (optional)
-- @param options.on_chunk function Stream callback (optional)
-- @return table Result {text, usage, model}
-- @return string|nil error Error message if failed
function AIClient:chat(options)
  assert(options.messages, "Messages required")
  assert(type(options.messages) == "table", "Messages must be a table")
  
  -- Check cache
  if self.cache_enabled and not options.stream then
    local cache_key = self:get_cache_key("chat", options)
    if self.cache[cache_key] then
      return self.cache[cache_key]
    end
  end
  
  -- Prepare request
  local request = {
    messages = options.messages,
    max_tokens = options.max_tokens or self.max_tokens,
    temperature = options.temperature or self.temperature,
    model = self.model,
    stream = options.stream or false,
    on_chunk = options.on_chunk
  }
  
  -- Call provider
  self.stats.requests = self.stats.requests + 1
  local result, err = self.provider_impl.chat(self, request)
  
  if not result then
    self.stats.errors = self.stats.errors + 1
    return nil, err
  end
  
  -- Update stats
  if result.usage then
    self.stats.tokens_used = self.stats.tokens_used + (result.usage.total_tokens or 0)
  end
  
  -- Cache result
  if self.cache_enabled and not options.stream then
    local cache_key = self:get_cache_key("chat", options)
    self.cache[cache_key] = result
  end
  
  return result
end

--- Count tokens in text (approximate)
-- @param text string Text to count
-- @return number tokens Approximate token count
function AIClient:count_tokens(text)
  -- Simple approximation: ~4 characters per token
  return math.ceil(#text / 4)
end

--- Estimate cost for operation
-- @param tokens number Number of tokens
-- @param operation string Operation type ("complete" or "chat")
-- @return number cost Cost in USD
function AIClient:estimate_cost(tokens, operation)
  -- Cost per 1K tokens (approximate, as of 2024)
  local costs = {
    openai = {
      ["gpt-3.5-turbo"] = 0.002,
      ["gpt-4"] = 0.03,
      ["gpt-4-turbo"] = 0.01
    },
    anthropic = {
      ["claude-3-sonnet-20240229"] = 0.015,
      ["claude-3-opus-20240229"] = 0.075
    },
    ollama = {}, -- Free (local)
    mock = {}    -- Free (testing)
  }
  
  local provider_costs = costs[self.provider] or {}
  local cost_per_1k = provider_costs[self.model] or 0
  
  return (tokens / 1000) * cost_per_1k
end

--- Get statistics
-- @return table stats Usage statistics
function AIClient:get_stats()
  return {
    requests = self.stats.requests,
    tokens_used = self.stats.tokens_used,
    errors = self.stats.errors,
    estimated_cost = self:estimate_cost(self.stats.tokens_used, "chat"),
    cache_size = self:get_cache_size()
  }
end

--- Clear cache
function AIClient:clear_cache()
  self.cache = {}
end

--- Get cache size
-- @return number size Number of cached items
function AIClient:get_cache_size()
  local count = 0
  for _ in pairs(self.cache) do
    count = count + 1
  end
  return count
end

--- Generate cache key
-- @param operation string Operation type
-- @param options table Options
-- @return string key Cache key
function AIClient:get_cache_key(operation, options)
  local parts = {
    operation,
    self.provider,
    self.model,
    json.encode(options)
  }
  return table.concat(parts, "::")
end

--- HTTP request helper (to be used by providers)
-- @param url string URL
-- @param method string HTTP method
-- @param headers table Headers
-- @param body string Request body (optional)
-- @return table response Response data
-- @return string|nil error Error message
function AIClient:http_request(url, method, headers, body)
  -- This is a simplified implementation
  -- In production, use lua-http or similar
  
  -- For now, return error to indicate external dependency needed
  return nil, "HTTP client not implemented. Install lua-http and implement http_request method."
end

return AIClient
