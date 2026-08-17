--!strict

local RemoteContracts = require(game:GetService("ReplicatedStorage").Shared.RemoteContracts)

local SmokeBomb = {}

function SmokeBomb.OnLaunch(context, payload)
	local remote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients({
			EventType = "EquipmentVFX",
			Payload = {
				Effect = "SmokeBomb",
				Player = context.player,
				Launch = payload,
			},
		})
	end
end

function SmokeBomb.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end
function SmokeBomb.OnTick(_context, _dt: number) end
function SmokeBomb.OnAttack(_context, _payload: any) end

return SmokeBomb
