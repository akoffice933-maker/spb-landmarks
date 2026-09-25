--!strict
--[[
	Минимальная реализация сигнала (без внешних зависимостей).
	Нужна для внутренних событий сервисов: PlayerDataService.DataChanged,
	ZoneService.PlayerEntered и т.д.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
	_fn: (...any) -> (),
	_signal: any,
	_index: number?,
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Wait: (self: Signal) -> ...any,
	Fire: (self: Signal, ...any) -> (),
	Destroy: (self: Signal) -> (),
	GetConnectionCount: (self: Signal) -> number,
	_connections: { Connection },
}

function Signal.new(): Signal
	local self = setmetatable({
		_connections = {},
	}, Signal)
	return self :: any
end

function Signal:Connect(fn: (...any) -> ()): Connection
	assert(typeof(fn) == "function", "Signal:Connect ожидает функцию")

	local connection: Connection = {
		Connected = true,
		_fn = fn,
		_signal = self,
		_index = nil,
	} :: any

	-- selene: allow(shadowing)
	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local parentSignal = self._signal :: Signal
		local index = self._index
		if index then
			table.remove(parentSignal._connections, index)
		end
		-- Индексы остальных соединений сдвинулись — пересчитываем
		for i, other in ipairs(parentSignal._connections) do
			other._index = i
		end
	end

	table.insert(self._connections, connection)
	connection._index = #self._connections
	return connection
end

function Signal:Once(fn: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...: any)
		if connection.Connected then
			connection:Disconnect()
		end
		fn(...)
	end)
	return connection
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local args: { any }? = nil
	local connection
	connection = self:Once(function(...: any)
		args = { ... }
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread)
		end
	end)
	if connection and not connection.Connected then
		-- Сигнал уже отработал (маловероятно, но пусть будет безопасно)
		return
	end
	coroutine.yield()
	return table.unpack(args :: { any })
end

function Signal:Fire(...: any)
	-- Копируем: обработчик может отписаться прямо во время вызова
	local connections = table.clone(self._connections)
	for _, connection in ipairs(connections) do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal:GetConnectionCount(): number
	return #self._connections
end

function Signal:Destroy()
	for _, connection in ipairs(self._connections) do
		connection.Connected = false
	end
	table.clear(self._connections)
end

return Signal
