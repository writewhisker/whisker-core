--- Full-Text Search Engine
-- Search across story content with ranking and filtering
--
-- @module whisker.search.engine
-- @author Whisker Team
-- @license MIT

local SearchEngine = {}
SearchEngine.__index = SearchEngine

--- Create new search engine
-- @param options table Configuration options
-- @return SearchEngine New search engine instance
function SearchEngine.new(options)
  options = options or {}
  
  local self = setmetatable({}, SearchEngine)
  
  -- Inverted index: {word => {story_id => {passage_ids}}}
  self.index = {}
  
  -- Document store: {story_id => story_data}
  self.documents = {}
  
  -- Search options
  self.case_sensitive = options.case_sensitive or false
  self.min_word_length = options.min_word_length or 2
  
  -- Stop words (common words to ignore)
  self.stop_words = {
    ["the"] = true, ["a"] = true, ["an"] = true, ["and"] = true,
    ["or"] = true, ["but"] = true, ["in"] = true, ["on"] = true,
    ["at"] = true, ["to"] = true, ["for"] = true, ["of"] = true,
    ["with"] = true, ["by"] = true, ["from"] = true, ["as"] = true
  }
  
  return self
end

--- Index a story
-- @param story table Story data
function SearchEngine:index_story(story)
  if not story or not story.id then
    return false, "Invalid story"
  end
  
  -- Store document
  self.documents[story.id] = story
  
  -- Index metadata
  if story.metadata then
    if story.metadata.title then
      self:index_text(story.id, "title", story.metadata.title)
    end
    if story.metadata.author then
      self:index_text(story.id, "author", story.metadata.author)
    end
    if story.metadata.tags then
      for _, tag in ipairs(story.metadata.tags) do
        self:index_text(story.id, "tag", tag)
      end
    end
  end
  
  -- Index passages
  for _, passage in ipairs(story.passages or {}) do
    if passage.name then
      self:index_text(story.id, "passage:" .. passage.id, passage.name)
    end
    if passage.text then
      self:index_text(story.id, "passage:" .. passage.id, passage.text)
    end
    if passage.tags then
      for _, tag in ipairs(passage.tags) do
        self:index_text(story.id, "passage:" .. passage.id, tag)
      end
    end
  end
  
  return true
end

--- Index text
-- @param story_id string Story ID
-- @param field string Field identifier
-- @param text string Text to index
function SearchEngine:index_text(story_id, field, text)
  local words = self:tokenize(text)
  
  for _, word in ipairs(words) do
    if not self.stop_words[word] and #word >= self.min_word_length then
      -- Create index entry if needed
      if not self.index[word] then
        self.index[word] = {}
      end
      
      if not self.index[word][story_id] then
        self.index[word][story_id] = {}
      end
      
      -- Add field to index
      self.index[word][story_id][field] = (self.index[word][story_id][field] or 0) + 1
    end
  end
end

--- Tokenize text into words
-- @param text string Text to tokenize
-- @return table words Array of words
function SearchEngine:tokenize(text)
  if not self.case_sensitive then
    text = text:lower()
  end
  
  local words = {}
  for word in text:gmatch("%w+") do
    table.insert(words, word)
  end
  
  return words
end

--- Search for query
-- @param query string Search query
-- @param options table Search options
-- @param options.fields table Fields to search (optional)
-- @param options.limit number Maximum results (default: 10)
-- @param options.min_score number Minimum score (default: 0)
-- @return table results Array of search results
function SearchEngine:search(query, options)
  options = options or {}
  
  local words = self:tokenize(query)
  local scores = {}  -- {story_id => score}
  local matches = {} -- {story_id => {matched_words, passages}}
  
  -- Calculate scores for each word
  for _, word in ipairs(words) do
    if not self.stop_words[word] and self.index[word] then
      for story_id, fields in pairs(self.index[word]) do
        -- Calculate score based on field weights
        local score = 0
        local matched_fields = {}
        
        for field, count in pairs(fields) do
          local field_type = field:match("^([^:]+)")
          local field_weight = self:get_field_weight(field_type)
          
          score = score + (count * field_weight)
          table.insert(matched_fields, field)
        end
        
        scores[story_id] = (scores[story_id] or 0) + score
        
        if not matches[story_id] then
          matches[story_id] = {words = {}, fields = {}}
        end
        table.insert(matches[story_id].words, word)
        for _, field in ipairs(matched_fields) do
          if not matches[story_id].fields[field] then
            matches[story_id].fields[field] = true
          end
        end
      end
    end
  end
  
  -- Convert to results array
  local results = {}
  for story_id, score in pairs(scores) do
    if score >= (options.min_score or 0) then
      local story = self.documents[story_id]
      
      table.insert(results, {
        story_id = story_id,
        story = story,
        score = score,
        matched_words = matches[story_id].words,
        matched_fields = self:fields_to_array(matches[story_id].fields),
        highlight = self:highlight_matches(story, matches[story_id].words)
      })
    end
  end
  
  -- Sort by score (descending)
  table.sort(results, function(a, b)
    return a.score > b.score
  end)
  
  -- Apply limit
  local limit = options.limit or 10
  if #results > limit then
    local limited = {}
    for i = 1, limit do
      limited[i] = results[i]
    end
    results = limited
  end
  
  return results
