-- PlayerLevelService
-- Paper Plane
--
-- Owns server-side player arenas.
--
-- Workspace
-- └─ PlayerLevels
--    └─ <UserId>
--       ├─ ArenaFloor
--       └─ GeneratedLevel
--
-- Responsibilities:
-- - allocate independent arena slot
-- - calculate WorldOffset
-- - create player level container
-- - create personal ArenaFloor
-- - build server-owned level geometry
-- - manage BuildRevision
-- - activate server StartZone service
-- - provide arena placement function
-- - notify PlayerLocationService when level is rebuilt
--
-- IMPORTANT:
--
-- PlayerLevelService knows HOW to place a player
-- on the current arena StartZone.
--
-- PlayerLocationService decides WHEN that placement
-- should happen and whether the player currently
-- belongs in ARENA or HUB.
--
-- PlayerLevelService does NOT subscribe to CharacterAdded.

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlayerLevelService = {}


-- =========================================================
-- MODULES
-- =========================================================

local LevelSystem =
	ReplicatedStorage:WaitForChild(
		"LevelSystem"
	)


local LevelConfig =
	require(
		LevelSystem:WaitForChild(
			"LevelConfig"
		)
	)


local LevelBuilder =
	require(
		LevelSystem:WaitForChild(
			"LevelBuilder"
		)
	)


local ServerStartZoneService =
	require(
		script.Parent:WaitForChild(
			"ServerStartZoneService"
		)
	)


-- =========================================================
-- ARENA CONFIG
-- =========================================================

-- Distance between centers of neighboring player arenas.

local ARENA_SPACING =
	500


-- First private arena is moved away from
-- the shared Factory / Hub.
--
-- Slot 0 -> Z = 1500
-- Slot 1 -> Z = 2000
-- Slot 2 -> Z = 2500
-- etc.

local ARENA_BASE_Z =
	1500


-- =========================================================
-- ARENA FLOOR
--
-- 450 studs wide in Z with 500 studs between
-- arena centers leaves a 50-stud empty gap.
--
-- X center = 150 gives the gameplay level plenty
-- of usable space in the main flight direction.
--
-- Floor top surface:
--
-- Position.Y = -0.5
-- Size.Y     = 1
--
-- therefore top surface is exactly Y = 0.
-- =========================================================

local ARENA_FLOOR_SIZE =
	Vector3.new(
		450,
		1,
		450
	)


local ARENA_FLOOR_LOCAL_POSITION =
	Vector3.new(
		150,
		-0.5,
		0
	)


-- HumanoidRootPart height above the top
-- surface of StartZone.

local CHARACTER_START_HEIGHT =
	3


-- =========================================================
-- SLOT -> WORLD OFFSET
-- =========================================================

local function getOffsetForSlot(
	slot
)

	return
		Vector3.new(
			0,
			0,
			ARENA_BASE_Z
			+ slot * ARENA_SPACING
		)
end


-- =========================================================
-- LEVEL BUILT EVENT
--
-- PlayerLocationService subscribes to this event.
--
-- Arguments:
-- player
-- levelId
-- revision
-- =========================================================

local levelBuiltEvent =
	Instance.new(
		"BindableEvent"
	)


PlayerLevelService.LevelBuilt =
	levelBuiltEvent.Event


-- =========================================================
-- ROOT CONTAINER
-- =========================================================

local playerLevelsFolder =
	workspace:FindFirstChild(
		"PlayerLevels"
	)


if not playerLevelsFolder then

	playerLevelsFolder =
		Instance.new(
			"Folder"
		)


	playerLevelsFolder.Name =
		"PlayerLevels"


	playerLevelsFolder.Parent =
		workspace
end


-- =========================================================
-- STATE
-- =========================================================

local playerStates = {}


local usedSlots = {}


-- =========================================================
-- SLOT MANAGEMENT
-- =========================================================

local function acquireSlot()

	local slot =
		0


	while usedSlots[slot] do

		slot +=
			1
	end


	usedSlots[slot] =
		true


	return slot
end


local function releaseSlot(
	slot
)

	if slot == nil then

		return
	end


	usedSlots[slot] =
		nil
end


-- =========================================================
-- PLAYER CONTAINER
-- =========================================================

local function createPlayerContainer(
	player
)

	local name =
		tostring(
			player.UserId
		)


	local oldContainer =
		playerLevelsFolder:FindFirstChild(
			name
		)


	if oldContainer then

		oldContainer:Destroy()
	end


	local container =
		Instance.new(
			"Folder"
		)


	container.Name =
		name


	container:SetAttribute(
		"UserId",
		player.UserId
	)


	container:SetAttribute(
		"BuildRevision",
		0
	)


	container.Parent =
		playerLevelsFolder


	return container
