--- Modular Parser Framework
-- Unified framework for importing stories from various formats
-- Provides format detection, parsing pipeline, and validation
--
-- @module whisker.import.parser_framework
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Parser = require("whisker.import.parser_framework")
-- Parser.register("twine", require("whisker.import.harlowe"))
-- local story = Parser.parse(file_content)

local ParserFramework = {}

--- Registered parsers
ParserFramework.parsers = {}

--- Parser interface that all parsers must implement
ParserFramework.ParserInterface = {
  name = nil,           -- Parser name (e.g., "twine-harlowe")
  formats = {},         -- Supported formats (e.g., {"html", "twee"})
  detect = nil,         -- function(data) -> boolean
  parse = nil,          -- function(data, options) -> intermediate_representation
  validate = nil,       -- function(ir) -> validation_result (optional)
  transform = nil       -- function(ir) -> whisker_story
}

--- Register a parser
-- @param name string Parser name
-- @param parser table Parser implementation
-- @usage
-- Parser.register("twine", {
--   name = "twine-harlowe",
--   formats = {"html"},
--   detect = function(data) return data:match("<tw%-storydata") end,
--   parse = function(data) return {...} end,
--   transform = function(ir) return story end
-- })
function ParserFramework.register(name, parser)
  -- Validate parser implements required methods
  assert(type(parser.detect) == "function", "Parser must implement detect()")
  assert(type(parser.parse) == "function", "Parser must implement parse()")
  assert(type(parser.transform) == "function", "Parser must implement transform()")
  
  parser.name = parser.name or name
  parser.formats = parser.formats or {}
  
  ParserFramework.parsers[name] = parser
end

--- Unregister a parser
-- @param name string Parser name
function ParserFramework.unregister(name)
  ParserFramework.parsers[name] = nil
end

--- Get registered parser by name
-- @param name string Parser name
-- @return table|nil parser Parser instance or nil
function ParserFramework.get_parser(name)
  return ParserFramework.parsers[name]
end

--- List all registered parsers
-- @return table parsers Array of parser names
function ParserFramework.list_parsers()
  local names = {}
  for name in pairs(ParserFramework.parsers) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Auto-detect format from data
-- Tries all registered parsers until one matches
-- @param data string Raw file content
-- @return string|nil parser_name Name of detected parser
-- @return table|nil parser Parser instance
function ParserFramework.detect_format(data)
  for name, parser in pairs(ParserFramework.parsers) do
    local success, result = pcall(parser.detect, data)
    if success and result then
      return name, parser
    end
  end
  
  return nil, nil
end

--- Parse data using specified parser
-- @param data string Raw file content
-- @param options table Parse options
-- @param options.parser string Parser name (optional, auto-detect if not specified)
-- @param options.validate boolean Run validation (default: true)
-- @param options.on_progress function Progress callback(stage, percent)
-- @return table|nil result Parse result with story data
-- @return string|nil error Error message if failed
-- @usage
-- local result, err = Parser.parse(file_content, {
--   parser = "twine",
--   on_progress = function(stage, percent)
--     print(stage, percent .. "%")
--   end
-- })
function ParserFramework.parse(data, options)
  options = options or {}
  
  -- Auto-detect parser if not specified
  local parser_name = options.parser
  local parser
  
  if parser_name then
    parser = ParserFramework.parsers[parser_name]
    if not parser then
      return nil, string.format("Unknown parser: %s", parser_name)
    end
  else
    -- Auto-detect
    parser_name, parser = ParserFramework.detect_format(data)
    if not parser then
      return nil, "Could not detect format. Please specify parser explicitly."
    end
  end
  
  -- Progress callback helper
  local function progress(stage, percent)
    if options.on_progress then
      options.on_progress(stage, percent or 0)
    end
  end
  
  -- Stage 1: Parse to intermediate representation
  progress("parsing", 25)
  local success, ir = pcall(parser.parse, data, options)
  if not success then
    return nil, string.format("Parse error: %s", ir)
  end
  
  -- Stage 2: Validate (optional)
  if options.validate ~= false and parser.validate then
    progress("validating", 50)
    local validation_result = parser.validate(ir)
    
    if validation_result and not validation_result.valid then
      -- Return validation errors
      return {
        success = false,
        errors = validation_result.errors or {},
        warnings = validation_result.warnings or {},
        ir = ir
      }
    end
  end
  
  -- Stage 3: Transform to whisker story format
  progress("transforming", 75)
  local story
  success, story = pcall(parser.transform, ir)
  if not success then
    return nil, string.format("Transform error: %s", story)
  end
  
  progress("complete", 100)
  
  -- Return result
  return {
    success = true,
    story = story,
    parser = parser_name,
    format = parser.formats[1] or "unknown",
    ir = ir  -- Keep intermediate representation for debugging
  }
end

