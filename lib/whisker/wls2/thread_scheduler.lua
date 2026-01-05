--- WLS 2.0 Thread Scheduler
-- Manages parallel narrative threads with priority-based scheduling.
--
-- @module whisker.wls2.thread_scheduler
-- @author Whisker Team
-- @license MIT

local M = {}

-- Dependencies for DI pattern
M._dependencies = {}

--- Thread status values
M.STATUS = {
  RUNNING = "running",
  WAITING = "waiting",
  COMPLETED = "completed",
  ERROR = "error",
}

--- Thread event types
M.EVENTS = {
  CREATED = "threadCreated",
  COMPLETED = "threadCompleted",
  ERROR = "threadError",
  ALL_COMPLETE = "allComplete",
}

--- Generate a unique thread ID
local function generate_id()
  return string.format("thread_%d_%d", os.time(), math.random(10000, 99999))
end

--- Create a new thread
-- @tparam string passage_id The passage to start from
-- @tparam[opt] table options Thread options
-- @treturn table Thread object
local function create_thread(passage_id, options)
  options = options or {}
  return {
    id = generate_id(),
    passage = passage_id,
    status = M.STATUS.RUNNING,
    priority = options.priority or 0,
    is_main = options.is_main or false,
    parent_id = options.parent_id,
    content_index = 0,
    local_variables = {},
    awaiting = nil,  -- Thread ID we're waiting for
    error = nil,
    created_at = os.time(),
  }
end

--- Thread Scheduler class
-- @type ThreadScheduler
local ThreadScheduler = {}
ThreadScheduler.__index = ThreadScheduler

--- Create a new ThreadScheduler
-- @tparam[opt] table options Scheduler options
-- @tparam[opt] table deps Injected dependencies (unused, for DI compatibility)
-- @treturn ThreadScheduler New scheduler instance
function M.new(options, deps)
  options = options or {}
  -- deps parameter for DI compatibility (currently unused)
  local self = setmetatable({}, ThreadScheduler)

  self.threads = {}
  self.max_threads = options.max_threads or 10
  self.default_priority = options.default_priority or 0
  self.round_robin = options.round_robin ~= false
  self.current_index = 0
  self.listeners = {}

  return self
end

--- Reset the scheduler
function ThreadScheduler:reset()
  self.threads = {}
  self.current_index = 0
end

--- Add an event listener
-- @tparam function callback Listener function(event, thread)
function ThreadScheduler:on(callback)
  table.insert(self.listeners, callback)
end

--- Remove an event listener
-- @tparam function callback Listener to remove
function ThreadScheduler:off(callback)
  for i, listener in ipairs(self.listeners) do
    if listener == callback then
      table.remove(self.listeners, i)
      return
    end
  end
end

--- Emit an event to all listeners
-- @tparam string event Event name
-- @tparam[opt] table thread Thread involved
function ThreadScheduler:emit(event, thread)
  for _, listener in ipairs(self.listeners) do
    listener(event, thread)
  end
end

--- Create a new thread
-- @tparam string passage_id Starting passage
-- @tparam[opt] table options Thread options
-- @treturn string Thread ID
function ThreadScheduler:create_thread(passage_id, options)
  if #self.threads >= self.max_threads then
    error("Maximum thread limit reached: " .. self.max_threads)
  end

  options = options or {}
  if options.priority == nil then
    options.priority = self.default_priority
  end

  local thread = create_thread(passage_id, options)
  table.insert(self.threads, thread)

  self:emit(M.EVENTS.CREATED, thread)

  return thread.id
end

--- Spawn a child thread from an existing thread
-- @tparam string passage_id Starting passage
-- @tparam[opt] string parent_id Parent thread ID
-- @treturn string New thread ID
function ThreadScheduler:spawn_thread(passage_id, parent_id)
  return self:create_thread(passage_id, {
    parent_id = parent_id,
    priority = self.default_priority,
  })
end

--- Get a thread by ID
-- @tparam string thread_id Thread ID
-- @treturn table|nil Thread object or nil
function ThreadScheduler:get_thread(thread_id)
  for _, thread in ipairs(self.threads) do
    if thread.id == thread_id then
      return thread
    end
  end
  return nil
end

--- Get the main thread
-- @treturn table|nil Main thread or nil
function ThreadScheduler:get_main_thread()
  for _, thread in ipairs(self.threads) do
    if thread.is_main then
      return thread
    end
  end
  return nil
end

--- Get all threads
-- @treturn table Array of all threads
function ThreadScheduler:get_all_threads()
  return self.threads
end

--- Get active (running or waiting) threads
-- @treturn table Array of active threads
function ThreadScheduler:get_active_threads()
  local active = {}
  for _, thread in ipairs(self.threads) do
    if thread.status == M.STATUS.RUNNING or thread.status == M.STATUS.WAITING then
      table.insert(active, thread)
    end
  end
  return active
end