end


-- =========================================================
-- CREATE ARENA FLOOR
--
-- Floor belongs to the player's arena, not to a
-- particular level.
--
-- Therefore it is created once when the player's
-- arena is initialized and survives level rebuilds.
-- =========================================================

local function createArenaFloor(
	container,
	worldOffset
)

	local oldFloor =
		container:FindFirstChild(
			"ArenaFloor"
		)


	if oldFloor then

		oldFloor:Destroy()
	end


	local floor =
		Instance.new(
			"Part"
		)


	floor.Name =
		"ArenaFloor"


	floor.Anchored =
		true


	floor.CanCollide =
		true


	floor.CanTouch =
		true


	floor.CanQuery =
		true


	floor.Size =
		ARENA_FLOOR_SIZE


	floor.Position =
		ARENA_FLOOR_LOCAL_POSITION
		+ worldOffset


	floor.Material =
		Enum.Material.Concrete


	floor.Color =
		Color3.fromRGB(
			105,
			110,
			120
		)


	floor.TopSurface =
		Enum.SurfaceType.Smooth


	floor.BottomSurface =
		Enum.SurfaceType.Smooth


	floor.Parent =
		container


	return floor
end


-- =========================================================
-- PLACE CHARACTER ON CURRENT START ZONE
--
-- IMPORTANT:
--
-- This function performs physical placement only.
--
-- It does NOT decide whether the player should currently
-- be in ARENA or HUB.
--
-- That decision belongs to PlayerLocationService.
-- =========================================================

local function placeCharacterOnStartZone(
	player,
	character
)

	local state =
		playerStates[player]


	if not state then

		return false
	end


	if not state.Runtime then

		return false
	end


	local startZone =
		state.Runtime.StartZone


	if not startZone
		or not startZone.Parent
	then

		return false
	end


	character =
		character
		or player.Character


	if not character
		or not character.Parent
	then

		return false
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

		return false
	end


	if humanoid.Health <= 0 then

		return false
	end


	-- =====================================================
	-- TARGET POSITION
	--
	-- StartZone.CFrame already contains:
	-- - level coordinates
	-- - arena WorldOffset
	-- - level rotation
	-- =====================================================

	local targetCFrame =
		startZone.CFrame
		*
		CFrame.new(
			0,
			startZone.Size.Y / 2
			+ CHARACTER_START_HEIGHT,
			0
		)


	-- Remove any movement left from spawn or physics.

	rootPart.AssemblyLinearVelocity =
		Vector3.zero


	rootPart.AssemblyAngularVelocity =
		Vector3.zero


	rootPart.CFrame =
		targetCFrame


	print(
		"Player placed on arena StartZone:",
		player.Name,
		"slot",
		state.Slot,
		"level",
		state.LevelId,
		"offset",
		state.WorldOffset
	)


	return true
end


-- =========================================================
-- INITIALIZE PLAYER
-- =========================================================

function PlayerLevelService.InitializePlayer(
	player
)

	local existing =
		playerStates[player]


	if existing then

		return existing
	end


	local slot =
		acquireSlot()


	local worldOffset =
		getOffsetForSlot(
			slot
		)


	local container =
		createPlayerContainer(
			player
		)


	local arenaFloor =
		createArenaFloor(
			container,
			worldOffset
		)


	local state = {

		Player =
			player,

		Slot =
			slot,

		WorldOffset =
			worldOffset,

		Container =
			container,

		ArenaFloor =
			arenaFloor,

		Runtime =
			nil,

		LevelId =
			nil,

		BuildRevision =
			0,
	}


	playerStates[player] =
		state


	print(
		"Player arena allocated:",
		player.Name,
		"slot",
		slot,
		"offset",
		worldOffset,
		"floor position",
		arenaFloor.Position
	)


	return state
end


-- =========================================================
-- GET STATE
-- =========================================================

function PlayerLevelService.GetState(
	player
)

	return
		playerStates[player]
end


-- =========================================================
-- GET WORLD OFFSET
-- =========================================================

function PlayerLevelService.GetWorldOffset(
	player
)

	local state =
		playerStates[player]


	if not state then

		state =
			PlayerLevelService.InitializePlayer(
				player
			)
	end


	return
		state.WorldOffset
end


-- =========================================================
-- GET BUILD REVISION
-- =========================================================

