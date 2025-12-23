#!/usr/bin/env lua
--- Run all Twine-related tests
-- Execute with: lua tests/run_all_twine_tests.lua
-- Or use busted directly: busted tests/

print("=================================================")
print("  Phase 4: Twine Integration Test Suite")
print("=================================================")
print("")

-- Check if busted is available
local busted_available = pcall(require, "busted.runner")

if busted_available then
  print("Running tests with busted...")
  print("")

  -- Let busted handle test execution
  -- This script is primarily for documentation
  -- Run tests using: busted tests/unit/twine tests/twine

  os.execute("busted tests/unit/twine tests/twine --verbose")
else
  print("Busted not found. Please install with:")
  print("  luarocks install busted")
  print("")
  print("Then run tests with:")
  print("  busted tests/unit/twine tests/twine")
  os.exit(1)
end

print("")
print("=================================================")
print("  Test Suite Complete")
print("=================================================")
