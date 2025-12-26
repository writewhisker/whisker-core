-- Ink ↔ Twine Compatibility Matrix
-- Defines feature mapping between Ink and Twine formats

local M = {}

-- Ink features that convert directly to Twine formats
M.INK_TO_TWINE_SUPPORTED = {
  {
    ink_feature = "knot",
    ink_pattern = "^%s*===%s*([%w_]+)%s*===",
    twine_equivalent = "passage",
    notes = "Knots become passages"
  },
  {
    ink_feature = "stitch",
    ink_pattern = "^%s*=%s*([%w_]+)",
    twine_equivalent = "passage",
    notes = "Stitches become passages with knot prefix"
  },
  {
    ink_feature = "choice",
    ink_pattern = "^%s*%*+%s*%[?([^%]%*]-)%]?",
    twine_equivalent = "link",
    notes = "Choices become links"
  },
  {
    ink_feature = "divert",
    ink_pattern = "->%s*([%w_%.]+)",
    twine_equivalent = "link",
    notes = "Diverts become links"
  },
  {
    ink_feature = "variable_declare",
    ink_pattern = "^%s*VAR%s+([%w_]+)%s*=%s*(.+)",
    twine_equivalent = "set",
    notes = "VAR declarations become set macros"
  },
  {
    ink_feature = "variable_assign",
    ink_pattern = "~%s*([%w_]+)%s*=%s*(.+)",
    twine_equivalent = "set",
    notes = "Variable assignments become set macros"
  },
  {
    ink_feature = "conditional",
    ink_pattern = "{%s*([^:}]+)%s*:",
    twine_equivalent = "if",
    notes = "Ink conditionals become if macros"
  },
  {
    ink_feature = "text",
    ink_pattern = "^[^=*~{}<>]+",
    twine_equivalent = "content",
    notes = "Plain text converts directly"
  },
}

-- Ink features that are approximated in Twine
M.INK_TO_TWINE_APPROXIMATED = {
  {
    ink_feature = "tunnel",
    ink_pattern = "->%s*([%w_%.]+)%s*->",
    approximation = "link with return marker",
    notes = "Tunnels approximated as links; return behavior requires manual handling",
    affects = {"harlowe", "sugarcube", "chapbook", "snowman"}
  },
  {
    ink_feature = "sticky_choice",
    ink_pattern = "^%s*%+%s*",
    approximation = "regular link",
    notes = "Sticky choices (reusable) become regular links; stickiness lost",
    affects = {"harlowe", "sugarcube", "chapbook", "snowman"}
  },
  {
    ink_feature = "fallback_choice",
    ink_pattern = "^%s*%*%s*$",
    approximation = "unconditional link",
    notes = "Fallback choices become regular links; fallback behavior lost",
    affects = {"harlowe", "sugarcube", "chapbook", "snowman"}
  },
  {
    ink_feature = "sequence",
    ink_pattern = "{%s*&%s*([^}]+)}",
    approximation = "first item only",
    notes = "Sequences show first item; cycling behavior requires manual implementation",
    affects = {"harlowe", "chapbook", "snowman"}
  },
  {
    ink_feature = "shuffle",
    ink_pattern = "{%s*~%s*([^}]+)}",
    approximation = "random selection",
    notes = "Shuffles become random; no-repeat behavior lost",
    affects = {"harlowe", "chapbook", "snowman"}
  },
}

-- Ink features incompatible with Twine
M.INK_TO_TWINE_INCOMPATIBLE = {
  {
    ink_feature = "thread",
    ink_pattern = "<%s*-",
    description = "Threads have no Twine equivalent; parallel narrative not supported",
    severity = "error"
  },
  {
    ink_feature = "external_function",
    ink_pattern = "EXTERNAL%s+",
    description = "External functions require custom implementation in target format",
    severity = "warning"
  },
  {
    ink_feature = "include",
    ink_pattern = "INCLUDE%s+",
    description = "Include statements must be resolved before conversion",
    severity = "warning"
  },
  {
    ink_feature = "list_type",
    ink_pattern = "LIST%s+",
    description = "Ink lists require manual conversion to arrays or objects",
    severity = "warning"
  },
  {
    ink_feature = "tunnel_return",
    ink_pattern = "->->",
    description = "Tunnel returns have no direct equivalent",
    severity = "warning"
  },
}

-- Twine features that convert to Ink
M.TWINE_TO_INK_SUPPORTED = {
  {
    twine_feature = "passage",
    formats = {"harlowe", "sugarcube", "chapbook", "snowman"},
    ink_equivalent = "knot",
    notes = "Passages become knots"
  },
  {
    twine_feature = "link",
    formats = {"harlowe", "sugarcube", "chapbook", "snowman"},
    ink_equivalent = "choice or divert",
    notes = "Links become choices (with text) or diverts (inline)"
  },
  {
    twine_feature = "set_variable",
    formats = {"harlowe", "sugarcube", "chapbook", "snowman"},
    ink_equivalent = "~ var = value",
    notes = "Variable assignments convert directly"
  },
  {
    twine_feature = "if_condition",
    formats = {"harlowe", "sugarcube", "chapbook", "snowman"},
    ink_equivalent = "{ condition: }",
    notes = "Conditionals convert with syntax adjustment"
  },
  {
    twine_feature = "print_variable",
    formats = {"harlowe", "sugarcube", "snowman"},
    ink_equivalent = "{variable}",
    notes = "Variable interpolation converts directly"
  },
}

