#!/usr/bin/env lua
--- Large Story Generator
-- Generates test stories of various sizes for performance testing
-- @module tools.generate_large_story
-- @author Whisker Core Team
-- @license MIT

local LargeStoryGenerator = {}

--- Generate random passage text
-- @param passage_num number Passage number
-- @param length string Text length (short, medium, long)
-- @return string Generated text
local function generate_passage_text(passage_num, length)
  local lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "

  if length == "short" then
    return string.format("Passage %d.", passage_num)
  elseif length == "long" then
    return string.format("Welcome to passage %d. %s%s",
      passage_num,
      string.rep(lorem, 5),
      "What do you want to do next?")
  else -- medium
    return string.format("You are now in passage %d. %sChoose your path.",
      passage_num, string.rep(lorem, 2))
  end
end

--- Generate a choice condition
-- @return string Condition expression
local function generate_condition()
  local conditions = {
    "has_key",
    "visited_passage_10",
    "gold > 50",
    "health > 0",
    "inventory.sword",
    "flags.door_unlocked",
  }
  return conditions[math.random(#conditions)]
end

--- Generate a large story
-- @param num_passages number Number of passages to generate
-- @param options table Options:
--   - text_length: string (short, medium, long)
--   - add_conditions: boolean
--   - add_tags: boolean
--   - branching_factor: number (average choices per passage)
--   - seed: number (random seed for reproducibility)
-- @return table Story data
function LargeStoryGenerator.generate(num_passages, options)
  options = options or {}

  if options.seed then
    math.randomseed(options.seed)
  else
    math.randomseed(os.time())
  end

  local text_length = options.text_length or "medium"
  local branching = options.branching_factor or 3
  local add_conditions = options.add_conditions or false
  local add_tags = options.add_tags or false

  local story = {
    title = string.format("Generated Story (%d passages)", num_passages),
    author = "Story Generator",
    start_passage = "passage_1",
    ifid = string.format("%08x-%04x-%04x-%04x-%012x",
      math.random(0xFFFFFFFF),
      math.random(0xFFFF),
      math.random(0xFFFF),
      math.random(0xFFFF),
      math.random(0xFFFFFFFF)),
    passages = {},
  }

  -- Build passage map for O(1) lookup
  story.passage_map = {}

  for i = 1, num_passages do
    local passage = {
      name = "passage_" .. i,
      text = generate_passage_text(i, text_length),
      choices = {},
    }

    -- Add tags if requested
    if add_tags then
      passage.tags = {}
      local chapter = math.floor((i - 1) / 50) + 1
      table.insert(passage.tags, "chapter_" .. chapter)

      if i <= 10 then
        table.insert(passage.tags, "intro")
      elseif i > num_passages - 10 then
        table.insert(passage.tags, "ending")
      end
    end

    -- Add choices (variable number around branching factor)
    local num_choices = math.max(1, branching + math.random(-1, 1))

    for j = 1, num_choices do
      local target = math.random(1, num_passages)
      local choice = {
        text = "Choice " .. j .. ": Go to passage " .. target,
        target = "passage_" .. target,
      }

      if add_conditions and math.random() < 0.3 then
        choice.condition = generate_condition()
      end

      table.insert(passage.choices, choice)
    end

    table.insert(story.passages, passage)
    story.passage_map[passage.name] = passage
  end

  return story
end

--- Save story to Lua file
-- @param path string Output path
-- @param story table Story data
-- @return boolean Success
function LargeStoryGenerator.save(path, story)
  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write("-- Generated story with " .. #story.passages .. " passages\n")
  file:write("-- Generated: " .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. "\n")
  file:write("return {\n")
  file:write(string.format("  title = %q,\n", story.title))
  file:write(string.format("  author = %q,\n", story.author))
  file:write(string.format("  start_passage = %q,\n", story.start_passage or "passage_1"))

  if story.ifid then
    file:write(string.format("  ifid = %q,\n", story.ifid))
  end

  file:write("  passages = {\n")

  for _, passage in ipairs(story.passages) do
    file:write("    {\n")
    file:write(string.format("      name = %q,\n", passage.name))
    file:write(string.format("      text = %q,\n", passage.text))

    if passage.tags and #passage.tags > 0 then
      file:write("      tags = { ")
      for i, tag in ipairs(passage.tags) do
        if i > 1 then file:write(", ") end
        file:write(string.format("%q", tag))
      end
      file:write(" },\n")
    end

    file:write("      choices = {\n")
    for _, choice in ipairs(passage.choices) do
      file:write("        { ")
      file:write(string.format("text = %q, target = %q", choice.text, choice.target))
      if choice.condition then
        file:write(string.format(", condition = %q", choice.condition))
      end
      file:write(" },\n")
    end
    file:write("      },\n")

    file:write("    },\n")
  end

  file:write("  },\n")
  file:write("}\n")

  file:close()
  return true
end

--- Generate performance report for a story
-- @param story table Story data
-- @return table Stats
function LargeStoryGenerator.stats(story)
  local total_text = 0
  local total_choices = 0
  local max_choices = 0

  for _, passage in ipairs(story.passages) do
    total_text = total_text + #(passage.text or "")
    local num_choices = #(passage.choices or {})
    total_choices = total_choices + num_choices
    max_choices = math.max(max_choices, num_choices)
  end

  return {
    passage_count = #story.passages,
    total_text_bytes = total_text,
    avg_text_bytes = total_text / #story.passages,
    total_choices = total_choices,
    avg_choices = total_choices / #story.passages,
    max_choices = max_choices,
  }
end

-- CLI interface
if arg and arg[0]:match("generate_large_story%.lua$") then
  local sizes = { 100, 500, 1000, 5000 }

  print("Generating large stories for testing...")
  print()

  for _, size in ipairs(sizes) do
    local story = LargeStoryGenerator.generate(size, {
      text_length = "medium",
      add_tags = true,
      seed = 12345, -- Reproducible
    })

    local filename = "tests/fixtures/large_stories/story_" .. size .. ".lua"
    local success = LargeStoryGenerator.save(filename, story)

    if success then
      local stats = LargeStoryGenerator.stats(story)
      print(string.format("Generated: %s", filename))
      print(string.format("  Passages: %d, Text: %.1f KB, Choices: %d",
        stats.passage_count,
        stats.total_text_bytes / 1024,
        stats.total_choices))
    else
      print("Error: Cannot write to " .. filename)
    end
  end
end

return LargeStoryGenerator