--- Parse file from disk
-- @param filepath string Path to file
-- @param options table Parse options
-- @return table|nil result Parse result
-- @return string|nil error Error message if failed
function ParserFramework.parse_file(filepath, options)
  local file, err = io.open(filepath, "r")
  if not file then
    return nil, string.format("Failed to open file: %s", err)
  end
  
  local data = file:read("*all")
  file:close()
  
  return ParserFramework.parse(data, options)
end

--- Batch parse multiple files
-- @param filepaths table Array of file paths
-- @param options table Parse options
-- @return table results Map of {filepath = result}
-- @return table errors Map of {filepath = error}
function ParserFramework.batch_parse(filepaths, options)
  local results = {}
  local errors = {}
  
  for _, filepath in ipairs(filepaths) do
    local result, err = ParserFramework.parse_file(filepath, options)
    if result then
      results[filepath] = result
    else
      errors[filepath] = err
    end
  end
  
  return results, errors
end

--- Create intermediate representation template
-- Provides a standard structure for parsers to use
-- @return table ir Empty intermediate representation
function ParserFramework.create_ir()
  return {
    -- Format information
    format = nil,
    version = nil,
    
    -- Story metadata
    metadata = {
      title = "Untitled",
      author = nil,
      ifid = nil,
      created = nil,
      modified = nil
    },
    
    -- Story content
    passages = {},      -- Array of passages
    variables = {},     -- Story variables with default values
    scripts = {},       -- Global scripts
    stylesheets = {},   -- Stylesheets
    
    -- Additional data
    tags = {},          -- Global tags
    custom = {}         -- Format-specific data
  }
end

--- Create passage template
-- @return table passage Empty passage
function ParserFramework.create_passage()
  return {
    id = nil,
    name = nil,
    tags = {},
    content = "",
    position = { x = 0, y = 0 },
    size = { width = 100, height = 100 },
    metadata = {}
  }
end

--- Validation helpers
ParserFramework.Validators = {}

--- Validate intermediate representation
-- @param ir table Intermediate representation
-- @return table result Validation result
function ParserFramework.Validators.validate_ir(ir)
  local errors = {}
  local warnings = {}
  
  -- Check required fields
  if not ir.metadata then
    table.insert(errors, "Missing metadata")
  end
  
  if not ir.passages or type(ir.passages) ~= "table" then
    table.insert(errors, "Missing or invalid passages")
  end
  
  -- Validate passages
  if ir.passages then
    local passage_ids = {}
    
    for i, passage in ipairs(ir.passages) do
      -- Check required passage fields
      if not passage.id then
        table.insert(errors, string.format("Passage %d missing id", i))
      else
        -- Check for duplicate IDs
        if passage_ids[passage.id] then
          table.insert(errors, string.format("Duplicate passage id: %s", passage.id))
        end
        passage_ids[passage.id] = true
      end
      
      if not passage.content then
        table.insert(warnings, string.format("Passage %s has no content", passage.id or i))
      end
    end
    
    -- Check for start passage
    if #ir.passages == 0 then
      table.insert(errors, "Story has no passages")
    end
  end
  
  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings
  }
end

--- Check for broken links in passages
-- @param ir table Intermediate representation
-- @return table broken_links Array of broken link info
function ParserFramework.Validators.check_links(ir)
  local passage_ids = {}
  local broken = {}
  
  -- Build passage ID map
  for _, passage in ipairs(ir.passages or {}) do
    if passage.id then
      passage_ids[passage.id] = true
    end
  end
  
  -- Check links in each passage
  for _, passage in ipairs(ir.passages or {}) do
    -- This is a simple pattern - parsers should implement their own link extraction
    local content = passage.content or ""
    
    -- Match [[passage_name]] style links
    for link in content:gmatch("%[%[([^%]]+)%]%]") do
      -- Extract passage name (remove display text if present)
      local target = link:match("^([^|]+)")
      
      if target and not passage_ids[target] then
        table.insert(broken, {
          from = passage.id,
          to = target,
          type = "missing_target"
        })
      end
    end
  end
  
  return broken
end

--- Find orphaned passages (no incoming links)
-- @param ir table Intermediate representation
-- @return table orphaned Array of orphaned passage IDs
function ParserFramework.Validators.find_orphans(ir)
  local has_incoming = {}
  local orphaned = {}
  
  -- Mark all passages as potentially orphaned
  for _, passage in ipairs(ir.passages or {}) do
    has_incoming[passage.id] = false
  end
  
  -- Mark first passage as having incoming link (it's the start)
  if ir.passages and #ir.passages > 0 then
    has_incoming[ir.passages[1].id] = true
  end
  
  -- Find all links
  for _, passage in ipairs(ir.passages or {}) do
    local content = passage.content or ""
    
    for link in content:gmatch("%[%[([^%]]+)%]%]") do
      local target = link:match("^([^|]+)")
      if target and has_incoming[target] ~= nil then
        has_incoming[target] = true
      end
    end
  end
  
  -- Collect orphaned passages
  for id, has_link in pairs(has_incoming) do
    if not has_link then
      table.insert(orphaned, id)
    end
  end
  
  return orphaned
end

return ParserFramework
