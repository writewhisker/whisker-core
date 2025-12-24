-- lib/whisker/kernel/package.lua
-- Kernel package metadata

return {
  name = "whisker.kernel",
  version = "2.2.0",
  description = "Whisker-Core microkernel with extensions",
  license = "MIT",

  -- Kernel components
  components = {
    "init",       -- Microkernel Bootstrap
    "bootstrap",  -- Kernel initialization (loads extensions)
    "container",  -- Dependency Container
    "events",     -- Event Bus
    "loader",     -- Module Loader
    "registry",   -- Registry Pattern
  },

  -- Current line counts (as of Phase 1 remediation)
  line_counts = {
    ["bootstrap.lua"] = 77,   -- Reduced from 277 (factory registrations moved to extensions)
    ["container.lua"] = 277,  -- Full DI container with child scopes
    ["events.lua"] = 273,     -- Event bus with history and namespaces
    ["init.lua"] = 47,        -- Capability detection
    ["loader.lua"] = 148,     -- Module loader
    ["registry.lua"] = 125,   -- Service registry
    total = 975,              -- Down from 1,175 (17% reduction)
  },
}
