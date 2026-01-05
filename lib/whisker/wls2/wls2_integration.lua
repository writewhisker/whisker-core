--- WLS 2.0 Integration Module
-- Integrates all WLS 2.0 components into a cohesive runtime.
--
-- @module whisker.wls2.wls2_integration
-- @author Whisker Team
-- @license MIT

local thread_scheduler = require("whisker.wls2.thread_scheduler")
local timed_content = require("whisker.wls2.timed_content")
local text_effects = require("whisker.wls2.text_effects")
local external_functions = require("whisker.wls2.external_functions")

local M = {}

-- Dependencies for DI pattern
M._dependencies = {"thread_scheduler", "timed_content", "text_effects", "external_functions"}

--- WLS2 event types
M.EVENTS = {
  INITIALIZED = "wls2Initialized",
  THREAD_OUTPUT = "threadOutput",
  TIMER_FIRED = "timerFired",
  EFFECT_UPDATED = "effectUpdated",
  EXTERNAL_CALLED = "externalCalled",
  TICK = "tick",
}

--- WLS2 Integration class
-- @type WLS2Integration
local WLS2Integration = {}
WLS2Integration.__index = WLS2Integration

--- Create a new WLS2Integration
-- @tparam[opt] table options Integration options
-- @tparam[opt] table deps Injected dependencies (unused, for DI compatibility)
-- @treturn WLS2Integration New integration instance
function M.new(options, deps)
  options = options or {}
  -- deps parameter for DI compatibility (currently unused)
  local self = setmetatable({}, WLS2Integration)

  -- Create component managers
  self.scheduler = thread_scheduler.new({
    max_threads = options.max_threads or 10,
    default_priority = options.default_priority or 0,
    round_robin = options.round_robin,
  })

  self.timers = timed_content.new()
  self.effects = text_effects.new()
  self.externals = external_functions.new()

  -- Integration state
  self.listeners = {}
  self.current_time = 0
  self.tick_rate = options.tick_rate or 16  -- ~60fps default
  self.running = false
  self.paused = false

  -- Story execution context
  self.story = nil
  self.passage_executor = nil

  -- Setup internal event forwarding
  self:setup_event_forwarding()

  return self
end

--- Setup event forwarding from components
function WLS2Integration:setup_event_forwarding()
  local integration = self

  -- Forward thread scheduler events
  self.scheduler:on(function(event, thread)
    if event == thread_scheduler.EVENTS.COMPLETED then
      integration:emit(M.EVENTS.THREAD_OUTPUT, {
        type = "thread_completed",
        thread_id = thread and thread.id,
        thread = thread,
      })
    end
  end)

  -- Forward timer events
  self.timers:on(function(event, block)
    if event == timed_content.EVENTS.FIRED then
      integration:emit(M.EVENTS.TIMER_FIRED, {
        timer_id = block.id,
        content = block.content,
        fire_count = block.fire_count,
      })
    end
  end)

  -- Forward effect events
  self.effects:on(function(event, effect)
    if event == text_effects.EVENTS.UPDATED then
      integration:emit(M.EVENTS.EFFECT_UPDATED, {
        effect_id = effect.id,
        rendered_text = effect.rendered_text,
        opacity = effect.opacity,
        offset_x = effect.offset_x,
        offset_y = effect.offset_y,
        completed = effect.completed,
      })
    end
  end)

  -- Forward external function events
  self.externals:on(function(event, data)
    if event == external_functions.EVENTS.CALLED then
      integration:emit(M.EVENTS.EXTERNAL_CALLED, data)
    end
  end)
end

--- Add an event listener
-- @tparam function callback Listener function(event, data)
function WLS2Integration:on(callback)
  table.insert(self.listeners, callback)
end

--- Remove an event listener
-- @tparam function callback Listener to remove
function WLS2Integration:off(callback)
  for i, listener in ipairs(self.listeners) do
    if listener == callback then
      table.remove(self.listeners, i)
      return
    end
  end
end

--- Emit an event to all listeners
-- @tparam string event Event name
-- @tparam table data Event data
function WLS2Integration:emit(event, data)
  for _, listener in ipairs(self.listeners) do
    listener(event, data)
  end
end

