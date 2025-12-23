--- ARIA Manager
-- Manages ARIA attributes for accessible UI components
-- @module whisker.a11y.aria_manager
-- @author Whisker Core Team
-- @license MIT

local AriaManager = {}
AriaManager.__index = AriaManager

-- Dependencies
AriaManager._dependencies = {"event_bus", "logger"}

-- Valid ARIA roles for interactive fiction
local VALID_ROLES = {
  "application",
  "article",
  "banner",
  "button",
  "complementary",
  "contentinfo",
  "dialog",
  "document",
  "heading",
  "list",
  "listbox",
  "listitem",
  "main",
  "navigation",
  "option",
  "region",
  "status",
}

-- ARIA states and properties
local ARIA_ATTRIBUTES = {
  -- States
  "aria-busy",
  "aria-checked",
  "aria-current",
  "aria-disabled",
  "aria-expanded",
  "aria-hidden",
  "aria-invalid",
  "aria-pressed",
  "aria-selected",

  -- Properties
  "aria-activedescendant",
  "aria-atomic",
  "aria-controls",
  "aria-describedby",
  "aria-details",
  "aria-haspopup",
  "aria-keyshortcuts",
  "aria-label",
  "aria-labelledby",
  "aria-live",
  "aria-owns",
  "aria-posinset",
  "aria-roledescription",
  "aria-setsize",
}

--- Create a new AriaManager
-- @param deps table Dependency container
-- @return AriaManager The new manager instance
function AriaManager.new(deps)
  local self = setmetatable({}, AriaManager)

  self.events = deps and deps.event_bus
  self.log = deps and deps.logger

  return self
end

--- Factory method for DI container
-- @param deps table Dependencies
-- @return AriaManager
function AriaManager.create(deps)
  return AriaManager.new(deps)
end

--- Get ARIA attributes for a story passage
-- @param passage table The passage object {id, title, content}
-- @param is_current boolean True if this is the current passage
-- @return table ARIA attributes
function AriaManager:get_passage_aria(passage, is_current)
  local attrs = {
    role = "article",
    ["aria-label"] = passage.title or ("Passage " .. (passage.id or "")),
  }

  if is_current then
    attrs["aria-current"] = "page"
  end

  return attrs
end

--- Get ARIA attributes for a choice list
-- @param choices table Array of choice objects
-- @return table ARIA attributes for the list
function AriaManager:get_choice_list_aria(choices)
  local count = choices and #choices or 0

  return {
    role = "listbox",
    ["aria-label"] = count == 1 and "1 choice available" or (count .. " choices available"),
    ["aria-orientation"] = "vertical",
  }
end

--- Get ARIA attributes for a choice item
-- @param choice table The choice object {text, id}
-- @param index number The choice index (1-based)
-- @param total number Total number of choices
-- @param is_selected boolean True if this choice is currently focused
-- @return table ARIA attributes
function AriaManager:get_choice_aria(choice, index, total, is_selected)
  return {
    role = "option",
    ["aria-label"] = choice.text,
    ["aria-posinset"] = tostring(index),
    ["aria-setsize"] = tostring(total),
    ["aria-selected"] = is_selected and "true" or "false",
    tabindex = is_selected and "0" or "-1",
  }
end

--- Get ARIA attributes for a dialog
-- @param title string The dialog title
-- @param description string|nil Optional description
-- @return table ARIA attributes
function AriaManager:get_dialog_aria(title, description)
  local attrs = {
    role = "dialog",
    ["aria-modal"] = "true",
    ["aria-label"] = title,
  }

  if description then
    attrs["aria-describedby"] = description
  end

  return attrs
end

--- Get ARIA attributes for a navigation region
-- @param label string The navigation label
-- @return table ARIA attributes
function AriaManager:get_navigation_aria(label)
  return {
    role = "navigation",
    ["aria-label"] = label,
  }
end

--- Get ARIA attributes for a button
-- @param label string The button label
-- @param is_pressed boolean|nil For toggle buttons, current pressed state
-- @param is_disabled boolean|nil True if button is disabled
-- @return table ARIA attributes
function AriaManager:get_button_aria(label, is_pressed, is_disabled)
  local attrs = {
    role = "button",
    ["aria-label"] = label,
  }

  if is_pressed ~= nil then
    attrs["aria-pressed"] = is_pressed and "true" or "false"
  end

  if is_disabled then
    attrs["aria-disabled"] = "true"
  end

  return attrs
end

--- Get ARIA attributes for a live region
-- @param priority string "polite" or "assertive"
-- @param is_atomic boolean True if entire region should be announced
-- @return table ARIA attributes
function AriaManager:get_live_region_aria(priority, is_atomic)
  return {
    ["aria-live"] = priority or "polite",
    ["aria-atomic"] = is_atomic and "true" or "false",
  }
end

--- Get ARIA attributes for loading state
-- @param is_loading boolean True if loading
-- @return table ARIA attributes
function AriaManager:get_loading_aria(is_loading)
  return {
    ["aria-busy"] = is_loading and "true" or "false",
  }
end

--- Get ARIA attributes for a heading
-- @param level number Heading level (1-6)
-- @return table ARIA attributes
function AriaManager:get_heading_aria(level)
  return {
    role = "heading",
    ["aria-level"] = tostring(level),
  }
end

--- Get skip link attributes
-- @param target_id string The ID of the target element
-- @return table ARIA attributes and other properties
function AriaManager:get_skip_link_aria(target_id)
  return {
    href = "#" .. target_id,
    ["aria-label"] = "Skip to main content",
    class = "skip-link",
  }
end

--- Get ARIA attributes for main content region
-- @param label string|nil Optional label for the region
-- @return table ARIA attributes
function AriaManager:get_main_aria(label)
  local attrs = {
    role = "main",
  }

  if label then
    attrs["aria-label"] = label
  end

  return attrs
end

--- Validate ARIA role
-- @param role string The role to validate
-- @return boolean True if valid
function AriaManager:is_valid_role(role)
  for _, valid in ipairs(VALID_ROLES) do
    if valid == role then
      return true
    end
  end
  return false
end

--- Validate ARIA attribute name
-- @param attr string The attribute name
-- @return boolean True if valid
function AriaManager:is_valid_aria_attribute(attr)
  for _, valid in ipairs(ARIA_ATTRIBUTES) do
    if valid == attr then
      return true
    end
  end
  return false
end

--- Format ARIA attributes as HTML attribute string
-- @param attrs table ARIA attributes
-- @return string HTML attribute string
function AriaManager:to_html_attrs(attrs)
  local parts = {}

  for key, value in pairs(attrs) do
    if value ~= nil and value ~= "" then
      table.insert(parts, string.format('%s="%s"', key, tostring(value)))
    end
  end

  return table.concat(parts, " ")
end

--- Merge ARIA attributes, with second taking precedence
-- @param base table Base attributes
-- @param override table Override attributes
-- @return table Merged attributes
function AriaManager:merge_aria(base, override)
  local result = {}

  for k, v in pairs(base) do
    result[k] = v
  end

  for k, v in pairs(override or {}) do
    result[k] = v
  end

  return result
end

return AriaManager
