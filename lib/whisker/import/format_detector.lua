--- Format Detector
-- Utilities for detecting source format from content
-- @module whisker.import.format_detector
-- @author Whisker Core Team
-- @license MIT

local FormatDetector = {}

--- Detection patterns for various formats
FormatDetector.patterns = {
  -- WLS format patterns
  wls = {
    { pattern = "^%s*::%s*.+", weight = 10 },                    -- Passage headers
    { pattern = "^%s*@TITLE%s+", weight = 8 },                   -- @TITLE directive
    { pattern = "^%s*@AUTHOR%s+", weight = 8 },                  -- @AUTHOR directive
    { pattern = "^%s*@IFID%s+", weight = 8 },                    -- @IFID directive
    { pattern = "^%s*VAR%s+%w+%s*=", weight = 7 },               -- VAR declaration
    { pattern = "^%s*LIST%s+%w+%s*=", weight = 7 },              -- LIST declaration
    { pattern = "%+%s*%[.-%]%s*%->", weight = 6 },               -- Choice syntax
    { pattern = "%${%s*.-%s*}", weight = 5 },                    -- Expression interpolation
    { pattern = "%->%s*.+%s*%->", weight = 8 },                  -- Tunnel call
    { pattern = "<%%-", weight = 7 },                            -- Tunnel return
  },

  -- Twine HTML format patterns
  twine = {
    { pattern = "<tw%-storydata", weight = 10 },
    { pattern = "<tw:storydata", weight = 10 },
    { pattern = 'id="storeArea"', weight = 8 },
    { pattern = "<tw%-passagedata", weight = 9 },
    { pattern = "Twine%.version", weight = 6 },
    { pattern = "data%-startnode", weight = 7 },
  },

  -- Harlowe syntax patterns (within Twine)
  harlowe = {
    { pattern = "%(set:%s*%$", weight = 8 },                     -- (set: $var to value)
    { pattern = "%(if:%s*%$", weight = 8 },                      -- (if: $var)
    { pattern = "%(link:", weight = 7 },                         -- (link: "text")
    { pattern = "%(go%-to:", weight = 7 },                       -- (go-to: "passage")
    { pattern = "%(display:", weight = 6 },                      -- (display: "passage")
    { pattern = "%(print:", weight = 6 },                        -- (print: $var)
  },

  -- SugarCube syntax patterns (within Twine)
  sugarcube = {
    { pattern = "<<set%s+%$", weight = 8 },                      -- <<set $var = value>>
    { pattern = "<<if%s+%$", weight = 8 },                       -- <<if $var>>
    { pattern = "<<link%s+", weight = 7 },                       -- <<link>>
    { pattern = "<<goto%s+", weight = 7 },                       -- <<goto>>
    { pattern = "<<include%s+", weight = 6 },                    -- <<include>>
    { pattern = "<<widget%s+", weight = 6 },                     -- <<widget>>
  },

  -- Chapbook syntax patterns (within Twine)
  chapbook = {
    { pattern = "%[if%s+", weight = 8 },                         -- [if condition]
    { pattern = "%[else%]", weight = 7 },                        -- [else]
    { pattern = "%[continue%]", weight = 7 },                    -- [continue]
    { pattern = "%-%-%-", weight = 5 },                          -- --- (section break)
    { pattern = "%w+:%s*%d+", weight = 4 },                      -- variable: value
  },

  -- Ink format patterns
  ink = {
    { pattern = "^%s*=%s*%w+", weight = 8 },                     -- = knot
    { pattern = "^%s*==%s*%w+", weight = 8 },                    -- == stitch
    { pattern = "^%s*%*%s+", weight = 6 },                       -- * choice
    { pattern = "^%s*%+%s+", weight = 6 },                       -- + sticky choice
    { pattern = "^%s*%->%s*%w+", weight = 7 },                   -- -> divert
    { pattern = "VAR%s+%w+%s*=", weight = 5 },                   -- VAR declaration
    { pattern = "~%s*%w+%s*=", weight = 5 },                     -- ~ temp variable
    { pattern = "{%s*.-%s*}", weight = 4 },                      -- {content}
  },

  -- ChoiceScript format patterns
  choicescript = {
    { pattern = "^%s*%*label%s+", weight = 9 },                  -- *label name
    { pattern = "^%s*%*create%s+", weight = 8 },                 -- *create var value
    { pattern = "^%s*%*set%s+", weight = 8 },                    -- *set var value
    { pattern = "^%s*%*if%s+", weight = 7 },                     -- *if condition
    { pattern = "^%s*%*choice%s*$", weight = 9 },                -- *choice
    { pattern = "^%s*%*goto%s+", weight = 7 },                   -- *goto label
    { pattern = "^%s*%*finish%s*", weight = 6 },                 -- *finish
    { pattern = "^%s*%*page_break%s*", weight = 6 },             -- *page_break
  },

  -- JSON format patterns
  json = {
    { pattern = "^%s*{", weight = 3 },                           -- Starts with {
    { pattern = '"passages"%s*:', weight = 8 },                  -- Has passages key
    { pattern = '"metadata"%s*:', weight = 6 },                  -- Has metadata key
    { pattern = '"ifid"%s*:', weight = 7 },                      -- Has IFID
  },
}

--- Detect format from source content
-- @param source string The source content
-- @return string|nil The detected format name, or nil
-- @return number confidence Confidence score (0-100)
function FormatDetector.detect(source)
  if type(source) ~= "string" or source == "" then
    return nil, 0
  end

  local scores = {}

  -- Calculate score for each format
  for format, patterns in pairs(FormatDetector.patterns) do
    scores[format] = 0
    for _, pattern_info in ipairs(patterns) do
      if source:find(pattern_info.pattern) then
        scores[format] = scores[format] + pattern_info.weight
      end
    end
  end

  -- Find the highest scoring format
  local best_format = nil
  local best_score = 0

  for format, score in pairs(scores) do
    if score > best_score then
      best_score = score
      best_format = format
    end
  end

  -- Calculate confidence (normalized to 0-100)
  local max_possible = 0
  if best_format then
    for _, pattern_info in ipairs(FormatDetector.patterns[best_format]) do
      max_possible = max_possible + pattern_info.weight
    end
  end

  local confidence = 0
  if max_possible > 0 then
    confidence = math.floor((best_score / max_possible) * 100)
  end

  -- Require minimum confidence
  if confidence < 20 then
    return nil, 0
  end

  return best_format, confidence
end

--- Detect Twine story format (Harlowe, SugarCube, Chapbook, etc.)
-- @param source string The source content
-- @return string|nil The Twine format name
function FormatDetector.detect_twine_format(source)
  if type(source) ~= "string" then
    return nil
  end

  -- Check for format attribute in tw-storydata
  local format = source:match('format="([^"]+)"')
  if format then
    format = format:lower()
    if format:find("harlowe") then return "harlowe" end
    if format:find("sugarcube") then return "sugarcube" end
    if format:find("chapbook") then return "chapbook" end
    if format:find("snowman") then return "snowman" end
    return format
  end

  -- Detect from syntax patterns
  local harlowe_score = 0
  local sugarcube_score = 0
  local chapbook_score = 0

  for _, pattern in ipairs(FormatDetector.patterns.harlowe) do
    if source:find(pattern.pattern) then
      harlowe_score = harlowe_score + pattern.weight
    end
  end

  for _, pattern in ipairs(FormatDetector.patterns.sugarcube) do
    if source:find(pattern.pattern) then
      sugarcube_score = sugarcube_score + pattern.weight
    end
  end

  for _, pattern in ipairs(FormatDetector.patterns.chapbook) do
    if source:find(pattern.pattern) then
      chapbook_score = chapbook_score + pattern.weight
    end
  end

  local max_score = math.max(harlowe_score, sugarcube_score, chapbook_score)
  if max_score == 0 then
    return "unknown"
  end

  if harlowe_score == max_score then return "harlowe" end
  if sugarcube_score == max_score then return "sugarcube" end
  if chapbook_score == max_score then return "chapbook" end

  return "unknown"
end

--- Detect format from file extension
-- @param filepath string The file path
-- @return string|nil The format name
function FormatDetector.detect_from_extension(filepath)
  if type(filepath) ~= "string" then
    return nil
  end

  local ext = filepath:match("%.([^%.]+)$")
  if not ext then
    return nil
  end

  ext = ext:lower()

  local extension_map = {
    -- WLS formats
    wls = "wls",
    whisker = "wls",

    -- Twine formats
    html = "twine",
    htm = "twine",
    tw = "twine",
    twee = "twine",

    -- Ink format
    ink = "ink",

    -- ChoiceScript
    txt = "choicescript",

    -- JSON
    json = "json",

    -- Markdown (may contain WLS or other)
    md = "markdown",
  }

  return extension_map[ext]
end

--- Get all supported format names
-- @return table Array of format names
function FormatDetector.get_supported_formats()
  local formats = {}
  for format in pairs(FormatDetector.patterns) do
    table.insert(formats, format)
  end
  table.sort(formats)
  return formats
end

--- Check if a format is supported
-- @param format string The format name
-- @return boolean True if supported
function FormatDetector.is_supported(format)
  return FormatDetector.patterns[format] ~= nil
end

return FormatDetector