--- Initialize with a story
-- @tparam table story Parsed story data
-- @tparam[opt] function passage_executor Function to execute passages
function WLS2Integration:initialize(story, passage_executor)
  self.story = story
  self.passage_executor = passage_executor

  -- Process audio declarations
  if story.audio_declarations then
    for id, decl in pairs(story.audio_declarations) do
      -- Register audio declarations for use by external functions
      self.externals:register("audio.preload_" .. id, function()
        return decl
      end)
    end
  end

  -- Process effect declarations
  if story.effect_declarations then
    for name, decl in pairs(story.effect_declarations) do
      -- Register custom effect handlers if needed
      if decl.handler then
        self.effects:register_handler(name, decl.handler)
      end
    end
  end

  -- Process external declarations
  if story.external_declarations then
    for name, decl in pairs(story.external_declarations) do
      -- External declarations are registered by host application
      -- Store metadata for validation
      if not self.externals:has(name) then
        -- Register a placeholder that warns if called without implementation
        self.externals:register(name, function()
          error("External function not implemented by host: " .. name)
        end, decl)
      end
    end
  end

  self:emit(M.EVENTS.INITIALIZED, { story = story })
end

--- Register external functions from host application
-- @tparam table functions Map of name -> function
function WLS2Integration:register_externals(functions)
  self.externals:register_all(functions)
end

--- Create the main thread and start execution
-- @tparam string start_passage Starting passage name
-- @treturn string Main thread ID
function WLS2Integration:start(start_passage)
  self.running = true
  self.paused = false

  -- Create main thread
  local main_id = self.scheduler:create_thread(start_passage, {
    is_main = true,
    priority = 10,  -- Main thread has highest priority
  })

  return main_id
end

--- Spawn a new thread
-- @tparam string passage_id Passage to execute
-- @tparam[opt] string parent_id Parent thread ID
-- @tparam[opt] table options Thread options
-- @treturn string New thread ID
function WLS2Integration:spawn_thread(passage_id, parent_id, options)
  options = options or {}
  options.parent_id = parent_id
  return self.scheduler:create_thread(passage_id, options)
end

--- Schedule timed content
-- @tparam number delay Delay in milliseconds
-- @tparam table content Content to deliver
-- @tparam[opt] table options Timer options
-- @treturn string Timer ID
function WLS2Integration:schedule_content(delay, content, options)
  return self.timers:schedule(delay, content, options)
end

--- Schedule repeating content
-- @tparam number interval Interval in milliseconds
-- @tparam table content Content to deliver
-- @tparam[opt] table options Timer options
-- @treturn string Timer ID
function WLS2Integration:schedule_repeat(interval, content, options)
  return self.timers:schedule_repeat(interval, content, options)
end

--- Apply a text effect
-- @tparam string text Text to apply effect to
-- @tparam string effect_name Effect name
-- @tparam[opt] table options Effect options
-- @treturn string Effect ID
function WLS2Integration:apply_effect(text, effect_name, options)
  return self.effects:apply(text, effect_name, options)
end

--- Call an external function
-- @tparam string name Function name
-- @param ... Arguments
-- @return Function result
function WLS2Integration:call_external(name, ...)
  return self.externals:call(name, ...)
end

--- Update the integration by one tick
-- @tparam[opt] number delta_ms Milliseconds since last update (default: tick_rate)
-- @treturn table Update results
function WLS2Integration:tick(delta_ms)
  if not self.running or self.paused then
    return {
      thread_outputs = {},
      timer_content = {},
      effect_states = {},
    }
  end

  delta_ms = delta_ms or self.tick_rate
  self.current_time = self.current_time + delta_ms

  -- Update timers
  local timer_content = self.timers:update(delta_ms)

  -- Update effects
  local effect_states = self.effects:update(delta_ms)

  -- Execute threads
  local thread_outputs = {}
  if self.passage_executor then
    thread_outputs = self.scheduler:step(self.passage_executor)
  end

  local results = {
    thread_outputs = thread_outputs,
    timer_content = timer_content,
    effect_states = effect_states,
    current_time = self.current_time,
  }

  self:emit(M.EVENTS.TICK, results)

  return results
end

