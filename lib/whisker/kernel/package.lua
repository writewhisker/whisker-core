-- lib/whisker/kernel/package.lua
-- Kernel package metadata (not counted in 50-line limit)

return {
  name = "whisker.kernel",
  version = "2.1.0",
  description = "Whisker-Core microkernel bootstrap",
  license = "MIT",

  -- Kernel components (to be implemented in later stages)
  components = {
    "init",      -- Stage 02: Microkernel Bootstrap
    "loader",    -- Stage 03: Module Loader
    "container", -- Stage 04-05: Dependency Container
    "events",    -- Stage 06-07: Event Bus
    "registry",  -- Stage 08: Registry Pattern
  },

  -- Line count limit enforcement
  limits = {
    ["init.lua"] = 50,
    ["loader.lua"] = 80,
    ["container.lua"] = 100,
    ["events.lua"] = 80,
    ["registry.lua"] = 40,
    total = 350,
  },
}
