--- Factory Interface Contract Tests
-- Validates implementations of IChoiceFactory, IPassageFactory, IStoryFactory
-- @module tests.contracts.factories_contract
-- @author Whisker Core Team
-- @license MIT

local FactoriesContract = {}

--- Create contract tests for IChoiceFactory
-- @param factory_impl table The factory implementation to test
-- @return table Test results
function FactoriesContract.test_choice_factory(factory_impl)
  local results = {passed = 0, failed = 0, errors = {}}

  -- Test: create method exists
  if type(factory_impl.create) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IChoiceFactory:create must be a function")
  end

  -- Test: from_table method exists
  if type(factory_impl.from_table) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IChoiceFactory:from_table must be a function")
  end

  -- Test: restore_metatable method exists
  if type(factory_impl.restore_metatable) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IChoiceFactory:restore_metatable must be a function")
  end

  -- Test: create returns valid choice
  local ok, choice = pcall(function()
    return factory_impl:create({
      text = "Test choice",
      target = "passage_1"
    })
  end)
  if ok and choice then
    if choice.text == "Test choice" and (choice.target == "passage_1" or choice.target_passage == "passage_1") then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IChoiceFactory:create should return choice with correct properties")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IChoiceFactory:create should not throw: " .. tostring(choice))
  end

  -- Test: from_table restores choice
  local ok2, restored = pcall(function()
    return factory_impl:from_table({
      id = "ch_123",
      text = "Restored choice",
      target_passage = "passage_2"
    })
  end)
  if ok2 and restored then
    if restored.text == "Restored choice" then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IChoiceFactory:from_table should restore choice data")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IChoiceFactory:from_table should not throw: " .. tostring(restored))
  end

  return results
end

--- Create contract tests for IPassageFactory
-- @param factory_impl table The factory implementation to test
-- @return table Test results
function FactoriesContract.test_passage_factory(factory_impl)
  local results = {passed = 0, failed = 0, errors = {}}

  -- Test: create method exists
  if type(factory_impl.create) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IPassageFactory:create must be a function")
  end

  -- Test: from_table method exists
  if type(factory_impl.from_table) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IPassageFactory:from_table must be a function")
  end

  -- Test: restore_metatable method exists
  if type(factory_impl.restore_metatable) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IPassageFactory:restore_metatable must be a function")
  end

  -- Test: create returns valid passage
  local ok, passage = pcall(function()
    return factory_impl:create({
      id = "test_passage",
      name = "Test Passage",
      content = "Test content"
    })
  end)
  if ok and passage then
    if passage.id == "test_passage" and passage.name == "Test Passage" then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IPassageFactory:create should return passage with correct properties")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IPassageFactory:create should not throw: " .. tostring(passage))
  end

  -- Test: from_table restores passage with choices
  local ok2, restored = pcall(function()
    return factory_impl:from_table({
      id = "restored_passage",
      name = "Restored Passage",
      content = "Restored content",
      choices = {
        {text = "Choice 1", target_passage = "p1"},
        {text = "Choice 2", target_passage = "p2"}
      }
    })
  end)
  if ok2 and restored then
    if restored.id == "restored_passage" and #restored.choices == 2 then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IPassageFactory:from_table should restore passage with choices")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IPassageFactory:from_table should not throw: " .. tostring(restored))
  end

  return results
end

--- Create contract tests for IStoryFactory
-- @param factory_impl table The factory implementation to test
-- @return table Test results
function FactoriesContract.test_story_factory(factory_impl)
  local results = {passed = 0, failed = 0, errors = {}}

  -- Test: create method exists
  if type(factory_impl.create) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IStoryFactory:create must be a function")
  end

  -- Test: from_table method exists
  if type(factory_impl.from_table) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IStoryFactory:from_table must be a function")
  end

  -- Test: restore_metatable method exists
  if type(factory_impl.restore_metatable) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IStoryFactory:restore_metatable must be a function")
  end

  -- Test: create returns valid story
  local ok, story = pcall(function()
    return factory_impl:create({
      title = "Test Story",
      author = "Test Author"
    })
  end)
  if ok and story then
    if story.metadata and story.metadata.name == "Test Story" then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IStoryFactory:create should return story with correct metadata")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IStoryFactory:create should not throw: " .. tostring(story))
  end

  -- Test: from_table restores story with passages
  local ok2, restored = pcall(function()
    return factory_impl:from_table({
      metadata = {name = "Restored Story", author = "Author"},
      passages = {
        start = {id = "start", name = "Start", content = "Beginning"}
      },
      start_passage = "start"
    })
  end)
  if ok2 and restored then
    if restored.metadata.name == "Restored Story" and restored.passages.start then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IStoryFactory:from_table should restore story with passages")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IStoryFactory:from_table should not throw: " .. tostring(restored))
  end

  return results
end

