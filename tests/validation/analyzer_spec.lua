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
    local metrics = analyzer:analyze_flow({})
    assert.is_table(metrics)
    assert.is_number(metrics.complexity)
  end)
  
  it("should run full analysis", function()
    local analyzer = Analyzer.new()
    local results = analyzer:analyze({})
    assert.is_table(results)
    assert.is_table(results.dead_ends)
    assert.is_table(results.orphans)
    assert.is_table(results.invalid_links)
  end)
end)
