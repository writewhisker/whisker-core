--- Contract Runner
-- Framework for running contract tests against implementations
-- @module tests.contracts.contract_runner
-- @author Whisker Core Team

local ContractRunner = {}

--- Runs a contract test suite against an implementation
-- @param contract_suite table The contract test module (e.g., engine_contract)
-- @param implementation_factory function Function that creates implementation instances
-- @param test_data_provider table Provides test data for the contract tests
-- @param options table Optional {name, tags, skip_tests}
function ContractRunner.run(contract_suite, implementation_factory, test_data_provider, options)
  options = options or {}

  local suite_name = options.name or "Contract Tests"
  local tags = options.tags or {}

  describe(suite_name, function()
    -- Set up tags if provided
    if #tags > 0 then
      for _, tag in ipairs(tags) do
        pending("Tagged: " .. tag)
      end
    end

    -- Check if suite has a run function
    if type(contract_suite.run_contract_tests) == "function" then
      -- Run the contract suite's main function
      contract_suite.run_contract_tests(implementation_factory, test_data_provider)
    elseif type(contract_suite) == "function" then
      -- Suite is a function itself
      contract_suite(implementation_factory, test_data_provider)
    else
      error("Contract suite must have run_contract_tests function or be callable")
    end
  end)
end

--- Validates that an implementation factory is properly structured
-- @param factory function The implementation factory to validate
-- @return boolean valid True if factory is valid
-- @return string|nil error Error message if invalid
function ContractRunner.validate_factory(factory)
  if type(factory) ~= "function" then
    return false, "Factory must be a function"
  end

  -- Try to create an instance
  local success, instance = pcall(factory)
  if not success then
    return false, "Factory failed to create instance: " .. tostring(instance)
  end

  if type(instance) ~= "table" then
    return false, "Factory must return a table instance"
  end

  return true, nil
end

--- Validates that test data provider has required fields
-- @param provider table The test data provider to validate
-- @param required_fields table Array of required field names
-- @return boolean valid True if provider is valid
-- @return string|nil error Error message if invalid
function ContractRunner.validate_provider(provider, required_fields)
  if type(provider) ~= "table" then
    return false, "Provider must be a table"
  end

  for _, field in ipairs(required_fields) do
    if provider[field] == nil then
      return false, "Provider missing required field: " .. field
    end
  end

  return true, nil
end

return ContractRunner
