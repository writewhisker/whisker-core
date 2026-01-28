--- Example Bootstrap
-- Standard initialization for whisker-core examples
-- Provides a clean API for examples to access the DI container and factories
-- @module examples.shared.bootstrap
-- @author Whisker Core Team
-- @license MIT

local Bootstrap = {}

--- Initialize the whisker-core framework
-- @return table Context object with container, events, and convenience accessors
function Bootstrap.init()
  -- Initialize kernel bootstrap module
  local KernelBootstrap = require("whisker.kernel.bootstrap")
  local kernel_result = KernelBootstrap.init()
  local container = kernel_result.container
  local events = kernel_result.events

  return {
    container = container,
    events = events,
    -- Convenience accessors
    story_factory = container:resolve("story_factory"),
    passage_factory = container:resolve("passage_factory"),
    choice_factory = container:resolve("choice_factory"),
    engine_factory = container:resolve("engine_factory"),
    game_state_factory = container:resolve("game_state_factory"),
  }
end

--- Create a story with passages and choices using the initialized context
-- @param whisker table The context returned from Bootstrap.init()
-- @param story_def table Story definition with title, author, passages array
-- @return table The created story
function Bootstrap.create_story(whisker, story_def)
  -- Create the story
  local story = whisker.story_factory:create({
    title = story_def.title,
    author = story_def.author,
    version = story_def.version,
    ifid = story_def.ifid,
  })

  -- Set start passage
  story.start_passage = story_def.start_passage

  -- Create passages
  for _, passage_def in ipairs(story_def.passages or {}) do
    local passage = whisker.passage_factory:create({
      id = passage_def.id,
      name = passage_def.name or passage_def.id,
      content = passage_def.content,
      tags = passage_def.tags,
    })

    -- Add choices to passage
    for _, choice_def in ipairs(passage_def.choices or {}) do
      local choice = whisker.choice_factory:create({
        text = choice_def.text,
        target = choice_def.target,
        condition = choice_def.condition,
      })
      passage:add_choice(choice)
    end

    story:add_passage(passage)
  end

  return story
end

return Bootstrap