--- Get runnable threads (running, not waiting)
-- @treturn table Array of runnable threads
function ThreadScheduler:get_runnable_threads()
  local runnable = {}
  for _, thread in ipairs(self.threads) do
    if thread.status == M.STATUS.RUNNING then
      table.insert(runnable, thread)
    end
  end
  return runnable
end

--- Mark a thread as completed
-- @tparam string thread_id Thread to complete
function ThreadScheduler:complete_thread(thread_id)
  local thread = self:get_thread(thread_id)
  if thread then
    thread.status = M.STATUS.COMPLETED
    self:emit(M.EVENTS.COMPLETED, thread)

    -- Unblock any threads waiting for this one
    for _, t in ipairs(self.threads) do
      if t.awaiting == thread_id then
        t.awaiting = nil
        t.status = M.STATUS.RUNNING
      end
    end

    -- Check if all threads are now complete
    if self:is_complete() then
      self:emit(M.EVENTS.ALL_COMPLETE, nil)
    end
  end
end

--- Mark a thread as awaiting another thread
-- @tparam string thread_id Thread that is waiting
-- @tparam string await_id Thread being waited for
function ThreadScheduler:await_thread_completion(thread_id, await_id)
  local thread = self:get_thread(thread_id)
  local awaited = self:get_thread(await_id)

  if thread and awaited then
    if awaited.status == M.STATUS.COMPLETED or awaited.status == M.STATUS.ERROR then
      -- Already complete, no need to wait
      return
    end

    thread.awaiting = await_id
    thread.status = M.STATUS.WAITING
  end
end

--- Terminate a thread
-- @tparam string thread_id Thread to terminate
function ThreadScheduler:terminate_thread(thread_id)
  for i, thread in ipairs(self.threads) do
    if thread.id == thread_id then
      table.remove(self.threads, i)
      return
    end
  end
end

--- Set a thread-local variable
-- @tparam string thread_id Thread ID
-- @tparam string name Variable name
-- @param value Variable value
function ThreadScheduler:set_thread_local(thread_id, name, value)
  local thread = self:get_thread(thread_id)
  if thread then
    thread.local_variables[name] = value
  end
end

--- Get a thread-local variable
-- @tparam string thread_id Thread ID
-- @tparam string name Variable name
-- @return Variable value or nil
function ThreadScheduler:get_thread_local(thread_id, name)
  local thread = self:get_thread(thread_id)
  if thread then
    return thread.local_variables[name]
  end
  return nil
end

--- Check if all threads are complete
-- @treturn boolean True if all threads are complete
function ThreadScheduler:is_complete()
  for _, thread in ipairs(self.threads) do
    if thread.status ~= M.STATUS.COMPLETED and thread.status ~= M.STATUS.ERROR then
      return false
    end
  end
  return #self.threads > 0
end

--- Check if the main thread is complete
-- @treturn boolean True if main thread is complete
function ThreadScheduler:is_main_complete()
  local main = self:get_main_thread()
  if main then
    return main.status == M.STATUS.COMPLETED or main.status == M.STATUS.ERROR
  end
  return true
end

--- Get next thread to execute based on scheduling policy
-- @treturn table|nil Next thread to run
function ThreadScheduler:get_next_thread()
  local runnable = self:get_runnable_threads()
  if #runnable == 0 then
    return nil
  end

  if self.round_robin then
    -- Round-robin scheduling
    self.current_index = (self.current_index % #runnable) + 1
    return runnable[self.current_index]
  else
    -- Priority-based scheduling (higher priority first)
    table.sort(runnable, function(a, b)
      return a.priority > b.priority
    end)
    return runnable[1]
  end
end

--- Execute one step for all active threads
-- @tparam function executor Function(thread) -> content array
-- @treturn table Array of ThreadOutput results
function ThreadScheduler:step(executor)
  local outputs = {}
  local runnable = self:get_runnable_threads()

  for _, thread in ipairs(runnable) do
    local content = executor(thread)
    table.insert(outputs, {
      thread_id = thread.id,
      content = content or {},
    })
  end

  return outputs
end

--- Interleave output from multiple threads
-- @tparam table outputs Array of ThreadOutput
-- @treturn table Interleaved content array
function ThreadScheduler:interleave_output(outputs)
  local result = {}
  for _, output in ipairs(outputs) do
    for _, content in ipairs(output.content) do
      table.insert(result, content)
    end
  end
  return result
end

--- Get scheduler statistics
-- @treturn table Stats object
function ThreadScheduler:get_stats()
  local completed = 0
  local active = 0

  for _, thread in ipairs(self.threads) do
    if thread.status == M.STATUS.COMPLETED then
      completed = completed + 1
    elseif thread.status == M.STATUS.RUNNING or thread.status == M.STATUS.WAITING then
      active = active + 1
    end
  end

  return {
    total_threads = #self.threads,
    active_threads = active,
    completed_threads = completed,
    max_threads = self.max_threads,
  }
end

return M
