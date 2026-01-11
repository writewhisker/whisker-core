--- Custom Test Matchers
-- Busted matchers for whisker-specific assertions
--
-- @module whisker.testing.matchers
-- @author Whisker Team
-- @license MIT
-- @usage
-- local matchers = require("whisker.testing.matchers")
-- matchers.register()  -- Register with Busted

local matchers = {}

---Story Matchers

--- Check if story has passage
-- @param state table Busted state
-- @param arguments table Arguments [story, passage_id]
-- @return boolean success
-- @return table error_info
matchers.has_passage = function(state, arguments)
  local story = arguments[1]
  local passage_id = arguments[2]
  
  if not story or not story.passages then
    return false
  end
  
  for _, passage in ipairs(story.passages) do
    if passage.id == passage_id then
      return true
    end
  end
  
  return false, {
    message = function()
      return string.format("Expected story to have passage '%s'", passage_id)
    end
  }
end

--- Check if story has variable
-- @param state table Busted state
-- @param arguments table Arguments [story, variable_name]
-- @return boolean success
-- @return table error_info
matchers.has_variable = function(state, arguments)
  local story = arguments[1]
  local var_name = arguments[2]
  
  if not story or not story.variables then
    return false
  end
  
  return story.variables[var_name] ~= nil, {
    message = function()
      return string.format("Expected story to have variable '%s'", var_name)
    end
  }
end

--- Check if passage has tag
-- @param state table Busted state
-- @param arguments table Arguments [passage, tag]
-- @return boolean success
-- @return table error_info
matchers.has_tag = function(state, arguments)
  local passage = arguments[1]
  local tag = arguments[2]
  
  if not passage or not passage.tags then
    return false
  end
  
  for _, t in ipairs(passage.tags) do
    if t == tag then
      return true
    end
  end
  
  return false, {
    message = function()
      return string.format("Expected passage to have tag '%s'", tag)
    end
  }
end

--- Check if choice connects to target
-- @param state table Busted state
-- @param arguments table Arguments [choice, target]
-- @return boolean success
-- @return table error_info
matchers.connects_to = function(state, arguments)
  local choice = arguments[1]
  local target = arguments[2]
  
  if not choice then
    return false
  end
  
  return choice.target == target, {
    message = function()
      return string.format("Expected choice to connect to '%s', but connects to '%s'", 
        target, choice.target or "nil")
    end
  }
end

--- Runtime Matchers

--- Check if runtime is at passage
-- @param state table Busted state
-- @param arguments table Arguments [runtime, passage_id]
-- @return boolean success
-- @return table error_info
matchers.is_at_passage = function(state, arguments)
  local runtime = arguments[1]
  local passage_id = arguments[2]
  
  if not runtime or not runtime.current_passage then
    return false
  end
  
  return runtime.current_passage == passage_id, {
    message = function()
      return string.format("Expected runtime at passage '%s', but at '%s'",
        passage_id, runtime.current_passage or "nil")
    end
  }
end

--- Check if passage has been visited
-- @param state table Busted state
-- @param arguments table Arguments [runtime, passage_id]
-- @return boolean success
-- @return table error_info
matchers.has_visited = function(state, arguments)
  local runtime = arguments[1]
  local passage_id = arguments[2]
  
  if not runtime or not runtime.history then
    return false
  end
  
  for _, visited in ipairs(runtime.history) do
    if visited == passage_id then
      return true
    end
  end
  
  return false, {
    message = function()
      return string.format("Expected passage '%s' to have been visited", passage_id)
    end
  }
end

--- Check if variable equals value
-- @param state table Busted state
-- @param arguments table Arguments [runtime, var_name, expected_value]
-- @return boolean success
-- @return table error_info
matchers.variable_equals = function(state, arguments)
  local runtime = arguments[1]
  local var_name = arguments[2]
  local expected = arguments[3]
  
  if not runtime or not runtime.variables then
    return false
  end
  
  local actual = runtime.variables[var_name]
  
  return actual == expected, {
    message = function()
      return string.format("Expected variable '%s' to equal '%s', but got '%s'",
        var_name, tostring(expected), tostring(actual))
    end
  }
end

--- Validation Matchers

