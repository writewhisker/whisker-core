#!/usr/bin/env lua
--[[
  AI Story Generator Example
  
  This example demonstrates how to use whisker-core's AI integration
  to automatically generate interactive fiction stories.
  
  Features demonstrated:
  - Multi-provider AI client configuration
  - Story outline generation
  - Passage content generation
  - Choice generation
  - Text improvement
  - Story analysis
  
  Usage:
    lua examples/ai_story_generator.lua
]]

-- Add lib directory to package path
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

local AIClient = require("whisker.ai.client")
local AITools = require("whisker.ai.tools")
local Story = require("whisker.core.story")

-- Configuration
local CONFIG = {
  provider = "mock",  -- Use "openai", "anthropic", or "ollama" with API keys
  model = "gpt-4",
  temperature = 0.8,  -- Higher = more creative
  
  story_config = {
    genre = "mystery",
    themes = {"detective", "small town", "secrets"},
    passages = 8,
    tone = "suspenseful"
  }
}

--[[
  Initialize AI Client
  
  For real providers, set environment variables:
  - OPENAI_API_KEY for OpenAI
  - ANTHROPIC_API_KEY for Anthropic
  - No key needed for Ollama (local)
]]
local function init_ai_client()
  print("🤖 Initializing AI Client...")
  print("   Provider: " .. CONFIG.provider)
  print("   Model: " .. CONFIG.model)
  print("")
  
  local ai_client = AIClient.new({
    provider = CONFIG.provider,
    model = CONFIG.model,
    temperature = CONFIG.temperature,
    max_tokens = 2000
  })
  
  return ai_client
end

--[[
  Generate Story Outline
  
  Creates a high-level structure for the story including:
  - Main plot points
  - Passage descriptions
  - Suggested connections
]]
local function generate_outline(tools, config)
  print("📝 Generating Story Outline...")
  print("   Genre: " .. config.genre)
  print("   Themes: " .. table.concat(config.themes, ", "))
  print("   Target passages: " .. config.passages)
  print("")
  
  local outline = tools:generate_outline({
    genre = config.genre,
    themes = config.themes,
    passages = config.passages
  })
  
  print("✅ Outline generated!")
  print("")
  print("Title: " .. (outline.title or "Untitled Story"))
  print("Summary: " .. (outline.summary or ""))
  print("")
  print("Passages:")
  for i, passage_desc in ipairs(outline.passages or {}) do
    print(string.format("  %d. %s", i, passage_desc))
  end
  print("")
  
  return outline
end

