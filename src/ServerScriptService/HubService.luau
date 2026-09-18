-- HubService
-- Paper Plane
--
-- Shared Factory Hub placement service.
--
-- The Hub itself is a global shared world area.
--
-- This module knows HOW to place a player in the Hub.
-- PlayerLocationService decides WHEN the player belongs there.
--
-- HUB ORIENTATION:
--
-- Player is rotated 180 degrees relative to HubSpawn
-- so that they face the Factory immediately after
-- entering the Hub.

local HubService = {}


-- =========================================================
-- CONFIG
-- =========================================================

local CHARACTER_HEIGHT =
	3


local HUB_ROTATION_Y =
	180


-- =========================================================
-- HUB SPAWN
-- =========================================================

local function getHubSpawn()

	local hubSpawn =
		workspace:FindFirstChild(
			"HubSpawn"
		)


	if not hubSpawn then

		error(
			"HubService: Workspace.HubSpawn not found"
		)
	end


	if not hubSpawn:IsA("BasePart") then

		error(
			"HubService: HubSpawn must be a BasePart"
		)
	end


	return hubSpawn
end


-- =========================================================
-- PLACE PLAYER
-- =========================================================

function HubService.PlacePlayer(
	player,
	character
)

	character =
		character
		or player.Character


	if not character
		or not character.Parent
	then

		return false
	end


	local humanoid =
		character:
		FindFirstChildOfClass(
			"Humanoid"
		)


	local rootPart =
		character:FindFirstChild(
			"HumanoidRootPart"
		)


	if not humanoid
		or not rootPart
	then

		return false
	end


	if humanoid.Health <= 0 then

		return false
	end


	local hubSpawn =
		getHubSpawn()


	-- =====================================================
	-- POSITION
	-- =====================================================

	local targetPosition =
		hubSpawn.Position
		+
		Vector3.new(
			0,
			hubSpawn.Size.Y / 2
			+ CHARACTER_HEIGHT,
			0
		)


	-- =====================================================
	-- ORIENTATION
	--
	-- Preserve HubSpawn horizontal orientation,
	-- then rotate player 180 degrees so the character
	-- faces the Factory.
	-- =====================================================

	local targetCFrame =
		CFrame.new(
			targetPosition
		)
		*
		CFrame.Angles(
			0,
			math.rad(
				hubSpawn.Orientation.Y
				+ HUB_ROTATION_Y
			),
			0
		)


	-- =====================================================
	-- RESET MOTION
	-- =====================================================

	rootPart.AssemblyLinearVelocity =
		Vector3.zero


	rootPart.AssemblyAngularVelocity =
		Vector3.zero


	-- =====================================================
	-- MOVE CHARACTER
	-- =====================================================

	rootPart.CFrame =
		targetCFrame


	print(
		"Player moved to HUB:",
		player.Name
	)


	return true
end


return HubService