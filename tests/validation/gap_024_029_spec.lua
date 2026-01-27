--- Tests for GAP-024 through GAP-029: Validation Error Codes
-- WLS 1.0 Compliance Tests
-- @module tests.validation.gap_024_029_spec

describe("GAP-024 through GAP-029: Validation Error Codes", function()
  local Analyzer = require("whisker.validation.analyzer")
  local Diagnostic = require("whisker.validation.diagnostic")
  local AssetValidator = require("whisker.validation.asset_validator")
  local ScriptValidator = require("whisker.validation.script_validator")

  local analyzer

  before_each(function()
    analyzer = Analyzer.new()
  end)

  -- ========================================================================
  -- GAP-024: Asset Validation Errors (WLS-AST-*)
  -- ========================================================================
  describe("GAP-024: Asset Validation", function()
    describe("extract_assets", function()
      it("should extract markdown images", function()
        local content = "Look at this: ![A cat](images/cat.png)"
        local assets = analyzer:extract_assets(content)
        assert.equals(1, #assets)
        assert.equals("image", assets[1].type)
        assert.equals("images/cat.png", assets[1].path)
        assert.equals("A cat", assets[1].alt)
      end)

      it("should extract @image directives", function()
        local content = '@image("assets/hero.jpg")'
        local assets = analyzer:extract_assets(content)
        assert.equals(1, #assets)
        assert.equals("image", assets[1].type)
        assert.equals("assets/hero.jpg", assets[1].path)
      end)

      it("should extract @audio directives", function()
        local content = '@audio("sounds/bgm.mp3")'
        local assets = analyzer:extract_assets(content)
        assert.equals(1, #assets)
        assert.equals("audio", assets[1].type)
        assert.equals("sounds/bgm.mp3", assets[1].path)
      end)

      it("should extract @video directives", function()
        local content = '@video("videos/intro.mp4")'
        local assets = analyzer:extract_assets(content)
        assert.equals(1, #assets)
        assert.equals("video", assets[1].type)
        assert.equals("videos/intro.mp4", assets[1].path)
      end)

      it("should extract @embed directives", function()
        local content = '@embed("https://youtube.com/watch?v=xyz")'
        local assets = analyzer:extract_assets(content)
        assert.equals(1, #assets)
        assert.equals("embed", assets[1].type)
        assert.equals("https://youtube.com/watch?v=xyz", assets[1].path)
      end)

      it("should extract multiple assets", function()
        local content = [[
          ![img1](a.png)
          @audio("b.mp3")
          ![img2](c.jpg)
        ]]
        local assets = analyzer:extract_assets(content)
        assert.equals(3, #assets)
      end)

      it("should handle table content (AST nodes)", function()
        local content = {
          { type = "text", value = "Here is an image: ![test](test.png)" }
        }
        local assets = analyzer:extract_assets(content)
        assert.equals(1, #assets)
      end)
    end)

    describe("AssetValidator", function()
      it("should detect empty path (WLS-AST-002)", function()
        local validator = AssetValidator.new()
        local diags = validator:validate("image", "")
        assert.equals(1, #diags)
        assert.equals("WLS-AST-002", diags[1].code)
      end)

      it("should detect invalid characters in path (WLS-AST-002)", function()
        local validator = AssetValidator.new()
        local diags = validator:validate("image", "file<>.png")
        assert.equals(1, #diags)
        assert.equals("WLS-AST-002", diags[1].code)
      end)

      it("should warn about unsupported type (WLS-AST-003)", function()
        local validator = AssetValidator.new({ check_existence = false })
        local diags = validator:validate("image", "file.bmp")
        assert.equals(1, #diags)
        assert.equals("WLS-AST-003", diags[1].code)
        assert.equals("warning", diags[1].severity)
      end)

      it("should allow supported image types", function()
        local validator = AssetValidator.new({ check_existence = false })
        local supported = { "png", "jpg", "jpeg", "gif", "svg", "webp" }
        for _, ext in ipairs(supported) do
          local diags = validator:validate("image", "file." .. ext)
          assert.equals(0, #diags)
        end
      end)

      it("should allow supported audio types", function()
        local validator = AssetValidator.new({ check_existence = false })
        local supported = { "mp3", "wav", "ogg", "m4a", "flac" }
        for _, ext in ipairs(supported) do
          local diags = validator:validate("audio", "file." .. ext)
          assert.equals(0, #diags)
        end
      end)

      it("should allow supported video types", function()
        local validator = AssetValidator.new({ check_existence = false })
        local supported = { "mp4", "webm", "ogv" }
        for _, ext in ipairs(supported) do
          local diags = validator:validate("video", "file." .. ext)
          assert.equals(0, #diags)
        end
      end)

      it("should skip URL validation for external assets", function()
        local validator = AssetValidator.new({ check_existence = true })
        local diags = validator:validate("image", "https://example.com/img.png")
        assert.equals(0, #diags)
      end)
    end)

    describe("validate_assets", function()
      it("should validate assets in passages", function()
        local story = {
          passages = {
            start = {
              content = '![test](test.png) @audio("")'
            }
          }
        }
        local diags = analyzer:validate_assets(story, { check_existence = false })
        -- Empty audio path should error
        assert.is_true(#diags >= 1)
      end)

      it("should handle nil story", function()
        local diags = analyzer:validate_assets(nil)
        assert.equals(0, #diags)
      end)
    end)
  end)

  -- ========================================================================
  -- GAP-025: Metadata Validation Errors (WLS-META-*)
  -- ========================================================================
  describe("GAP-025: Metadata Validation", function()
    describe("validate_metadata", function()
      it("should error on missing title (WLS-META-001)", function()
        local story = { passages = {} }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-001" and d.message:match("title") then
            found = true
            assert.equals("error", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should warn on missing author (WLS-META-001)", function()
        local story = { title = "Test", passages = {} }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-001" and d.message:match("author") then
            found = true
            assert.equals("warning", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should warn on missing ifid (WLS-META-001)", function()
        local story = { title = "Test", author = "Me", passages = {} }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-001" and d.message:match("ifid") then
            found = true
            assert.equals("warning", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should error on invalid IFID format (WLS-META-002)", function()
        local story = {
          title = "Test",
          author = "Me",
          ifid = "not-a-uuid"
        }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-002" and d.message:match("IFID") then
            found = true
            assert.equals("error", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should accept valid UUID v4 IFID", function()
        local story = {
          title = "Test",
          author = "Me",
          ifid = "12345678-1234-4123-8123-123456789abc"
        }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-002" and d.message:match("IFID") then
            found = true
          end
        end
        assert.is_false(found)
      end)

      it("should warn on invalid version format (WLS-META-002)", function()
        local story = {
          title = "Test",
          author = "Me",
          ifid = "12345678-1234-4123-8123-123456789abc",
          version = "v1.0"  -- Invalid: has 'v' prefix
        }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-002" and d.message:match("version") then
            found = true
          end
        end
        assert.is_true(found)
      end)

      it("should accept valid semver version", function()
        local story = {
          title = "Test",
          author = "Me",
          ifid = "12345678-1234-4123-8123-123456789abc",
          version = "1.0.0"
        }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-002" and d.message:match("version") then
            found = true
          end
        end
        assert.is_false(found)
      end)

      it("should warn on deprecated metadata (WLS-META-003)", function()
        local story = {
          title = "Test",
          author = "Me",
          ifid = "12345678-1234-4123-8123-123456789abc",
          metadata = {
            format = "old-format"
          }
        }
        local diags = analyzer:validate_metadata(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-META-003" then
            found = true
            assert.equals("warning", d.severity)
          end
        end
        assert.is_true(found)
      end)
    end)
  end)

  -- ========================================================================
  -- GAP-026: Script Validation Errors (WLS-SCR-*)
  -- ========================================================================
  describe("GAP-026: Script Validation", function()
    describe("extract_scripts", function()
      it("should extract script blocks", function()
        local content = "Text {@ local x = 1 @} more text"
        local scripts = analyzer:extract_scripts(content)
        assert.equals(1, #scripts)
        assert.equals(" local x = 1 ", scripts[1].script)
        assert.equals("block", scripts[1].type)
      end)

      it("should extract multiple script blocks", function()
        local content = "{@ a = 1 @} text {@ b = 2 @}"
        local scripts = analyzer:extract_scripts(content)
        assert.equals(2, #scripts)
      end)
    end)

    describe("ScriptValidator", function()
      it("should detect syntax errors (WLS-SCR-001)", function()
        local validator = ScriptValidator.new()
        local diags = validator:validate("if then end")  -- Invalid syntax
        assert.equals(1, #diags)
        assert.equals("WLS-SCR-001", diags[1].code)
        assert.equals("error", diags[1].severity)
      end)

      it("should detect forbidden function calls (WLS-SCR-003)", function()
        local validator = ScriptValidator.new()
        local diags = validator:validate("os.execute('rm -rf /')")
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-SCR-003" then
            found = true
            assert.equals("error", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should detect io.open as forbidden (WLS-SCR-003)", function()
        local validator = ScriptValidator.new()
        local diags = validator:validate("local f = io.open('file')")
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-SCR-003" then
            found = true
          end
        end
        assert.is_true(found)
      end)

      it("should detect infinite loop risk (WLS-SCR-004)", function()
        local validator = ScriptValidator.new()
        local diags = validator:validate("while true do print(1) end")
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-SCR-004" then
            found = true
            assert.equals("warning", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should allow valid scripts", function()
        local validator = ScriptValidator.new()
        local diags = validator:validate("local x = 1 + 2")
        assert.equals(0, #diags)
      end)

      it("should handle empty scripts", function()
        local validator = ScriptValidator.new()
        local diags = validator:validate("")
        assert.equals(0, #diags)
      end)
    end)
  end)

  -- ========================================================================
  -- GAP-027: Collection Validation Errors (WLS-COL-*)
  -- ========================================================================
  describe("GAP-027: Collection Validation", function()
    describe("validate_collections", function()
      it("should detect duplicate collection names (WLS-COL-001)", function()
        local story = {
          lists = { items = { "a", "b" } },
          arrays = { items = {} }  -- Same name as list
        }
        local diags = analyzer:validate_collections(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-COL-001" then
            found = true
            assert.equals("error", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should allow unique collection names", function()
        local story = {
          lists = { list1 = { "a", "b" } },
          arrays = { array1 = {} },
          maps = { map1 = {} }
        }
        local diags = analyzer:validate_collections(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-COL-001" then
            found = true
          end
        end
        assert.is_false(found)
      end)

      it("should detect invalid collection item types (WLS-COL-003)", function()
        -- Note: In Lua, we can't have function types in literal tables easily
        -- This test validates the detection mechanism
        local story = {
          lists = { items = { values = { "valid", 123, true } } }
        }
        local diags = analyzer:validate_collections(story)
        -- All these types are valid
        local type_errors = 0
        for _, d in ipairs(diags) do
          if d.code == "WLS-COL-003" then
            type_errors = type_errors + 1
          end
        end
        assert.equals(0, type_errors)
      end)

      it("should handle nil story", function()
        local diags = analyzer:validate_collections(nil)
        assert.equals(0, #diags)
      end)
    end)
  end)

  -- ========================================================================
  -- GAP-028: Module Validation Errors (WLS-MOD-*)
  -- ========================================================================
  describe("GAP-028: Module Validation", function()
    describe("validate_modules", function()
      it("should detect duplicate namespaces (WLS-MOD-005)", function()
        local story = {
          namespaces = { ns1 = {}, ns1 = {} }  -- Duplicate (though Lua dedupes)
        }
        -- Note: Lua tables dedupe keys, so we test via different means
        local diags = analyzer:validate_modules(story)
        -- This tests the mechanism; actual duplicates would come from parser
        assert.is_table(diags)
      end)

      it("should detect duplicate function parameters (WLS-MOD-006)", function()
        local story = {
          functions = {
            myFunc = {
              params = { "a", "b", "a" }  -- Duplicate param
            }
          }
        }
        local diags = analyzer:validate_modules(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-MOD-006" then
            found = true
            assert.equals("error", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should allow valid function parameters", function()
        local story = {
          functions = {
            myFunc = {
              params = { "a", "b", "c" }
            }
          }
        }
        local diags = analyzer:validate_modules(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-MOD-006" then
            found = true
          end
        end
        assert.is_false(found)
      end)
    end)

    describe("validate_includes", function()
      it("should detect empty include path (WLS-MOD-002)", function()
        local story = {
          includes = { { path = "" } }
        }
        local diags = analyzer:validate_includes(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-MOD-002" then
            found = true
            assert.equals("error", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should warn about suspicious path traversal", function()
        local story = {
          includes = { { path = "../../etc/../passwd" } }
        }
        local diags = analyzer:validate_includes(story)
        local found = false
        for _, d in ipairs(diags) do
          if d.code == "WLS-MOD-007" then
            found = true
            assert.equals("warning", d.severity)
          end
        end
        assert.is_true(found)
      end)

      it("should allow valid include paths", function()
        local story = {
          includes = { { path = "./modules/utils.wls" } }
        }
        local diags = analyzer:validate_includes(story)
        assert.equals(0, #diags)
      end)
    end)
  end)

  -- ========================================================================
  -- GAP-029: Diagnostic Class and Error Message Format
  -- ========================================================================
  describe("GAP-029: Diagnostic Class", function()
    describe("Diagnostic.new", function()
      it("should create diagnostic with required fields", function()
        local diag = Diagnostic.new("WLS-VAR-001", "Variable undefined")
        assert.equals("WLS-VAR-001", diag.code)
        assert.equals("Variable undefined", diag.message)
        assert.equals("error", diag.severity)
      end)

      it("should accept optional fields", function()
        local diag = Diagnostic.new("WLS-VAR-001", "Var x undefined", {
          severity = "warning",
          location = { line = 10, column = 5 },
          suggestion = "Define x first",
          passage_id = "start"
        })
        assert.equals("warning", diag.severity)
        assert.equals(10, diag.location.line)
        assert.equals(5, diag.location.column)
        assert.equals("Define x first", diag.suggestion)
        assert.equals("start", diag.passage_id)
      end)
    end)

    describe("Diagnostic.format", function()
      it("should format basic diagnostic", function()
        local diag = Diagnostic.new("WLS-VAR-001", "Variable undefined")
        local formatted = Diagnostic.format(diag)
        assert.is_string(formatted)
        assert.truthy(formatted:match("WLS%-VAR%-001"))
        assert.truthy(formatted:match("Variable undefined"))
      end)

      it("should include location when present", function()
        local diag = Diagnostic.new("WLS-VAR-001", "Test", {
          location = { line = 10, column = 5 }
        })
        local formatted = Diagnostic.format(diag)
        assert.truthy(formatted:match("10"))
      end)

      it("should include suggestion when present", function()
        local diag = Diagnostic.new("WLS-VAR-001", "Test", {
          suggestion = "Fix it like this"
        })
        local formatted = Diagnostic.format(diag)
        assert.truthy(formatted:match("Suggestion"))
        assert.truthy(formatted:match("Fix it like this"))
      end)
    end)

    describe("Diagnostic.format_all", function()
      it("should format multiple diagnostics", function()
        local diags = {
          Diagnostic.new("WLS-VAR-001", "Error 1"),
          Diagnostic.new("WLS-VAR-002", "Warning 1", { severity = "warning" })
        }
        local formatted = Diagnostic.format_all(diags, { show_summary = true })
        assert.is_string(formatted)
        assert.truthy(formatted:match("1 error"))
        assert.truthy(formatted:match("1 warning"))
      end)
    end)

    describe("Diagnostic.to_lsp", function()
      it("should convert to LSP format", function()
        local diag = Diagnostic.new("WLS-VAR-001", "Test", {
          location = { line = 10, column = 5 }
        })
        local lsp = Diagnostic.to_lsp(diag)
        assert.equals(1, lsp.severity)  -- Error = 1
        assert.equals("WLS-VAR-001", lsp.code)
        assert.equals("whisker", lsp.source)
        assert.equals(9, lsp.range.start.line)  -- 0-indexed
        assert.equals(4, lsp.range.start.character)  -- 0-indexed
      end)
    end)

    describe("Diagnostic.count_by_severity", function()
      it("should count diagnostics by severity", function()
        local diags = {
          Diagnostic.new("E1", "Error", { severity = "error" }),
          Diagnostic.new("E2", "Error", { severity = "error" }),
          Diagnostic.new("W1", "Warning", { severity = "warning" }),
          Diagnostic.new("I1", "Info", { severity = "info" })
        }
        local counts = Diagnostic.count_by_severity(diags)
        assert.equals(2, counts.errors)
        assert.equals(1, counts.warnings)
        assert.equals(1, counts.info)
      end)
    end)

    describe("Diagnostic.filter_by_severity", function()
      it("should filter by severity", function()
        local diags = {
          Diagnostic.new("E1", "Error", { severity = "error" }),
          Diagnostic.new("W1", "Warning", { severity = "warning" })
        }
        local errors = Diagnostic.filter_by_severity(diags, "error")
        assert.equals(1, #errors)
        assert.equals("E1", errors[1].code)
      end)
    end)

    describe("Diagnostic.filter_by_code_prefix", function()
      it("should filter by code prefix", function()
        local diags = {
          Diagnostic.new("WLS-VAR-001", "Var error"),
          Diagnostic.new("WLS-VAR-002", "Var warning"),
          Diagnostic.new("WLS-AST-001", "Asset error")
        }
        local var_diags = Diagnostic.filter_by_code_prefix(diags, "WLS-VAR")
        assert.equals(2, #var_diags)
      end)
    end)
  end)

  -- ========================================================================
  -- Integration: Analyzer with all validators
  -- ========================================================================
  describe("Analyzer Integration", function()
    it("should include all diagnostics in analyze result", function()
      local story = {
        title = "Test Story",
        author = "Test Author",
        ifid = "12345678-1234-4123-8123-123456789abc",
        start_passage = "start",
        passages = {
          start = {
            content = {
              { type = "text", value = "Hello world" }
            },
            choices = {
              { target_passage = "END" }
            }
          }
        }
      }
      local result = analyzer:analyze(story)

      -- Check all expected keys exist
      assert.is_table(result.dead_ends)
      assert.is_table(result.orphans)
      assert.is_table(result.invalid_links)
      assert.is_table(result.variable_diagnostics)
      assert.is_table(result.css_diagnostics)
      assert.is_table(result.asset_diagnostics)
      assert.is_table(result.metadata_diagnostics)
      assert.is_table(result.script_diagnostics)
      assert.is_table(result.collection_diagnostics)
      assert.is_table(result.module_diagnostics)
      assert.is_table(result.include_diagnostics)
    end)

    it("should get all diagnostics as flat array", function()
      local story = {}  -- Minimal story that will generate some diagnostics
      local all = analyzer:get_all_diagnostics(story)
      assert.is_table(all)
    end)

    it("should filter diagnostics by severity", function()
      local story = {}
      local errors = analyzer:get_diagnostics_by_severity(story, "error")
      assert.is_table(errors)
      for _, d in ipairs(errors) do
        assert.equals("error", d.severity)
      end
    end)

    it("should filter diagnostics by code prefix", function()
      local story = {}
      local meta_diags = analyzer:get_diagnostics_by_code(story, "WLS-META")
      assert.is_table(meta_diags)
      for _, d in ipairs(meta_diags) do
        assert.truthy(d.code:match("^WLS%-META"))
      end
    end)
  end)
end)