-- Twine features approximated in Ink
M.TWINE_TO_INK_APPROXIMATED = {
  {
    twine_feature = "live",
    formats = {"harlowe"},
    approximation = "none",
    notes = "Real-time updates not supported in Ink"
  },
  {
    twine_feature = "repeat",
    formats = {"sugarcube"},
    approximation = "none",
    notes = "Timed repeats not supported in Ink"
  },
  {
    twine_feature = "dropdown",
    formats = {"harlowe", "chapbook"},
    approximation = "choices",
    notes = "Dropdown becomes multiple choices"
  },
  {
    twine_feature = "cycling_link",
    formats = {"harlowe", "sugarcube", "chapbook"},
    approximation = "choices",
    notes = "Cycling links become multiple choices"
  },
}

-- Twine features incompatible with Ink
M.TWINE_TO_INK_INCOMPATIBLE = {
  {
    twine_feature = "enchant",
    formats = {"harlowe"},
    description = "DOM manipulation not available in Ink",
    severity = "error"
  },
  {
    twine_feature = "css_styling",
    formats = {"harlowe", "sugarcube", "chapbook", "snowman"},
    description = "CSS styling stripped during conversion",
    severity = "warning"
  },
  {
    twine_feature = "javascript",
    formats = {"snowman", "sugarcube"},
    description = "Inline JavaScript not supported in Ink",
    severity = "error"
  },
  {
    twine_feature = "dom_events",
    formats = {"harlowe", "sugarcube"},
    description = "Click, mouseover events not supported in Ink",
    severity = "warning"
  },
  {
    twine_feature = "audio_video",
    formats = {"harlowe", "sugarcube", "chapbook"},
    description = "Media embeds require custom Ink implementation",
    severity = "warning"
  },
}

--- Check if an Ink feature is supported for a target format
-- @param feature string The Ink feature name
-- @param target_format string The target Twine format
-- @return boolean, string Whether supported and notes
function M.is_ink_feature_supported(feature, target_format)
  for _, item in ipairs(M.INK_TO_TWINE_SUPPORTED) do
    if item.ink_feature == feature then
      return true, item.notes
    end
  end

  for _, item in ipairs(M.INK_TO_TWINE_APPROXIMATED) do
    if item.ink_feature == feature then
      for _, fmt in ipairs(item.affects) do
        if fmt == target_format then
          return false, "approximated: " .. item.notes
        end
      end
    end
  end

  for _, item in ipairs(M.INK_TO_TWINE_INCOMPATIBLE) do
    if item.ink_feature == feature then
      return false, "incompatible: " .. item.description
    end
  end

  return true, "unknown feature, assumed supported"
end

--- Check if a Twine feature is supported for Ink conversion
-- @param feature string The Twine feature name
-- @param source_format string The source Twine format
-- @return boolean, string Whether supported and notes
function M.is_twine_feature_supported(feature, source_format)
  for _, item in ipairs(M.TWINE_TO_INK_SUPPORTED) do
    if item.twine_feature == feature then
      for _, fmt in ipairs(item.formats) do
        if fmt == source_format then
          return true, item.notes
        end
      end
    end
  end

  for _, item in ipairs(M.TWINE_TO_INK_APPROXIMATED) do
    if item.twine_feature == feature then
      for _, fmt in ipairs(item.formats) do
        if fmt == source_format then
          return false, "approximated: " .. item.notes
        end
      end
    end
  end

  for _, item in ipairs(M.TWINE_TO_INK_INCOMPATIBLE) do
    if item.twine_feature == feature then
      for _, fmt in ipairs(item.formats) do
        if fmt == source_format then
          return false, "incompatible: " .. item.description
        end
      end
    end
  end

  return true, "unknown feature, assumed supported"
end

--- Get all incompatible features for Ink to Twine conversion
-- @return table List of incompatible features
function M.get_ink_incompatible()
  return M.INK_TO_TWINE_INCOMPATIBLE
end

--- Get all approximated features for Ink to Twine conversion
-- @return table List of approximated features
function M.get_ink_approximated()
  return M.INK_TO_TWINE_APPROXIMATED
end

--- Get all incompatible features for Twine to Ink conversion
-- @return table List of incompatible features
function M.get_twine_incompatible()
  return M.TWINE_TO_INK_INCOMPATIBLE
end

--- Get all approximated features for Twine to Ink conversion
-- @return table List of approximated features
function M.get_twine_approximated()
  return M.TWINE_TO_INK_APPROXIMATED
end

return M