function PlayerLevelService.GetBuildRevision(
	player
)

	local state =
		playerStates[player]


	if not state then

		return 0
	end


	return
		state.BuildRevision
end


-- =========================================================
-- BUILD LEVEL
-- =========================================================

function PlayerLevelService.BuildLevel(
	player,
	levelId
)

	local state =
		playerStates[player]


	if not state then

		state =
			PlayerLevelService.InitializePlayer(
				player
			)
	end


	local config =
		LevelConfig.GetLevel(
			levelId
		)


	-- =====================================================
	-- STOP OLD START ZONE
	-- =====================================================

	ServerStartZoneService.Stop(
		player
	)


	-- =====================================================
	-- NEW BUILD REVISION
	-- =====================================================

	state.BuildRevision +=
		1


	local revision =
		state.BuildRevision


	-- =====================================================
	-- BUILD SERVER-OWNED LEVEL
	-- =====================================================

	local runtime =
		LevelBuilder.Build(
			config,
			state.Container,
			state.WorldOffset
		)


	runtime.BuildRevision =
		revision


	runtime.Model:SetAttribute(
		"BuildRevision",
		revision
	)


	runtime.Model:SetAttribute(
		"LevelId",
		levelId
	)


	-- =====================================================
	-- UPDATE STATE
	-- =====================================================

	state.Runtime =
		runtime


	state.LevelId =
		levelId


	state.Container:SetAttribute(
		"CurrentLevelId",
		levelId
	)


	state.Container:SetAttribute(
		"BuildRevision",
		revision
	)


	-- =====================================================
	-- START ZONE
	-- =====================================================

	ServerStartZoneService.Activate(
		player,
		runtime,
		config
	)


	-- =====================================================
	-- NOTIFY LOCATION SYSTEM
	--
	-- PlayerLocationService decides whether the
	-- character should actually be moved.
	--
	-- If the player is currently in HUB, it can leave
	-- the character there.
	--
	-- If the player is in ARENA, it can call:
	--
	-- PlayerLevelService.PlacePlayerAtCurrentLevel()
	-- =====================================================

	levelBuiltEvent:Fire(
		player,
		levelId,
		revision
	)


	print(
		"Server level built:",
		player.Name,
		levelId,
		config.Name,
		"slot",
		state.Slot,
		"offset",
		state.WorldOffset,
		"revision",
		revision
	)


	return
		runtime,
		revision
end


-- =========================================================
-- PLACE PLAYER AT CURRENT LEVEL
--
-- Public API used by PlayerLocationService.
--
-- PlayerLocationService owns the location decision.
-- PlayerLevelService owns knowledge of arena geometry.
-- =========================================================

function PlayerLevelService.PlacePlayerAtCurrentLevel(
	player
)

	return
		placeCharacterOnStartZone(
			player,
			player.Character
		)
end


-- =========================================================
-- GET RUNTIME
-- =========================================================

function PlayerLevelService.GetRuntime(
	player
)

	local state =
		playerStates[player]


	if not state then

		return nil
	end


	return
		state.Runtime
end


-- =========================================================
-- GET LEVEL ID
-- =========================================================

function PlayerLevelService.GetLevelId(
	player
)

	local state =
		playerStates[player]


	if not state then

		return nil
	end


	return
		state.LevelId
end


-- =========================================================
-- GET CONTAINER
-- =========================================================

function PlayerLevelService.GetContainer(
	player
)

	local state =
		playerStates[player]


	if not state then

		return nil
	end


	return
		state.Container
end


-- =========================================================
-- GET ARENA FLOOR
-- =========================================================

function PlayerLevelService.GetArenaFloor(
	player
)

	local state =
		playerStates[player]


	if not state then

		return nil
	end


	return
		state.ArenaFloor
end


-- =========================================================
-- CAN LAUNCH
-- =========================================================

function PlayerLevelService.CanLaunch(
	player
)

	return
		ServerStartZoneService.CanLaunch(
			player
		)
end


-- =========================================================
-- REMOVE PLAYER
-- =========================================================

function PlayerLevelService.RemovePlayer(
	player
)

	local state =
		playerStates[player]


	if not state then

		return
	end


	ServerStartZoneService.Stop(
		player
	)


	-- Destroying the player container automatically
	-- destroys both:
	--
	-- ArenaFloor
	-- GeneratedLevel

	if state.Container
		and state.Container.Parent
	then

		state.Container:Destroy()
	end


	releaseSlot(
		state.Slot
	)


	playerStates[player] =
		nil
end


return PlayerLevelService