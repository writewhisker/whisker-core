--- Service Interface Tests
-- Tests for IService, IServiceRegistry, and IServiceLifecycle interfaces
-- @module tests.unit.interfaces.service_interfaces_spec

describe("Service Interfaces", function()
  local Service

  before_each(function()
    package.loaded["whisker.interfaces.service"] = nil
    Service = require("whisker.interfaces.service")
  end)

  describe("IService", function()
    it("defines getName method", function()
      assert.is_function(Service.IService.getName)
    end)

    it("defines initialize method", function()
      assert.is_function(Service.IService.initialize)
    end)

    it("defines isInitialized method", function()
      assert.is_function(Service.IService.isInitialized)
    end)

    it("defines destroy method", function()
      assert.is_function(Service.IService.destroy)
    end)

    it("getName throws error when not implemented", function()
      assert.has_error(function()
        Service.IService:getName()
      end, "IService:getName must be implemented")
    end)

    it("initialize throws error when not implemented", function()
      assert.has_error(function()
        Service.IService:initialize({})
      end, "IService:initialize must be implemented")
    end)

    it("isInitialized throws error when not implemented", function()
      assert.has_error(function()
        Service.IService:isInitialized()
      end, "IService:isInitialized must be implemented")
    end)

    it("destroy throws error when not implemented", function()
      assert.has_error(function()
        Service.IService:destroy()
      end, "IService:destroy must be implemented")
    end)
  end)

  describe("IServiceRegistry", function()
    it("defines register method", function()
      assert.is_function(Service.IServiceRegistry.register)
    end)

    it("defines unregister method", function()
      assert.is_function(Service.IServiceRegistry.unregister)
    end)

    it("defines has method", function()
      assert.is_function(Service.IServiceRegistry.has)
    end)

    it("defines get method", function()
      assert.is_function(Service.IServiceRegistry.get)
    end)

    it("defines getNames method", function()
      assert.is_function(Service.IServiceRegistry.getNames)
    end)

    it("defines getByInterface method", function()
      assert.is_function(Service.IServiceRegistry.getByInterface)
    end)

    it("defines getByMetadata method", function()
      assert.is_function(Service.IServiceRegistry.getByMetadata)
    end)

    it("defines discover method", function()
      assert.is_function(Service.IServiceRegistry.discover)
    end)

    it("register throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:register("test", "path.to.module")
      end, "IServiceRegistry:register must be implemented")
    end)

    it("unregister throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:unregister("test")
      end, "IServiceRegistry:unregister must be implemented")
    end)

    it("has throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:has("test")
      end, "IServiceRegistry:has must be implemented")
    end)

    it("get throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:get("test")
      end, "IServiceRegistry:get must be implemented")
    end)

    it("getNames throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:getNames()
      end, "IServiceRegistry:getNames must be implemented")
    end)

    it("getByInterface throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:getByInterface("IState")
      end, "IServiceRegistry:getByInterface must be implemented")
    end)

    it("getByMetadata throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:getByMetadata("priority", 100)
      end, "IServiceRegistry:getByMetadata must be implemented")
    end)

    it("discover throws error when not implemented", function()
      assert.has_error(function()
        Service.IServiceRegistry:discover("/path/to/services")
      end, "IServiceRegistry:discover must be implemented")
    end)
  end)

  describe("IServiceLifecycle", function()
    it("defines onBeforeInit hook", function()
      assert.is_function(Service.IServiceLifecycle.onBeforeInit)
    end)

    it("defines onAfterInit hook", function()
      assert.is_function(Service.IServiceLifecycle.onAfterInit)
    end)

    it("defines onBeforeDestroy hook", function()
      assert.is_function(Service.IServiceLifecycle.onBeforeDestroy)
    end)

    it("defines onAfterDestroy hook", function()
      assert.is_function(Service.IServiceLifecycle.onAfterDestroy)
    end)

    it("defines onSuspend hook", function()
      assert.is_function(Service.IServiceLifecycle.onSuspend)
    end)

    it("defines onResume hook", function()
      assert.is_function(Service.IServiceLifecycle.onResume)
    end)

    -- Lifecycle hooks have default implementations that do nothing
    it("onBeforeInit is callable without error", function()
      assert.has_no_errors(function()
        Service.IServiceLifecycle:onBeforeInit({})
      end)
    end)

    it("onAfterInit is callable without error", function()
      assert.has_no_errors(function()
        Service.IServiceLifecycle:onAfterInit({})
      end)
    end)

    it("onBeforeDestroy is callable without error", function()
      assert.has_no_errors(function()
        Service.IServiceLifecycle:onBeforeDestroy()
      end)
    end)

    it("onAfterDestroy is callable without error", function()
      assert.has_no_errors(function()
        Service.IServiceLifecycle:onAfterDestroy()
      end)
    end)

    it("onSuspend is callable without error", function()
      assert.has_no_errors(function()
        Service.IServiceLifecycle:onSuspend()
      end)
    end)

    it("onResume is callable without error", function()
      assert.has_no_errors(function()
        Service.IServiceLifecycle:onResume()
      end)
    end)
  end)

  describe("ServiceStatus", function()
    it("defines UNREGISTERED status", function()
      assert.equals("unregistered", Service.ServiceStatus.UNREGISTERED)
    end)

    it("defines REGISTERED status", function()
      assert.equals("registered", Service.ServiceStatus.REGISTERED)
    end)

    it("defines INITIALIZING status", function()
      assert.equals("initializing", Service.ServiceStatus.INITIALIZING)
    end)

    it("defines READY status", function()
      assert.equals("ready", Service.ServiceStatus.READY)
    end)

    it("defines SUSPENDED status", function()
      assert.equals("suspended", Service.ServiceStatus.SUSPENDED)
    end)

    it("defines DESTROYING status", function()
      assert.equals("destroying", Service.ServiceStatus.DESTROYING)
    end)

    it("defines DESTROYED status", function()
      assert.equals("destroyed", Service.ServiceStatus.DESTROYED)
    end)

    it("defines ERROR status", function()
      assert.equals("error", Service.ServiceStatus.ERROR)
    end)
  end)

  describe("ServicePriority", function()
    it("defines CRITICAL priority", function()
      assert.equals(0, Service.ServicePriority.CRITICAL)
    end)

    it("defines HIGH priority", function()
      assert.equals(100, Service.ServicePriority.HIGH)
    end)

    it("defines NORMAL priority", function()
      assert.equals(500, Service.ServicePriority.NORMAL)
    end)

    it("defines LOW priority", function()
      assert.equals(900, Service.ServicePriority.LOW)
    end)

    it("defines LAZY priority", function()
      assert.equals(1000, Service.ServicePriority.LAZY)
    end)

    it("has correct priority ordering (CRITICAL < HIGH < NORMAL < LOW < LAZY)", function()
      assert.is_true(Service.ServicePriority.CRITICAL < Service.ServicePriority.HIGH)
      assert.is_true(Service.ServicePriority.HIGH < Service.ServicePriority.NORMAL)
      assert.is_true(Service.ServicePriority.NORMAL < Service.ServicePriority.LOW)
      assert.is_true(Service.ServicePriority.LOW < Service.ServicePriority.LAZY)
    end)
  end)

  describe("module exports", function()
    it("exports IService", function()
      assert.is_table(Service.IService)
    end)

    it("exports IServiceRegistry", function()
      assert.is_table(Service.IServiceRegistry)
    end)

    it("exports IServiceLifecycle", function()
      assert.is_table(Service.IServiceLifecycle)
    end)

    it("exports ServiceStatus", function()
      assert.is_table(Service.ServiceStatus)
    end)

    it("exports ServicePriority", function()
      assert.is_table(Service.ServicePriority)
    end)
  end)

  describe("interfaces export from init", function()
    local Interfaces

    before_each(function()
      package.loaded["whisker.interfaces"] = nil
      package.loaded["whisker.interfaces.service"] = nil
      Interfaces = require("whisker.interfaces")
    end)

    it("exports IService", function()
      assert.is_table(Interfaces.IService)
    end)

    it("exports IServiceRegistry", function()
      assert.is_table(Interfaces.IServiceRegistry)
    end)

    it("exports IServiceLifecycle", function()
      assert.is_table(Interfaces.IServiceLifecycle)
    end)

    it("exports ServiceStatus", function()
      assert.is_table(Interfaces.ServiceStatus)
    end)

    it("exports ServicePriority", function()
      assert.is_table(Interfaces.ServicePriority)
    end)

    it("exports Service module", function()
      assert.is_table(Interfaces.Service)
    end)
  end)
end)
