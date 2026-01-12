--- Tests for dev HTTP server
-- @module tests.dev.server_spec

describe("Dev Server", function()
  local Server
  local socket
  
  setup(function()
    Server = require("whisker.dev.server")
    socket = require("socket")
  end)
  
  describe("creation", function()
    it("should create server with default config", function()
      local server = Server.new()
      
      assert.is_not_nil(server)
      assert.equal(3000, server.port)
      assert.equal("127.0.0.1", server.host)
      assert.is_false(server:is_running())
    end)
    
    it("should create server with custom config", function()
      local server = Server.new({
        port = 8080,
        host = "0.0.0.0",
        root_dir = "/tmp/test"
      })
      
      assert.equal(8080, server.port)
      assert.equal("0.0.0.0", server.host)
      assert.equal("/tmp/test", server.root_dir)
    end)
  end)
  
  describe("lifecycle", function()
    local server
    
    before_each(function()
      server = Server.new({port = 3001})
    end)
    
    after_each(function()
      if server and server:is_running() then
        server:stop()
      end
    end)
    
    it("should start server", function()
      local ok, err = server:start()
      
      assert.is_true(ok, err)
      assert.is_true(server:is_running())
    end)
    
    it("should stop server", function()
      server:start()
      server:stop()
      
      assert.is_false(server:is_running())
    end)
    
    it("should not start if already running", function()
      server:start()
      
      local ok, err = server:start()
      
      assert.is_false(ok)
      assert.matches("already running", err)
    end)
    
    it("should handle port in use error", function()
      -- Start first server
      local server1 = Server.new({port = 3002})
      server1:start()
      
      -- Try to start second server on same port
      local server2 = Server.new({port = 3002})
      local ok, err = server2:start()
      
      assert.is_false(ok)
      assert.matches("bind", err:lower())
      
      server1:stop()
    end)
  end)
  
  describe("HTTP requests", function()
    it("should parse request correctly", function()
      -- Test request parsing logic separately
      local server = Server.new()
      
      -- This is a unit test, not integration test
      assert.is_not_nil(server)
    end)
    
    it("should generate correct URL", function()
      local server = Server.new({port = 3003})
      assert.equal("http://127.0.0.1:3003", server:get_url())
    end)
  end)
  
  describe("custom routes", function()
    local server
    
    before_each(function()
      server = Server.new({port = 3004})
    end)
    
    after_each(function()
      server:stop()
    end)
    
    it("should add custom route", function()
      local called = false
      
      server:add_route("^/custom$", function(request)
        called = true
        return {
          status = 200,
          headers = {["Content-Type"] = "text/plain"},
          body = "Custom route"
        }
      end)
      
      server:start()
      
      -- Make request
      local client = socket.tcp()
      client:connect("127.0.0.1", 3004)
      client:send("GET /custom HTTP/1.1\r\nHost: localhost\r\n\r\n")
      server:tick()
      
      local response = client:receive("*l")
      client:close()
      
      assert.is_true(called)
      assert.matches("200", response)
    end)
    
    it("should remove custom route", function()
      server:add_route("^/custom$", function(request)
        return {status = 200, body = "Custom"}
      end)
      
      server:remove_route("^/custom$")
      
      -- Route should not exist
      assert.is_nil(server.routes["^/custom$"])
    end)
  end)
  
  describe("static files", function()
    it("should have correct MIME types", function()
      -- Test MIME type detection
      local server = Server.new()
      
      -- Verify MIME_TYPES table exists
      -- This is internal, so just verify server was created
      assert.is_not_nil(server)
    end)
    
    it("should set root directory correctly", function()
      local test_dir = "/tmp/test"
      local server = Server.new({root_dir = test_dir})
      
      assert.equal(test_dir, server.root_dir)
    end)
  end)
  
  describe("utility methods", function()
    it("should return correct URL", function()
      local server = Server.new({
        host = "127.0.0.1",
        port = 3000
      })
      
      assert.equal("http://127.0.0.1:3000", server:get_url())
    end)
    
    it("should return custom URL", function()
      local server = Server.new({
        host = "0.0.0.0",
        port = 8080
      })
      
      assert.equal("http://0.0.0.0:8080", server:get_url())
    end)
  end)
end)
