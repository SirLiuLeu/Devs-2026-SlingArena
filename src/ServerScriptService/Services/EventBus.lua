--!strict

local EventBus = {}
EventBus.__index = EventBus

export type EventBusType = {
	On: (self: EventBusType, eventName: string, callback: (...any) -> ()) -> RBXScriptConnection,
	Fire: (self: EventBusType, eventName: string, ...any) -> (),
	Destroy: (self: EventBusType) -> (),
}

function EventBus.new(): EventBusType
	local self = setmetatable({}, EventBus)
	self._events = {}
	return self :: any
end

function EventBus:On(eventName: string, callback: (...any) -> ())
	local bindable = self._events[eventName]
	if not bindable then
		bindable = Instance.new("BindableEvent")
		self._events[eventName] = bindable
	end
	return bindable.Event:Connect(callback)
end

function EventBus:Fire(eventName: string, ...: any)
	local bindable = self._events[eventName]
	if bindable then
		bindable:Fire(...)
	end
end

function EventBus:Destroy()
	for _, bindable in pairs(self._events) do
		bindable:Destroy()
	end
	table.clear(self._events)
end

return EventBus
