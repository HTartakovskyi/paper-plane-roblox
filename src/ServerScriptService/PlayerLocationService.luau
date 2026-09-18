-- PlayerLocationService
-- Paper Plane
--
-- SINGLE SERVER AUTHORITY FOR CHARACTER LOCATION.
--
-- Supported locations:
--
-- ARENA
-- HUB
--
-- Responsibilities:
-- - own CharacterAdded
-- - remember where player belongs
-- - route respawn
-- - move player to Arena
-- - move player to shared Hub
-- - react to level rebuilds
-- - notify server observers when location changes
-- - keep ARENA players inside their own private arena
-- - register real HUB visits for analytics
--
-- IMPORTANT:
--
-- Location changes are COMMITTED only after
-- successful character placement.

local Players =
	game:GetService("Players")


local PlayerLocationService = {}


-- =========================================================
-- MODULES
-- =========================================================

local PlayerLevelService =
	require(
		script.Parent:WaitForChild(
			"PlayerLevelService"
		)
	)


local HubService =
	require(
		script.Parent:WaitForChild(
			"HubService"
		)
	)


local AnalyticsService =
	require(
		script.Parent:WaitForChild(
			"AnalyticsService"
		)
	)


-- =========================================================
-- LOCATION TYPES
-- =========================================================

local LOCATION_ARENA =
	"ARENA"


local LOCATION_HUB =
	"HUB"


-- =========================================================
-- PUBLIC CONSTANTS
-- =========================================================

PlayerLocationService.LOCATION_ARENA =
	LOCATION_ARENA


PlayerLocationService.LOCATION_HUB =
	LOCATION_HUB


-- =========================================================
-- ARENA BOUNDARY CONFIG
-- =========================================================

local ARENA_BOUNDARY_CHECK_INTERVAL =
	0.20


local ARENA_BOUNDARY_MARGIN =
	4


local ARENA_MIN_Y =
	-25


local ARENA_RETURN_COOLDOWN =
	1.0


-- =========================================================
-- STATE
-- =========================================================

local playerStates = {}


-- =========================================================
-- CHANGED EVENT
-- =========================================================

local changedBindable =
	Instance.new(
		"BindableEvent"
	)


PlayerLocationService.Changed =
	changedBindable.Event


-- =========================================================
-- PLACE CHARACTER FOR LOCATION
-- =========================================================

local function placeCharacterForLocation(
	player,
	character,
	location
)

	if location
		== LOCATION_ARENA
	then

		return
			PlayerLevelService.PlacePlayerAtCurrentLevel(
				player,
				character
			)
	end


	if location
		== LOCATION_HUB
	then

		return
			HubService.PlacePlayer(
				player,
				character
			)
	end


	warn(
		"PlayerLocationService: unknown location:",
		location
	)


	return false
end


-- =========================================================
-- PLACE CURRENT LOCATION
-- =========================================================

local function placeCharacter(
	player,
	character
)

	local state =
		playerStates[player]


	if not state then

		return false
	end


	return
		placeCharacterForLocation(
			player,
			character,
			state.Location
		)
end


-- =========================================================
-- HANDLE CHARACTER
-- =========================================================

local function handleCharacterAdded(
	player,
	character
)

	task.spawn(
		function()

			local humanoid =
				character:WaitForChild(
					"Humanoid",
					10
				)


			local rootPart =
				character:WaitForChild(
					"HumanoidRootPart",
					10
				)


			if not humanoid
				or not rootPart
			then

				return
			end


			task.wait()


			placeCharacter(
				player,
				character
			)
		end
	)
end


-- =========================================================
-- INITIALIZE PLAYER
-- =========================================================

function PlayerLocationService.InitializePlayer(
	player
)

	local existing =
		playerStates[player]


	if existing then

		return existing
	end


	local state = {

		Location =
			LOCATION_ARENA,

		CharacterAddedConnection =
			nil,

		LastArenaCorrectionTime =
			0,
	}


	playerStates[player] =
		state


	state.CharacterAddedConnection =
		player.CharacterAdded:Connect(
			function(character)

				handleCharacterAdded(
					player,
					character
				)
			end
		)


	if player.Character then

		handleCharacterAdded(
			player,
			player.Character
		)
	end


	print(
		"Player location initialized:",
		player.Name,
		LOCATION_ARENA
	)


	return state
end


-- =========================================================
-- GET LOCATION
-- =========================================================

function PlayerLocationService.GetLocation(
	player
)

	local state =
		playerStates[player]


	if not state then

		return nil
	end


	return
		state.Location
end


-- =========================================================
-- IS IN ARENA
-- =========================================================

function PlayerLocationService.IsInArena(
	player
)

	return
		PlayerLocationService.GetLocation(
			player
		)
		== LOCATION_ARENA
end


-- =========================================================
-- IS IN HUB
-- =========================================================

function PlayerLocationService.IsInHub(
	player
)

	return
		PlayerLocationService.GetLocation(
			player
		)
		== LOCATION_HUB
end


-- =========================================================
-- CHANGE LOCATION
-- =========================================================

