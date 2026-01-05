--- WLS 2.0 Text Effects Manager
-- Manages text effects like typewriter, fade, shake, etc.
--
-- @module whisker.wls2.text_effects
-- @author Whisker Team
-- @license MIT

local M = {}

-- Dependencies for DI pattern
M._dependencies = {}

--- Effect types
M.EFFECTS = {
  TYPEWRITER = "typewriter",
  FADE_IN = "fade-in",
  FADE_OUT = "fade-out",
  SHAKE = "shake",
  RAINBOW = "rainbow",
  GLITCH = "glitch",
}

--- Effect event types
M.EVENTS = {
  STARTED = "effectStarted",
  UPDATED = "effectUpdated",
  COMPLETED = "effectCompleted",
}

--- Generate a unique effect ID
local function generate_id()
  return string.format("effect_%d_%d", os.time(), math.random(10000, 99999))
end

--- Text Effects Manager class
-- @type TextEffectsManager
local TextEffectsManager = {}
TextEffectsManager.__index = TextEffectsManager

--- Create a new TextEffectsManager
-- @tparam[opt] table deps Injected dependencies (unused, for DI compatibility)
-- @treturn TextEffectsManager New manager instance
function M.new(deps)
  -- deps parameter for DI compatibility (currently unused)
  local self = setmetatable({}, TextEffectsManager)

  self.active_effects = {}
  self.effect_handlers = {}
  self.listeners = {}
  self.current_time = 0

  -- Register default effect handlers
  self:register_default_handlers()

  return self
end

--- Add an event listener
-- @tparam function callback Listener function(event, effect)
function TextEffectsManager:on(callback)
  table.insert(self.listeners, callback)
end

--- Remove an event listener
-- @tparam function callback Listener to remove
function TextEffectsManager:off(callback)
  for i, listener in ipairs(self.listeners) do
    if listener == callback then
      table.remove(self.listeners, i)
      return
    end
  end
end

--- Emit an event to all listeners
-- @tparam string event Event name
-- @tparam table effect Effect involved
function TextEffectsManager:emit(event, effect)
  for _, listener in ipairs(self.listeners) do
    listener(event, effect)
  end
end

--- Register an effect handler
-- @tparam string name Effect name
-- @tparam function handler Handler function(effect, delta_ms) -> rendered_text
function TextEffectsManager:register_handler(name, handler)
  self.effect_handlers[name] = handler
end

--- Register default effect handlers
function TextEffectsManager:register_default_handlers()
  -- Typewriter effect
  self:register_handler(M.EFFECTS.TYPEWRITER, function(effect, _delta_ms)
    local char_duration = effect.options.speed or 50  -- ms per character
    local elapsed = self.current_time - effect.start_time
    local chars_shown = math.floor(elapsed / char_duration)

    if chars_shown >= #effect.text then
      effect.completed = true
      return effect.text
    else
      return effect.text:sub(1, chars_shown)
    end
  end)

  -- Fade in effect
  self:register_handler(M.EFFECTS.FADE_IN, function(effect, _delta_ms)
    local duration = effect.options.duration or 1000
    local elapsed = self.current_time - effect.start_time
    local progress = math.min(1, elapsed / duration)

    effect.opacity = progress

    if progress >= 1 then
      effect.completed = true
    end

    return effect.text
  end)

  -- Fade out effect
  self:register_handler(M.EFFECTS.FADE_OUT, function(effect, _delta_ms)
    local duration = effect.options.duration or 1000
    local elapsed = self.current_time - effect.start_time
    local progress = math.min(1, elapsed / duration)

    effect.opacity = 1 - progress

    if progress >= 1 then
      effect.completed = true
    end

    return effect.text
  end)

  -- Shake effect
  self:register_handler(M.EFFECTS.SHAKE, function(effect, _delta_ms)
    local duration = effect.options.duration or 500
    local elapsed = self.current_time - effect.start_time

    if elapsed >= duration then
      effect.completed = true
      effect.offset_x = 0
      effect.offset_y = 0
    else
      local intensity = effect.options.intensity or 5
      effect.offset_x = (math.random() * 2 - 1) * intensity
      effect.offset_y = (math.random() * 2 - 1) * intensity
    end

    return effect.text
  end)
