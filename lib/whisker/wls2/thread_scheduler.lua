--- Thread Scheduler for WLS 2.0
--- Enables parallel narrative execution with multiple threads
--- @module whisker.wls2.thread_scheduler

local ThreadScheduler = {
    _VERSION = "2.0.0"
}
ThreadScheduler.__index = ThreadScheduler
ThreadScheduler._dependencies = {}

--- Thread states
ThreadScheduler.STATE = {
    RUNNING = "running",
    WAITING = "waiting",
    PAUSED = "paused",
    COMPLETED = "completed",
    CANCELLED = "cancelled"
}

--- Generate a unique thread ID
local _thread_counter = 0
local function generate_thread_id()
    _thread_counter = _thread_counter + 1
    return "thread_" .. _thread_counter
end

--- Create a new Thread object
--- @param passage string Starting passage name
--- @param parent_id string|nil Parent thread ID
--- @param priority number Thread priority (higher = runs first)
--- @return table Thread object
local function create_thread(passage, parent_id, priority)
    return {
        id = generate_thread_id(),
        passage = passage,
        parentId = parent_id,
        children = {},
        state = ThreadScheduler.STATE.RUNNING,
        priority = priority or 0,
        variables = {},      -- Thread-local variables
        waitingFor = nil,    -- Thread ID we're waiting for
        result = nil,        -- Result value when completed
        createdAt = os.time()
    }
end

--- Create a new ThreadScheduler
--- @param deps table Optional dependencies
--- @return ThreadScheduler The new scheduler instance
function ThreadScheduler.new(deps)
    local self = setmetatable({}, ThreadScheduler)
    self._threads = {}       -- id -> thread
    self._mainThread = nil   -- Main thread ID
    self._deps = deps or {}
    return self
end

--- Create a factory function for DI
--- @param deps table Dependencies
--- @return function Factory function
function ThreadScheduler.create(deps)
    return function(config)
        return ThreadScheduler.new(deps)
    end
end

--- Create the main thread
--- @param passage string Starting passage name
--- @return string Thread ID
function ThreadScheduler:createThread(passage)
    local thread = create_thread(passage, nil, 0)
    thread.isMain = true
    self._threads[thread.id] = thread
    self._mainThread = thread.id
    return thread.id
end

--- Spawn a child thread from a parent
--- @param passage string Starting passage name
--- @param parentId string Parent thread ID
--- @param priority number|nil Thread priority
--- @return string New thread ID
function ThreadScheduler:spawnThread(passage, parentId, priority)
    local parent = self._threads[parentId]
    if not parent then
        error("Parent thread not found: " .. tostring(parentId))
    end

    local thread = create_thread(passage, parentId, priority or 0)
    self._threads[thread.id] = thread

    -- Add to parent's children
    table.insert(parent.children, thread.id)

    return thread.id
end

--- Get a thread by ID
--- @param threadId string Thread ID
--- @return table|nil Thread object or nil
function ThreadScheduler:getThread(threadId)
    return self._threads[threadId]
end

--- Get the main thread
--- @return table|nil Main thread or nil
function ThreadScheduler:getMainThread()
    if self._mainThread then
        return self._threads[self._mainThread]
    end
    return nil
end

--- Get all threads
--- @return table Map of thread IDs to threads
function ThreadScheduler:getAllThreads()
    return self._threads
end

--- Get runnable threads sorted by priority
--- @return table Array of runnable threads
function ThreadScheduler:getRunnableThreads()
    local runnable = {}

    for _, thread in pairs(self._threads) do
        if thread.state == ThreadScheduler.STATE.RUNNING then
            table.insert(runnable, thread)
        end
    end

    -- Sort by priority (highest first)
    table.sort(runnable, function(a, b)
        return a.priority > b.priority
    end)

    return runnable
end

--- Set a thread's state
--- @param threadId string Thread ID
--- @param state string New state
function ThreadScheduler:setThreadState(threadId, state)
    local thread = self._threads[threadId]
    if thread then
        thread.state = state
    end
end

