-- whisker/interfaces/engine.lua
-- IEngine interface definition
-- Runtime engines must implement this interface

local IEngine = {
  _name = "IEngine",
  _description = "Runtime engine for story execution",
  _required = {"load", "start", "get_current_passage", "get_available_choices", "make_choice", "can_continue"},
  _optional = {"reset", "get_state", "set_state"},

  -- Load a story into the engine
  -- @param story Story - Story object to load
  load = "function(self, story)",

  -- Start or restart the story from the beginning
  start = "function(self)",

  -- Get the current passage
  -- @return Passage - Current passage object
  get_current_passage = "function(self) -> Passage",

  -- Get available choices for current passage
  -- @return table - Array of available Choice objects
  get_available_choices = "function(self) -> table",

  -- Make a choice by index
  -- @param index number - 1-based index of choice to make
  -- @return Passage - New current passage after choice
  make_choice = "function(self, index) -> Passage",

  -- Check if the story can continue (not at an ending)
  -- @return boolean - True if choices available or auto-continue
  can_continue = "function(self) -> boolean",
}

return IEngine
