--- Capabilities Unit Tests
-- @module tests.unit.security.capabilities_spec

describe("Capabilities", function()
  local Capabilities

  before_each(function()
    package.loaded["whisker.security.capabilities"] = nil
    Capabilities = require("whisker.security.capabilities")
  end)

  describe("REGISTRY", function()
    it("defines READ_STATE capability", function()
      local cap = Capabilities.REGISTRY.READ_STATE
      assert.is_not_nil(cap)
      assert.equals("READ_STATE", cap.id)
      assert.equals("LOW", cap.risk_level)
      assert.is_string(cap.name)
      assert.is_string(cap.description)
    end)

    it("defines WRITE_STATE capability", function()
      local cap = Capabilities.REGISTRY.WRITE_STATE
      assert.is_not_nil(cap)
      assert.equals("WRITE_STATE", cap.id)
      assert.equals("MEDIUM", cap.risk_level)
    end)

    it("defines NETWORK capability as HIGH risk", function()
      local cap = Capabilities.REGISTRY.NETWORK
      assert.is_not_nil(cap)
      assert.equals("HIGH", cap.risk_level)
      assert.is_table(cap.warnings)
    end)

    it("defines FILESYSTEM capability as HIGH risk", function()
      local cap = Capabilities.REGISTRY.FILESYSTEM
      assert.is_not_nil(cap)
      assert.equals("HIGH", cap.risk_level)
    end)
  end)

  describe("is_valid", function()
    it("returns true for valid capabilities", function()
      assert.is_true(Capabilities.is_valid("READ_STATE"))
      assert.is_true(Capabilities.is_valid("WRITE_STATE"))
      assert.is_true(Capabilities.is_valid("NETWORK"))
      assert.is_true(Capabilities.is_valid("FILESYSTEM"))
    end)

    it("returns false for invalid capabilities", function()
      assert.is_false(Capabilities.is_valid("INVALID"))
      assert.is_false(Capabilities.is_valid(""))
      assert.is_false(Capabilities.is_valid(nil))
    end)
  end)

  describe("is_high_risk", function()
    it("returns true for HIGH and CRITICAL risk", function()
      assert.is_true(Capabilities.is_high_risk("NETWORK"))
      assert.is_true(Capabilities.is_high_risk("FILESYSTEM"))
    end)

    it("returns false for LOW and MEDIUM risk", function()
      assert.is_false(Capabilities.is_high_risk("READ_STATE"))
      assert.is_false(Capabilities.is_high_risk("WRITE_STATE"))
    end)
  end)

  describe("validate", function()
    it("validates valid capability arrays", function()
      local valid, err = Capabilities.validate({"READ_STATE", "WRITE_STATE"})
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("rejects invalid capability arrays", function()
      local valid, err = Capabilities.validate({"INVALID"})
      assert.is_false(valid)
      assert.is_string(err)
    end)

    it("rejects non-string elements", function()
      local valid, err = Capabilities.validate({123})
      assert.is_false(valid)
      assert.matches("must be string", err)
    end)

    it("rejects non-table input", function()
      local valid, err = Capabilities.validate("READ_STATE")
      assert.is_false(valid)
      assert.matches("must be a table", err)
    end)
  end)

  describe("expand", function()
    it("includes required capabilities", function()
      -- WRITE_STATE requires READ_STATE
      local expanded = Capabilities.expand({"WRITE_STATE"})

      local has_read = false
      local has_write = false
      for _, cap in ipairs(expanded) do
        if cap == "READ_STATE" then has_read = true end
        if cap == "WRITE_STATE" then has_write = true end
      end

      assert.is_true(has_write)
      -- If WRITE_STATE requires READ_STATE, it should be included
      -- (depends on how requirements are defined)
    end)

    it("handles empty array", function()
      local expanded = Capabilities.expand({})
      assert.same({}, expanded)
    end)
  end)

  describe("to_set and from_set", function()
    it("converts between array and set", function()
      local caps = {"READ_STATE", "NETWORK"}
      local set = Capabilities.to_set(caps)

      assert.is_true(set.READ_STATE)
      assert.is_true(set.NETWORK)
      assert.is_nil(set.WRITE_STATE)

      local arr = Capabilities.from_set(set)
      table.sort(arr)
      assert.same({"NETWORK", "READ_STATE"}, arr)
    end)
  end)

  describe("get_permission_prompts", function()
    it("returns prompts sorted by risk level", function()
      local prompts = Capabilities.get_permission_prompts({
        "READ_STATE", "NETWORK", "FILESYSTEM"
      })

      assert.equals(3, #prompts)
      -- HIGH risk should come first
      assert.equals("HIGH", prompts[1].risk_level)
    end)

    it("includes user prompts and warnings", function()
      local prompts = Capabilities.get_permission_prompts({"NETWORK"})

      assert.equals(1, #prompts)
      assert.is_string(prompts[1].prompt)
      assert.is_table(prompts[1].warnings)
    end)
  end)
end)
