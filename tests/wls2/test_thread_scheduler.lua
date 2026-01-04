-- spec/wls2/thread_scheduler_spec.lua
-- Tests for WLS 2.0 Thread Scheduler

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("ThreadScheduler", function()
    local ThreadScheduler

    before_each(function()
        ThreadScheduler = require("whisker.wls2.thread_scheduler")
    end)

    describe("constants", function()
        it("defines thread states", function()
            assert.equals("running", ThreadScheduler.STATE.RUNNING)
            assert.equals("waiting", ThreadScheduler.STATE.WAITING)
            assert.equals("paused", ThreadScheduler.STATE.PAUSED)
            assert.equals("completed", ThreadScheduler.STATE.COMPLETED)
            assert.equals("cancelled", ThreadScheduler.STATE.CANCELLED)
        end)
    end)

    describe("scheduler", function()
        local scheduler

        before_each(function()
            scheduler = ThreadScheduler.new()
        end)

        it("creates a new scheduler", function()
            assert.is_not_nil(scheduler)
        end)

        it("creates main thread", function()
            local threadId = scheduler:createThread("Start")
            assert.is_not_nil(threadId)

            local thread = scheduler:getThread(threadId)
            assert.equals("Start", thread.passage)
            assert.is_true(thread.isMain)
            assert.equals(ThreadScheduler.STATE.RUNNING, thread.state)
        end)

        it("gets main thread", function()
            local threadId = scheduler:createThread("Start")
            local mainThread = scheduler:getMainThread()

            assert.is_not_nil(mainThread)
            assert.equals(threadId, mainThread.id)
        end)

        it("spawns child thread", function()
            local mainId = scheduler:createThread("Start")
            local childId = scheduler:spawnThread("Background", mainId)

            local child = scheduler:getThread(childId)
            assert.equals("Background", child.passage)
            assert.equals(mainId, child.parentId)
            assert.equals(ThreadScheduler.STATE.RUNNING, child.state)

            -- Parent should track child
            local main = scheduler:getThread(mainId)
            assert.equals(1, #main.children)
            assert.equals(childId, main.children[1])
        end)

        it("throws for invalid parent", function()
            assert.has_error(function()
                scheduler:spawnThread("Child", "nonexistent")
            end)
        end)

        it("spawns with priority", function()
            local mainId = scheduler:createThread("Start")
            local highId = scheduler:spawnThread("High", mainId, 10)
            local lowId = scheduler:spawnThread("Low", mainId, 1)

            local runnable = scheduler:getRunnableThreads()
            assert.equals(3, #runnable)
            -- Highest priority first
            assert.equals(highId, runnable[1].id)
        end)

        it("pauses and resumes thread", function()
            local threadId = scheduler:createThread("Start")

            scheduler:pauseThread(threadId)
            local thread = scheduler:getThread(threadId)
            assert.equals(ThreadScheduler.STATE.PAUSED, thread.state)

            scheduler:resumeThread(threadId)
            thread = scheduler:getThread(threadId)
            assert.equals(ThreadScheduler.STATE.RUNNING, thread.state)
        end)

        it("completes thread with result", function()
            local threadId = scheduler:createThread("Start")

            scheduler:completeThread(threadId, "done")
            local thread = scheduler:getThread(threadId)
            assert.equals(ThreadScheduler.STATE.COMPLETED, thread.state)
            assert.equals("done", thread.result)
        end)

        it("cancels thread and children", function()
            local mainId = scheduler:createThread("Start")
            local childId = scheduler:spawnThread("Child", mainId)
            local grandchildId = scheduler:spawnThread("Grandchild", childId)

            scheduler:cancelThread(mainId)

            assert.equals(ThreadScheduler.STATE.CANCELLED, scheduler:getThread(mainId).state)
            assert.equals(ThreadScheduler.STATE.CANCELLED, scheduler:getThread(childId).state)
            assert.equals(ThreadScheduler.STATE.CANCELLED, scheduler:getThread(grandchildId).state)
        end)

        it("awaits thread completion", function()
            local mainId = scheduler:createThread("Start")
            local childId = scheduler:spawnThread("Child", mainId)

            scheduler:awaitThread(mainId, childId)
            local main = scheduler:getThread(mainId)
            assert.equals(ThreadScheduler.STATE.WAITING, main.state)
            assert.equals(childId, main.waitingFor)

            -- Complete the child
            scheduler:completeThread(childId, "result")

            -- Main should be running again
            main = scheduler:getThread(mainId)
            assert.equals(ThreadScheduler.STATE.RUNNING, main.state)
            assert.is_nil(main.waitingFor)
        end)

        it("sets and gets thread variables", function()
            local threadId = scheduler:createThread("Start")

            scheduler:setThreadVariable(threadId, "count", 42)
            local value = scheduler:getThreadVariable(threadId, "count")
            assert.equals(42, value)

            -- Non-existent variable
            assert.is_nil(scheduler:getThreadVariable(threadId, "missing"))
        end)

        it("steps execution", function()
            local mainId = scheduler:createThread("Start")
            scheduler:spawnThread("Child1", mainId, 1)
            scheduler:spawnThread("Child2", mainId, 2)

            local stepResults = scheduler:step(function(thread)
                return {"output from " .. thread.passage}
            end)

            -- Should have results from all 3 runnable threads
            assert.equals(3, #stepResults)
        end)

        it("checks completion status", function()
            local mainId = scheduler:createThread("Start")
            assert.is_false(scheduler:isComplete())

            scheduler:completeThread(mainId)
            assert.is_true(scheduler:isComplete())
        end)

        it("gets thread counts by state", function()
            local mainId = scheduler:createThread("Start")
            scheduler:spawnThread("Running", mainId)
            local pausedId = scheduler:spawnThread("Paused", mainId)
            local completedId = scheduler:spawnThread("Completed", mainId)

            scheduler:pauseThread(pausedId)
            scheduler:completeThread(completedId)

            local counts = scheduler:getThreadCounts()
            assert.equals(2, counts[ThreadScheduler.STATE.RUNNING])
            assert.equals(1, counts[ThreadScheduler.STATE.PAUSED])
            assert.equals(1, counts[ThreadScheduler.STATE.COMPLETED])
        end)

        it("clears all threads", function()
            scheduler:createThread("Start")
            assert.is_not_nil(scheduler:getMainThread())

            scheduler:clear()
            assert.is_nil(scheduler:getMainThread())
        end)
    end)
end)