--- Run until all threads need input or are complete
-- @tparam[opt] number max_ticks Maximum ticks to execute
-- @treturn table Final state
function WLS2Integration:run_until_blocked(max_ticks)
  max_ticks = max_ticks or 1000
  local tick_count = 0
  local all_outputs = {
    thread_outputs = {},
    timer_content = {},
    effect_states = {},
  }

  while tick_count < max_ticks do
    local results = self:tick()

    -- Accumulate outputs
    for _, output in ipairs(results.thread_outputs) do
      table.insert(all_outputs.thread_outputs, output)
    end
    for _, content in ipairs(results.timer_content) do
      table.insert(all_outputs.timer_content, content)
    end
    for id, state in pairs(results.effect_states) do
      all_outputs.effect_states[id] = state
    end

    -- Check if we should stop
    if self.scheduler:is_complete() then
      break
    end

    -- Check if all threads are waiting for input
    local runnable = self.scheduler:get_runnable_threads()
    if #runnable == 0 then
      break
    end

    tick_count = tick_count + 1
  end

  all_outputs.tick_count = tick_count
  return all_outputs
end

--- Pause execution
function WLS2Integration:pause()
  self.paused = true
  self.timers:pause()
end

--- Resume execution
function WLS2Integration:resume()
  self.paused = false
  self.timers:resume()
end

--- Check if paused
-- @treturn boolean True if paused
function WLS2Integration:is_paused()
  return self.paused
end

--- Check if complete
-- @treturn boolean True if all threads complete
function WLS2Integration:is_complete()
  return self.scheduler:is_complete()
end

--- Check if main thread is complete
-- @treturn boolean True if main thread complete
function WLS2Integration:is_main_complete()
  return self.scheduler:is_main_complete()
end

--- Complete a thread
-- @tparam string thread_id Thread to complete
function WLS2Integration:complete_thread(thread_id)
  self.scheduler:complete_thread(thread_id)
end

--- Set a thread to await another
-- @tparam string thread_id Waiting thread
-- @tparam string await_id Thread to wait for
function WLS2Integration:await_thread(thread_id, await_id)
  self.scheduler:await_thread_completion(thread_id, await_id)
end

--- Get thread by ID
-- @tparam string thread_id Thread ID
-- @treturn table|nil Thread object
function WLS2Integration:get_thread(thread_id)
  return self.scheduler:get_thread(thread_id)
end

--- Get main thread
-- @treturn table|nil Main thread object
function WLS2Integration:get_main_thread()
  return self.scheduler:get_main_thread()
end

--- Get all active threads
-- @treturn table Array of active threads
function WLS2Integration:get_active_threads()
  return self.scheduler:get_active_threads()
end

--- Get integration statistics
-- @treturn table Stats object
function WLS2Integration:get_stats()
  return {
    scheduler = self.scheduler:get_stats(),
    timers = {
      active = #self.timers:get_active_timers(),
      paused = self.timers:is_paused(),
    },
    effects = {
      active = not self.effects:all_complete(),
    },
    externals = self.externals:get_stats(),
    current_time = self.current_time,
    running = self.running,
    paused = self.paused,
  }
end

--- Reset the integration
function WLS2Integration:reset()
  self.scheduler:reset()
  self.timers:reset()
  self.effects:reset()
  self.externals:clear_history()

  self.current_time = 0
  self.running = false
  self.paused = false
  self.story = nil
end

--- Get component managers for direct access
-- @treturn table Map of component managers
function WLS2Integration:get_components()
  return {
    scheduler = self.scheduler,
    timers = self.timers,
    effects = self.effects,
    externals = self.externals,
  }
end

--- Parse a time string (convenience wrapper)
-- @tparam string time_str Time string like "500ms" or "2s"
-- @treturn number Milliseconds
function M.parse_time_string(time_str)
  return timed_content.parse_time_string(time_str)
end

--- Parse an effect declaration (convenience wrapper)
-- @tparam string declaration Effect declaration string
-- @treturn table Parsed effect
function M.parse_effect_declaration(declaration)
  return text_effects.parse_effect_declaration(declaration)
end

--- Thread status constants
M.THREAD_STATUS = thread_scheduler.STATUS

--- Effect types
M.EFFECT_TYPES = text_effects.EFFECTS

return M
