--- Core Factories
-- Central export for all core factory implementations
-- @module whisker.core.factories
-- @author Whisker Core Team
-- @license MIT

return {
  ChoiceFactory = require("whisker.core.factories.choice_factory"),
  PassageFactory = require("whisker.core.factories.passage_factory"),
  StoryFactory = require("whisker.core.factories.story_factory"),
  GameStateFactory = require("whisker.core.factories.game_state_factory"),
  LuaInterpreterFactory = require("whisker.core.factories.lua_interpreter_factory"),
}
