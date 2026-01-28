--- Tests for story analyzer

describe("Story Analyzer", function()
  local Analyzer

  setup(function()
    Analyzer = require("whisker.validation.analyzer")
  end)

  it("should create analyzer", function()
    local analyzer = Analyzer.new()
    assert.is_not_nil(analyzer)
  end)

  it("should detect dead ends", function()
    local analyzer = Analyzer.new()
    local dead_ends = analyzer:detect_dead_ends({})
    assert.is_table(dead_ends)
  end)

  it("should detect orphans", function()
    local analyzer = Analyzer.new()
    local orphans = analyzer:detect_orphans({})
    assert.is_table(orphans)
  end)

  it("should validate links", function()
    local analyzer = Analyzer.new()
    local invalid = analyzer:validate_links({})
    assert.is_table(invalid)
  end)

  it("should track variables", function()
    local analyzer = Analyzer.new()
    local vars = analyzer:track_variables({})
    assert.is_table(vars)
  end)

  it("should check accessibility", function()
    local analyzer = Analyzer.new()
    local issues = analyzer:check_accessibility({})
    assert.is_table(issues)
  end)

  it("should analyze flow", function()
    local analyzer = Analyzer.new()
    local result = analyzer:analyze_flow({})
    assert.is_table(result)
    assert.is_table(result.metrics)
    assert.is_number(result.metrics.complexity)
  end)

  it("should run full analysis", function()
    local analyzer = Analyzer.new()
    local results = analyzer:analyze({})
    assert.is_table(results)
    assert.is_table(results.dead_ends)
    assert.is_table(results.orphans)
    assert.is_table(results.invalid_links)
  end)

  -- GAP-006: Reserved CSS Classes
  describe("Reserved CSS Classes (GAP-006)", function()
    it("should warn about whisker- prefix", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(
        '.whisker-custom:[text]',
        "test_passage"
      )

      assert.equals(1, #diagnostics)
      assert.equals("WLS-PRS-001", diagnostics[1].code)
      assert.matches("whisker%-", diagnostics[1].message)
    end)

    it("should warn about ws- prefix", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(
        '.ws-highlight:[text]',
        "test_passage"
      )

      assert.equals(1, #diagnostics)
      assert.matches("ws%-", diagnostics[1].message)
    end)

    it("should allow non-reserved classes", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(
        '.my-custom-class:[text]',
        "test_passage"
      )

      assert.equals(0, #diagnostics)
    end)

    it("should check block-level classes", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(
        '.whisker-block::[multiline content]',
        "test_passage"
      )

      assert.equals(1, #diagnostics)
    end)

    it("should suggest renamed class", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(
        '.whisker-custom:[text]',
        "test_passage"
      )

      assert.equals(1, #diagnostics)
      assert.matches("user%-custom", diagnostics[1].suggestion)
    end)

    it("should handle multiple reserved classes in content", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(
        '.whisker-one:[text] and .ws-two:[more text]',
        "test_passage"
      )

      assert.equals(2, #diagnostics)
    end)

    it("should include css_diagnostics in full analysis", function()
      local analyzer = Analyzer.new()
      local story = {
        passages = {
          test_passage = {
            content = '.whisker-test:[content]'
          }
        }
      }

      local results = analyzer:analyze(story)
      assert.is_table(results.css_diagnostics)
      assert.equals(1, #results.css_diagnostics)
    end)

    it("should handle nil content gracefully", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(nil, "test_passage")
      assert.equals(0, #diagnostics)
    end)

    it("should handle content without CSS classes", function()
      local analyzer = Analyzer.new()
      local diagnostics = analyzer:validate_css_classes(
        'Just some regular text without classes',
        "test_passage"
      )

      assert.equals(0, #diagnostics)
    end)
  end)
end)