--- Check if story is valid
-- @param state table Busted state
-- @param arguments table Arguments [story]
-- @return boolean success
-- @return table error_info
matchers.is_valid_story = function(state, arguments)
  local story = arguments[1]
  
  -- Basic validation
  if not story then
    return false, { message = function() return "Story is nil" end }
  end
  
  if type(story) ~= "table" then
    return false, { message = function() return "Story must be a table" end }
  end
  
  if not story.id then
    return false, { message = function() return "Story missing ID" end }
  end
  
  if not story.passages or type(story.passages) ~= "table" then
    return false, { message = function() return "Story missing passages array" end }
  end
  
  if #story.passages == 0 then
    return false, { message = function() return "Story has no passages" end }
  end
  
  return true
end

--- Check if story has no dead ends
-- @param state table Busted state
-- @param arguments table Arguments [story]
-- @return boolean success
-- @return table error_info
matchers.has_no_dead_ends = function(state, arguments)
  local story = arguments[1]
  
  if not story or not story.passages then
    return false
  end
  
  -- Find passages with no outgoing links
  local dead_ends = {}
  
  for _, passage in ipairs(story.passages) do
    -- Check if passage has links
    local has_links = false
    
    if passage.links and #passage.links > 0 then
      has_links = true
    end
    
    -- Check for special tags that indicate endings
    local is_ending = false
    if passage.tags then
      for _, tag in ipairs(passage.tags) do
        if tag == "ending" or tag == "end" then
          is_ending = true
          break
        end
      end
    end
    
    if not has_links and not is_ending then
      table.insert(dead_ends, passage.id)
    end
  end
  
  return #dead_ends == 0, {
    message = function()
      return string.format("Story has dead ends: %s", table.concat(dead_ends, ", "))
    end
  }
end

--- Check if story has no orphaned passages
-- @param state table Busted state
-- @param arguments table Arguments [story]
-- @return boolean success
-- @return table error_info
matchers.has_no_orphans = function(state, arguments)
  local story = arguments[1]
  
  if not story or not story.passages then
    return false
  end
  
  -- Build graph of reachable passages
  local reachable = {}
  local to_visit = {}
  
  -- Find start passage
  local start_passage = nil
  for _, passage in ipairs(story.passages) do
    if passage.tags then
      for _, tag in ipairs(passage.tags) do
        if tag == "start" or passage.id == "start" then
          start_passage = passage.id
          break
        end
      end
    end
  end
  
  if not start_passage and #story.passages > 0 then
    start_passage = story.passages[1].id
  end
  
  if start_passage then
    table.insert(to_visit, start_passage)
  end
  
  -- BFS to find all reachable passages
  while #to_visit > 0 do
    local current = table.remove(to_visit, 1)
    
    if not reachable[current] then
      reachable[current] = true
      
      -- Find passage and add its links to queue
      for _, passage in ipairs(story.passages) do
        if passage.id == current and passage.links then
          for _, link in ipairs(passage.links) do
            if not reachable[link.target] then
              table.insert(to_visit, link.target)
            end
          end
        end
      end
    end
  end
  
  -- Find orphaned passages
  local orphans = {}
  for _, passage in ipairs(story.passages) do
    if not reachable[passage.id] then
      table.insert(orphans, passage.id)
    end
  end
  
  return #orphans == 0, {
    message = function()
      return string.format("Story has orphaned passages: %s", table.concat(orphans, ", "))
    end
  }
end

--- Fuzzy Matchers

--- Check if passage contains text (case-insensitive)
-- @param state table Busted state
-- @param arguments table Arguments [passage, text]
-- @return boolean success
-- @return table error_info
matchers.contains_text = function(state, arguments)
  local passage = arguments[1]
  local text = arguments[2]
  
  if not passage or not passage.text then
    return false
  end
  
  local passage_text = passage.text:lower()
  local search_text = text:lower()
  
  return passage_text:find(search_text, 1, true) ~= nil, {
    message = function()
      return string.format("Expected passage to contain '%s'", text)
    end
  }
end

--- Check if text matches Lua pattern
-- @param state table Busted state
-- @param arguments table Arguments [text, pattern]
-- @return boolean success
-- @return table error_info
matchers.matches_pattern = function(state, arguments)
  local text = arguments[1]
  local pattern = arguments[2]
  
  if not text then
    return false
  end
  
  return text:match(pattern) ~= nil, {
    message = function()
      return string.format("Expected text to match pattern '%s'", pattern)
    end
  }
end

--- Register all matchers with Busted
-- @usage matchers.register()
function matchers.register()
  -- Check if assert exists (Busted environment)
  if assert and assert.register then
    for name, matcher in pairs(matchers) do
      if name ~= "register" then
        assert:register("assertion", name, matcher)
      end
    end
  end
end

return matchers
