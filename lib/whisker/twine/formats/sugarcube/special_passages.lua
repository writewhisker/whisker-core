--- SugarCube special passage handler
-- Maps special passages to whisker-core lifecycle hooks
--
-- lib/whisker/twine/formats/sugarcube/special_passages.lua

local SpecialPassages = {}

--------------------------------------------------------------------------------
-- Special Passage Detection
--------------------------------------------------------------------------------

--- Check if passage name is a special SugarCube passage
---@param passage_name string Passage name
---@return boolean True if special passage
function SpecialPassages.is_special(passage_name)
  local special = {
    StoryInit = true,
    StoryCaption = true,
    StoryMenu = true,
    StoryBanner = true,
    StorySubtitle = true,
    StoryAuthor = true,
    PassageReady = true,
    PassageHeader = true,
    PassageFooter = true,
    PassageDone = true
  }

  return special[passage_name] or false
end

--------------------------------------------------------------------------------
-- Hook Type Mapping
--------------------------------------------------------------------------------

--- Get lifecycle hook name for special passage
---@param passage_name string Special passage name
---@return string|nil Hook type name
function SpecialPassages.get_hook_type(passage_name)
  local mappings = {
    StoryInit = "story_init",
    StoryCaption = "sidebar_content",
    StoryMenu = "story_menu",
    StoryBanner = "story_banner",
    StorySubtitle = "story_subtitle",
    StoryAuthor = "story_author",
    PassageReady = "before_passage",
    PassageHeader = "passage_header",
    PassageFooter = "passage_footer",
    PassageDone = "after_passage"
  }

  return mappings[passage_name]
end

--------------------------------------------------------------------------------
-- Special Passage Processing
--------------------------------------------------------------------------------

--- Process special passage and create lifecycle hook node
---@param passage table Passage data
---@param handler table Handler for parsing content
---@return table|nil AST node for lifecycle hook
function SpecialPassages.process(passage, handler)
  local hook_type = SpecialPassages.get_hook_type(passage.name)

  if not hook_type then
    return nil
  end

  -- Parse passage content
  local body = {}
  if handler and passage.content then
    body = handler:parse_passage(passage)
  end

  return {
    type = "lifecycle_hook",
    hook_type = hook_type,
    passage_name = passage.name,
    body = body
  }
end

--------------------------------------------------------------------------------
-- Documentation
--------------------------------------------------------------------------------

--- Get description of what a special passage does
---@param passage_name string Special passage name
---@return string Description
function SpecialPassages.get_description(passage_name)
  local descriptions = {
    StoryInit = "Runs once when the story starts. Use for initializing variables.",
    StoryCaption = "Displayed in the sidebar, below the story title.",
    StoryMenu = "Displayed in the sidebar menu.",
    StoryBanner = "Displayed at the top of the sidebar.",
    StorySubtitle = "Subtitle shown below story title.",
    StoryAuthor = "Author credit shown in sidebar.",
    PassageReady = "Runs before each passage is rendered. Variables set here won't show.",
    PassageHeader = "Content prepended to every passage.",
    PassageFooter = "Content appended to every passage.",
    PassageDone = "Runs after each passage is rendered."
  }

  return descriptions[passage_name] or "Unknown special passage"
end

--- Get list of all special passage names
---@return table Array of special passage names
function SpecialPassages.get_all_names()
  return {
    "StoryInit",
    "StoryCaption",
    "StoryMenu",
    "StoryBanner",
    "StorySubtitle",
    "StoryAuthor",
    "PassageReady",
    "PassageHeader",
    "PassageFooter",
    "PassageDone"
  }
end

return SpecialPassages
