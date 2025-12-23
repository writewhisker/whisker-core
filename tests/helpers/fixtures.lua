--- Test Fixtures
-- Factory functions for creating test data
-- @module tests.helpers.fixtures
-- @author Whisker Core Team

local Fixtures = {}

--- Create a simple story fixture
-- @param overrides table|nil Override default values
-- @return table Story data
function Fixtures.create_simple_story(overrides)
  overrides = overrides or {}

  local story = {
    metadata = overrides.metadata or {
      name = overrides.name or "Test Story",
      author = overrides.author or "Test Author",
      version = overrides.version or "1.0.0",
      format = "whisker",
      format_version = "1.0.0",
    },
    variables = overrides.variables or {},
    passages = overrides.passages or {},
    start_passage = overrides.start_passage or "start",
    stylesheets = overrides.stylesheets or {},
    scripts = overrides.scripts or {},
    assets = overrides.assets or {},
    tags = overrides.tags or {},
    settings = overrides.settings or {},
  }

  -- Add default start passage if not provided
  if #story.passages == 0 then
    table.insert(story.passages, Fixtures.create_passage({id = "start", name = "Start"}))
  end

  return story
end

--- Create a complex story with multiple passages
-- @param options table|nil Creation options
-- @return table Story data
function Fixtures.create_complex_story(options)
  options = options or {}
  local passage_count = options.passage_count or 5

  local story = Fixtures.create_simple_story({
    name = options.name or "Complex Test Story",
  })

  story.passages = {}

  -- Create passages
  for i = 1, passage_count do
    local passage = Fixtures.create_passage({
      id = "passage_" .. i,
      name = "Passage " .. i,
      content = "This is passage " .. i,
    })

    -- Add choice to next passage (except last)
    if i < passage_count then
      table.insert(passage.choices, Fixtures.create_choice({
        text = "Go to passage " .. (i + 1),
        target = "passage_" .. (i + 1),
      }))
    end

    table.insert(story.passages, passage)
  end

  story.start_passage = "passage_1"

  return story
end

--- Create a passage fixture
-- @param overrides table|nil Override default values
-- @return table Passage data
function Fixtures.create_passage(overrides)
  overrides = overrides or {}

  return {
    id = overrides.id or ("passage_" .. math.random(10000)),
    name = overrides.name or "Test Passage",
    content = overrides.content or "Test content",
    tags = overrides.tags or {},
    choices = overrides.choices or {},
    position = overrides.position or {x = 0, y = 0},
    size = overrides.size or {width = 100, height = 100},
    metadata = overrides.metadata or {},
    on_enter_script = overrides.on_enter_script,
    on_exit_script = overrides.on_exit_script,
  }
end

--- Create a choice fixture
-- @param overrides table|nil Override default values
-- @return table Choice data
function Fixtures.create_choice(overrides)
  overrides = overrides or {}

  return {
    id = overrides.id or ("choice_" .. math.random(10000)),
    text = overrides.text or "Test Choice",
    target = overrides.target or "next_passage",
    condition = overrides.condition,
    action = overrides.action,
    metadata = overrides.metadata or {},
  }
end

--- Create a branching story (for testing multiple paths)
-- @return table Story data with branches
function Fixtures.create_branching_story()
  local story = Fixtures.create_simple_story({name = "Branching Story"})

  story.passages = {
    Fixtures.create_passage({
      id = "start",
      name = "Start",
      content = "Choose your path",
      choices = {
        Fixtures.create_choice({text = "Go left", target = "left"}),
        Fixtures.create_choice({text = "Go right", target = "right"}),
      },
    }),
    Fixtures.create_passage({
      id = "left",
      name = "Left Path",
      content = "You went left",
      choices = {
        Fixtures.create_choice({text = "Continue", target = "end"}),
      },
    }),
    Fixtures.create_passage({
      id = "right",
      name = "Right Path",
      content = "You went right",
      choices = {
        Fixtures.create_choice({text = "Continue", target = "end"}),
      },
    }),
    Fixtures.create_passage({
      id = "end",
      name = "The End",
      content = "You reached the end",
    }),
  }

  story.start_passage = "start"

  return story
end

--- Create a story with variables
-- @return table Story data with variables
function Fixtures.create_story_with_variables()
  local story = Fixtures.create_simple_story({
    name = "Story With Variables",
    variables = {
      player_name = "Alice",
      score = 0,
      has_key = false,
      inventory = {},
    },
  })

  story.passages = {
    Fixtures.create_passage({
      id = "start",
      name = "Start",
      content = "Hello, {player_name}!",
      choices = {
        Fixtures.create_choice({
          text = "Get key",
          target = "get_key",
          action = "has_key = true",
        }),
        Fixtures.create_choice({
          text = "Try door",
          target = "door",
        }),
      },
    }),
    Fixtures.create_passage({
      id = "get_key",
      name = "Get Key",
      content = "You found a key!",
      on_enter_script = "score = score + 10",
      choices = {
        Fixtures.create_choice({text = "Go to door", target = "door"}),
      },
    }),
    Fixtures.create_passage({
      id = "door",
      name = "Door",
      content = "A locked door stands before you.",
      choices = {
        Fixtures.create_choice({
          text = "Unlock door (requires key)",
          target = "end",
          condition = "has_key == true",
        }),
        Fixtures.create_choice({
          text = "Go back",
          target = "start",
        }),
      },
    }),
    Fixtures.create_passage({
      id = "end",
      name = "The End",
      content = "You escaped!",
    }),
  }

  story.start_passage = "start"

  return story
end

return Fixtures
