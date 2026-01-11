--- AI-Powered Story Tools
-- Creative assistance tools using AI
--
-- @module whisker.ai.tools
-- @author Whisker Team
-- @license MIT

local tools = {}

--- Create new AI tools instance
-- @param options table Configuration
-- @param options.ai_client table AI client instance
-- @return table Tools instance
function tools.new(options)
  assert(options.ai_client, "AI client required")
  
  local self = setmetatable({}, {__index = tools})
  self.ai = options.ai_client
  
  return self
end

--- Generate story outline
-- @param options table Generation options
-- @param options.genre string Story genre
-- @param options.themes table Array of themes
-- @param options.passages number Number of passages
-- @return table outline Story outline
function tools:generate_outline(options)
  local prompt = string.format([[
Generate an outline for an interactive fiction story.

Genre: %s
Themes: %s
Number of Passages: %d

Create a structured outline with:
1. Story premise (2-3 sentences)
2. Main passages with brief descriptions
3. Key choice points
4. Multiple possible endings

Format as a structured outline.
]], options.genre or "adventure", 
    table.concat(options.themes or {"exploration"}, ", "),
    options.passages or 10)
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 800 })
  
  if not result then
    return nil, err
  end
  
  return {
    text = result.text,
    genre = options.genre,
    themes = options.themes
  }
end

--- Generate passage content
-- @param options table Generation options
-- @param options.context string Story context
-- @param options.mood string Passage mood
-- @param options.length string Length (short/medium/long)
-- @return string text Generated passage text
function tools:generate_passage(options)
  local word_counts = {
    short = "30-60 words",
    medium = "60-120 words",
    long = "120-200 words"
  }
  
  local length = options.length or "medium"
  local word_count = word_counts[length] or word_counts.medium
  
  local prompt = string.format([[
Write a passage for an interactive story.

Context: %s
Mood: %s
Length: %s

Requirements:
- Write in second person ("you")
- Be descriptive and engaging
- End with a moment that leads to a choice
- Don't include the choices themselves

Passage:
]], options.context or "The story begins",
    options.mood or "mysterious",
    word_count)
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 300 })
  
  if not result then
    return nil, err
  end
  
  return result.text
end

--- Generate choices for a passage
-- @param options table Generation options
-- @param options.passage_text string Passage text
-- @param options.num_choices number Number of choices (default: 3)
-- @param options.type string Choice type (action/dialogue/decision)
-- @return table choices Array of choice objects
function tools:generate_choices(options)
  local num_choices = options.num_choices or 3
  local choice_type = options.type or "action"
  
  local prompt = string.format([[
Given this passage from an interactive story, generate %d meaningful choices.

Passage:
%s

Choice Type: %s

Generate %d distinct choices that:
- Are concise (5-10 words each)
- Lead to different story directions
- Match the passage's tone
- Are formatted as: 1. [choice text]

Choices:
]], num_choices, options.passage_text or "", choice_type, num_choices)
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 200 })
  
  if not result then
    return nil, err
  end
  
  -- Parse choices from result
  local choices = {}
  for line in result.text:gmatch("[^\r\n]+") do
    local choice_text = line:match("^%d+%.%s*(.+)$")
    if choice_text then
      table.insert(choices, {
        text = choice_text:match("^%s*(.-)%s*$"),  -- Trim whitespace
        target = nil  -- To be set by user
      })
    end
  end
  
  return choices
end

--- Improve passage text
-- @param options table Improvement options
-- @param options.text string Original text
-- @param options.improvements table Array of improvement types
-- @return string text Improved text
function tools:improve_text(options)
  local improvements = table.concat(options.improvements or {"grammar", "clarity"}, ", ")
  
  local prompt = string.format([[
Improve the following passage from an interactive story.

Original:
%s

Apply these improvements: %s

Requirements:
- Maintain the original meaning and tone
- Keep it in second person
- Don't add or remove major plot points
- Return ONLY the improved text

Improved:
]], options.text or "", improvements)
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 400 })
  
  if not result then
    return nil, err
  end
  
  return result.text
end

--- Analyze story for issues
-- @param story table Story data
-- @return table analysis Analysis results
function tools:analyze_story(story)
  -- Build story summary
  local summary = string.format([[
Story: %s
Passages: %d
]], story.metadata and story.metadata.title or "Untitled", 
    #(story.passages or {}))
  
  -- Add passage info
  for i, passage in ipairs(story.passages or {}) do
    if i <= 5 then  -- Only first 5 for brevity
      summary = summary .. string.format("\nPassage %d (%s): %s", 
        i, passage.id, (passage.text or ""):sub(1, 100))
    end
  end
  
  local prompt = string.format([[
Analyze this interactive story for issues.

%s

Provide analysis of:
1. Pacing (slow/medium/fast)
2. Plot holes (if any)
3. Character consistency
4. Suggested improvements

Analysis:
]], summary)
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 500 })
  
  if not result then
    return nil, err
  end
  
  return {
    text = result.text,
    pacing = "medium",  -- Parse from result
    plot_holes = {},    -- Parse from result
    suggestions = {}    -- Parse from result
  }
end

--- Change passage tone
-- @param options table Options
-- @param options.text string Original text
-- @param options.tone string Target tone
-- @return string text Rewritten text
function tools:change_tone(options)
  local prompt = string.format([[
Rewrite this passage in a %s tone.

Original:
%s

Requirements:
- Maintain the plot and events
- Change the writing style to match the tone
- Keep in second person
- Return ONLY the rewritten text

Rewritten:
]], options.tone or "formal", options.text or "")
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 400 })
  
  if not result then
    return nil, err
  end
  
  return result.text
end

--- Expand passage content
-- @param text string Original text
-- @param target_length number Target word count
-- @return string text Expanded text
function tools:expand_content(text, target_length)
  local prompt = string.format([[
Expand this passage to approximately %d words while maintaining its meaning.

Original:
%s

Add more:
- Descriptive details
- Sensory information
- Atmospheric elements

Return ONLY the expanded text.

Expanded:
]], target_length or 150, text or "")
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 500 })
  
  if not result then
    return nil, err
  end
  
  return result.text
end

--- Shorten passage content
-- @param text string Original text
-- @param target_length number Target word count
-- @return string text Shortened text
function tools:shorten_content(text, target_length)
  local prompt = string.format([[
Shorten this passage to approximately %d words while keeping the essential meaning.

Original:
%s

Requirements:
- Keep key plot points
- Maintain tone
- Remove unnecessary details
- Return ONLY the shortened text

Shortened:
]], target_length or 50, text or "")
  
  local result, err = self.ai:complete({ prompt = prompt, max_tokens = 300 })
  
  if not result then
    return nil, err
  end
  
  return result.text
end

return tools
