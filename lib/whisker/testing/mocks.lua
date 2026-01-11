--- Mock Generators
-- Generate realistic mock data for testing
--
-- @module whisker.testing.mocks
-- @author Whisker Team
-- @license MIT
-- @usage
-- local mocks = require("whisker.testing.mocks")
-- local story = mocks.mock_story({ passages = 20 })

local mocks = {}

--- Initialize random seed
-- @param seed number Random seed (optional)
function mocks.seed(seed)
  math.randomseed(seed or os.time())
end

--- Word lists for content generation
local WORDS = {
  nouns = {"hero", "villain", "castle", "forest", "sword", "shield", "dragon", "treasure", "magic", "kingdom"},
  verbs = {"walks", "runs", "fights", "discovers", "explores", "finds", "searches", "guards", "protects", "attacks"},
  adjectives = {"dark", "bright", "mysterious", "ancient", "powerful", "hidden", "forgotten", "cursed", "blessed", "legendary"}
}

--- Generate random name
-- @return string Random name
local function random_name()
  local prefixes = {"Aether", "Shadow", "Light", "Dark", "Fire", "Ice", "Thunder", "Storm", "Wind", "Earth"}
  local suffixes = {"blade", "heart", "soul", "stone", "wind", "fire", "frost", "peak", "vale", "keep"}
  
  return prefixes[math.random(#prefixes)] .. suffixes[math.random(#suffixes)]
end

--- Generate Lorem Ipsum text
-- @param words number Number of words
-- @return string Lorem Ipsum text
local function lorem_ipsum(words)
  words = words or 50
  local lorem = {
    "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
    "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "dolore",
    "magna", "aliqua", "enim", "ad", "minim", "veniam", "quis", "nostrud"
  }
  
  local result = {}
  for i = 1, words do
    result[i] = lorem[math.random(#lorem)]
  end
  
  return table.concat(result, " ")
end

--- Generate narrative text
-- @param sentences number Number of sentences
-- @return string Narrative text
local function narrative_text(sentences)
  sentences = sentences or 3
  local result = {}
  
  for i = 1, sentences do
    local words = {
      WORDS.adjectives[math.random(#WORDS.adjectives)],
      WORDS.nouns[math.random(#WORDS.nouns)],
      WORDS.verbs[math.random(#WORDS.verbs)],
      "the",
      WORDS.adjectives[math.random(#WORDS.adjectives)],
      WORDS.nouns[math.random(#WORDS.nouns)]
    }
    
    local sentence = table.concat(words, " ")
    sentence = sentence:sub(1,1):upper() .. sentence:sub(2) .. "."
    table.insert(result, sentence)
  end
  
  return table.concat(result, " ")
end

--- Mock story generator
-- @param options table Generation options
-- @param options.passages number Number of passages (default: 10)
-- @param options.max_choices_per_passage number Max choices (default: 3)
-- @param options.branching_factor number Branching probability 0-1 (default: 0.7)
-- @param options.seed number Random seed
-- @param options.template string Template type
-- @return table Generated story
function mocks.mock_story(options)
  options = options or {}
  
  if options.seed then
    mocks.seed(options.seed)
  end
  
  -- Use template if specified
  if options.template then
    return mocks.mock_story_from_template(options.template, options)
  end
  
  local passage_count = options.passages or 10
  local max_choices = options.max_choices_per_passage or 3
  local branching_factor = options.branching_factor or 0.7
  
  local story = {
    id = "mock-story-" .. os.time(),
    metadata = {
      title = random_name() .. " Story",
      author = "Test Author",
      version = "1.0",
      created_at = os.time()
    },
    passages = {},
    variables = {
      health = { type = "number", default = 100 },
      score = { type = "number", default = 0 },
      visited = { type = "table", default = {} }
    },
    tags = {"test", "mock"}
  }
  
  -- Generate passages
  for i = 1, passage_count do
    local passage = mocks.mock_passage({
      id = "passage-" .. i,
      name = random_name(),
      sentences = math.random(2, 5)
    })
    
    -- Add start tag to first passage
    if i == 1 then
      table.insert(passage.tags, "start")
    end
    
    -- Add ending tag to last few passages
    if i > passage_count - 2 then
      table.insert(passage.tags, "ending")
    end
    
    table.insert(story.passages, passage)
  end
  
  -- Generate connections
  for i = 1, passage_count do
    local passage = story.passages[i]
    
    -- Don't add links to ending passages
    if not (i > passage_count - 2) then
      local num_choices = math.random(1, max_choices)
      
      -- Apply branching factor
      if math.random() > branching_factor then
        num_choices = 1
      end
      
      for j = 1, num_choices do
        -- Connect to a future passage
        local target_index = math.min(i + math.random(1, 3), passage_count)
        local target = story.passages[target_index]
        
        table.insert(passage.links, {
          text = "Go to " .. target.name,
          target = target.id
        })
      end
    end
  end
  
  return story
end

--- Mock passage generator
-- @param options table Generation options
-- @param options.id string Passage ID
-- @param options.name string Passage name
-- @param options.sentences number Number of sentences (default: 3)
-- @param options.choices number Number of choices (default: 0)
-- @param options.tags table Tags array
-- @return table Generated passage
function mocks.mock_passage(options)
  options = options or {}
  
  local id = options.id or ("passage-" .. os.time())
  local name = options.name or random_name()
  local sentences = options.sentences or 3
  
  return {
    id = id,
    name = name,
    text = narrative_text(sentences),
    tags = options.tags or {},
    links = {},
    position = {
      x = math.random(100, 800),
      y = math.random(100, 600)
    }
  }
end

--- Mock choice generator
-- @param options table Generation options
-- @param options.text string Choice text
-- @param options.target string Target passage ID
-- @param options.condition string Condition expression
-- @return table Generated choice
function mocks.mock_choice(options)
  options = options or {}
  
  return {
    text = options.text or ("Choice " .. math.random(1, 100)),
    target = options.target or ("passage-" .. math.random(1, 10)),
    condition = options.condition,
    effects = options.effects or {}
  }
end

--- Mock runtime generator
-- @param story table Story to create runtime for
-- @return table Mock runtime
function mocks.mock_runtime(story)
  return {
    story = story,
    current_passage = story.passages and story.passages[1] and story.passages[1].id or nil,
    variables = {},
    history = {},
    
    goto_passage = function(self, passage_id)
      table.insert(self.history, self.current_passage)
      self.current_passage = passage_id
    end,
    
    set_variable = function(self, name, value)
      self.variables[name] = value
    end,
    
    get_variable = function(self, name)
      return self.variables[name]
    end
  }
end

--- Mock storage generator
-- @param options table Generation options
-- @param options.stories table Array of stories to pre-populate
-- @return table Mock storage backend
function mocks.mock_storage(options)
  options = options or {}
  
  local storage = {
    stories = {},
    metadata = {}
  }
  
  -- Pre-populate with stories
  if options.stories then
    for _, story in ipairs(options.stories) do
      storage.stories[story.id] = story
      storage.metadata[story.id] = {
        id = story.id,
        title = story.metadata and story.metadata.title or "Untitled",
        size = 0,
        created_at = os.time(),
        updated_at = os.time()
      }
    end
  end
  
  -- Implement backend interface
  storage.save = function(self, key, data, metadata)
    self.stories[key] = data
    self.metadata[key] = metadata or {}
    return true
  end
  
  storage.load = function(self, key)
    return self.stories[key]
  end
  
  storage.delete = function(self, key)
    self.stories[key] = nil
    self.metadata[key] = nil
    return true
  end
  
  storage.exists = function(self, key)
    return self.stories[key] ~= nil
  end
  
  storage.list = function(self, filter)
    local results = {}
    for key, meta in pairs(self.metadata) do
      table.insert(results, meta)
    end
    return results
  end
  
  storage.clear = function(self)
    self.stories = {}
    self.metadata = {}
    return true
  end
  
  return storage
end

--- Story Templates

--- Generate story from template
-- @param template string Template name
-- @param options table Template options
-- @return table Generated story
function mocks.mock_story_from_template(template, options)
  options = options or {}
  
  if template == "linear" then
    return mocks.template_linear(options)
  elseif template == "branching" then
    return mocks.template_branching(options)
  elseif template == "complex" then
    return mocks.template_complex(options)
  elseif template == "adventure" then
    return mocks.template_adventure(options)
  else
    return mocks.mock_story(options)
  end
end

--- Linear story template (no branches)
-- @param options table Options
-- @return table Linear story
function mocks.template_linear(options)
  local passage_count = options.passages or 5
  
  local story = mocks.mock_story({
    passages = passage_count,
    max_choices_per_passage = 1,
    branching_factor = 0
  })
  
  -- Override connections to be strictly linear
  for i = 1, #story.passages - 1 do
    story.passages[i].links = {{
      text = "Continue",
      target = story.passages[i + 1].id
    }}
  end
  
  story.passages[#story.passages].links = {}
  
  return story
end

--- Branching story template
-- @param options table Options
-- @return table Branching story
function mocks.template_branching(options)
  return mocks.mock_story({
    passages = options.passages or 15,
    max_choices_per_passage = 3,
    branching_factor = 0.9
  })
end

--- Complex interconnected story
-- @param options table Options
-- @return table Complex story
function mocks.template_complex(options)
  local story = mocks.mock_story({
    passages = options.passages or 20,
    max_choices_per_passage = 4,
    branching_factor = 1.0
  })
  
  -- Add some backwards links for complexity
  for i = 5, #story.passages do
    if math.random() > 0.7 then
      local target = story.passages[math.random(1, i - 1)]
      table.insert(story.passages[i].links, {
        text = "Go back to " .. target.name,
        target = target.id
      })
    end
  end
  
  return story
end

--- Adventure story template
-- @param options table Options
-- @return table Adventure story
function mocks.template_adventure(options)
  local story = mocks.template_branching(options)
  
  story.metadata.title = random_name() .. " Adventure"
  story.metadata.genre = "adventure"
  
  -- Add adventure-specific variables
  story.variables.inventory = { type = "table", default = {} }
  story.variables.gold = { type = "number", default = 0 }
  story.variables.strength = { type = "number", default = 10 }
  
  -- Add adventure tags
  for _, passage in ipairs(story.passages) do
    if math.random() > 0.7 then
      local tags = {"combat", "exploration", "dialogue", "treasure"}
      table.insert(passage.tags, tags[math.random(#tags)])
    end
  end
  
  return story
end

--- Edge Cases and Fixtures

--- Generate edge case stories
-- @param case_type string Type of edge case
-- @return table Edge case story
function mocks.edge_case(case_type)
  if case_type == "empty" then
    return {
      id = "empty",
      metadata = {},
      passages = {},
      variables = {},
      tags = {}
    }
  elseif case_type == "minimal" then
    return {
      id = "minimal",
      metadata = { title = "Minimal" },
      passages = {
        { id = "only", name = "Only Passage", text = "Only one passage", tags = {"start", "ending"}, links = {} }
      },
      variables = {},
      tags = {}
    }
  elseif case_type == "huge" then
    return mocks.mock_story({ passages = 1000 })
  elseif case_type == "malformed" then
    return {
      id = "malformed",
      -- Missing required fields
      passages = {
        { text = "No ID" },
        { id = "partial" }
      }
    }
  end
  
  return {}
end

return mocks
