-- tests/support/helpers.lua
-- Common test utilities and assertion helpers
-- Note: These helpers use the busted 'assert' global when available

local Helpers = {}

-- Helper to get assert (busted's or standard)
local function get_assert()
  -- In busted context, assert is enhanced with .is_not_nil, .are.equal, etc.
  return assert
end

-- Assert that a passage has expected properties
-- @param passage table - Passage object to check
-- @param expected table - Expected properties (id, title, content, etc.)
function Helpers.assert_passage(passage, expected)
  local a = get_assert()
  a(passage ~= nil, "Passage should not be nil")

  if expected.id then
    a(expected.id == passage.id,
      string.format("Passage id mismatch: expected '%s', got '%s'", expected.id, tostring(passage.id)))
  end

  if expected.title then
    a(expected.title == passage.title,
      string.format("Passage title mismatch: expected '%s', got '%s'", expected.title, tostring(passage.title)))
  end

  if expected.content then
    a(expected.content == passage.content, "Passage content mismatch")
  end

  if expected.choice_count then
    local actual_count = passage.choices and #passage.choices or 0
    a(expected.choice_count == actual_count,
      string.format("Choice count mismatch: expected %d, got %d", expected.choice_count, actual_count))
  end
end

-- Assert that a choice has expected properties
-- @param choice table - Choice object to check
-- @param expected table - Expected properties (id, text, target, etc.)
function Helpers.assert_choice(choice, expected)
  local a = get_assert()
  a(choice ~= nil, "Choice should not be nil")

  if expected.id then
    a(expected.id == choice.id,
      string.format("Choice id mismatch: expected '%s', got '%s'", expected.id, tostring(choice.id)))
  end

  if expected.text then
    a(expected.text == choice.text,
      string.format("Choice text mismatch: expected '%s', got '%s'", expected.text, tostring(choice.text)))
  end

  if expected.target then
    a(expected.target == choice.target,
      string.format("Choice target mismatch: expected '%s', got '%s'", expected.target, tostring(choice.target)))
  end

  if expected.has_condition ~= nil then
    local has_cond = choice.condition ~= nil
    a(expected.has_condition == has_cond, "Choice condition presence mismatch")
  end
end

-- Assert that a story is valid
-- @param story table - Story data to validate
function Helpers.assert_story_valid(story)
  local a = get_assert()
  a(story ~= nil, "Story should not be nil")
  a(story.name ~= nil, "Story should have a name")
  a(story.start ~= nil, "Story should have a start passage")
  a(story.passages ~= nil, "Story should have passages")
  a(type(story.passages) == "table", "Passages should be a table")

  -- Verify start passage exists
  a(story.passages[story.start] ~= nil,
    string.format("Start passage '%s' not found in passages", story.start))

  -- Verify all passage targets are valid
  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.target then
          a(story.passages[choice.target] ~= nil,
            string.format("Choice in '%s' references non-existent passage '%s'",
              passage_id, choice.target))
        end
      end
    end
  end
end

-- Assert that a table contains expected keys
-- @param tbl table - Table to check
-- @param keys table - Array of expected key names
function Helpers.assert_has_keys(tbl, keys)
  local a = get_assert()
  a(type(tbl) == "table", "Expected a table")
  for _, key in ipairs(keys) do
    a(tbl[key] ~= nil,
      string.format("Expected key '%s' not found in table", key))
  end
end

-- Assert that a function does not error
-- @param fn function - Function to call
-- @param ... - Arguments to pass to function
-- @return any - Return value from function
function Helpers.assert_no_error(fn, ...)
  local a = get_assert()
  local ok, result = pcall(fn, ...)
  a(ok, string.format("Expected no error, got: %s", tostring(result)))
  return result
end

-- Create a simple test story programmatically
-- @param options table - Optional overrides
-- @return table - Story data
function Helpers.make_story(options)
  options = options or {}
  return {
    name = options.name or "Test Story",
    version = options.version or "2.0",
    start = options.start or "start",
    passages = options.passages or {
      start = {
        id = "start",
        title = "Start",
        content = "Test content",
        choices = options.choices or {}
      }
    },
    variables = options.variables or {}
  }
end

-- Create a simple passage programmatically
-- @param id string - Passage ID
-- @param options table - Optional overrides
-- @return table - Passage data
function Helpers.make_passage(id, options)
  options = options or {}
  return {
    id = id,
    title = options.title or id,
    content = options.content or "Content for " .. id,
    choices = options.choices or {}
  }
end

-- Create a simple choice programmatically
-- @param target string - Target passage ID
-- @param options table - Optional overrides
-- @return table - Choice data
function Helpers.make_choice(target, options)
  options = options or {}
  return {
    id = options.id or ("to_" .. target),
    text = options.text or ("Go to " .. target),
    target = target,
    condition = options.condition
  }
end

-- Deep compare two tables
-- @param t1 table - First table
-- @param t2 table - Second table
-- @return boolean - True if tables are equal
function Helpers.tables_equal(t1, t2)
  if type(t1) ~= type(t2) then return false end
  if type(t1) ~= "table" then return t1 == t2 end

  for k, v in pairs(t1) do
    if not Helpers.tables_equal(v, t2[k]) then return false end
  end

  for k in pairs(t2) do
    if t1[k] == nil then return false end
  end

  return true
end

return Helpers
