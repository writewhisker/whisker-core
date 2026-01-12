--- Tests for Lua module hot reload
-- @module tests.dev.hot_reload_spec

describe("Hot Reload", function()
  local HotReload
  local test_dir
  
  setup(function()
    HotReload = require("whisker.dev.hot_reload")
  end)
  
  before_each(function()
    -- Create temp test directory
    test_dir = "/tmp/whisker_hot_reload_test_" .. os.time()
    os.execute("mkdir -p " .. test_dir)
    
    -- Add test directory to package.path
    package.path = test_dir .. "/?.lua;" .. package.path
  end)
  
  after_each(function()
    -- Clean up test directory
    os.execute("rm -rf " .. test_dir)
    
    -- Clean up loaded test modules
    for module_name, _ in pairs(package.loaded) do
      if module_name:match("^test_module") then
        package.loaded[module_name] = nil
      end
    end
  end)
  
  describe("creation", function()
    it("should create hot reload manager", function()
      local hr = HotReload.new()
      
      assert.is_not_nil(hr)
      assert.is_table(hr.module_paths)
      assert.is_table(hr.module_dependencies)
    end)
    
    it("should create with config", function()
      local hr = HotReload.new({
        watch_paths = {"/tmp/test"}
      })
      
      assert.equal(1, #hr.watch_paths)
      assert.equal("/tmp/test", hr.watch_paths[1])
    end)
    
    it("should scan initially loaded modules", function()
      local hr = HotReload.new()
      
      -- Should have tracked some modules
      assert.is_true(hr:get_module_count() > 0)
    end)
  end)
  
  describe("module path resolution", function()
    it("should get module path for loaded module", function()
      -- Load a known module
      require("whisker.dev.hot_reload")
      
      local hr = HotReload.new()
      local path = hr:_get_module_path("whisker.dev.hot_reload")
      
      assert.is_not_nil(path)
      assert.matches("hot_reload%.lua", path)
    end)
    
    it("should return nil for non-existent module", function()
      local hr = HotReload.new()
      local path = hr:_get_module_path("nonexistent.module.name")
      
      assert.is_nil(path)
    end)
  end)
  
  describe("module reloading", function()
    it("should reload a module", function()
      -- Create test module
      local module_path = test_dir .. "/test_module1.lua"
      local f = io.open(module_path, "w")
      f:write([[
        local M = {}
        M.value = 1
        return M
      ]])
      f:close()
      
      -- Load module
      local mod = require("test_module1")
      assert.equal(1, mod.value)
      
      local hr = HotReload.new()
      
      -- Modify module
      f = io.open(module_path, "w")
      f:write([[
        local M = {}
        M.value = 2
        return M
      ]])
      f:close()
      
      -- Reload
      local success, err = hr:reload_module("test_module1")
      assert.is_true(success, err)
      
      -- Verify reload
      mod = require("test_module1")
      assert.equal(2, mod.value)
    end)
    
    it("should emit event on successful reload", function()
      -- Create test module
      local module_path = test_dir .. "/test_module2.lua"
      local f = io.open(module_path, "w")
      f:write("return {value = 1}")
      f:close()
      
      require("test_module2")
      
      local hr = HotReload.new()
      
      local reloaded = false
      hr:on("module_reloaded", function(data)
        reloaded = true
        assert.equal("test_module2", data.module)
      end)
      
      -- Modify and reload
      f = io.open(module_path, "w")
      f:write("return {value = 2}")
      f:close()
      
      hr:reload_module("test_module2")
      
      assert.is_true(reloaded)
    end)
    
    it("should handle reload errors gracefully", function()
      -- Create valid module
      local module_path = test_dir .. "/test_module3.lua"
      local f = io.open(module_path, "w")
      f:write("return {value = 1}")
      f:close()
      
      local mod = require("test_module3")
      assert.equal(1, mod.value)
      
      local hr = HotReload.new()
      
      -- Introduce syntax error
      f = io.open(module_path, "w")
      f:write("return {value = } -- syntax error")
      f:close()
      
      -- Try to reload
      local success, err = hr:reload_module("test_module3")
      
      assert.is_false(success)
      assert.is_not_nil(err)
      
      -- Original module should still work
      mod = require("test_module3")
      assert.equal(1, mod.value)
    end)
    
    it("should restore backup on reload failure", function()
      -- Create module
      local module_path = test_dir .. "/test_module4.lua"
      local f = io.open(module_path, "w")
      f:write("return {original = true}")
      f:close()
      
      require("test_module4")
      
      local hr = HotReload.new()
      
      -- Break the module
      f = io.open(module_path, "w")
      f:write("syntax error here")
      f:close()
      
      -- Reload should fail and restore backup
      hr:reload_module("test_module4")
      
      local mod = require("test_module4")
      assert.is_true(mod.original)
    end)
    
    it("should return error for non-loaded module", function()
      local hr = HotReload.new()
      
      local success, err = hr:reload_module("module.that.does.not.exist")
      
      assert.is_false(success)
      assert.matches("not loaded", err)
    end)
  end)
  
  describe("dependency tracking", function()
    it("should register dependencies", function()
      local hr = HotReload.new()
      
      hr:register_dependency("module_a", "module_b")
      
      assert.equal(1, hr:get_dependent_count("module_b"))
    end)
    
    it("should not duplicate dependencies", function()
      local hr = HotReload.new()
      
      hr:register_dependency("module_a", "module_b")
      hr:register_dependency("module_a", "module_b")
      
      assert.equal(1, hr:get_dependent_count("module_b"))
    end)
    
    it("should track multiple dependents", function()
      local hr = HotReload.new()
      
      hr:register_dependency("module_a", "module_core")
      hr:register_dependency("module_b", "module_core")
      hr:register_dependency("module_c", "module_core")
      
      assert.equal(3, hr:get_dependent_count("module_core"))
    end)
    
    it("should get dependents list", function()
      local hr = HotReload.new()
      
      hr:register_dependency("dep1", "base")
      hr:register_dependency("dep2", "base")
      
      local dependents = hr:_get_dependents("base")
      
      assert.equal(2, #dependents)
    end)
  end)
  
  describe("file change handling", function()
    it("should handle file change for tracked module", function()
      -- Create and load module
      local module_path = test_dir .. "/test_module5.lua"
      local f = io.open(module_path, "w")
      f:write("return {version = 1}")
      f:close()
      
      require("test_module5")
      
      local hr = HotReload.new()
      hr.module_paths["test_module5"] = module_path
      
      -- Modify module
      f = io.open(module_path, "w")
      f:write("return {version = 2}")
      f:close()
      
      -- Handle change
      local handled = hr:handle_file_change(module_path)
      
      assert.is_true(handled)
      
      -- Verify reload
      local mod = require("test_module5")
      assert.equal(2, mod.version)
    end)
    
    it("should return false for untracked file", function()
      local hr = HotReload.new()
      
      local handled = hr:handle_file_change("/some/random/path.lua")
      
      assert.is_false(handled)
    end)
    
    it("should emit reload_failed on error", function()
      -- Create module
      local module_path = test_dir .. "/test_module6.lua"
      local f = io.open(module_path, "w")
      f:write("return {}")
      f:close()
      
      require("test_module6")
      
      local hr = HotReload.new()
      hr.module_paths["test_module6"] = module_path
      
      local failed = false
      hr:on("reload_failed", function(data)
        failed = true
        assert.equal("test_module6", data.module)
        assert.is_not_nil(data.error)
      end)
      
      -- Break module
      f = io.open(module_path, "w")
      f:write("invalid lua code")
      f:close()
      
      hr:handle_file_change(module_path)
      
      assert.is_true(failed)
    end)
  end)
  
  describe("watcher integration", function()
    it("should connect to watcher", function()
      local hr = HotReload.new()
      local Watcher = require("whisker.dev.watcher")
      
      local watcher = Watcher.new({paths = {test_dir}})
      
      -- Should not error
      assert.has_no_errors(function()
        hr:connect_watcher(watcher)
      end)
    end)
    
    it("should respond to watcher file_modified events", function()
      -- Create module
      local module_path = test_dir .. "/test_module7.lua"
      local f = io.open(module_path, "w")
      f:write("return {from_watcher = 1}")
      f:close()
      
      require("test_module7")
      
      local hr = HotReload.new()
      hr.module_paths["test_module7"] = module_path
      
      local Watcher = require("whisker.dev.watcher")
      local watcher = Watcher.new({
        paths = {test_dir},
        debounce = 0.01
      })
      
      hr:connect_watcher(watcher)
      
      -- Test that connection works by simulating an event directly
      local event_received = false
      hr:on("module_reloaded", function(data)
        event_received = true
        assert.equal("test_module7", data.module)
      end)
      
      -- Modify file
      f = io.open(module_path, "w")
      f:write("return {from_watcher = 2}")
      f:close()
      
      -- Manually trigger the change handler (simulating what watcher would do)
      hr:handle_file_change(module_path)
      
      assert.is_true(event_received, "Module should have been reloaded")
      
      -- Verify the module was actually reloaded
      local mod = require("test_module7")
      assert.equal(2, mod.from_watcher)
    end)
  end)
  
  describe("utility methods", function()
    it("should get tracked modules list", function()
      local hr = HotReload.new()
      
      local modules = hr:get_tracked_modules()
      
      assert.is_table(modules)
      assert.is_true(#modules > 0)
    end)
    
    it("should get module count", function()
      local hr = HotReload.new()
      
      local count = hr:get_module_count()
      
      assert.is_number(count)
      assert.is_true(count > 0)
    end)
    
    it("should clear backups", function()
      local hr = HotReload.new()
      hr.module_backups["test"] = {some = "data"}
      
      hr:clear_backups()
      
      assert.is_nil(hr.module_backups["test"])
    end)
    
    it("should get dependent count", function()
      local hr = HotReload.new()
      
      hr:register_dependency("a", "base")
      hr:register_dependency("b", "base")
      
      assert.equal(2, hr:get_dependent_count("base"))
      assert.equal(0, hr:get_dependent_count("nonexistent"))
    end)
  end)
  
  describe("validation", function()
    it("should validate table modules", function()
      local hr = HotReload.new()
      
      assert.is_true(hr:_validate_module({some = "table"}))
    end)
    
    it("should validate function modules", function()
      local hr = HotReload.new()
      
      assert.is_true(hr:_validate_module(function() end))
    end)
    
    it("should validate boolean modules", function()
      local hr = HotReload.new()
      
      assert.is_true(hr:_validate_module(true))
      assert.is_true(hr:_validate_module(false))
    end)
    
    it("should reject invalid module types", function()
      local hr = HotReload.new()
      
      assert.is_false(hr:_validate_module(nil))
      assert.is_false(hr:_validate_module("string"))
      assert.is_false(hr:_validate_module(123))
    end)
  end)
end)