end

--- Get field weight for scoring
-- @param field_type string Field type
-- @return number weight Field weight
function SearchEngine:get_field_weight(field_type)
  local weights = {
    title = 10,
    author = 5,
    tag = 3,
    passage = 1
  }
  return weights[field_type] or 1
end

--- Convert fields table to array
-- @param fields table Fields table
-- @return table array Field names array
function SearchEngine:fields_to_array(fields)
  local result = {}
  for field in pairs(fields) do
    table.insert(result, field)
  end
  return result
end

--- Highlight matches in text
-- @param story table Story data
-- @param words table Matched words
-- @return table highlights Highlighted excerpts
function SearchEngine:highlight_matches(story, words)
  local highlights = {}
  
  -- Highlight in title
  if story.metadata and story.metadata.title then
    local highlighted = self:highlight_text(story.metadata.title, words)
    if highlighted ~= story.metadata.title then
      table.insert(highlights, {
        field = "title",
        text = highlighted
      })
    end
  end
  
  -- Highlight in passages (first 3 matches)
  local passage_count = 0
  for _, passage in ipairs(story.passages or {}) do
    if passage_count >= 3 then break end
    
    if passage.text then
      local highlighted = self:highlight_text(passage.text, words)
      if highlighted ~= passage.text then
        table.insert(highlights, {
          field = "passage",
          passage_id = passage.id,
          text = self:create_excerpt(highlighted, 100)
        })
        passage_count = passage_count + 1
      end
    end
  end
  
  return highlights
end

--- Highlight words in text
-- @param text string Original text
-- @param words table Words to highlight
-- @return string text Text with highlights
function SearchEngine:highlight_text(text, words)
  local result = text
  
  for _, word in ipairs(words) do
    local pattern = "(" .. word .. ")"
    if not self.case_sensitive then
      pattern = pattern:lower()
      result = result:lower()
    end
    
    -- Simple highlight with markers
    result = result:gsub(pattern, "**%1**")
  end
  
  return result
end

--- Create excerpt around matches
-- @param text string Full text
-- @param max_length number Maximum excerpt length
-- @return string excerpt Text excerpt
function SearchEngine:create_excerpt(text, max_length)
  if #text <= max_length then
    return text
  end
  
  -- Find first highlight
  local start_pos = text:find("%*%*")
  if not start_pos then
    return text:sub(1, max_length) .. "..."
  end
  
  -- Extract around highlight
  local excerpt_start = math.max(1, start_pos - math.floor(max_length / 2))
  local excerpt_end = math.min(#text, excerpt_start + max_length)
  
  local excerpt = text:sub(excerpt_start, excerpt_end)
  
  if excerpt_start > 1 then
    excerpt = "..." .. excerpt
  end
  if excerpt_end < #text then
    excerpt = excerpt .. "..."
  end
  
  return excerpt
end

--- Remove story from index
-- @param story_id string Story ID
function SearchEngine:remove_story(story_id)
  -- Remove from documents
  self.documents[story_id] = nil
  
  -- Remove from index
  for word, stories in pairs(self.index) do
    if stories[story_id] then
      stories[story_id] = nil
      
      -- Remove word entry if no more stories
      local has_stories = false
      for _ in pairs(stories) do
        has_stories = true
        break
      end
      if not has_stories then
        self.index[word] = nil
      end
    end
  end
end

--- Get index statistics
-- @return table stats Index statistics
function SearchEngine:get_stats()
  local word_count = 0
  for _ in pairs(self.index) do
    word_count = word_count + 1
  end
  
  local story_count = 0
  for _ in pairs(self.documents) do
    story_count = story_count + 1
  end
  
  return {
    indexed_words = word_count,
    indexed_stories = story_count
  }
end

--- Clear entire index
function SearchEngine:clear()
  self.index = {}
  self.documents = {}
end

return SearchEngine
