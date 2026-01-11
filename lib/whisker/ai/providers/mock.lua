--- Mock AI Provider
-- For testing without API calls
--
-- @module whisker.ai.providers.mock

local mock = {}

--- Complete text (mock)
-- @param client table AI client
-- @param request table Request options
-- @return table result Mock result
function mock.complete(client, request)
  local text = "This is a mock completion for: " .. (request.prompt or "")
  
  return {
    text = text,
    usage = {
      prompt_tokens = client:count_tokens(request.prompt or ""),
      completion_tokens = client:count_tokens(text),
      total_tokens = client:count_tokens(request.prompt or "") + client:count_tokens(text)
    },
    model = client.model,
    provider = "mock"
  }
end

--- Chat completion (mock)
-- @param client table AI client
-- @param request table Request options
-- @return table result Mock result
function mock.chat(client, request)
  local last_message = request.messages[#request.messages]
  local text = "Mock response to: " .. (last_message.content or "")
  
  return {
    text = text,
    usage = {
      prompt_tokens = 50,
      completion_tokens = client:count_tokens(text),
      total_tokens = 50 + client:count_tokens(text)
    },
    model = client.model,
    provider = "mock"
  }
end

return mock
