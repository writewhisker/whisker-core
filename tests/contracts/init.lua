--- Contract Tests
-- Central export for all contract test modules
-- @module tests.contracts
-- @author Whisker Core Team

return {
  ContractRunner = require("tests.contracts.contract_runner"),
  EngineContract = require("tests.contracts.engine_contract"),
  PluginContract = require("tests.contracts.plugin_contract"),
  SerializerContract = require("tests.contracts.serializer_contract"),
  ConditionContract = require("tests.contracts.condition_contract"),
}
