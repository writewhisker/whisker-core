--- Motion Preference Manager
-- Handles reduced motion preferences for accessibility
-- @module whisker.a11y.motion_preference
-- @author Whisker Core Team
-- @license MIT

local MotionPreference = {}
MotionPreference.__index = MotionPreference

-- Dependencies
MotionPreference._dependencies = {"event_bus", "logger"}

--- Create a new MotionPreference manager
-- @param deps table Dependency container
-- @return MotionPreference The new manager instance
function MotionPreference.new(deps)
  local self = setmetatable({}, MotionPreference)

  self.events = deps and deps.event_bus
  self.log = deps and deps.logger

  -- Preference state
  self._reduced_motion = false
  self._user_override = nil -- nil = follow system, true/false = user choice

  return self
end

--- Factory method for DI container
-- @param deps table Dependencies
-- @return MotionPreference
function MotionPreference.create(deps)
  return MotionPreference.new(deps)
end

--- Check if reduced motion is enabled
-- @return boolean True if reduced motion is enabled
function MotionPreference:is_reduced_motion()
  if self._user_override ~= nil then
    return self._user_override
  end
  return self._reduced_motion
end

--- Set the system preference (from prefers-reduced-motion media query)
-- @param reduced boolean True if system prefers reduced motion
function MotionPreference:set_system_preference(reduced)
  self._reduced_motion = reduced

  if self._user_override == nil then
    if self.events then
      self.events:emit("a11y.motion_preference_changed", {
        reduced_motion = reduced,
        source = "system",
      })
    end
  end
end

--- Enable reduced motion (user override)
function MotionPreference:enable_reduced_motion()
  self._user_override = true

  if self.events then
    self.events:emit("a11y.motion_preference_changed", {
      reduced_motion = true,
      source = "user",
    })
  end

  if self.log then
    self.log:debug("Reduced motion enabled by user")
  end
end

--- Disable reduced motion (user override)
function MotionPreference:disable_reduced_motion()
  self._user_override = false

  if self.events then
    self.events:emit("a11y.motion_preference_changed", {
      reduced_motion = false,
      source = "user",
    })
  end

  if self.log then
    self.log:debug("Reduced motion disabled by user")
  end
end

--- Reset to system preference
function MotionPreference:reset_to_system()
  self._user_override = nil

  if self.events then
    self.events:emit("a11y.motion_preference_changed", {
      reduced_motion = self._reduced_motion,
      source = "system",
    })
  end
end

--- Toggle reduced motion preference
function MotionPreference:toggle()
  if self:is_reduced_motion() then
    self:disable_reduced_motion()
  else
    self:enable_reduced_motion()
  end
end

--- Get animation duration based on preference
-- @param normal_duration number Duration in ms when motion is OK
-- @param reduced_duration number|nil Duration in ms when reduced (default: 1)
-- @return number The appropriate duration
function MotionPreference:get_animation_duration(normal_duration, reduced_duration)
  reduced_duration = reduced_duration or 1

  if self:is_reduced_motion() then
    return reduced_duration
  end

  return normal_duration
end

--- Check if an animation should play
-- @param is_essential boolean True if animation conveys essential info
-- @return boolean True if animation should play
function MotionPreference:should_animate(is_essential)
  if is_essential then
    return true -- Essential animations always play
  end

  return not self:is_reduced_motion()
end

--- Get CSS for reduced motion support
-- @return string CSS media query rules
function MotionPreference:get_css()
  return [[
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}

body[data-reduced-motion="true"] *,
body[data-reduced-motion="true"] *::before,
body[data-reduced-motion="true"] *::after {
  animation-duration: 0.01ms !important;
  animation-iteration-count: 1 !important;
  transition-duration: 0.01ms !important;
  scroll-behavior: auto !important;
}

/* Safe transitions that don't cause motion sickness */
.safe-transition {
  transition: opacity 0.2s ease;
}

@media (prefers-reduced-motion: reduce) {
  .safe-transition {
    transition: opacity 0.05s ease;
  }
}
]]
end

--- Get JavaScript for detecting system preference
-- @return string JavaScript code
function MotionPreference:get_detection_js()
  return [[
(function() {
  const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');

  function updatePreference(e) {
    if (e.matches) {
      document.body.setAttribute('data-system-reduced-motion', 'true');
    } else {
      document.body.removeAttribute('data-system-reduced-motion');
    }

    // Dispatch event for framework integration
    window.dispatchEvent(new CustomEvent('whisker:motion-preference', {
      detail: { reducedMotion: e.matches }
    }));
  }

  // Initial check
  updatePreference(mediaQuery);

  // Listen for changes
  mediaQuery.addEventListener('change', updatePreference);
})();
]]
end

--- Get the current preference source
-- @return string "user" or "system"
function MotionPreference:get_source()
  if self._user_override ~= nil then
    return "user"
  end
  return "system"
end

--- Serialize preference for storage
-- @return table Serializable preference data
function MotionPreference:serialize()
  return {
    user_override = self._user_override,
    system_preference = self._reduced_motion,
  }
end

--- Restore preference from storage
-- @param data table Previously serialized data
function MotionPreference:deserialize(data)
  if data then
    self._user_override = data.user_override
    if data.system_preference ~= nil then
      self._reduced_motion = data.system_preference
    end
  end
end

return MotionPreference
