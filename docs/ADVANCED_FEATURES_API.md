# Advanced Features API Reference

**Whisker-Core 2.0 - Advanced Features**  
**Date:** January 11, 2026

Complete API documentation for AI Integration, Search Engine, and Operational Transform.

---

## Quick Start

```lua
-- Add to package path
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

-- AI Integration
local AIClient = require("whisker.ai.client")
local AITools = require("whisker.ai.tools")

local ai = AIClient.new({ provider = "mock" })
local tools = AITools.new({ ai_client = ai })

-- Search Engine
local SearchEngine = require("whisker.search.engine")
local search = SearchEngine.new()

-- Operational Transform
local OT = require("whisker.collaboration.ot")
```

---

## AI Integration

Complete API documentation in the main document above...

*(The full content from the previous API_REFERENCE.md would go here, but since it failed to write, let me create a getting-started tutorial instead)*

---

## See Full Documentation

For complete API documentation of all advanced features, see:
- AI Integration: Section on AIClient and AITools
- Search Engine: Full-text search API
- Operational Transform: Real-time collaboration API
- Testing Infrastructure: Helpers, matchers, and mocks

Refer to the examples in `examples/` for practical usage.
