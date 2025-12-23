--- Permission Manager Unit Tests
-- @module tests.unit.security.permission_manager_spec

describe("PermissionManager", function()
  local PermissionManager
  local PermissionStorage

  before_each(function()
    package.loaded["whisker.security.permission_manager"] = nil
    package.loaded["whisker.security.permission_storage"] = nil
    package.loaded["whisker.security.capabilities"] = nil

    PermissionManager = require("whisker.security.permission_manager")
    PermissionStorage = require("whisker.security.permission_storage")

    -- Initialize with in-memory storage (no file)
    PermissionStorage.init(nil)
    PermissionStorage.clear()
  end)

  after_each(function()
    PermissionStorage.clear()
  end)

  describe("grant", function()
    it("grants permission", function()
      PermissionManager.grant("test-plugin", "READ_STATE")

      assert.is_true(PermissionManager.is_granted("test-plugin", "READ_STATE"))
    end)

    it("throws for invalid capability", function()
      assert.has.errors(function()
        PermissionManager.grant("test", "INVALID")
      end)
    end)
  end)

  describe("deny", function()
    it("denies permission", function()
      PermissionManager.deny("test-plugin", "NETWORK")

      assert.is_true(PermissionManager.is_denied("test-plugin", "NETWORK"))
      assert.is_false(PermissionManager.is_granted("test-plugin", "NETWORK"))
    end)
  end)

  describe("revoke", function()
    it("revokes previously granted permission", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.revoke("test-plugin", "READ_STATE")

      assert.is_false(PermissionManager.is_granted("test-plugin", "READ_STATE"))
      assert.is_true(PermissionManager.is_denied("test-plugin", "READ_STATE"))
    end)

    it("revokes all permissions for plugin", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.grant("test-plugin", "WRITE_STATE")
      PermissionManager.revoke("test-plugin")

      assert.is_false(PermissionManager.is_granted("test-plugin", "READ_STATE"))
      assert.is_false(PermissionManager.is_granted("test-plugin", "WRITE_STATE"))
    end)
  end)

  describe("reset", function()
    it("removes permission decision", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.reset("test-plugin", "READ_STATE")

      assert.is_true(PermissionManager.is_pending("test-plugin", "READ_STATE"))
    end)
  end)

  describe("is_pending", function()
    it("returns true for undecided permissions", function()
      assert.is_true(PermissionManager.is_pending("test-plugin", "READ_STATE"))
    end)

    it("returns false for granted permissions", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      assert.is_false(PermissionManager.is_pending("test-plugin", "READ_STATE"))
    end)

    it("returns false for denied permissions", function()
      PermissionManager.deny("test-plugin", "READ_STATE")
      assert.is_false(PermissionManager.is_pending("test-plugin", "READ_STATE"))
    end)
  end)

  describe("get_all", function()
    it("returns all permissions for plugin", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.deny("test-plugin", "NETWORK")

      local perms = PermissionManager.get_all("test-plugin")

      assert.equals("granted", perms.READ_STATE)
      assert.equals("denied", perms.NETWORK)
    end)
  end)

  describe("get_summary", function()
    it("returns categorized permission summary", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.deny("test-plugin", "NETWORK")
      PermissionManager.grant("test-plugin", "WRITE_STATE")
      PermissionManager.revoke("test-plugin", "WRITE_STATE")

      local summary = PermissionManager.get_summary("test-plugin")

      assert.equals(1, #summary.granted)
      assert.equals(1, #summary.denied)
      assert.equals(1, #summary.revoked)
    end)
  end)

  describe("all_granted", function()
    it("returns true when all capabilities granted", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.grant("test-plugin", "WRITE_STATE")

      assert.is_true(PermissionManager.all_granted("test-plugin", {"READ_STATE", "WRITE_STATE"}))
    end)

    it("returns false when any capability missing", function()
      PermissionManager.grant("test-plugin", "READ_STATE")

      assert.is_false(PermissionManager.all_granted("test-plugin", {"READ_STATE", "NETWORK"}))
    end)
  end)

  describe("get_granted", function()
    it("returns only granted capabilities", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.grant("test-plugin", "WRITE_STATE")
      PermissionManager.deny("test-plugin", "NETWORK")

      local granted = PermissionManager.get_granted("test-plugin")
      table.sort(granted)

      assert.equals(2, #granted)
      assert.same({"READ_STATE", "WRITE_STATE"}, granted)
    end)
  end)

  describe("grant_all", function()
    it("grants all specified capabilities", function()
      PermissionManager.grant_all("test-plugin", {"READ_STATE", "WRITE_STATE", "NETWORK"})

      assert.is_true(PermissionManager.is_granted("test-plugin", "READ_STATE"))
      assert.is_true(PermissionManager.is_granted("test-plugin", "WRITE_STATE"))
      assert.is_true(PermissionManager.is_granted("test-plugin", "NETWORK"))
    end)
  end)

  describe("request", function()
    it("returns already-decided permissions immediately", function()
      PermissionManager.grant("test-plugin", "READ_STATE")
      PermissionManager.deny("test-plugin", "NETWORK")

      local granted_result, denied_result

      PermissionManager.request("test-plugin", {"READ_STATE", "NETWORK"}, function(granted, denied)
        granted_result = granted
        denied_result = denied
      end)

      assert.equals(1, #granted_result)
      assert.equals(1, #denied_result)
    end)

    it("auto-denies when no UI handler", function()
      local granted_result, denied_result

      PermissionManager.request("test-plugin", {"READ_STATE"}, function(granted, denied)
        granted_result = granted
        denied_result = denied
      end)

      assert.equals(0, #granted_result)
      assert.equals(1, #denied_result)
    end)
  end)

  describe("request_sync", function()
    it("returns results synchronously", function()
      PermissionManager.grant("test-plugin", "READ_STATE")

      local granted, denied = PermissionManager.request_sync("test-plugin", {"READ_STATE"})

      assert.equals(1, #granted)
      assert.equals(0, #denied)
    end)
  end)
end)
