--- CSP Generator Unit Tests
-- @module tests.unit.security.csp_generator_spec

describe("CSPGenerator", function()
  local CSPGenerator

  before_each(function()
    package.loaded["whisker.security.csp_generator"] = nil
    package.loaded["whisker.security.html_parser"] = nil
    CSPGenerator = require("whisker.security.csp_generator")
    CSPGenerator.clear_all_extensions()
  end)

  describe("generate_nonce", function()
    it("generates unique nonces", function()
      local nonce1 = CSPGenerator.generate_nonce()
      local nonce2 = CSPGenerator.generate_nonce()

      assert.is_string(nonce1)
      assert.is_string(nonce2)
      assert.is_not.equals(nonce1, nonce2)
    end)

    it("generates nonces of sufficient length", function()
      local nonce = CSPGenerator.generate_nonce()
      assert.is_true(#nonce >= 16)
    end)

    it("generates valid base64", function()
      local nonce = CSPGenerator.generate_nonce()
      assert.is_truthy(nonce:match("^[A-Za-z0-9+/]+=*$"))
    end)
  end)

  describe("is_valid_nonce", function()
    it("validates proper nonces", function()
      local nonce = CSPGenerator.generate_nonce()
      assert.is_true(CSPGenerator.is_valid_nonce(nonce))
    end)

    it("rejects short nonces", function()
      assert.is_false(CSPGenerator.is_valid_nonce("abc"))
    end)

    it("rejects non-base64", function()
      assert.is_false(CSPGenerator.is_valid_nonce("not-valid-base64!!!"))
    end)

    it("rejects non-strings", function()
      assert.is_false(CSPGenerator.is_valid_nonce(123))
      assert.is_false(CSPGenerator.is_valid_nonce(nil))
    end)
  end)

  describe("create_default_policy", function()
    it("creates restrictive default policy", function()
      local policy = CSPGenerator.create_default_policy()

      assert.is_table(policy.default_src)
      assert.is_table(policy.script_src)
      assert.is_table(policy.object_src)

      -- Check defaults
      assert.includes(policy.default_src, "'self'")
      assert.includes(policy.object_src, "'none'")
      assert.includes(policy.frame_ancestors, "'none'")
    end)

    it("does not include unsafe-inline by default for scripts", function()
      local policy = CSPGenerator.create_default_policy()

      local has_unsafe_inline = false
      for _, source in ipairs(policy.script_src) do
        if source == "'unsafe-inline'" then
          has_unsafe_inline = true
        end
      end

      assert.is_false(has_unsafe_inline)
    end)

    it("adds nonce when provided", function()
      local policy = CSPGenerator.create_default_policy({
        nonce = "abc123def456ghij"
      })

      local has_nonce = false
      for _, source in ipairs(policy.script_src) do
        if source:match("^'nonce%-") then
          has_nonce = true
        end
      end

      assert.is_true(has_nonce)
    end)

    it("adds unsafe-eval when requested", function()
      local policy = CSPGenerator.create_default_policy({
        allow_eval = true
      })

      local has_eval = false
      for _, source in ipairs(policy.script_src) do
        if source == "'unsafe-eval'" then
          has_eval = true
        end
      end

      assert.is_true(has_eval)
    end)
  end)

  describe("serialize_policy", function()
    it("serializes policy to CSP string", function()
      local policy = {
        default_src = {"'self'"},
        script_src = {"'self'", "'nonce-abc123'"},
      }

      local result = CSPGenerator.serialize_policy(policy)

      assert.matches("default%-src 'self'", result)
      assert.matches("script%-src 'self' 'nonce%-abc123'", result)
    end)

    it("uses hyphens instead of underscores", function()
      local policy = {
        script_src = {"'self'"},
        frame_ancestors = {"'none'"},
      }

      local result = CSPGenerator.serialize_policy(policy)

      assert.matches("script%-src", result)
      assert.matches("frame%-ancestors", result)
      assert.does_not.match("_", result)
    end)

    it("joins directives with semicolons", function()
      local policy = {
        default_src = {"'self'"},
        script_src = {"'self'"},
      }

      local result = CSPGenerator.serialize_policy(policy)

      assert.matches("; ", result)
    end)
  end)

  describe("create_meta_tag", function()
    it("creates valid meta tag", function()
      local policy = "default-src 'self'; script-src 'self'"
      local meta = CSPGenerator.create_meta_tag(policy)

      assert.matches('<meta http%-equiv="Content%-Security%-Policy"', meta)
      assert.matches('content=', meta)
    end)

    it("escapes HTML entities in policy", function()
      local policy = "default-src 'self'"
      local meta = CSPGenerator.create_meta_tag(policy)

      -- Should be properly escaped (&#39; is also valid for apostrophe)
      assert.matches("&#39;", meta)
    end)
  end)

  describe("create_header", function()
    it("creates CSP header", function()
      local policy = "default-src 'self'"
      local header = CSPGenerator.create_header(policy)

      assert.equals("Content-Security-Policy", header.name)
      assert.equals(policy, header.value)
    end)
  end)

  describe("create_report_only_header", function()
    it("creates report-only header", function()
      local policy = "default-src 'self'"
      local header = CSPGenerator.create_report_only_header(policy)

      assert.equals("Content-Security-Policy-Report-Only", header.name)
    end)

    it("includes report-uri when provided", function()
      local policy = "default-src 'self'"
      local header = CSPGenerator.create_report_only_header(policy, "/csp-report")

      assert.matches("report%-uri /csp%-report", header.value)
    end)
  end)

  describe("plugin extensions", function()
    it("registers and applies extensions", function()
      CSPGenerator.register_extension("test-plugin", "connect_src", {
        "https://api.example.com"
      })

      local policy = CSPGenerator.create_default_policy()
      CSPGenerator.apply_extensions(policy)

      local has_api = false
      for _, source in ipairs(policy.connect_src) do
        if source == "https://api.example.com" then
          has_api = true
        end
      end

      assert.is_true(has_api)
    end)

    it("avoids duplicate sources", function()
      CSPGenerator.register_extension("plugin1", "connect_src", {"'self'"})
      CSPGenerator.register_extension("plugin2", "connect_src", {"'self'"})

      local policy = CSPGenerator.create_default_policy()
      CSPGenerator.apply_extensions(policy)

      local self_count = 0
      for _, source in ipairs(policy.connect_src) do
        if source == "'self'" then
          self_count = self_count + 1
        end
      end

      assert.equals(1, self_count)
    end)

    it("clears extensions", function()
      CSPGenerator.register_extension("test", "script_src", {"https://cdn.example.com"})
      CSPGenerator.clear_extension("test")

      local extensions = CSPGenerator.get_extensions()
      assert.is_nil(extensions["test"])
    end)
  end)

  describe("generate_for_export", function()
    it("generates complete CSP setup", function()
      local result = CSPGenerator.generate_for_export()

      assert.is_string(result.meta_tag)
      assert.is_string(result.nonce)
      assert.is_table(result.policy)
      assert.is_string(result.policy_string)
    end)

    it("includes nonce in policy", function()
      local result = CSPGenerator.generate_for_export()

      assert.matches("nonce%-", result.policy_string)
      assert.matches(result.nonce, result.meta_tag)
    end)
  end)

  describe("validate_policy", function()
    it("passes for default policy", function()
      local policy = CSPGenerator.create_default_policy()
      local valid, issues = CSPGenerator.validate_policy(policy)

      assert.is_true(valid)
    end)

    it("warns about unsafe configurations", function()
      local policy = {
        default_src = {"'self'"},
        script_src = {"'unsafe-inline'", "'unsafe-eval'", "*"},
      }

      local valid, issues = CSPGenerator.validate_policy(policy)

      assert.is_false(valid)
      assert.is_true(#issues >= 2)
    end)

    it("warns about missing directives", function()
      local policy = {
        script_src = {"'self'"},
      }

      local valid, issues = CSPGenerator.validate_policy(policy)

      assert.is_false(valid)
      assert.is_true(#issues > 0)
    end)
  end)
end)

-- Helper function for test assertions
function assert.includes(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  error("Value '" .. tostring(value) .. "' not found in table")
end
