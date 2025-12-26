--- Tests for CLI Progress Bar
-- @module tests.unit.cli.test_progress

describe("CLI Progress Bar", function()
  local Progress

  setup(function()
    Progress = require("whisker.cli.progress")
  end)

  describe("new", function()
    it("creates progress bar with default options", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      assert.is_not_nil(progress)
      assert.equals(10, progress._total)
      assert.equals(0, progress._current)
      assert.equals(40, progress._width)
      assert.is_true(progress._show_eta)
    end)

    it("creates progress bar with custom options", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 100, {
        width = 60,
        show_eta = false
      })

      assert.equals(100, progress._total)
      assert.equals(60, progress._width)
      assert.is_false(progress._show_eta)
    end)

    it("uses default console when not provided", function()
      local progress = Progress.new({}, 5)

      assert.is_not_nil(progress._console)
      assert.is_function(progress._console.write)
      assert.is_function(progress._console.print)
    end)
  end)

  describe("update", function()
    it("updates current progress value", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:update(5)
      assert.equals(5, progress._current)

      progress:update(8)
      assert.equals(8, progress._current)
    end)

    it("stores message when provided", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:update(1, "Processing file 1")

      assert.equals(1, #progress._items)
      assert.equals(1, progress._items[1].index)
      assert.equals("Processing file 1", progress._items[1].message)
    end)

    it("calls render after update", function()
      local rendered = false
      local console = {
        write = function() rendered = true end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:update(3)
      assert.is_true(rendered)
    end)
  end)

  describe("increment", function()
    it("increments progress by one", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:increment()
      assert.equals(1, progress._current)

      progress:increment()
      assert.equals(2, progress._current)
    end)

    it("stores message when incrementing", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:increment("Item 1 done")
      progress:increment("Item 2 done")

      assert.equals(2, #progress._items)
      assert.equals("Item 1 done", progress._items[1].message)
      assert.equals("Item 2 done", progress._items[2].message)
    end)
  end)

  describe("render", function()
    it("writes progress bar to console", function()
      local output = nil
      local console = {
        write = function(_, text) output = text end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10, {
        show_eta = false
      })

      progress:update(5)

      assert.is_not_nil(output)
      assert.matches("50%%", output)
      assert.matches("5/10", output)
    end)

    it("shows correct percentage at 0%", function()
      local output = nil
      local console = {
        write = function(_, text) output = text end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10, {show_eta = false})

      progress:render()

      assert.matches("0%%", output)
      assert.matches("0/10", output)
    end)

    it("shows correct percentage at 100%", function()
      local output = nil
      local console = {
        write = function(_, text) output = text end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10, {show_eta = false})

      progress:update(10)

      assert.matches("100%%", output)
      assert.matches("10/10", output)
    end)

    it("handles zero total gracefully", function()
      local output = nil
      local console = {
        write = function(_, text) output = text end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 0, {show_eta = false})

      progress:render()

      assert.matches("0%%", output)
    end)
  end)

  describe("finish", function()
    it("sets progress to 100%", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:update(5)
      progress:finish()

      assert.equals(10, progress._current)
    end)

    it("prints newline after finishing", function()
      local print_called = false
      local console = {
        write = function() end,
        print = function() print_called = true end
      }
      local progress = Progress.new({console = console}, 10)

      progress:finish()

      assert.is_true(print_called)
    end)

    it("prints completion message if provided", function()
      local messages = {}
      local console = {
        write = function() end,
        print = function(_, text) table.insert(messages, text) end
      }
      local progress = Progress.new({console = console}, 10)

      progress:finish("All done!")

      assert.equals(2, #messages)  -- newline + message
      assert.equals("All done!", messages[2])
    end)
  end)

  describe("get_elapsed", function()
    it("returns elapsed time in seconds", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      local elapsed = progress:get_elapsed()

      assert.is_number(elapsed)
      assert.is_true(elapsed >= 0)
    end)
  end)

  describe("get_percentage", function()
    it("returns percentage from 0 to 100", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      assert.equals(0, progress:get_percentage())

      progress:update(5)
      assert.equals(50, progress:get_percentage())

      progress:update(10)
      assert.equals(100, progress:get_percentage())
    end)

    it("returns 0 when total is 0", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 0)

      assert.equals(0, progress:get_percentage())
    end)
  end)

  describe("is_complete", function()
    it("returns false when not complete", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      assert.is_false(progress:is_complete())

      progress:update(5)
      assert.is_false(progress:is_complete())
    end)

    it("returns true when complete", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:update(10)
      assert.is_true(progress:is_complete())
    end)

    it("returns true after finish", function()
      local console = {
        write = function() end,
        print = function() end
      }
      local progress = Progress.new({console = console}, 10)

      progress:finish()
      assert.is_true(progress:is_complete())
    end)
  end)
end)