--- Create contract tests for IGameStateFactory
-- @param factory_impl table The factory implementation to test
-- @return table Test results
function FactoriesContract.test_game_state_factory(factory_impl)
  local results = {passed = 0, failed = 0, errors = {}}

  -- Test: create method exists
  if type(factory_impl.create) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IGameStateFactory:create must be a function")
  end

  -- Test: create returns valid game state
  local ok, game_state = pcall(function()
    return factory_impl:create()
  end)
  if ok and game_state then
    -- Check for essential methods
    if type(game_state.set) == "function" and type(game_state.get) == "function" then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IGameStateFactory:create should return game state with set/get methods")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IGameStateFactory:create should not throw: " .. tostring(game_state))
  end

  return results
end

--- Create contract tests for ILuaInterpreterFactory
-- @param factory_impl table The factory implementation to test
-- @return table Test results
function FactoriesContract.test_lua_interpreter_factory(factory_impl)
  local results = {passed = 0, failed = 0, errors = {}}

  -- Test: create method exists
  if type(factory_impl.create) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "ILuaInterpreterFactory:create must be a function")
  end

  -- Test: create returns valid interpreter
  local ok, interpreter = pcall(function()
    return factory_impl:create()
  end)
  if ok and interpreter then
    -- Check for essential methods
    if type(interpreter.execute_code) == "function" then
      results.passed = results.passed + 1
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "ILuaInterpreterFactory:create should return interpreter with execute_code method")
    end
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "ILuaInterpreterFactory:create should not throw: " .. tostring(interpreter))
  end

  return results
end

--- Create contract tests for IEngineFactory
-- @param factory_impl table The factory implementation to test
-- @param story_factory table A story factory to create test stories
-- @return table Test results
function FactoriesContract.test_engine_factory(factory_impl, story_factory)
  local results = {passed = 0, failed = 0, errors = {}}

  -- Test: create method exists
  if type(factory_impl.create) == "function" then
    results.passed = results.passed + 1
  else
    results.failed = results.failed + 1
    table.insert(results.errors, "IEngineFactory:create must be a function")
  end

  -- Test: create returns valid engine (if story factory provided)
  if story_factory then
    local ok, engine = pcall(function()
      local story = story_factory:create({title = "Test"})
      return factory_impl:create(story)
    end)
    if ok and engine then
      -- Check for essential methods
      if type(engine.start_story) == "function" then
        results.passed = results.passed + 1
      else
        results.failed = results.failed + 1
        table.insert(results.errors, "IEngineFactory:create should return engine with start_story method")
      end
    else
      results.failed = results.failed + 1
      table.insert(results.errors, "IEngineFactory:create should not throw: " .. tostring(engine))
    end
  end

  return results
end

--- Run all factory contract tests
-- @param factories table Map of factory name to implementation
-- @return table Combined test results
function FactoriesContract.run_all(factories)
  local all_results = {
    passed = 0,
    failed = 0,
    errors = {},
    by_factory = {}
  }

  if factories.choice_factory then
    local r = FactoriesContract.test_choice_factory(factories.choice_factory)
    all_results.by_factory.choice_factory = r
    all_results.passed = all_results.passed + r.passed
    all_results.failed = all_results.failed + r.failed
    for _, err in ipairs(r.errors) do
      table.insert(all_results.errors, "ChoiceFactory: " .. err)
    end
  end

  if factories.passage_factory then
    local r = FactoriesContract.test_passage_factory(factories.passage_factory)
    all_results.by_factory.passage_factory = r
    all_results.passed = all_results.passed + r.passed
    all_results.failed = all_results.failed + r.failed
    for _, err in ipairs(r.errors) do
      table.insert(all_results.errors, "PassageFactory: " .. err)
    end
  end

  if factories.story_factory then
    local r = FactoriesContract.test_story_factory(factories.story_factory)
    all_results.by_factory.story_factory = r
    all_results.passed = all_results.passed + r.passed
    all_results.failed = all_results.failed + r.failed
    for _, err in ipairs(r.errors) do
      table.insert(all_results.errors, "StoryFactory: " .. err)
    end
  end

  if factories.game_state_factory then
    local r = FactoriesContract.test_game_state_factory(factories.game_state_factory)
    all_results.by_factory.game_state_factory = r
    all_results.passed = all_results.passed + r.passed
    all_results.failed = all_results.failed + r.failed
    for _, err in ipairs(r.errors) do
      table.insert(all_results.errors, "GameStateFactory: " .. err)
    end
  end

  if factories.lua_interpreter_factory then
    local r = FactoriesContract.test_lua_interpreter_factory(factories.lua_interpreter_factory)
    all_results.by_factory.lua_interpreter_factory = r
    all_results.passed = all_results.passed + r.passed
    all_results.failed = all_results.failed + r.failed
    for _, err in ipairs(r.errors) do
      table.insert(all_results.errors, "LuaInterpreterFactory: " .. err)
    end
  end

  if factories.engine_factory then
    local r = FactoriesContract.test_engine_factory(factories.engine_factory, factories.story_factory)
    all_results.by_factory.engine_factory = r
    all_results.passed = all_results.passed + r.passed
    all_results.failed = all_results.failed + r.failed
    for _, err in ipairs(r.errors) do
      table.insert(all_results.errors, "EngineFactory: " .. err)
    end
  end

  return all_results
end

return FactoriesContract