--- Pause a thread
--- @param threadId string Thread ID
function ThreadScheduler:pauseThread(threadId)
    self:setThreadState(threadId, ThreadScheduler.STATE.PAUSED)
end

--- Resume a thread
--- @param threadId string Thread ID
function ThreadScheduler:resumeThread(threadId)
    local thread = self._threads[threadId]
    if thread and thread.state == ThreadScheduler.STATE.PAUSED then
        thread.state = ThreadScheduler.STATE.RUNNING
    end
end

--- Complete a thread with a result
--- @param threadId string Thread ID
--- @param result any Result value
function ThreadScheduler:completeThread(threadId, result)
    local thread = self._threads[threadId]
    if not thread then return end

    thread.state = ThreadScheduler.STATE.COMPLETED
    thread.result = result

    -- Resume any threads waiting for this one
    for _, t in pairs(self._threads) do
        if t.waitingFor == threadId then
            t.waitingFor = nil
            t.state = ThreadScheduler.STATE.RUNNING
        end
    end
end

--- Cancel a thread and its children
--- @param threadId string Thread ID
function ThreadScheduler:cancelThread(threadId)
    local thread = self._threads[threadId]
    if not thread then return end

    thread.state = ThreadScheduler.STATE.CANCELLED

    -- Cancel all children recursively
    for _, childId in ipairs(thread.children) do
        self:cancelThread(childId)
    end
end

--- Make a thread wait for another thread
--- @param waiterId string Thread that will wait
--- @param targetId string Thread to wait for
function ThreadScheduler:awaitThread(waiterId, targetId)
    local waiter = self._threads[waiterId]
    local target = self._threads[targetId]

    if not waiter or not target then
        error("Invalid thread IDs for await")
    end

    if target.state == ThreadScheduler.STATE.COMPLETED then
        -- Already done, don't wait
        return target.result
    end

    waiter.state = ThreadScheduler.STATE.WAITING
    waiter.waitingFor = targetId
    return nil
end

--- Set a thread-local variable
--- @param threadId string Thread ID
--- @param name string Variable name
--- @param value any Variable value
function ThreadScheduler:setThreadVariable(threadId, name, value)
    local thread = self._threads[threadId]
    if thread then
        thread.variables[name] = value
    end
end

--- Get a thread-local variable
--- @param threadId string Thread ID
--- @param name string Variable name
--- @return any Variable value or nil
function ThreadScheduler:getThreadVariable(threadId, name)
    local thread = self._threads[threadId]
    if thread then
        return thread.variables[name]
    end
    return nil
end

--- Step the scheduler - execute one step for each runnable thread
--- @param executor function Function to execute thread step: (thread) -> outputs[]
--- @return table Array of {threadId, outputs} for each stepped thread
function ThreadScheduler:step(executor)
    local results = {}
    local runnable = self:getRunnableThreads()

    for _, thread in ipairs(runnable) do
        local outputs = executor(thread)
        table.insert(results, {
            threadId = thread.id,
            outputs = outputs or {}
        })
    end

    return results
end

--- Check if all threads are complete
--- @return boolean True if all threads are completed or cancelled
function ThreadScheduler:isComplete()
    for _, thread in pairs(self._threads) do
        if thread.state == ThreadScheduler.STATE.RUNNING or
           thread.state == ThreadScheduler.STATE.WAITING or
           thread.state == ThreadScheduler.STATE.PAUSED then
            return false
        end
    end
    return true
end

--- Get count of threads by state
--- @return table Map of state -> count
function ThreadScheduler:getThreadCounts()
    local counts = {
        [ThreadScheduler.STATE.RUNNING] = 0,
        [ThreadScheduler.STATE.WAITING] = 0,
        [ThreadScheduler.STATE.PAUSED] = 0,
        [ThreadScheduler.STATE.COMPLETED] = 0,
        [ThreadScheduler.STATE.CANCELLED] = 0
    }

    for _, thread in pairs(self._threads) do
        counts[thread.state] = (counts[thread.state] or 0) + 1
    end

    return counts
end

--- Clear all threads
function ThreadScheduler:clear()
    self._threads = {}
    self._mainThread = nil
end

return ThreadScheduler
