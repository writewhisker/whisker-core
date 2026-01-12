--- Tests for file watcher
-- @module tests.dev.watcher_spec

describe("File Watcher", function()
  local Watcher
  local test_dir
  
  setup(function()
    Watcher = require("whisker.dev.watcher")
  end)
  
  before_each(function()
    -- Create temp test directory
    test_dir = "/tmp/whisker_watcher_test_" .. os.time()
    os.execute("mkdir -p " .. test_dir)
  end)
  
  after_each(function()
    -- Clean up test directory
    os.execute("rm -rf " .. test_dir)
  end)
  
  describe("creation", function()
    it("should create watcher with default config", function()
      local watcher = Watcher.new()
      
      assert.is_not_nil(watcher)
      assert.is_false(watcher:is_watching())
      assert.is_table(watcher.paths)
      assert.is_table(watcher.patterns)
      assert.is_table(watcher.ignore)
    end)
    
    it("should create watcher with custom paths", function()
      local watcher = Watcher.new({
        paths = {test_dir}
      })
      
      assert.equal(1, #watcher.paths)
      assert.equal(test_dir, watcher.paths[1])
    end)
    
    it("should create watcher with custom patterns", function()
      local watcher = Watcher.new({
        patterns = {"%.lua$", "%.txt$"}
      })
      
      assert.equal(2, #watcher.patterns)
    end)
    
    it("should create watcher with custom debounce", function()
      local watcher = Watcher.new({
        debounce = 0.5
      })
      
      assert.equal(0.5, watcher.debounce)
    end)
  end)
  
  describe("lifecycle", function()
    it("should start watching", function()
      local watcher = Watcher.new({paths = {test_dir}})
      
      local ok = watcher:start()
      
      assert.is_true(ok)
      assert.is_true(watcher:is_watching())
    end)
    
    it("should stop watching", function()
      local watcher = Watcher.new({paths = {test_dir}})
      watcher:start()
      
      watcher:stop()
      
      assert.is_false(watcher:is_watching())
    end)
    
    it("should not start if already watching", function()
      local watcher = Watcher.new({paths = {test_dir}})
      watcher:start()
      
      local ok = watcher:start()
      
      assert.is_false(ok)
    end)
  end)
  
  describe("path management", function()
    it("should add path to watch", function()
      local watcher = Watcher.new({paths = {test_dir}})
      local new_dir = test_dir .. "/subdir"
      os.execute("mkdir -p " .. new_dir)
      
      watcher:add_path(new_dir)
      
      assert.equal(2, #watcher.paths)
    end)
    
    it("should not add duplicate path", function()
      local watcher = Watcher.new({paths = {test_dir}})
      
      watcher:add_path(test_dir)
      
      assert.equal(1, #watcher.paths)
    end)
    
    it("should remove path", function()
      local watcher = Watcher.new({paths = {test_dir, "/tmp"}})
      
      watcher:remove_path(test_dir)
      
      assert.equal(1, #watcher.paths)
      assert.equal("/tmp", watcher.paths[1])
    end)
  end)
  
  describe("file detection", function()
    it("should detect existing files", function()
      -- Create test files
      local file1 = test_dir .. "/test1.lua"
      local file2 = test_dir .. "/test2.txt"
      local f1 = io.open(file1, "w")
      f1:write("-- test")
      f1:close()
      local f2 = io.open(file2, "w")
      f2:write("test")
      f2:close()
      
      local watcher = Watcher.new({
        paths = {test_dir},
        patterns = {"%.lua$"}
      })
      
      local files = watcher:get_watched_files()
      
      -- Should detect test1.lua but not test2.txt
      assert.is_true(#files >= 1)
      
      local found_lua = false
      for _, path in ipairs(files) do
        if path:match("test1%.lua") then
          found_lua = true
        end
        assert.is_nil(path:match("test2%.txt"), "Should not watch .txt files")
      end
      
      assert.is_true(found_lua, "Should find test1.lua")
    end)
    
    it("should respect ignore patterns", function()
      -- Create test files
      os.execute("mkdir -p " .. test_dir .. "/.git")
      local git_file = test_dir .. "/.git/config"
      local regular_file = test_dir .. "/regular.lua"
      
      local f1 = io.open(git_file, "w")
      f1:write("test")
      f1:close()
      
      local f2 = io.open(regular_file, "w")
      f2:write("-- test")
      f2:close()
      
      local watcher = Watcher.new({
        paths = {test_dir}
      })
      
      local files = watcher:get_watched_files()
      
      -- Should not include .git files
      for _, path in ipairs(files) do
        assert.is_nil(path:match("%.git"), "Should ignore .git directory")
      end
    end)
    
    it("should detect new files", function()
      local watcher = Watcher.new({
        paths = {test_dir},
        debounce = 0.01  -- Very short for testing
      })
      
      watcher:start()
      
      local created = false
      watcher:on("file_created", function(data)
        created = true
      end)
      
      -- Give time for initial scan
      os.execute("sleep 0.1")
      
      -- Create new file
      local new_file = test_dir .. "/new_file.lua"
      local f = io.open(new_file, "w")
      f:write("-- new")
      f:close()
      
      -- Tick multiple times with delays for debounce
      for i = 1, 20 do
        watcher:tick()
        os.execute("sleep 0.05")
        if created then break end
      end
      
      assert.is_true(created, "Should detect new file creation")
    end)
    
    it("should detect file modifications", function()
      -- Create initial file
      local test_file = test_dir .. "/test.lua"
      local f = io.open(test_file, "w")
      f:write("-- original")
      f:close()
      
      local watcher = Watcher.new({
        paths = {test_dir},
        debounce = 0.01
      })
      
      watcher:start()
      
      local modified = false
      watcher:on("file_modified", function(data)
        modified = true
      end)
      
      -- Wait then modify
      os.execute("sleep 0.1")
      
      f = io.open(test_file, "w")
      f:write("-- modified content")
      f:close()
      
      -- Tick to detect changes with debounce
      for i = 1, 20 do
        watcher:tick()
        os.execute("sleep 0.05")
        if modified then break end
      end
      
      assert.is_true(modified, "Should detect file modification")
    end)
    
    it("should detect file deletions", function()
      -- Create file
      local test_file = test_dir .. "/delete_me.lua"
      local f = io.open(test_file, "w")
      f:write("-- will be deleted")
      f:close()
      
      local watcher = Watcher.new({
        paths = {test_dir},
        debounce = 0.01
      })
      
      watcher:start()
      
      local deleted = false
      watcher:on("file_deleted", function(data)
        deleted = true
      end)
      
      -- Wait a bit
      os.execute("sleep 0.1")
      
      -- Delete file
      os.remove(test_file)
      
      -- Tick to detect with debounce
      for i = 1, 20 do
        watcher:tick()
        os.execute("sleep 0.05")
        if deleted then break end
      end
      
      assert.is_true(deleted, "Should detect file deletion")
    end)
  end)
  
  describe("debouncing", function()
    it("should debounce rapid changes", function()
      local test_file = test_dir .. "/rapid.lua"
      local f = io.open(test_file, "w")
      f:write("-- original")
      f:close()
      
      local watcher = Watcher.new({
        paths = {test_dir},
        debounce = 0.1
      })
      
      watcher:start()
      
      local change_count = 0
      watcher:on("file_modified", function(data)
        change_count = change_count + 1
      end)
      
      -- Make rapid changes
      for i = 1, 3 do
        f = io.open(test_file, "w")
        f:write("-- change " .. i)
        f:close()
        watcher:tick()
        os.execute("sleep 0.01")
      end
      
      -- Wait for debounce
      os.execute("sleep 0.15")
      watcher:tick()
      
      -- Should only emit once due to debouncing
      assert.is_true(change_count <= 1, "Should debounce rapid changes")
    end)
  end)
  
  describe("recursive watching", function()
    it("should watch subdirectories when recursive", function()
      local subdir = test_dir .. "/subdir"
      os.execute("mkdir -p " .. subdir)
      
      local sub_file = subdir .. "/sub.lua"
      local f = io.open(sub_file, "w")
      f:write("-- sub")
      f:close()
      
      local watcher = Watcher.new({
        paths = {test_dir},
        recursive = true
      })
      
      local files = watcher:get_watched_files()
      
      local found = false
      for _, path in ipairs(files) do
        if path:match("subdir/sub%.lua") then
          found = true
        end
      end
      
      assert.is_true(found, "Should find files in subdirectories")
    end)
    
    it("should not watch subdirectories when not recursive", function()
      local subdir = test_dir .. "/subdir"
      os.execute("mkdir -p " .. subdir)
      
      local sub_file = subdir .. "/sub.lua"
      local f = io.open(sub_file, "w")
      f:write("-- sub")
      f:close()
      
      local watcher = Watcher.new({
        paths = {test_dir},
        recursive = false
      })
      
      local files = watcher:get_watched_files()
      
      for _, path in ipairs(files) do
        assert.is_nil(path:match("subdir/sub%.lua"), "Should not find files in subdirectories")
      end
    end)
  end)
  
  describe("utility methods", function()
    it("should return file count", function()
      -- Create test files
      for i = 1, 3 do
        local f = io.open(test_dir .. "/test" .. i .. ".lua", "w")
        f:write("-- test")
        f:close()
      end
      
      local watcher = Watcher.new({
        paths = {test_dir}
      })
      
      assert.equal(3, watcher:get_file_count())
    end)
    
    it("should return watched files list", function()
      local f = io.open(test_dir .. "/test.lua", "w")
      f:write("-- test")
      f:close()
      
      local watcher = Watcher.new({
        paths = {test_dir}
      })
      
      local files = watcher:get_watched_files()
      
      assert.is_table(files)
      assert.equal(1, #files)
    end)
  end)
end)
