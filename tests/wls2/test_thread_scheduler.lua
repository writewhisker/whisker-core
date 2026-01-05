--- Tests for WLS 2.0 Thread Scheduler
-- @module tests.wls2.test_thread_scheduler

describe("WLS 2.0 Thread Scheduler", function()
  local thread_scheduler

  setup(function()
    thread_scheduler = require("whisker.wls2.thread_scheduler")
  end)

  describe("creation", function()
    it("creates a new scheduler with default options", function()
      local scheduler = thread_scheduler.new()
      assert.is_not_nil(scheduler)
    end)

    it("creates a scheduler with custom max_threads", function()
      local scheduler = thread_scheduler.new({ max_threads = 5 })
      assert.is_not_nil(scheduler)
    end)

    it("creates a scheduler with custom default_priority", function()
      local scheduler = thread_scheduler.new({ default_priority = 10 })
      assert.is_not_nil(scheduler)
    end)

    it("creates a scheduler with round_robin disabled", function()
      local scheduler = thread_scheduler.new({ round_robin = false })
      assert.is_not_nil(scheduler)
    end)
  end)

  describe("thread creation", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("creates a thread and returns its ID", function()
      local id = scheduler:create_thread("start")
      assert.is_string(id)
      assert.matches("^thread_", id)
    end)

    it("creates a thread with custom priority", function()
      local id = scheduler:create_thread("start", { priority = 5 })
      local thread = scheduler:get_thread(id)
      assert.equals(5, thread.priority)
    end)

    it("creates a main thread", function()
      local id = scheduler:create_thread("start", { is_main = true })
      local thread = scheduler:get_thread(id)
      assert.is_true(thread.is_main)
    end)

    it("enforces max thread limit", function()
      local scheduler = thread_scheduler.new({ max_threads = 2 })
      scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")
      assert.has_error(function()
        scheduler:create_thread("passage3")
      end, "Maximum thread limit reached: 2")
    end)

    it("creates child threads with parent_id", function()
      local parent_id = scheduler:create_thread("parent")
      local child_id = scheduler:spawn_thread("child", parent_id)
      local child = scheduler:get_thread(child_id)
      assert.equals(parent_id, child.parent_id)
    end)
  end)

  describe("thread retrieval", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("retrieves a thread by ID", function()
      local id = scheduler:create_thread("passage1")
      local thread = scheduler:get_thread(id)
      assert.is_not_nil(thread)
      assert.equals(id, thread.id)
      assert.equals("passage1", thread.passage)
    end)

    it("returns nil for non-existent thread", function()
      local thread = scheduler:get_thread("nonexistent")
      assert.is_nil(thread)
    end)

    it("retrieves the main thread", function()
      scheduler:create_thread("secondary")
      scheduler:create_thread("main", { is_main = true })
      local main = scheduler:get_main_thread()
      assert.is_not_nil(main)
      assert.is_true(main.is_main)
    end)

    it("returns nil when no main thread exists", function()
      scheduler:create_thread("secondary")
      local main = scheduler:get_main_thread()
      assert.is_nil(main)
    end)

    it("retrieves all threads", function()
      scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")
      scheduler:create_thread("passage3")
      local all = scheduler:get_all_threads()
      assert.equals(3, #all)
    end)
  end)

  describe("thread status", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("creates threads with RUNNING status", function()
      local id = scheduler:create_thread("passage1")
      local thread = scheduler:get_thread(id)
      assert.equals(thread_scheduler.STATUS.RUNNING, thread.status)
    end)

    it("marks threads as completed", function()
      local id = scheduler:create_thread("passage1")
      scheduler:complete_thread(id)
      local thread = scheduler:get_thread(id)
      assert.equals(thread_scheduler.STATUS.COMPLETED, thread.status)
    end)

    it("sets threads to WAITING when awaiting another", function()
      local id1 = scheduler:create_thread("passage1")
      local id2 = scheduler:create_thread("passage2")
      scheduler:await_thread_completion(id1, id2)
      local thread1 = scheduler:get_thread(id1)
      assert.equals(thread_scheduler.STATUS.WAITING, thread1.status)
      assert.equals(id2, thread1.awaiting)
    end)

    it("unblocks waiting threads when awaited thread completes", function()
      local id1 = scheduler:create_thread("passage1")
      local id2 = scheduler:create_thread("passage2")
      scheduler:await_thread_completion(id1, id2)
      scheduler:complete_thread(id2)
      local thread1 = scheduler:get_thread(id1)
      assert.equals(thread_scheduler.STATUS.RUNNING, thread1.status)
      assert.is_nil(thread1.awaiting)
    end)
  end)

  describe("active and runnable threads", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("returns active threads (RUNNING or WAITING)", function()
      scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")
      local id3 = scheduler:create_thread("passage3")
      scheduler:complete_thread(id3)

      local active = scheduler:get_active_threads()
      assert.equals(2, #active)
    end)

    it("returns only runnable threads (RUNNING, not WAITING)", function()
      local id1 = scheduler:create_thread("passage1")
      local id2 = scheduler:create_thread("passage2")
      scheduler:await_thread_completion(id1, id2)

      local runnable = scheduler:get_runnable_threads()
      assert.equals(1, #runnable)
      assert.equals(id2, runnable[1].id)
    end)
  end)

  describe("thread termination", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("terminates a thread by removing it", function()
      local id = scheduler:create_thread("passage1")
      scheduler:terminate_thread(id)
      assert.is_nil(scheduler:get_thread(id))
    end)

    it("handles termination of non-existent thread", function()
      assert.has_no.errors(function()
        scheduler:terminate_thread("nonexistent")
      end)
    end)
  end)

  describe("thread-local variables", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("sets and gets thread-local variables", function()
      local id = scheduler:create_thread("passage1")
      scheduler:set_thread_local(id, "count", 42)
      local value = scheduler:get_thread_local(id, "count")
      assert.equals(42, value)
    end)

    it("returns nil for non-existent variable", function()
      local id = scheduler:create_thread("passage1")
      local value = scheduler:get_thread_local(id, "nonexistent")
      assert.is_nil(value)
    end)

    it("returns nil for non-existent thread", function()
      local value = scheduler:get_thread_local("nonexistent", "var")
      assert.is_nil(value)
    end)

    it("isolates variables between threads", function()
      local id1 = scheduler:create_thread("passage1")
      local id2 = scheduler:create_thread("passage2")
      scheduler:set_thread_local(id1, "count", 10)
      scheduler:set_thread_local(id2, "count", 20)
      assert.equals(10, scheduler:get_thread_local(id1, "count"))
      assert.equals(20, scheduler:get_thread_local(id2, "count"))
    end)
  end)

  describe("completion checking", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("returns false when threads are active", function()
      scheduler:create_thread("passage1")
      assert.is_false(scheduler:is_complete())
    end)

    it("returns true when all threads are completed", function()
      local id1 = scheduler:create_thread("passage1")
      local id2 = scheduler:create_thread("passage2")
      scheduler:complete_thread(id1)
      scheduler:complete_thread(id2)
      assert.is_true(scheduler:is_complete())
    end)

    it("checks main thread completion", function()
      local main_id = scheduler:create_thread("main", { is_main = true })
      scheduler:create_thread("secondary")
      assert.is_false(scheduler:is_main_complete())
      scheduler:complete_thread(main_id)
      assert.is_true(scheduler:is_main_complete())
    end)

    it("returns true for main complete when no main thread", function()
      scheduler:create_thread("secondary")
      assert.is_true(scheduler:is_main_complete())
    end)
  end)

  describe("scheduling", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("returns nil when no runnable threads", function()
      local id = scheduler:create_thread("passage1")
      scheduler:complete_thread(id)
      local next_thread = scheduler:get_next_thread()
      assert.is_nil(next_thread)
    end)

    it("uses round-robin scheduling by default", function()
      scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")
      local first = scheduler:get_next_thread()
      local second = scheduler:get_next_thread()
      assert.is_not_nil(first)
      assert.is_not_nil(second)
    end)

    it("uses priority scheduling when round_robin is false", function()
      local scheduler = thread_scheduler.new({ round_robin = false })
      scheduler:create_thread("low", { priority = 1 })
      scheduler:create_thread("high", { priority = 10 })
      scheduler:create_thread("medium", { priority = 5 })

      local next_thread = scheduler:get_next_thread()
      assert.equals(10, next_thread.priority)
    end)
  end)

  describe("step execution", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("executes a step for all runnable threads", function()
      scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")

      local executor = function(thread)
        return { { type = "text", content = "from " .. thread.passage } }
      end

      local outputs = scheduler:step(executor)
      assert.equals(2, #outputs)
    end)

    it("returns thread_id with each output", function()
      local id = scheduler:create_thread("passage1")
      local executor = function()
        return { { type = "text" } }
      end

      local outputs = scheduler:step(executor)
      assert.equals(1, #outputs)
      assert.equals(id, outputs[1].thread_id)
    end)
  end)

  describe("output interleaving", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new()
    end)

    it("interleaves output from multiple threads", function()
      local outputs = {
        { thread_id = "t1", content = { { text = "a" }, { text = "b" } } },
        { thread_id = "t2", content = { { text = "c" } } },
      }

      local result = scheduler:interleave_output(outputs)
      assert.equals(3, #result)
    end)
  end)

  describe("events", function()
    local scheduler
    local events

    before_each(function()
      scheduler = thread_scheduler.new()
      events = {}
      scheduler:on(function(event, thread)
        table.insert(events, { event = event, thread = thread })
      end)
    end)

    it("emits CREATED event on thread creation", function()
      scheduler:create_thread("passage1")
      assert.equals(1, #events)
      assert.equals(thread_scheduler.EVENTS.CREATED, events[1].event)
    end)

    it("emits COMPLETED event on thread completion", function()
      local id = scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")  -- Create second thread so ALL_COMPLETE isn't triggered
      scheduler:complete_thread(id)
      assert.equals(3, #events)  -- CREATED + CREATED + COMPLETED
      assert.equals(thread_scheduler.EVENTS.COMPLETED, events[3].event)
    end)

    it("emits ALL_COMPLETE when all threads complete", function()
      local id = scheduler:create_thread("passage1")
      scheduler:complete_thread(id)
      assert.equals(3, #events)  -- CREATED + COMPLETED + ALL_COMPLETE
      assert.equals(thread_scheduler.EVENTS.ALL_COMPLETE, events[3].event)
    end)

    it("removes listeners with off()", function()
      local callback = function() end
      scheduler:on(callback)
      scheduler:off(callback)
      -- No assertion needed - just verify no errors
    end)
  end)

  describe("statistics", function()
    local scheduler

    before_each(function()
      scheduler = thread_scheduler.new({ max_threads = 5 })
    end)

    it("returns correct stats", function()
      local id1 = scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")
      scheduler:complete_thread(id1)

      local stats = scheduler:get_stats()
      assert.equals(2, stats.total_threads)
      assert.equals(1, stats.active_threads)
      assert.equals(1, stats.completed_threads)
      assert.equals(5, stats.max_threads)
    end)
  end)

  describe("reset", function()
    it("clears all threads", function()
      local scheduler = thread_scheduler.new()
      scheduler:create_thread("passage1")
      scheduler:create_thread("passage2")
      scheduler:reset()
      local all = scheduler:get_all_threads()
      assert.equals(0, #all)
    end)
  end)
end)