end

--- Apply an effect to text
-- @tparam string text Text to apply effect to
-- @tparam string effect_name Effect name
-- @tparam[opt] table options Effect options
-- @treturn string Effect ID
function TextEffectsManager:apply(text, effect_name, options)
  options = options or {}

  local id = generate_id()
  local effect = {
    id = id,
    text = text,
    effect_name = effect_name,
    options = options,
    start_time = self.current_time,
    completed = false,
    opacity = 1,
    offset_x = 0,
    offset_y = 0,
    rendered_text = "",
  }

  self.active_effects[id] = effect
  self:emit(M.EVENTS.STARTED, effect)

  return id
end

--- Update all active effects
-- @tparam number delta_ms Milliseconds since last update
-- @treturn table Map of effect_id to rendered state
function TextEffectsManager:update(delta_ms)
  self.current_time = self.current_time + delta_ms
  local results = {}

  for id, effect in pairs(self.active_effects) do
    local handler = self.effect_handlers[effect.effect_name]
    if handler then
      local rendered = handler(effect, delta_ms)
      effect.rendered_text = rendered

      results[id] = {
        text = rendered,
        opacity = effect.opacity,
        offset_x = effect.offset_x,
        offset_y = effect.offset_y,
        completed = effect.completed,
      }

      self:emit(M.EVENTS.UPDATED, effect)

      if effect.completed then
        self:emit(M.EVENTS.COMPLETED, effect)
        self.active_effects[id] = nil
      end
    end
  end

  return results
end

--- Get an active effect by ID
-- @tparam string effect_id Effect ID
-- @treturn table|nil Effect or nil
function TextEffectsManager:get_effect(effect_id)
  return self.active_effects[effect_id]
end

--- Cancel an effect
-- @tparam string effect_id Effect ID to cancel
function TextEffectsManager:cancel(effect_id)
  self.active_effects[effect_id] = nil
end

--- Cancel all effects
function TextEffectsManager:cancel_all()
  self.active_effects = {}
end

--- Check if an effect is complete
-- @tparam string effect_id Effect ID
-- @treturn boolean True if complete or not found
function TextEffectsManager:is_complete(effect_id)
  local effect = self.active_effects[effect_id]
  return effect == nil or effect.completed
end

--- Check if all effects are complete
-- @treturn boolean True if no active effects
function TextEffectsManager:all_complete()
  return next(self.active_effects) == nil
end

--- Reset the manager
function TextEffectsManager:reset()
  self.active_effects = {}
  self.current_time = 0
end

--- Parse an effect declaration string
-- @tparam string declaration Effect declaration like "shake 500ms"
-- @treturn table Parsed effect with name, duration, options
function M.parse_effect_declaration(declaration)
  local parts = {}
  for part in declaration:gmatch("%S+") do
    table.insert(parts, part)
  end

  if #parts == 0 then
    error("Invalid @effect declaration: " .. declaration)
  end

  local name = parts[1]
  local options = {}
  local duration = nil

  for i = 2, #parts do
    local part = parts[i]

    -- Check for key:value format
    local key, value = part:match("^(%w+):(.+)$")
    if key then
      local num_value = tonumber(value)
      options[key] = num_value or value
    else
      -- Check for duration format
      local num, unit = part:match("^(%d+%.?%d*)(%a*)$")
      if num then
        local ms = tonumber(num)
        if unit == "s" then
          ms = ms * 1000
        end
        duration = ms
      end
    end
  end

  return {
    name = name,
    duration = duration,
    options = options,
  }
end

return M
