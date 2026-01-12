--- Tests for Sync CLI Command
-- @module tests.cli.commands.sync_spec

describe("SyncCommand", function()
  local SyncCommand
  local test_config_path
  
  before_each(function()
    -- Reset module
    package.loaded["whisker.cli.commands.sync"] = nil
    SyncCommand = require("whisker.cli.commands.sync")
    
    -- Use a test config file
    test_config_path = "/tmp/test_whisker_sync_config.json"
  end)
  
  after_each(function()
    -- Clean up test config file
    os.remove(test_config_path)
  end)
  
  describe("initialization", function()
    it("should create new sync command", function()
      local cmd = SyncCommand.new()
      assert.is_not_nil(cmd)
    end)
  end)
  
  describe("parse_args", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
    end)
    
    it("should parse basic arguments", function()
      local args = {"config", "--url", "https://test.com", "--key", "test-key"}
      local parsed = cmd:parse_args(args)
      
      assert.equal("config", parsed.subcommand)
      assert.equal("https://test.com", parsed.url)
      assert.equal("test-key", parsed.key)
    end)
    
    it("should parse transport option", function()
      local args = {"config", "--transport", "websocket"}
      local parsed = cmd:parse_args(args)
      
      assert.equal("websocket", parsed.transport)
    end)
    
    it("should parse interval option", function()
      local args = {"config", "--interval", "30000"}
      local parsed = cmd:parse_args(args)
      
      assert.equal(30000, parsed.sync_interval)
    end)
    
    it("should parse device name", function()
      local args = {"config", "--device-name", "My Laptop"}
      local parsed = cmd:parse_args(args)
      
      assert.equal("My Laptop", parsed.device_name)
    end)
    
    it("should parse conflict strategy", function()
      local args = {"config", "--strategy", "auto_merge"}
      local parsed = cmd:parse_args(args)
      
      assert.equal("auto_merge", parsed.conflict_strategy)
    end)
    
    it("should use defaults", function()
      local args = {"config"}
      local parsed = cmd:parse_args(args)
      
      assert.equal("http", parsed.transport)
      assert.equal(60000, parsed.sync_interval)
      assert.equal("last_write_wins", parsed.conflict_strategy)
    end)
  end)
  
  describe("config management", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
      cmd._config_path = test_config_path
    end)
    
    it("should save and load configuration", function()
      local config = {
        url = "https://test.com",
        api_key = "test-key",
        transport = "http",
        sync_interval = 60000,
        device_name = "Test Device",
        conflict_strategy = "last_write_wins"
      }
      
      local ok, err = cmd:save_config(config)
      assert.is_true(ok)
      assert.is_nil(err)
      
      local loaded, err2 = cmd:load_config()
      assert.is_not_nil(loaded)
      assert.is_nil(err2)
      assert.equal(config.url, loaded.url)
      assert.equal(config.api_key, loaded.api_key)
      assert.equal(config.transport, loaded.transport)
    end)
    
    it("should return error when config not found", function()
      local loaded, err = cmd:load_config()
      assert.is_nil(loaded)
      assert.is_not_nil(err)
      assert.matches("not found", err)
    end)
    
    it("should handle invalid JSON", function()
      local file = io.open(test_config_path, "w")
      file:write("invalid json {{{")
      file:close()
      
      local loaded, err = cmd:load_config()
      assert.is_nil(loaded)
      assert.is_not_nil(err)
    end)
  end)
  
  describe("format_bytes", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
    end)
    
    it("should format bytes", function()
      assert.equal("100 B", cmd:format_bytes(100))
    end)
    
    it("should format kilobytes", function()
      assert.equal("1.0 KB", cmd:format_bytes(1024))
      assert.equal("5.5 KB", cmd:format_bytes(5632))
    end)
    
    it("should format megabytes", function()
      assert.equal("1.0 MB", cmd:format_bytes(1024 * 1024))
      assert.equal("2.5 MB", cmd:format_bytes(2.5 * 1024 * 1024))
    end)
  end)
  
  describe("format_duration", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
    end)
    
    it("should format seconds", function()
      assert.equal("30 seconds ago", cmd:format_duration(30))
    end)
    
    it("should format minutes", function()
      assert.equal("5 minutes ago", cmd:format_duration(300))
    end)
    
    it("should format hours", function()
      assert.equal("2 hours ago", cmd:format_duration(7200))
    end)
    
    it("should format days", function()
      assert.equal("1 days ago", cmd:format_duration(86400))
    end)
  end)
  
  describe("cmd_help", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
    end)
    
    it("should return 0", function()
      local exit_code = cmd:cmd_help()
      assert.equal(0, exit_code)
    end)
  end)
  
  describe("cmd_config", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
      cmd._config_path = test_config_path
    end)
    
    it("should require url", function()
      local parsed = {
        subcommand = "config",
        key = "test-key"
      }
      
      local exit_code = cmd:cmd_config(parsed)
      assert.equal(1, exit_code)
    end)
    
    it("should require key", function()
      local parsed = {
        subcommand = "config",
        url = "https://test.com"
      }
      
      local exit_code = cmd:cmd_config(parsed)
      assert.equal(1, exit_code)
    end)
    
    it("should save configuration", function()
      local parsed = {
        subcommand = "config",
        url = "https://test.com",
        key = "test-key",
        transport = "http",
        sync_interval = 60000,
        device_name = "Test Device",
        conflict_strategy = "last_write_wins"
      }
      
      local exit_code = cmd:cmd_config(parsed)
      assert.equal(0, exit_code)
      
      -- Verify config saved
      local config, err = cmd:load_config()
      assert.is_not_nil(config)
      assert.equal("https://test.com", config.url)
    end)
  end)
  
  describe("execute", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
      cmd._config_path = test_config_path
    end)
    
    it("should show help with no args", function()
      local exit_code = cmd:execute({})
      assert.equal(0, exit_code)
    end)
    
    it("should show help with help command", function()
      local exit_code = cmd:execute({"help"})
      assert.equal(0, exit_code)
    end)
    
    it("should execute config command", function()
      local exit_code = cmd:execute({"config", "--url", "https://test.com", "--key", "test-key"})
      assert.equal(0, exit_code)
    end)
    
    it("should return error for unknown subcommand", function()
      local exit_code = cmd:execute({"unknown"})
      assert.equal(0, exit_code)  -- Returns help
    end)
  end)
  
  describe("integration", function()
    local cmd
    
    before_each(function()
      cmd = SyncCommand.new()
      cmd._config_path = test_config_path
    end)
    
    it("should configure and show status", function()
      -- Configure
      local exit_code1 = cmd:execute({
        "config", 
        "--url", "https://test.com", 
        "--key", "test-key",
        "--device-name", "Test Device"
      })
      assert.equal(0, exit_code1)
      
      -- Show status (will fail without actual backend, but config should load)
      local config, err = cmd:load_config()
      assert.is_not_nil(config)
      assert.equal("https://test.com", config.url)
    end)
  end)
end)
