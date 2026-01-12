--- Tests for serve command
-- @module tests.cli.commands.serve_spec

describe("Serve Command", function()
  local ServeCommand
  
  setup(function()
    ServeCommand = require("whisker.cli.commands.serve")
  end)
  
  describe("argument parsing", function()
    it("should parse port argument", function()
      local config = ServeCommand._parse_args({"--port", "8080"})
      
      assert.equal(8080, config.port)
    end)
    
    it("should parse short port argument", function()
      local config = ServeCommand._parse_args({"-p", "9000"})
      
      assert.equal(9000, config.port)
    end)
    
    it("should parse host argument", function()
      local config = ServeCommand._parse_args({"--host", "0.0.0.0"})
      
      assert.equal("0.0.0.0", config.host)
    end)
    
    it("should parse story path", function()
      local config = ServeCommand._parse_args({"story.json"})
      
      assert.equal("story.json", config.story_path)
    end)
    
    it("should parse no-reload flag", function()
      local config = ServeCommand._parse_args({"--no-reload"})
      
      assert.is_false(config.hot_reload)
    end)
    
    it("should parse open browser flag", function()
      local config = ServeCommand._parse_args({"--open"})
      
      assert.is_true(config.open_browser)
    end)
    
    it("should parse verbose flag", function()
      local config = ServeCommand._parse_args({"--verbose"})
      
      assert.is_true(config.verbose)
    end)
    
    it("should parse multiple watch paths", function()
      local config = ServeCommand._parse_args({
        "--watch", "/path1",
        "--watch", "/path2"
      })
      
      assert.is_table(config.watch_paths)
      assert.equal(2, #config.watch_paths)
      assert.equal("/path1", config.watch_paths[1])
      assert.equal("/path2", config.watch_paths[2])
    end)
    
    it("should parse combined arguments", function()
      local config = ServeCommand._parse_args({
        "story.json",
        "--port", "4000",
        "--host", "localhost",
        "--open",
        "--verbose"
      })
      
      assert.equal("story.json", config.story_path)
      assert.equal(4000, config.port)
      assert.equal("localhost", config.host)
      assert.is_true(config.open_browser)
      assert.is_true(config.verbose)
    end)
    
    it("should use defaults", function()
      local config = ServeCommand._parse_args({})
      
      assert.equal(3000, config.port)
      assert.equal("127.0.0.1", config.host)
      assert.is_true(config.hot_reload)
      assert.is_false(config.open_browser)
      assert.is_false(config.verbose)
    end)
  end)
  
  describe("help", function()
    it("should display help without error", function()
      -- Just verify it doesn't error
      assert.has_no_errors(function()
        ServeCommand.help()
      end)
    end)
  end)
end)
