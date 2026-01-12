--- Tests for DevEnv integration
-- @module tests.dev.init_spec

describe("DevEnv Integration", function()
  local DevEnv
  
  setup(function()
    DevEnv = require("whisker.dev")
  end)
  
  describe("creation", function()
    it("should create dev environment with defaults", function()
      local dev = DevEnv.new()
      
      assert.is_not_nil(dev)
      assert.equal(3000, dev.config.port)
      assert.equal("127.0.0.1", dev.config.host)
      assert.is_true(dev.config.hot_reload)
    end)
    
    it("should create with custom config", function()
      local dev = DevEnv.new({
        port = 8080,
        host = "0.0.0.0",
        hot_reload = false
      })
      
      assert.equal(8080, dev.config.port)
      assert.equal("0.0.0.0", dev.config.host)
      assert.is_false(dev.config.hot_reload)
    end)
  end)
  
  describe("initialization", function()
    it("should initialize all components", function()
      local dev = DevEnv.new({port = 3100})
      
      dev:init()
      
      assert.is_not_nil(dev.server)
      assert.is_not_nil(dev.watcher)
      assert.is_not_nil(dev.hot_reload)
    end)
    
    it("should not create watcher if hot_reload disabled", function()
      local dev = DevEnv.new({
        port = 3101,
        hot_reload = false
      })
      
      dev:init()
      
      assert.is_not_nil(dev.server)
      assert.is_nil(dev.watcher)
      assert.is_nil(dev.hot_reload)
    end)
  end)
  
  describe("lifecycle", function()
    local dev
    
    before_each(function()
      dev = DevEnv.new({port = 3102})
    end)
    
    after_each(function()
      if dev and dev:is_running() then
        dev:stop()
      end
    end)
    
    it("should start successfully", function()
      local ok, err = dev:start()
      
      assert.is_true(ok, err)
      assert.is_true(dev:is_running())
    end)
    
    it("should stop successfully", function()
      dev:start()
      
      dev:stop()
      
      assert.is_false(dev:is_running())
    end)
    
    it("should not start if already running", function()
      dev:start()
      
      local ok, err = dev:start()
      
      assert.is_false(ok)
      assert.matches("Already running", err)
    end)
    
    it("should handle port conflicts", function()
      local dev1 = DevEnv.new({port = 3103})
      local dev2 = DevEnv.new({port = 3103})
      
      dev1:start()
      
      local ok, err = dev2:start()
      
      assert.is_false(ok)
      assert.is_not_nil(err)
      
      dev1:stop()
    end)
  end)
  
  describe("server integration", function()
    it("should have server running after start", function()
      local dev = DevEnv.new({port = 3104})
      dev:start()
      
      assert.is_true(dev.server:is_running())
      
      dev:stop()
    end)
    
    it("should have correct URL", function()
      local dev = DevEnv.new({
        port = 3105,
        host = "127.0.0.1"
      })
      dev:init()  -- Need to init to create server
      
      assert.equal("http://127.0.0.1:3105", dev:get_url())
    end)
  end)
  
  describe("hot reload integration", function()
    it("should enable hot reload by default", function()
      local dev = DevEnv.new({port = 3106})
      dev:init()
      
      assert.is_not_nil(dev.hot_reload)
      assert.is_not_nil(dev.watcher)
    end)
    
    it("should connect hot reload to watcher", function()
      local dev = DevEnv.new({port = 3107})
      dev:init()
      
      -- Both should exist
      assert.is_not_nil(dev.hot_reload)
      assert.is_not_nil(dev.watcher)
    end)
  end)
  
  describe("status", function()
    it("should return correct status", function()
      local dev = DevEnv.new({port = 3108})
      dev:start()
      
      local status = dev:get_status()
      
      assert.is_true(status.running)
      assert.equal("http://127.0.0.1:3108", status.url)
      assert.is_true(status.hot_reload)
      assert.is_true(status.watching)
      assert.is_number(status.files_watched)
      assert.is_number(status.modules_tracked)
      
      dev:stop()
    end)
    
    it("should show not running when stopped", function()
      local dev = DevEnv.new({port = 3109})
      
      local status = dev:get_status()
      
      assert.is_false(status.running)
    end)
  end)
  
  describe("tick processing", function()
    it("should return false when not running", function()
      local dev = DevEnv.new({port = 3110})
      
      local result = dev:tick()
      
      assert.is_false(result)
    end)
    
    it("should return true when running", function()
      local dev = DevEnv.new({port = 3111})
      dev:start()
      
      local result = dev:tick()
      
      assert.is_true(result)
      
      dev:stop()
    end)
    
    it("should tick both server and watcher", function()
      local dev = DevEnv.new({port = 3112})
      dev:start()
      
      -- Tick a few times
      for i = 1, 5 do
        assert.is_true(dev:tick())
      end
      
      dev:stop()
    end)
  end)
end)