local function changeLocation(
	player,
	newLocation
)

	local state =
		playerStates[player]


	if not state then

		state =
			PlayerLocationService.InitializePlayer(
				player
			)
	end


	if state.Location
		== newLocation
	then

		return
			placeCharacterForLocation(
				player,
				player.Character,
				newLocation
			)
	end


	local oldLocation =
		state.Location


	local moved =
		placeCharacterForLocation(
			player,
			player.Character,
			newLocation
		)


	if not moved then

		warn(
			"PlayerLocationService: failed to move player:",
			player.Name,
			oldLocation,
			"->",
			newLocation
		)


		return false
	end


	state.Location =
		newLocation


	state.LastArenaCorrectionTime =
		0


	print(
		"Player location changed:",
		player.Name,
		oldLocation,
		"->",
		newLocation
	)


	changedBindable:Fire(
		player,
		newLocation,
		oldLocation
	)


	-- =====================================================
	-- ANALYTICS
	--
	-- Count only a REAL transition into HUB.
	--
	-- Respawning while already in HUB does not add
	-- another visit.
	-- =====================================================

	if newLocation == LOCATION_HUB
		and oldLocation ~= LOCATION_HUB
	then

		AnalyticsService.RegisterHubVisit(
			player
		)
	end


	return true
end


-- =========================================================
-- GO TO ARENA
-- =========================================================

function PlayerLocationService.GoToArena(
	player
)

	return
		changeLocation(
			player,
			LOCATION_ARENA
		)
end


-- =========================================================
-- GO TO HUB
-- =========================================================

function PlayerLocationService.GoToHub(
	player
)

	return
		changeLocation(
			player,
			LOCATION_HUB
		)
end


-- =========================================================
-- LEVEL REBUILT
-- =========================================================

PlayerLevelService.LevelBuilt:Connect(
	function(
		player,
		levelId,
		revision
	)

		local state =
			playerStates[player]


		if not state then

			return
		end


		if state.Location
			~= LOCATION_ARENA
		then

			return
		end


		if not player.Character then

			return
		end


		placeCharacter(
			player,
			player.Character
		)
	end
)


-- =========================================================
-- ARENA BOUNDARY CHECK
-- =========================================================

local function checkArenaBoundary(
	player,
	state
)

	if state.Location
		~= LOCATION_ARENA
	then

		return
	end


	local character =
		player.Character


	if not character
		or not character.Parent
	then

		return
	end


	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)


	local rootPart =
		character:FindFirstChild(
			"HumanoidRootPart"
		)


	if not humanoid
		or not rootPart
	then

		return
	end


	if humanoid.Health <= 0 then

		return
	end


	local arenaFloor =
		PlayerLevelService.GetArenaFloor(
			player
		)


	if not arenaFloor
		or not arenaFloor.Parent
	then

		return
	end


	local position =
		rootPart.Position


	local halfX =
		arenaFloor.Size.X / 2


	local halfZ =
		arenaFloor.Size.Z / 2


	local minX =
		arenaFloor.Position.X
	- halfX
	- ARENA_BOUNDARY_MARGIN


	local maxX =
		arenaFloor.Position.X
		+ halfX
		+ ARENA_BOUNDARY_MARGIN


	local minZ =
		arenaFloor.Position.Z
	- halfZ
	- ARENA_BOUNDARY_MARGIN


	local maxZ =
		arenaFloor.Position.Z
		+ halfZ
		+ ARENA_BOUNDARY_MARGIN


	local outsideXZ =
		position.X < minX
		or position.X > maxX
		or position.Z < minZ
		or position.Z > maxZ


	local belowArena =
		position.Y
		< ARENA_MIN_Y


	if not outsideXZ
		and not belowArena
	then

		return
	end


	local now =
		time()


	if now
		- state.LastArenaCorrectionTime
			< ARENA_RETURN_COOLDOWN
	then

		return
	end


	state.LastArenaCorrectionTime =
		now


	local reason


	if belowArena then

		reason =
			"FELL_BELOW_ARENA"

	else

		reason =
			"LEFT_ARENA_BOUNDS"
	end


	local moved =
		PlayerLevelService.PlacePlayerAtCurrentLevel(
			player
		)


	if moved then

		print(
			"PlayerLocationService: player returned to arena:",
			player.Name,
			reason
		)

	else

		warn(
			"PlayerLocationService: failed arena boundary correction:",
			player.Name,
			reason
		)
	end
end


-- =========================================================
-- ARENA BOUNDARY WATCHDOG
-- =========================================================

task.spawn(
	function()

		while true do

			task.wait(
				ARENA_BOUNDARY_CHECK_INTERVAL
			)


			for player, state in pairs(
				playerStates
				) do

				if player.Parent
					== Players
				then

					checkArenaBoundary(
						player,
						state
					)
				end
			end
		end
	end
)


-- =========================================================
-- REMOVE PLAYER
-- =========================================================

function PlayerLocationService.RemovePlayer(
	player
)

	local state =
		playerStates[player]


	if not state then

		return
	end


	if state.CharacterAddedConnection then

		state.CharacterAddedConnection:
			Disconnect()


		state.CharacterAddedConnection =
			nil
	end


	playerStates[player] =
		nil
end


return PlayerLocationService