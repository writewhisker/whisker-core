-- lib/whisker/threads/thread_scheduler.lua
-- Thread scheduler with hook operation support

local ThreadScheduler = {}
ThreadScheduler.__index = ThreadScheduler

--- Create a new ThreadScheduler instance
-- @param engine Engine instance for hook operations
-- @return ThreadScheduler instance
function ThreadScheduler.new(engine)
  local self = setmetatable({}, ThreadScheduler)
  self.engine = engine
  self.threads = {}
  return self
end

--- Parse hook operations from thread content
-- @param content string Thread content
-- @return table Array of operations
function ThreadScheduler:parse_hook_operations(content)
  local operations = {}
  
  -- Pattern: @operation: target { content }
  for operation, target, op_content in content:gmatch("@(%w+):%s*(%w+)%s*{([^}]*)}") do
    if operation == "replace" or operation == "append" or operation == "prepend" or 
       operation == "show" or operation == "hide" then
      table.insert(operations, {
        operation = operation,
        target = target,
        content = op_content
      })
    end
  end
  
  return operations
end

--- Execute hook operations during thread step
-- @param thread table Thread object
function ThreadScheduler:execute_thread_step(thread)
  if not thread or not thread.content then
    return
  end
  
  -- Get current content for this step
  local step_content = thread.content[thread.current_step]
  
  if not step_content then
    return
  end
  
  -- Parse and execute hook operations
  local hook_ops = self:parse_hook_operations(step_content)
  
  for _, op in ipairs(hook_ops) do
    if self.engine then
      local success, err = self.engine:execute_hook_operation(
        op.operation,
        op.target,
        op.content
      )
      
      if not success and err then
        print("Hook operation failed in thread: " .. err)
      end
    end
  end
end

--- Register a new thread
-- @param name string Thread name
-- @param interval number Interval in seconds
-- @param content table Array of step contents
function ThreadScheduler:register_thread(name, interval, content)
  self.threads[name] = {
    name = name,
    interval = interval,
    content = content,
    current_step = 1,
    elapsed = 0
  }
end

--- Update all active threads
-- @param delta_time number Time elapsed since last update
function ThreadScheduler:update(delta_time)
  for name, thread in pairs(self.threads) do
    thread.elapsed = thread.elapsed + delta_time
    
    if thread.elapsed >= thread.interval then
      thread.elapsed = 0
      self:execute_thread_step(thread)
      
      -- Move to next step (loop if at end)
      thread.current_step = thread.current_step + 1
      if thread.current_step > #thread.content then
        thread.current_step = 1
      end
    end
  end
end

--- Clear all threads
function ThreadScheduler:clear()
  self.threads = {}
end

return ThreadScheduler
