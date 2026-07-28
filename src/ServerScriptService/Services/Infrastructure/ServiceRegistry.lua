--!strict

local ServiceRegistry = {}
ServiceRegistry.__index = ServiceRegistry

export type ServiceRegistryType = {
	Register: (self: ServiceRegistryType, name: string, service: any) -> (),
	Get: (self: ServiceRegistryType, name: string) -> any,
	GetOptional: (self: ServiceRegistryType, name: string) -> any,
	RequireMethod: (self: ServiceRegistryType, name: string, methodName: string) -> ((...any) -> any)?,
}

function ServiceRegistry.new(): ServiceRegistryType
	local self = setmetatable({}, ServiceRegistry)
	self._services = {}
	self._warnedMissing = {}
	self._warnedMethod = {}
	return self :: any
end

function ServiceRegistry:Register(name: string, service: any)
	self._services[name] = service
end

function ServiceRegistry:GetOptional(name: string)
	return self._services[name]
end

function ServiceRegistry:Get(name: string)
	local service = self._services[name]
	if service == nil and not self._warnedMissing[name] then
		self._warnedMissing[name] = true
		warn(string.format("[ServiceRegistry] Missing service '%s'.", name))
	end
	return service
end

function ServiceRegistry:RequireMethod(name: string, methodName: string)
	local service = self:Get(name)
	if service == nil then
		return nil
	end
	local method = service[methodName]
	if typeof(method) ~= "function" then
		local key = string.format("%s.%s", name, methodName)
		if not self._warnedMethod[key] then
			self._warnedMethod[key] = true
			warn(string.format("[ServiceRegistry] Service '%s' missing method '%s'.", name, methodName))
		end
		return nil
	end
	return function(...)
		return method(service, ...)
	end
end

return ServiceRegistry
