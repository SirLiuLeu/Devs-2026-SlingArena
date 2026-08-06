--!strict

export type PlayerData = { [string]: any }

export type IDataProvider = {
	LoadPlayerData: (self: IDataProvider, player: Player, defaultData: PlayerData) -> PlayerData,
	SavePlayerData: (self: IDataProvider, player: Player, data: PlayerData) -> boolean,
	GetPlayerData: (self: IDataProvider, player: Player) -> PlayerData?,
	UpdatePlayerData: (self: IDataProvider, player: Player, updater: (PlayerData) -> PlayerData?) -> PlayerData?,
	ClearPlayerData: (self: IDataProvider, player: Player) -> (),
}

return {}
