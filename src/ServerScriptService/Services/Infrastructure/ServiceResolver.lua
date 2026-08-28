--!strict

-- Centralizes all cross-service access so callers only depend on ServiceRegistry.
local ServiceResolver = {}

export type Context = {
	ServiceRegistry: any?,
}

local function getRegistry(context: Context): any?
	local registry = context.ServiceRegistry
	if registry == nil then
		warn("[ServiceResolver] ServiceRegistry is unavailable.")
	end
	return registry
end

function ServiceResolver.Get(context: Context, name: string): any
	local registry = getRegistry(context)
	return registry and registry:GetOptional(name)
end

function ServiceResolver.Require(context: Context, name: string, requiredMethods: { string }?): any
	local registry = getRegistry(context)
	if registry == nil then
		return nil
	end

	local service = registry:Get(name)
	if service == nil then
		return nil
	end

	for _, methodName in ipairs(requiredMethods or {}) do
		if registry:RequireMethod(name, methodName) == nil then
			return nil
		end
	end

	return service
end

function ServiceResolver.RequireMethod(context: Context, name: string, methodName: string): ((...any) -> any)?
	local registry = getRegistry(context)
	if registry == nil then
		return nil
	end
	return registry:RequireMethod(name, methodName)
end

return ServiceResolver
