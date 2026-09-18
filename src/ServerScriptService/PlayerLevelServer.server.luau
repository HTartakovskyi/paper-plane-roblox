-- PlayerLevelServer
-- Paper Plane
--
-- Permanent server lifecycle for:
-- - player arenas
-- - initial level
-- - player world location
--
-- IMPORTANT:
--
-- Gameplay initialization starts ONLY after
-- PlayerDataService confirms successful persistent
-- data loading through DataReady.

local Players =
	game:GetService("Players")


local PlayerDataService =
	require(
		script.Parent:WaitForChild(
			"PlayerDataService"
		)
	)


local PlayerLevelService =
	require(
		script.Parent:WaitForChild(
			"PlayerLevelService"
		)
	)


local PlayerLocationService =
	require(
		script.Parent:WaitForChild(
			"PlayerLocationService"
		)
	)


local ProgressionService =
	require(
		script.Parent:WaitForChild(
			"ProgressionService"
		)
	)


-- =========================================================
-- STATE
--
-- Prevent duplicate setup in case:
-- - DataReady fires
-- - module starts after data is already loaded
-- =========================================================

local initializedPlayers = {}


-- =========================================================
-- SETUP PLAYER
-- =========================================================

local function setupPlayer(
	player
)

	if initializedPlayers[player] then

		return
	end


	if player.Parent ~= Players then

		return
	end


	if not PlayerDataService.IsLoaded(
		player
		) then

		return
	end


	initializedPlayers[player] =
		true


	-- =====================================================
	-- 1. ALLOCATE PRIVATE ARENA
	-- =====================================================

	PlayerLevelService.InitializePlayer(
		player
	)


	-- =====================================================
	-- 2. READ PERSISTENT CURRENT LEVEL
	-- =====================================================

	local levelId =
		ProgressionService.GetCurrentLevelId(
			player
		)


	-- =====================================================
	-- 3. BUILD LEVEL
	-- =====================================================

	PlayerLevelService.BuildLevel(
		player,
		levelId
	)


	-- =====================================================
	-- 4. START LOCATION LIFECYCLE
	-- =====================================================

	PlayerLocationService.InitializePlayer(
		player
	)


	print(
		"PlayerLevelServer: gameplay initialized:",
		player.Name,
		"level",
		levelId
	)
end


-- =========================================================
-- DATA READY
-- =========================================================

PlayerDataService.DataReady:Connect(
	function(player)

		task.spawn(
			setupPlayer,
			player
		)
	end
)


-- =========================================================
-- EXISTING ALREADY-LOADED PLAYERS
--
-- Protects against module initialization ordering:
-- DataReady may theoretically have fired before this
-- script connected.
-- =========================================================

for _, player in ipairs(
	Players:GetPlayers()
	) do

	if PlayerDataService.IsLoaded(
		player
		) then

		task.spawn(
			setupPlayer,
			player
		)
	end
end


-- =========================================================
-- PLAYER REMOVING
-- =========================================================

Players.PlayerRemoving:Connect(
	function(player)

		initializedPlayers[player] =
			nil


		PlayerLocationService.RemovePlayer(
			player
		)


		PlayerLevelService.RemovePlayer(
			player
		)
	end
)


print(
	"PlayerLevelServer started - waiting for DataReady"
)