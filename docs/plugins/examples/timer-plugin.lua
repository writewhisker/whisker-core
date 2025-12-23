--- Timer Plugin Example
-- Tracks time spent in story and passages
-- @module examples.timer-plugin

local plugin = {
  ctx = nil,
  start_time = nil,
  passage_times = {},
  current_passage = nil,
  passage_start = nil,
}

return {
  name = "timer",
  version = "1.0.0",
  author = "whisker-core",
  description = "Tracks time spent in story",
  license = "MIT",

  capabilities = {
    "persistence:read",
    "persistence:write",
  },

  on_init = function(ctx)
    plugin.ctx = ctx
    ctx.log.debug("Timer plugin initialized")
  end,

  hooks = {
    on_story_start = function(ctx)
      plugin.start_time = os.time()
      plugin.passage_times = {}
      plugin.current_passage = nil
      plugin.passage_start = nil
      ctx.log.info("Timer started")
    end,

    on_passage_enter = function(ctx, passage)
      -- Record time for previous passage
      if plugin.current_passage and plugin.passage_start then
        local elapsed = os.time() - plugin.passage_start
        plugin.passage_times[plugin.current_passage] =
          (plugin.passage_times[plugin.current_passage] or 0) + elapsed
      end

      -- Start timing new passage
      plugin.current_passage = passage.name
      plugin.passage_start = os.time()
    end,

    on_story_end = function(ctx)
      -- Record final passage time
      if plugin.current_passage and plugin.passage_start then
        local elapsed = os.time() - plugin.passage_start
        plugin.passage_times[plugin.current_passage] =
          (plugin.passage_times[plugin.current_passage] or 0) + elapsed
      end

      local total = os.time() - plugin.start_time
      ctx.log.info(string.format("Story completed in %d seconds", total))
    end,

    on_save = function(save_data, ctx)
      -- Record current passage time before saving
      local current_elapsed = 0
      if plugin.passage_start then
        current_elapsed = os.time() - plugin.passage_start
      end

      save_data.timer = {
        start_time = plugin.start_time,
        passage_times = plugin.passage_times,
        current_passage = plugin.current_passage,
        current_elapsed = current_elapsed,
      }
      return save_data
    end,

    on_load = function(save_data, ctx)
      if save_data.timer then
        plugin.start_time = save_data.timer.start_time
        plugin.passage_times = save_data.timer.passage_times or {}
        plugin.current_passage = save_data.timer.current_passage
        plugin.passage_start = os.time() - (save_data.timer.current_elapsed or 0)
      end
      return save_data
    end,
  },

  api = {
    --- Get total elapsed time in seconds
    -- @return number Total seconds since story start
    get_total_time = function()
      if not plugin.start_time then
        return 0
      end
      return os.time() - plugin.start_time
    end,

    --- Get formatted total time
    -- @return string Formatted as "HH:MM:SS"
    get_total_time_formatted = function()
      local total = plugin.ctx and os.time() - plugin.start_time or 0
      local hours = math.floor(total / 3600)
      local minutes = math.floor((total % 3600) / 60)
      local seconds = total % 60
      return string.format("%02d:%02d:%02d", hours, minutes, seconds)
    end,

    --- Get time spent in a specific passage
    -- @param passage_name string Passage identifier
    -- @return number Seconds spent in passage
    get_passage_time = function(passage_name)
      local time = plugin.passage_times[passage_name] or 0

      -- Add current session time if on this passage
      if plugin.current_passage == passage_name and plugin.passage_start then
        time = time + (os.time() - plugin.passage_start)
      end

      return time
    end,

    --- Get all passage times
    -- @return table Map of passage names to time in seconds
    get_all_passage_times = function()
      local times = {}
      for name, time in pairs(plugin.passage_times) do
        times[name] = time
      end

      -- Add current passage time
      if plugin.current_passage and plugin.passage_start then
        times[plugin.current_passage] =
          (times[plugin.current_passage] or 0) + (os.time() - plugin.passage_start)
      end

      return times
    end,

    --- Get the passage where most time was spent
    -- @return string|nil Passage name
    -- @return number Time in seconds
    get_longest_passage = function()
      local times = plugin.ctx and
        whisker.plugin.timer.get_all_passage_times() or
        plugin.passage_times

      local longest_name = nil
      local longest_time = 0

      for name, time in pairs(times) do
        if time > longest_time then
          longest_name = name
          longest_time = time
        end
      end

      return longest_name, longest_time
    end,

    --- Get current passage name
    -- @return string|nil Current passage name
    get_current_passage = function()
      return plugin.current_passage
    end,
  },
}

--[[
Usage in story:

-- Get total time
local total = whisker.plugin.timer.get_total_time()
print("Playing for " .. total .. " seconds")

-- Get formatted time
local formatted = whisker.plugin.timer.get_total_time_formatted()
print("Time: " .. formatted)  -- "00:05:23"

-- Get time in specific passage
local time = whisker.plugin.timer.get_passage_time("intro")
print("Spent " .. time .. " seconds in intro")

-- Get longest passage
local name, time = whisker.plugin.timer.get_longest_passage()
print("Longest: " .. name .. " (" .. time .. "s)")
]]
