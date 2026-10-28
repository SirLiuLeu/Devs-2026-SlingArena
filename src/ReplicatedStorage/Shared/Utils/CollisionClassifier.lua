--!strict

local CollectionService = game:GetService("CollectionService")

export type CollisionType = "Wall" | "Ground" | "Food" | "Lava" | "Trap"

local TAG_TO_TYPE: { [string]: CollisionType } = {
	Collision_Wall = "Wall",
	Collision_Ground = "Ground",
	Collision_Food = "Food",
	Collision_Lava = "Lava",
	Collision_Trap = "Trap",
}

-- If multiple collision tags are accidentally assigned to the same Instance,
-- prefer gameplay-specific/safety types over generic Wall classification.
local TAG_PRIORITY = {
	"Collision_Food",
	"Collision_Lava",
	"Collision_Trap",
	"Collision_Ground",
	"Collision_Wall",
}

local CollisionClassifier = {}

-- Finds the closest tagged ancestor, so a tag on a child MeshPart can override
-- a broader tag on its containing Model. Tags are not inherited by Roblox itself.
function CollisionClassifier.GetType(instance: Instance): (CollisionType?, Instance?)
	local cursor: Instance? = instance
	while cursor do
		for _, tag in ipairs(TAG_PRIORITY) do
			if CollectionService:HasTag(cursor, tag) then
				return TAG_TO_TYPE[tag], cursor
			end
		end
		cursor = cursor.Parent
	end

	return nil, nil
end

return CollisionClassifier
