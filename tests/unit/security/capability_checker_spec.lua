--- Capability Checker Unit Tests
-- @module tests.unit.security.capability_checker_spec

describe("CapabilityChecker", function()
  local CapabilityChecker
  local SecurityContext

  before_each(function()
    package.loaded["whisker.security.capability_checker"] = nil
    package.loaded["whisker.security.security_context"] = nil
    package.loaded["whisker.security.capabilities"] = nil

    CapabilityChecker = require("whisker.security.capability_checker")
    SecurityContext = require("whisker.security.security_context")
    SecurityContext.clear()
  end)

  after_each(function()
    SecurityContext.clear()
  end)

  describe("check_capability", function()
    it("allows capability when declared and no permission manager", function()
      SecurityContext.enter("test-plugin", {"READ_STATE"})

      local allowed, reason = CapabilityChecker.check_capability("READ_STATE")
      assert.is_true(allowed)
      assert.is_nil(reason)

      SecurityContext.exit()
    end)

    it("denies capability when not declared", function()
      SecurityContext.enter("test-plugin", {"READ_STATE"})

      local allowed, reason = CapabilityChecker.check_capability("NETWORK")
      assert.is_false(allowed)
      assert.matches("did not declare", reason)

      SecurityContext.exit()
    end)

    it("allows all capabilities when not in plugin context", function()
      -- Core code (no plugin context) has all capabilities
      local allowed = CapabilityChecker.check_capability("READ_STATE")
      assert.is_true(allowed)

      allowed = CapabilityChecker.check_capability("NETWORK")
      assert.is_true(allowed)
    end)

    it("returns error for unknown capability", function()
      SecurityContext.enter("test", {"READ_STATE"})

      local allowed, reason = CapabilityChecker.check_capability("INVALID_CAP")
      assert.is_false(allowed)
      assert.matches("Unknown capability", reason)

      SecurityContext.exit()
    end)
  end)

  describe("require_capability", function()
    it("does not throw when capability is available", function()
      SecurityContext.enter("test", {"READ_STATE"})

      assert.has_no.errors(function()
        CapabilityChecker.require_capability("READ_STATE")
      end)

      SecurityContext.exit()
    end)

    it("throws when capability is not available", function()
      SecurityContext.enter("test", {"READ_STATE"})

      assert.has.errors(function()
        CapabilityChecker.require_capability("NETWORK")
      end)

      SecurityContext.exit()
    end)
  end)

  describe("check_capabilities", function()
    it("returns true when all capabilities available", function()
      SecurityContext.enter("test", {"READ_STATE", "WRITE_STATE"})

      local allowed = CapabilityChecker.check_capabilities({"READ_STATE", "WRITE_STATE"})
      assert.is_true(allowed)

      SecurityContext.exit()
    end)

    it("returns false when any capability missing", function()
      SecurityContext.enter("test", {"READ_STATE"})

      local allowed, reason = CapabilityChecker.check_capabilities({"READ_STATE", "NETWORK"})
      assert.is_false(allowed)
      assert.matches("NETWORK", reason)

      SecurityContext.exit()
    end)
  end)

  describe("validate_manifest", function()
    it("validates valid manifest", function()
      local manifest = {
        capabilities = {"READ_STATE", "WRITE_STATE"}
      }

      local valid, err = CapabilityChecker.validate_manifest(manifest)
      assert.is_true(valid)
    end)

    it("validates manifest without capabilities", function()
      local manifest = {}

      local valid = CapabilityChecker.validate_manifest(manifest)
      assert.is_true(valid)
    end)

    it("rejects invalid capability", function()
      local manifest = {
        capabilities = {"INVALID"}
      }

      local valid, err = CapabilityChecker.validate_manifest(manifest)
      assert.is_false(valid)
      assert.matches("Unknown capability", err)
    end)

    it("rejects WRITE_STATE without READ_STATE", function()
      local manifest = {
        capabilities = {"WRITE_STATE"}
      }

      local valid, err = CapabilityChecker.validate_manifest(manifest)
      assert.is_false(valid)
      assert.matches("requires READ_STATE", err)
    end)
  end)

  describe("get_missing_capabilities", function()
    it("returns missing capabilities", function()
      SecurityContext.enter("test", {"READ_STATE"})

      local missing = CapabilityChecker.get_missing_capabilities({
        "READ_STATE", "WRITE_STATE", "NETWORK"
      })

      assert.equals(2, #missing)
      -- Should contain WRITE_STATE and NETWORK
      local missing_set = {}
      for _, cap in ipairs(missing) do
        missing_set[cap] = true
      end
      assert.is_true(missing_set.WRITE_STATE)
      assert.is_true(missing_set.NETWORK)

      SecurityContext.exit()
    end)

    it("returns empty when all available", function()
      SecurityContext.enter("test", {"READ_STATE", "NETWORK"})

      local missing = CapabilityChecker.get_missing_capabilities({"READ_STATE", "NETWORK"})
      assert.equals(0, #missing)

      SecurityContext.exit()
    end)
  end)

  describe("with_capability", function()
    it("wraps function with capability check", function()
      local wrapped = CapabilityChecker.with_capability("READ_STATE", function()
        return "result"
      end)

      SecurityContext.enter("test", {"READ_STATE"})
      local result = wrapped()
      assert.equals("result", result)
      SecurityContext.exit()
    end)

    it("throws when capability missing", function()
      local wrapped = CapabilityChecker.with_capability("NETWORK", function()
        return "result"
      end)

      SecurityContext.enter("test", {"READ_STATE"})
      assert.has.errors(function()
        wrapped()
      end)
      SecurityContext.exit()
    end)
  end)

  describe("get_current_capabilities", function()
    it("returns current context capabilities", function()
      SecurityContext.enter("test", {"READ_STATE", "NETWORK"})

      local caps = CapabilityChecker.get_current_capabilities()
      table.sort(caps)
      assert.same({"NETWORK", "READ_STATE"}, caps)

      SecurityContext.exit()
    end)
  end)

  describe("is_trusted_mode", function()
    it("returns true when not in plugin context", function()
      assert.is_true(CapabilityChecker.is_trusted_mode())
    end)

    it("returns false when in plugin context", function()
      SecurityContext.enter("test", {})
      assert.is_false(CapabilityChecker.is_trusted_mode())
      SecurityContext.exit()
    end)
  end)
end)