--[[
  Create Story from Outline
  
  Generates full passage content for each passage in the outline
]]
local function create_story_from_outline(tools, outline, config)
  print("🎨 Creating Story Content...")
  print("")
  
  -- Create story metadata
  local story_data = {
    metadata = {
      title = outline.title or "AI Generated Mystery",
      author = "AI Assistant",
      description = outline.summary or "",
      created = os.time(),
      genre = config.genre,
      tags = config.themes
    },
    passages = {},
    start_passage = "start"
  }
  
  -- Generate passages
  for i, passage_desc in ipairs(outline.passages or {}) do
    local passage_id = i == 1 and "start" or ("passage_" .. i)
    
    print(string.format("   Generating passage %d/%d: %s", i, #outline.passages, passage_id))
    
    -- Generate passage content
    local content = tools:generate_passage({
      context = passage_desc,
      mood = config.tone or "neutral",
      length = "medium"
    })
    
    -- Generate choices (except for ending)
    local choices = {}
    if i < #outline.passages then
      local num_choices = math.random(2, 3)  -- 2-3 choices per passage
      
      local generated_choices = tools:generate_choices({
        passage_text = content,
        num_choices = num_choices,
        type = "action"
      })
      
      for j, choice in ipairs(generated_choices or {}) do
        local target = (i + j <= #outline.passages) and ("passage_" .. (i + j)) or "ending"
        table.insert(choices, {
          text = choice.text,
          target = target
        })
      end
    end
    
    -- Add passage to story
    table.insert(story_data.passages, {
      id = passage_id,
      text = content,
      choices = choices,
      tags = {}
    })
  end
  
  print("")
  print("✅ Story content generated!")
  print("")
  
  return story_data
end

--[[
  Improve Story Quality
  
  Uses AI to enhance passages for better quality
]]
local function improve_story(tools, story_data)
  print("✨ Improving Story Quality...")
  print("")
  
  for i, passage in ipairs(story_data.passages) do
    print(string.format("   Improving passage %d/%d...", i, #story_data.passages))
    
    local improved = tools:improve_text({
      text = passage.text,
      improvements = {"grammar", "clarity", "engagement"}
    })
    
    passage.text = improved
  end
  
  print("")
  print("✅ Story improved!")
  print("")
  
  return story_data
end

--[[
  Analyze Story
  
  Provides feedback on story quality and suggestions
]]
local function analyze_story_quality(tools, story_data)
  print("🔍 Analyzing Story...")
  print("")
  
  -- Convert to Story object for analysis
  local story = Story.from_table(story_data)
  
  local analysis = tools:analyze_story(story)
  
  print("Analysis Results:")
  print("  " .. (analysis or "Story structure looks good!"))
  print("")
  
  return analysis
end

--[[
  Display Story Statistics
]]
local function display_stats(ai_client, story_data)
  print("📊 Story Statistics:")
  print("")
  
  -- Story stats
  local total_words = 0
  local total_choices = 0
  
  for _, passage in ipairs(story_data.passages) do
    total_words = total_words + #(passage.text:gmatch("%S+"))
    total_choices = total_choices + #passage.choices
  end
  
  print(string.format("  Passages: %d", #story_data.passages))
  print(string.format("  Total Choices: %d", total_choices))
  print(string.format("  Total Words: ~%d", total_words))
  print(string.format("  Avg Words/Passage: ~%d", math.floor(total_words / #story_data.passages)))
  print("")
  
  -- AI stats
  local ai_stats = ai_client:get_stats()
  print("  AI Usage:")
  print(string.format("    Requests: %d", ai_stats.requests or 0))
  print(string.format("    Total Tokens: %d", ai_stats.total_tokens or 0))
  print(string.format("    Estimated Cost: $%.4f", ai_stats.estimated_cost or 0))
  print(string.format("    Cache Hits: %d", ai_stats.cache_hits or 0))
  print("")
end

--[[
  Save Story to File
]]
local function save_story(story_data, filename)
  print("💾 Saving Story...")
  
  local json = require("cjson")
  local file = io.open(filename, "w")
  
  if not file then
    print("❌ Error: Could not open file for writing: " .. filename)
    return false
  end
  
  file:write(json.encode(story_data))
  file:close()
  
  print("✅ Story saved to: " .. filename)
  print("")
  
  return true
end

--[[
  Main Function
]]
local function main()
  print("=" .. string.rep("=", 70))
  print("  AI Story Generator")
  print("  Whisker-Core Advanced Features Demo")
  print("=" .. string.rep("=", 70))
  print("")
  
  -- Initialize AI
  local ai_client = init_ai_client()
  local tools = AITools.new({ ai_client = ai_client })
  
  -- Generate outline
  local outline = generate_outline(tools, CONFIG.story_config)
  
  -- Create story from outline
  local story_data = create_story_from_outline(tools, outline, CONFIG.story_config)
  
  -- Improve quality (optional - can be slow with real API)
  if os.getenv("IMPROVE_QUALITY") == "1" then
    story_data = improve_story(tools, story_data)
  else
    print("ℹ️  Skipping quality improvement (set IMPROVE_QUALITY=1 to enable)")
    print("")
  end
  
  -- Analyze story
  if os.getenv("ANALYZE_STORY") == "1" then
    analyze_story_quality(tools, story_data)
  else
    print("ℹ️  Skipping story analysis (set ANALYZE_STORY=1 to enable)")
    print("")
  end
  
  -- Display stats
  display_stats(ai_client, story_data)
  
  -- Save story
  local output_file = "ai_generated_story.json"
  save_story(story_data, output_file)
  
  print("=" .. string.rep("=", 70))
  print("  Story Generation Complete!")
  print("=" .. string.rep("=", 70))
  print("")
  print("Next steps:")
  print("  1. Review the generated story in: " .. output_file)
  print("  2. Edit and refine passages as needed")
  print("  3. Use the runtime to test playability")
  print("  4. Export to HTML or other formats")
  print("")
  print("Tips:")
  print("  - Try different genres: mystery, sci-fi, fantasy, romance")
  print("  - Adjust temperature (0.0-1.0) for creativity vs consistency")
  print("  - Use real AI providers for better quality")
  print("  - Set OPENAI_API_KEY or ANTHROPIC_API_KEY environment variables")
  print("")
end

-- Run if executed directly
if arg and arg[0] and arg[0]:match("ai_story_generator%.lua$") then
  main()
end

return {
  init_ai_client = init_ai_client,
  generate_outline = generate_outline,
  create_story_from_outline = create_story_from_outline,
  improve_story = improve_story,
  analyze_story_quality = analyze_story_quality
}
