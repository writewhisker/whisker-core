--- A/B Testing Framework for whisker-core Analytics
-- Test definition, variant assignment, and statistical analysis
-- @module whisker.analytics.testing
-- @author Whisker Core Team
-- @license MIT

local ABTesting = {}
ABTesting.__index = ABTesting
ABTesting.VERSION = "1.0.0"

--- Test storage
ABTesting._tests = {}

--- Variant assignments (userId/sessionId -> variant)
ABTesting._assignments = {}

--- Dependencies
ABTesting._deps = {
  consent_manager = nil,
  collector = nil
}

--- Check if table contains a value
local function table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then return true end
  end
  return false
end

--- Simple hash function
local function hash_string(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 1000000
  end
  return hash
end

--- Generate UUID
local function generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

--- Get timestamp
local function get_timestamp()
  return os.time() * 1000
end

--- Set dependencies
-- @param deps table Dependencies to inject
function ABTesting.setDependencies(deps)
  if deps.consent_manager then
    ABTesting._deps.consent_manager = deps.consent_manager
  end
  if deps.collector then
    ABTesting._deps.collector = deps.collector
  end
end

--- Initialize A/B testing system
function ABTesting.initialize()
  ABTesting._tests = {}
  ABTesting._assignments = {}
end

--- Define a new test
-- @param testDef table Test definition
-- @return table|nil Test object
-- @return string|nil Error message
function ABTesting.defineTest(testDef)
  -- Validate
  local isValid, errors = ABTesting._validateTestDefinition(testDef)
  if not isValid then
    return nil, table.concat(errors, ", ")
  end

  -- Set defaults
  testDef.status = testDef.status or "draft"
  testDef.createdAt = get_timestamp()
  testDef.minSampleSize = testDef.minSampleSize or 100
  testDef.confidenceLevel = testDef.confidenceLevel or 0.95

  -- Normalize variant weights
  ABTesting._normalizeVariantWeights(testDef.variants)

  -- Store test
  ABTesting._tests[testDef.id] = testDef

  return testDef
end

--- Validate test definition
-- @param testDef table Test definition
-- @return boolean Valid
-- @return table Errors
function ABTesting._validateTestDefinition(testDef)
  local errors = {}

  if not testDef.id or type(testDef.id) ~= "string" then
    table.insert(errors, "Missing test id")
  end

  if not testDef.variants or #testDef.variants < 2 then
    table.insert(errors, "Test must have at least 2 variants")
  end

  if testDef.variants then
    local totalWeight = 0
    for _, variant in ipairs(testDef.variants) do
      if not variant.id then
        table.insert(errors, "Variant missing id")
      end
      totalWeight = totalWeight + (variant.weight or 0)
    end

    if totalWeight == 0 then
      table.insert(errors, "Total variant weight must be > 0")
    end
  end

  return #errors == 0, errors
end

--- Normalize variant weights to sum to 100
-- @param variants table Variants to normalize
function ABTesting._normalizeVariantWeights(variants)
  local totalWeight = 0
  for _, variant in ipairs(variants) do
    totalWeight = totalWeight + (variant.weight or 0)
  end

  for _, variant in ipairs(variants) do
    variant.normalizedWeight = (variant.weight / totalWeight) * 100
  end
end

--- Get test by ID
-- @param testId string Test ID
-- @return table|nil Test object
function ABTesting.getTest(testId)
  return ABTesting._tests[testId]
end

--- Get all tests
-- @return table All tests
function ABTesting.getAllTests()
  return ABTesting._tests
end

--- Get active tests
-- @return table Array of active tests
function ABTesting.getActiveTests()
  local active = {}
  for _, test in pairs(ABTesting._tests) do
    if test.status == "active" then
      table.insert(active, test)
    end
  end
  return active
end

--- Start test
-- @param testId string Test ID
-- @return boolean Success
-- @return string|nil Error message
function ABTesting.startTest(testId)
  local test = ABTesting._tests[testId]
  if not test then
    return false, "Test not found: " .. testId
  end

  if test.status ~= "draft" and test.status ~= "paused" then
    return false, "Can only start draft or paused tests"
  end

  test.status = "active"
  test.startDate = test.startDate or get_timestamp()

  return true
end

--- Pause test
-- @param testId string Test ID
-- @return boolean Success
-- @return string|nil Error message
function ABTesting.pauseTest(testId)
  local test = ABTesting._tests[testId]
  if not test then
    return false, "Test not found: " .. testId
  end

  if test.status ~= "active" then
    return false, "Can only pause active tests"
  end

  test.status = "paused"
  return true
end

--- Complete test
-- @param testId string Test ID
-- @return boolean Success
-- @return string|nil Error message
function ABTesting.completeTest(testId)
  local test = ABTesting._tests[testId]
  if not test then
    return false, "Test not found: " .. testId
  end

  test.status = "completed"
  test.endDate = get_timestamp()

  return true
end

--- Archive test
-- @param testId string Test ID
-- @return boolean Success
function ABTesting.archiveTest(testId)
  local test = ABTesting._tests[testId]
  if not test then
    return false, "Test not found: " .. testId
  end

  test.status = "archived"
  return true
end

--- Delete test
-- @param testId string Test ID
function ABTesting.deleteTest(testId)
  ABTesting._tests[testId] = nil
end

--- Get variant for user
-- @param testId string Test ID
-- @return table|nil Variant
function ABTesting.getVariant(testId)
  local test = ABTesting.getTest(testId)
  if not test or test.status ~= "active" then
    return nil
  end

  -- Get user/session ID
  local userId = ABTesting._getUserId()

  -- Check for existing assignment
  local cacheKey = testId .. ":" .. userId
  if ABTesting._assignments[cacheKey] then
    return ABTesting._assignments[cacheKey]
  end

  -- Assign variant
  local variant = ABTesting._assignVariant(test, userId)

  -- Cache assignment
  ABTesting._assignments[cacheKey] = variant

  -- Track exposure
  ABTesting._trackExposure(test, variant)

  return variant
end

--- Assign variant to user
-- @param test table Test object
-- @param userId string User ID
-- @return table Variant
function ABTesting._assignVariant(test, userId)
  -- Use hash for deterministic assignment
  local hash = hash_string(userId .. test.id)
  local bucket = hash % 100

  -- Select variant based on bucket
  local cumulative = 0
  for _, variant in ipairs(test.variants) do
    cumulative = cumulative + variant.normalizedWeight
    if bucket < cumulative then
      return variant
    end
  end

  -- Fallback to first variant
  return test.variants[1]
end

--- Get user ID for variant assignment
-- @return string User/session ID
function ABTesting._getUserId()
  if ABTesting._deps.consent_manager then
    local userId = ABTesting._deps.consent_manager.getUserId()
    if userId then
      return userId
    end
    return ABTesting._deps.consent_manager.getSessionId() or generate_uuid()
  end
  return generate_uuid()
end

--- Track exposure event
-- @param test table Test object
-- @param variant table Variant
function ABTesting._trackExposure(test, variant)
  if ABTesting._deps.collector then
    ABTesting._deps.collector.trackEvent("test", "exposure", {
      testId = test.id,
      testName = test.name,
      variantId = variant.id,
      variantName = variant.name
    })
  end
end

--- Track conversion
-- @param testId string Test ID
-- @param conversionType string Type of conversion
-- @param value number|nil Optional value
function ABTesting.trackConversion(testId, conversionType, value)
  local test = ABTesting.getTest(testId)
  if not test then return end

  local userId = ABTesting._getUserId()
  local cacheKey = testId .. ":" .. userId
  local variant = ABTesting._assignments[cacheKey]

  if not variant then return end

  if ABTesting._deps.collector then
    ABTesting._deps.collector.trackEvent("test", "conversion", {
      testId = test.id,
      variantId = variant.id,
      conversionType = conversionType,
      value = value
    })
  end
end

--- Get assignment for test and user
-- @param testId string Test ID
-- @param userId string User ID
-- @return table|nil Variant
function ABTesting.getAssignment(testId, userId)
  local cacheKey = testId .. ":" .. userId
  return ABTesting._assignments[cacheKey]
end

--- Clear assignments (for testing)
function ABTesting.clearAssignments()
  ABTesting._assignments = {}
end

-- Statistics module
ABTesting.Statistics = {}

--- Calculate mean
-- @param values table Array of numbers
-- @return number Mean
function ABTesting.Statistics.mean(values)
  if #values == 0 then return 0 end

  local sum = 0
  for _, v in ipairs(values) do
    sum = sum + v
  end
  return sum / #values
end

--- Calculate standard deviation
-- @param values table Array of numbers
-- @return number Standard deviation
function ABTesting.Statistics.stdDev(values)
  if #values < 2 then return 0 end

  local avg = ABTesting.Statistics.mean(values)
  local sumSquaredDiff = 0

  for _, v in ipairs(values) do
    local diff = v - avg
    sumSquaredDiff = sumSquaredDiff + (diff * diff)
  end

  return math.sqrt(sumSquaredDiff / (#values - 1))
end

--- Calculate confidence interval
-- @param values table Array of numbers
-- @param confidenceLevel number Confidence level (default 0.95)
-- @return number|nil Lower bound
-- @return number|nil Upper bound
function ABTesting.Statistics.confidenceInterval(values, confidenceLevel)
  confidenceLevel = confidenceLevel or 0.95

  if #values < 2 then
    return nil, nil
  end

  local avg = ABTesting.Statistics.mean(values)
  local stdErr = ABTesting.Statistics.stdDev(values) / math.sqrt(#values)

  -- Z-scores for common confidence levels
  local zScores = {
    [0.90] = 1.645,
    [0.95] = 1.96,
    [0.99] = 2.576
  }

  local z = zScores[confidenceLevel] or 1.96
  local margin = z * stdErr

  return avg - margin, avg + margin
end

--- Two-sample t-test
-- @param valuesA table First sample
-- @param valuesB table Second sample
-- @return table|nil Results
-- @return string|nil Error message
function ABTesting.Statistics.tTest(valuesA, valuesB)
  if #valuesA < 2 or #valuesB < 2 then
    return nil, "Insufficient samples for t-test"
  end

  local meanA = ABTesting.Statistics.mean(valuesA)
  local meanB = ABTesting.Statistics.mean(valuesB)

  local stdDevA = ABTesting.Statistics.stdDev(valuesA)
  local stdDevB = ABTesting.Statistics.stdDev(valuesB)

  local n1 = #valuesA
  local n2 = #valuesB

  -- Pooled standard error
  local se = math.sqrt((stdDevA * stdDevA / n1) + (stdDevB * stdDevB / n2))

  -- t-statistic
  local t = 0
  if se > 0 then
    t = (meanA - meanB) / se
  elseif meanA ~= meanB then
    -- When both groups have zero variance but different means,
    -- the difference is infinitely significant
    t = math.huge
  end

  -- Degrees of freedom
  local df = n1 + n2 - 2

  -- Approximate p-value
  local pValue = ABTesting.Statistics._approxPValue(math.abs(t), df)

  return {
    meanA = meanA,
    meanB = meanB,
    tStatistic = t,
    degreesOfFreedom = df,
    pValue = pValue,
    significant = pValue < 0.05
  }
end

--- Approximate p-value (simplified)
-- @param t number T-statistic
-- @param df number Degrees of freedom
-- @return number P-value
function ABTesting.Statistics._approxPValue(t, df)
  -- Handle infinite t-statistic (zero variance, different means)
  if t == math.huge then
    return 0
  end

  -- Simplified approximation
  if t < 1.96 then
    return 0.05 + (1.96 - t) * 0.45 / 1.96
  else
    return 0.05 * math.exp(-(t - 1.96))
  end
end

--- Reset A/B testing (for testing)
function ABTesting.reset()
  ABTesting._tests = {}
  ABTesting._assignments = {}
  ABTesting._deps.consent_manager = nil
  ABTesting._deps.collector = nil
end

return ABTesting
